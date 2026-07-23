# TCM Research Corpus

An automatically-growing collection of research papers on **TCM syndrome
differentiation (변증)** and **adaptive/dynamic medical inquiry** — the
directions tracked in [`../ADAPTIVE_TCM_INQUIRY_NOTES.md`](../ADAPTIVE_TCM_INQUIRY_NOTES.md).

The goal: accumulate a durable, deduplicated literature base in the repo that
can serve as a **data source for improving the patient question/answer and
diagnosis-support flow** of the app.

## How it works

```
tools/fetch_tcm_papers.py        # the collector (stdlib only, no pip installs)
research/queries.txt             # search queries — edit to steer what gets collected
research/papers.json             # the corpus (machine-readable, append-only)
research/papers.md               # human-readable catalog (auto-generated)
.github/workflows/fetch-tcm-papers.yml   # daily schedule (00:20 UTC / 09:20 KST)
```

Every day the GitHub Action:

1. Runs each query in `queries.txt` against **arXiv** and **Europe PMC**
   (which indexes PubMed/MEDLINE + preprints) — both free, no API key.
2. Deduplicates results against everything already in `papers.json`
   (by DOI / arXiv id / PMID, with a normalized-title fallback).
3. Appends only genuinely new papers, then regenerates `papers.md`.
4. Commits the changes back to the repo — so nothing already fetched is
   fetched again, and the corpus only grows.

If a run finds nothing new, it makes no commit.

## Running it manually

- **From GitHub:** Actions tab → *Fetch TCM research papers* → *Run workflow*.
- **Locally:** `python3 tools/fetch_tcm_papers.py` (requires outbound internet
  to arXiv and `ebi.ac.uk`).

## Data schema (`papers.json`)

Each entry:

```json
{
  "id": "arxiv:2602.22828",          // stable dedup key (arxiv:/doi:/pmid:/epmc:)
  "title": "...",
  "authors": ["..."],
  "year": "2026",
  "source": "arXiv",                  // or "Europe PMC" / "Europe PMC (preprint)"
  "url": "https://...",
  "abstract": "...",
  "matched_queries": ["..."],         // which query surfaced it first
  "first_seen": "2026-07-23"          // when it entered the corpus
}
```

## Using it as a source in the app

`papers.json` is a plain JSON array, so it can be:

- bundled as a Flutter asset and parsed for an in-app "evidence / references"
  view behind a practitioner-only screen;
- fed (title + abstract) into a retrieval / RAG step to ground the app's
  next-question and pattern-suggestion logic;
- mined offline to refine the rule-based signals in the adaptive inquiry
  summary before any clinician-validated rules are added.

Keep the safety stance from the notes: this corpus is **decision support for a
licensed practitioner**, not a source of automated patient diagnosis.

## Tuning what gets collected

Edit `research/queries.txt` (one query per line, `#` for comments). Narrower
queries as the model matures will keep the corpus focused. No code changes
needed — the collector reads that file on every run.
