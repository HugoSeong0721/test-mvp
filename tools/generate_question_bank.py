#!/usr/bin/env python3
"""Generate a research-grounded question bank with Claude.

Reads the collected paper corpus (research/papers.json), selects the abstracts
most relevant to each TCM pattern direction used by the app's Pattern Finder,
and asks Claude to draft follow-up inquiry questions grounded ONLY in those
abstracts — each question citing the paper ids it draws on. The result is
written to research/question_bank.json, which ships with the app as an asset.

Runs inside the daily GitHub Action AFTER the paper fetch. Requires the
ANTHROPIC_API_KEY environment variable (a GitHub Actions secret); exits
successfully with a notice when the key is absent, so the workflow stays green
until the key is configured.

Safety stance (mirrors ADAPTIVE_TCM_INQUIRY_NOTES.md): the generated questions
are inquiry suggestions for a licensed practitioner to review — never automated
diagnosis. The app shows them with that framing.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAPERS_JSON = ROOT / "research" / "papers.json"
BANK_JSON = ROOT / "research" / "question_bank.json"
LAST_RUN_JSON = ROOT / "research" / ".last_run.json"

MODEL = "claude-opus-5"
ABSTRACTS_PER_PATTERN = 8
QUESTIONS_PER_PATTERN = 3

# Must stay in sync with PatternFinderService.patterns in
# lib/core/services/pattern_finder_service.dart (ids and researchQuery).
PATTERNS = [
    {
        "id": "qi_deficiency",
        "name_ko": "기허(기운 부족) 방향",
        "query": "qi deficiency fatigue syndrome differentiation",
    },
    {
        "id": "yang_deficiency",
        "name_ko": "양허(몸이 찬) 방향",
        "query": "yang deficiency cold syndrome differentiation",
    },
    {
        "id": "yin_deficiency",
        "name_ko": "음허(허열·건조) 방향",
        "query": "yin deficiency heat night sweat syndrome differentiation",
    },
    {
        "id": "damp_phlegm",
        "name_ko": "습담(무겁고 더부룩) 방향",
        "query": "damp phlegm spleen digestion syndrome differentiation",
    },
    {
        "id": "liver_qi",
        "name_ko": "간기울결(스트레스·긴장) 방향",
        "query": "liver qi stagnation depression stress syndrome differentiation",
    },
    {
        "id": "blood_stasis",
        "name_ko": "어혈(고정된 통증) 방향",
        "query": "blood stasis pain syndrome differentiation",
    },
    {
        "id": "blood_deficiency",
        "name_ko": "혈허(어지럼·창백) 방향",
        "query": "blood deficiency dizziness insomnia syndrome differentiation",
    },
]

SYSTEM_PROMPT = """You are a clinical-decision-support assistant for licensed \
Traditional Korean/Chinese Medicine practitioners. You draft follow-up inquiry \
questions that help a practitioner confirm or rule out a candidate pattern \
direction during in-person consultation.

Rules:
- Ground every question ONLY in the provided paper abstracts. Do not invent \
findings that are not supported by them.
- Each question must cite the ids of the abstracts it draws on.
- Questions are asked to the patient, so phrase them in warm, plain Korean a \
patient can answer directly (also provide an English translation).
- Prefer questions that DISCRIMINATE this pattern from similar ones (e.g. \
cold-heat, deficiency-excess, fixed vs moving pain).
- These are inquiry suggestions for a practitioner to review — never phrase \
them as a diagnosis or treatment recommendation."""

OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "questions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "question_ko": {"type": "string"},
                    "question_en": {"type": "string"},
                    "rationale_ko": {
                        "type": "string",
                        "description": "One sentence, in Korean, on why this "
                        "question helps confirm or rule out the pattern, "
                        "referencing what the cited abstracts report.",
                    },
                    "source_ids": {
                        "type": "array",
                        "items": {"type": "string"},
                    },
                },
                "required": [
                    "question_ko",
                    "question_en",
                    "rationale_ko",
                    "source_ids",
                ],
                "additionalProperties": False,
            },
        }
    },
    "required": ["questions"],
    "additionalProperties": False,
}


def relevance_score(paper: dict, query: str) -> int:
    """Mirror of ResearchPaper.relevanceScore in the Flutter app."""
    terms = {t for t in re.split(r"[^a-z0-9]+", query.lower()) if len(t) > 2}
    title = (paper.get("title") or "").lower()
    abstract = (paper.get("abstract") or "").lower()
    score = 0
    for term in terms:
        if term in title:
            score += 3
        if term in abstract:
            score += 1
    return score


def top_papers(papers: list[dict], query: str, limit: int) -> list[dict]:
    scored = [(relevance_score(p, query), p) for p in papers]
    scored = [(s, p) for s, p in scored if s > 0 and (p.get("abstract") or "").strip()]
    scored.sort(key=lambda x: -x[0])
    return [p for _, p in scored[:limit]]


def build_user_prompt(pattern: dict, papers: list[dict]) -> str:
    lines = [
        f"Candidate pattern direction: {pattern['name_ko']} "
        f"(id: {pattern['id']})",
        "",
        f"Draft exactly {QUESTIONS_PER_PATTERN} follow-up inquiry questions "
        "for this pattern, grounded in the abstracts below.",
        "",
        "Abstracts:",
    ]
    for p in papers:
        abstract = (p.get("abstract") or "").strip()
        # Keep each abstract bounded so the prompt stays small.
        if len(abstract) > 1500:
            abstract = abstract[:1500] + "…"
        lines.append(f"---")
        lines.append(f"id: {p['id']}")
        lines.append(f"title: {p.get('title', '')}")
        lines.append(f"abstract: {abstract}")
    return "\n".join(lines)


def extract_text(response) -> str:
    for block in response.content:
        if block.type == "text":
            return block.text
    return ""


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        print(
            "ANTHROPIC_API_KEY is not set — skipping question bank generation. "
            "Add the key as a GitHub Actions secret to enable this step."
        )
        return 0

    # Only spend tokens when there is something new to ground on, unless the
    # bank does not exist yet (or FORCE_GENERATE=1).
    force = os.environ.get("FORCE_GENERATE") == "1"
    bank_exists = False
    if BANK_JSON.exists():
        try:
            bank_exists = bool(json.loads(BANK_JSON.read_text())["patterns"])
        except Exception:  # noqa: BLE001
            bank_exists = False
    added = 0
    if LAST_RUN_JSON.exists():
        try:
            added = int(json.loads(LAST_RUN_JSON.read_text())["added"])
        except Exception:  # noqa: BLE001
            added = 0
    if bank_exists and added == 0 and not force:
        print("No new papers and bank already exists — skipping generation.")
        return 0

    papers = json.loads(PAPERS_JSON.read_text(encoding="utf-8"))
    if not papers:
        print("Paper corpus is empty — nothing to ground on; skipping.")
        return 0

    import anthropic

    client = anthropic.Anthropic()

    bank: dict = {
        "generated_at": _dt.datetime.now(_dt.timezone.utc).isoformat(),
        "model": MODEL,
        "corpus_size": len(papers),
        "patterns": {},
    }
    paper_by_id = {p["id"]: p for p in papers}

    for pattern in PATTERNS:
        selected = top_papers(papers, pattern["query"], ABSTRACTS_PER_PATTERN)
        if not selected:
            print(f"[{pattern['id']}] no relevant abstracts — skipped")
            continue
        print(f"[{pattern['id']}] generating from {len(selected)} abstracts…")
        try:
            response = client.beta.messages.create(
                model=MODEL,
                max_tokens=16000,
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
                system=SYSTEM_PROMPT,
                output_config={
                    "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}
                },
                messages=[
                    {
                        "role": "user",
                        "content": build_user_prompt(pattern, selected),
                    }
                ],
            )
        except TypeError:
            # Older SDK without the fallbacks parameter — retry plain.
            response = client.messages.create(
                model=MODEL,
                max_tokens=16000,
                system=SYSTEM_PROMPT,
                output_config={
                    "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}
                },
                messages=[
                    {
                        "role": "user",
                        "content": build_user_prompt(pattern, selected),
                    }
                ],
            )
        except anthropic.APIStatusError as exc:
            print(f"[{pattern['id']}] API error {exc.status_code} — skipped")
            continue

        if response.stop_reason == "refusal":
            print(f"[{pattern['id']}] request refused — skipped")
            continue

        try:
            data = json.loads(extract_text(response))
        except json.JSONDecodeError:
            print(f"[{pattern['id']}] unparseable response — skipped")
            continue

        questions = data.get("questions", [])[:QUESTIONS_PER_PATTERN]
        # Attach human-readable source info so the app can render citations
        # without a corpus lookup.
        source_ids = sorted({sid for q in questions for sid in q["source_ids"]})
        sources = [
            {
                "id": sid,
                "title": paper_by_id[sid].get("title", ""),
                "year": paper_by_id[sid].get("year", ""),
                "url": paper_by_id[sid].get("url", ""),
            }
            for sid in source_ids
            if sid in paper_by_id
        ]
        bank["patterns"][pattern["id"]] = {
            "name_ko": pattern["name_ko"],
            "questions": questions,
            "sources": sources,
        }
        print(f"[{pattern['id']}] {len(questions)} questions, {len(sources)} sources")

    if not bank["patterns"]:
        print("No patterns generated — leaving existing bank untouched.")
        return 0

    BANK_JSON.write_text(
        json.dumps(bank, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {BANK_JSON} with {len(bank['patterns'])} patterns.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
