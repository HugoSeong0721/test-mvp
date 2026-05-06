# Session Status

Updated: 2026-05-05

## Working Style
- Batch related requests together before implementation.
- Prefer one pass that includes code changes, verification, and a short closeout.
- Keep demo velocity high; defer prod security hardening unless explicitly requested.
- Leave short handoff notes here, in `NEXT_STEPS.md`, and in `BUGS.md`.

## Current Focus
- Make clinic selection real across practitioner and patient flows.
- Scope visible slots, appointment requests, visits, intake submissions, and feedback to the selected/logged-in clinic.
- Make practitioner log in with a clinic context first.

## Already In Place
- Practitioner local account create/login flow exists.
- Clinic profile workspace exists.
- Patient can search/select a clinic after login.
- Share link can carry a `clinicId` into the patient portal.

## In Progress
- Add `clinicId` to local scheduling models.
- Filter patient/practitioner dashboards to a single clinic context.
- Persist clinic-aware writes for patient intake, answer requests, and visit feedback.
