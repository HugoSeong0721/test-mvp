#!/usr/bin/env python3
"""Fetch new TCM syndrome-differentiation / adaptive-inquiry research papers.

This script queries free, no-auth academic APIs (arXiv + Europe PMC, which
covers PubMed/MEDLINE) for papers related to the research directions tracked in
ADAPTIVE_TCM_INQUIRY_NOTES.md, deduplicates them against everything collected so
far, and accumulates the new ones into research/papers.json.

It has NO third-party dependencies (standard library only) so it can run in a
bare GitHub Actions runner without a pip install step.

Design goals:
- Idempotent: running it twice in a row adds nothing the second time.
- Additive: papers are only appended, never removed, so the JSON store grows
  into a durable research corpus you can use as a source for the diagnosis app.
- Transparent: a human-readable catalog (research/papers.md) is regenerated on
  every run so you can browse what has been collected without opening the JSON.
"""

from __future__ import annotations

import datetime as _dt
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #

ROOT = Path(__file__).resolve().parent.parent
RESEARCH_DIR = ROOT / "research"
PAPERS_JSON = RESEARCH_DIR / "papers.json"
PAPERS_MD = RESEARCH_DIR / "papers.md"
QUERIES_FILE = RESEARCH_DIR / "queries.txt"

# How many results to request per query per source.
MAX_PER_QUERY = 25
# Politeness delay between API calls (seconds).
REQUEST_DELAY = 1.0
# Network timeout (seconds).
TIMEOUT = 30
# A contact email helps API providers reach you about heavy usage; harmless if
# left as-is. Europe PMC and arXiv both recommend a descriptive User-Agent.
USER_AGENT = "test-mvp-tcm-paper-collector/1.0 (https://github.com/HugoSeong0721/test-mvp)"

# Default search queries covering the three research directions described in
# ADAPTIVE_TCM_INQUIRY_NOTES.md. You can override/extend these by editing
# research/queries.txt (one query per line, '#' comments allowed).
# Relevance gate. A fetched paper is kept only if its title or abstract
# contains at least one of these anchor terms. This filters out the noise that
# broad keyword search (especially arXiv) otherwise pulls in — unrelated recent
# physics/ML papers, tangential biomedical results, and so on. Terms are matched
# case-insensitively as substrings, so "acupunctur" also catches "acupuncture".
RELEVANCE_ANCHORS = [
    # Core TCM
    "chinese medicine",
    "tcm",
    "syndrome differ",  # syndrome differentiation
    "zheng differentiation",
    "acupunctur",
    "tongue diagnos",
    "tongue image",
    "pulse diagnos",
    "body constitution",
    "herbal medicine",
    "materia medica",
    "meridian",
    "traditional medicine",
    "traditional korean medicine",
    "kampo",
    "辨证",
    "中医",
    "中醫",
    # Adaptive medical inquiry / decision support (kept intentionally — see notes)
    "medical inquiry",
    "symptom inquiry",
    "adaptive questioning",
    "clinical decision support",
    "differential diagnosis",
]


def is_relevant(rec: dict) -> bool:
    haystack = f"{rec.get('title', '')} {rec.get('abstract', '')}".lower()
    return any(anchor in haystack for anchor in RELEVANCE_ANCHORS)


DEFAULT_QUERIES = [
    # 1. Decision tree & adaptive symptom selection
    "traditional chinese medicine syndrome differentiation decision tree",
    "TCM body constitution classification machine learning",
    "adaptive symptom questionnaire traditional chinese medicine",
    # 2. Dynamic QA & adaptive dialogue
    "traditional chinese medicine dynamic questioning diagnosis",
    "active medical inquiry reinforcement learning diagnosis",
    "large language model traditional chinese medicine diagnosis dialogue",
    "tongue image constitution reasoning language model",
    # 3. Knowledge graph & chain-of-thought
    "traditional chinese medicine knowledge graph syndrome differentiation",
    "chain of thought reasoning traditional chinese medicine",
    "TCM clinical decision support syndrome differentiation",
    # Cross-cutting
    "multi-label symptom syndrome classification traditional chinese medicine",
]


# --------------------------------------------------------------------------- #
# Utilities
# --------------------------------------------------------------------------- #

def today() -> str:
    return _dt.date.today().isoformat()


def http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read()


def normalize_title(title: str) -> str:
    """Lowercase, strip punctuation/whitespace — used as a fallback dedup key."""
    return re.sub(r"[^a-z0-9]+", "", (title or "").lower())


def load_queries() -> list[str]:
    if QUERIES_FILE.exists():
        lines = []
        for raw in QUERIES_FILE.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if line:
                lines.append(line)
        if lines:
            return lines
    return DEFAULT_QUERIES


# --------------------------------------------------------------------------- #
# Source: arXiv (Atom XML)
# --------------------------------------------------------------------------- #

ATOM_NS = {"a": "http://www.w3.org/2005/Atom"}


def fetch_arxiv(query: str) -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "search_query": f"all:{query}",
            "start": 0,
            "max_results": MAX_PER_QUERY,
            # Relevance sort keeps on-topic hits near the top; date sort floods
            # the results with the newest arXiv papers regardless of topic.
            "sortBy": "relevance",
            "sortOrder": "descending",
        }
    )
    url = f"http://export.arxiv.org/api/query?{params}"
    try:
        data = http_get(url)
    except Exception as exc:  # noqa: BLE001 - best-effort collector
        print(f"  [arxiv] request failed: {exc}", file=sys.stderr)
        return []

    try:
        root = ET.fromstring(data)
    except ET.ParseError as exc:
        print(f"  [arxiv] parse failed: {exc}", file=sys.stderr)
        return []

    records = []
    for entry in root.findall("a:entry", ATOM_NS):
        arxiv_url = entry.findtext("a:id", default="", namespaces=ATOM_NS).strip()
        # arxiv id looks like http://arxiv.org/abs/2602.22828v1
        m = re.search(r"arxiv\.org/abs/([^v]+)", arxiv_url)
        arxiv_id = m.group(1) if m else arxiv_url
        title = " ".join(
            (entry.findtext("a:title", default="", namespaces=ATOM_NS) or "").split()
        )
        summary = " ".join(
            (entry.findtext("a:summary", default="", namespaces=ATOM_NS) or "").split()
        )
        published = entry.findtext("a:published", default="", namespaces=ATOM_NS) or ""
        year = published[:4] if published else ""
        authors = [
            (a.findtext("a:name", default="", namespaces=ATOM_NS) or "").strip()
            for a in entry.findall("a:author", ATOM_NS)
        ]
        records.append(
            {
                "id": f"arxiv:{arxiv_id}",
                "title": title,
                "authors": [a for a in authors if a],
                "year": year,
                "source": "arXiv",
                "url": arxiv_url.replace("http://", "https://"),
                "abstract": summary,
            }
        )
    return records


# --------------------------------------------------------------------------- #
# Source: Europe PMC (JSON — covers PubMed/MEDLINE + preprints)
# --------------------------------------------------------------------------- #

def fetch_europepmc(query: str) -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "query": query,
            "format": "json",
            "pageSize": MAX_PER_QUERY,
            "sort": "P_PDATE_D desc",
            "resultType": "core",
        }
    )
    url = f"https://www.ebi.ac.uk/europepmc/webservices/rest/search?{params}"
    try:
        data = http_get(url)
        payload = json.loads(data)
    except Exception as exc:  # noqa: BLE001 - best-effort collector
        print(f"  [europepmc] request failed: {exc}", file=sys.stderr)
        return []

    records = []
    for res in payload.get("resultList", {}).get("result", []):
        doi = (res.get("doi") or "").strip().lower()
        pmid = res.get("pmid")
        source_id = res.get("id")
        source_db = res.get("source")
        if doi:
            rec_id = f"doi:{doi}"
            url_out = f"https://doi.org/{doi}"
        elif pmid:
            rec_id = f"pmid:{pmid}"
            url_out = f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/"
        else:
            rec_id = f"epmc:{source_db}/{source_id}"
            url_out = (
                f"https://europepmc.org/article/{source_db}/{source_id}"
                if source_db and source_id
                else ""
            )
        authors = []
        author_string = res.get("authorString") or ""
        if author_string:
            authors = [a.strip() for a in author_string.split(",") if a.strip()]
        records.append(
            {
                "id": rec_id,
                "title": " ".join((res.get("title") or "").split()),
                "authors": authors,
                "year": str(res.get("pubYear") or ""),
                "source": "Europe PMC" if source_db != "PPR" else "Europe PMC (preprint)",
                "url": url_out,
                "abstract": " ".join((res.get("abstractText") or "").split()),
            }
        )
    return records


# --------------------------------------------------------------------------- #
# Store handling + dedup
# --------------------------------------------------------------------------- #

def load_store() -> list[dict]:
    if PAPERS_JSON.exists():
        try:
            return json.loads(PAPERS_JSON.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            print("  [store] papers.json unreadable; starting fresh", file=sys.stderr)
    return []


def build_index(store: list[dict]) -> tuple[set[str], set[str]]:
    """Return (id_set, normalized_title_set) for dedup."""
    ids = {p["id"] for p in store if p.get("id")}
    titles = {normalize_title(p.get("title", "")) for p in store}
    titles.discard("")
    return ids, titles


def save_store(store: list[dict]) -> None:
    PAPERS_JSON.write_text(
        json.dumps(store, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def write_markdown(store: list[dict]) -> None:
    by_year: dict[str, list[dict]] = {}
    for p in store:
        by_year.setdefault(p.get("year") or "n.d.", []).append(p)

    lines = [
        "# TCM Syndrome-Differentiation Research Corpus",
        "",
        "> Auto-generated by `tools/fetch_tcm_papers.py`. Do not edit by hand — "
        "changes are overwritten on the next scheduled run.",
        "",
        f"**Total papers collected:** {len(store)}  ",
        f"**Last updated:** {today()}",
        "",
        "This corpus feeds the adaptive-inquiry direction described in "
        "`ADAPTIVE_TCM_INQUIRY_NOTES.md`. New papers are fetched daily from "
        "arXiv and Europe PMC (PubMed/MEDLINE) and appended, never removed.",
        "",
    ]
    for year in sorted(by_year, reverse=True):
        papers = sorted(by_year[year], key=lambda p: p.get("title", "").lower())
        lines.append(f"## {year} ({len(papers)})")
        lines.append("")
        for p in papers:
            authors = ", ".join(p.get("authors", [])[:3])
            if len(p.get("authors", [])) > 3:
                authors += " et al."
            title = p.get("title") or "(untitled)"
            url = p.get("url") or ""
            src = p.get("source") or ""
            head = f"- [{title}]({url})" if url else f"- {title}"
            meta = " · ".join(x for x in [authors, src] if x)
            lines.append(head)
            if meta:
                lines.append(f"  <br>_{meta}_")
        lines.append("")
    PAPERS_MD.write_text("\n".join(lines), encoding="utf-8")


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main() -> int:
    RESEARCH_DIR.mkdir(exist_ok=True)
    queries = load_queries()
    store = load_store()
    seen_ids, seen_titles = build_index(store)

    print(f"Loaded {len(store)} existing papers. Running {len(queries)} queries.")

    added = 0
    # Track new records within this run too, so the same paper surfacing from
    # two different queries isn't added twice.
    for i, query in enumerate(queries, 1):
        print(f"[{i}/{len(queries)}] {query}")
        results = fetch_arxiv(query)
        time.sleep(REQUEST_DELAY)
        results += fetch_europepmc(query)
        time.sleep(REQUEST_DELAY)

        for rec in results:
            if not is_relevant(rec):
                continue
            title_key = normalize_title(rec.get("title", ""))
            if rec["id"] in seen_ids:
                continue
            if title_key and title_key in seen_titles:
                continue
            rec["matched_queries"] = [query]
            rec["first_seen"] = today()
            store.append(rec)
            seen_ids.add(rec["id"])
            if title_key:
                seen_titles.add(title_key)
            added += 1

    save_store(store)
    write_markdown(store)
    print(f"Done. Added {added} new papers. Corpus now holds {len(store)}.")

    # Emit a machine-readable summary for the GitHub Actions step summary.
    summary_path = Path(__file__).parent.parent / "research" / ".last_run.json"
    summary_path.write_text(
        json.dumps({"date": today(), "added": added, "total": len(store)}, indent=2),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
