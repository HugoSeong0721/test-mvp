# Adaptive TCM Inquiry Notes

This app should support practitioner-led care conversations, not automated diagnosis. Any TCM pattern language shown in the product must be treated as decision support for a licensed practitioner.

## Research-Inspired Direction

- Decision-tree symptom selection: ask fewer, more meaningful questions instead of asking every patient every question. Reference: "Decision Tree-Based Body Constitution Diagnosis System for Traditional Chinese Medicine" (PubMed: https://pubmed.ncbi.nlm.nih.gov/35295930/).
- Active medical inquiry: choose the next question based on what has already been answered, similar to reinforcement-learning inquiry systems. Reference: https://www.jmir.org/2024/1/e54616/.
- Knowledge graph / chain reasoning: accumulate symptoms into explainable signal clusters before suggesting a next question or pattern direction. Reference: TCM-DiffRAG, https://arxiv.org/abs/2602.22828.
- Future multimodal intake: tongue photos or other observations could become optional practitioner-reviewed evidence, not required for MVP. Reference: TongueVLM, https://medinform.jmir.org/2026/1/e87237.
- Future multi-turn training: compare the conversation flow to active multi-turn diagnostic datasets such as MedAction, https://arxiv.org/html/2605.07305v1.

## MVP Implementation

- Patient answers are saved with an `adaptiveTcmSummary`.
- The summary extracts lightweight signals across sleep, digestion, temperature, energy, emotion, and body pain/tension.
- The practitioner dashboard shows the strongest signals and a small number of "next best" follow-up questions.
- Each suggested pattern direction links to supporting papers in the bundled research corpus (`research/papers.json`, refreshed daily by a scheduled GitHub Action) via token-relevance retrieval — tap the "TCM path" chip to open the Research Library pre-filtered to the matching literature.
- This is intentionally rule-based for now, so behavior is predictable and easy to review.

## Later

- Replace keyword-only signals with clinician-validated rules.
- Add a small TCM knowledge graph for symptom relationships.
- Track whether follow-up questions improve practitioner notes and patient clarity.
- Add safety copy and review gates before showing any pattern suggestion to patients.
- Keep scheduling, appointment confirmation, and database automation out of the MVP until the conversation workflow is solid.
