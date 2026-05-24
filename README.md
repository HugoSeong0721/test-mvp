# Test MVP

Web-first MVP for an acupuncture clinic portal and patient workflow.

## Quick Links

| Use | Link |
|---|---|
| Practitioner portal | https://hugoseong0721.github.io/test-mvp/#/clinic |
| Patient / beta portal | https://hugoseong0721.github.io/test-mvp/#/patient |

## Current Login Flow

- Practitioners create their own account in the browser and then log in with that account.
- Patients sign up with email and password from the patient portal screen.
- Shared demo credentials are no longer used.

## Patient Beta Flow

1. Open the patient portal link.
2. Sign up with your own email and a password with at least 6 characters.
3. Continue into the patient home screen.
4. Open the Intake tab, complete the form, and submit it.
5. Use the green `Feedback` button in the lower-right corner if anything is broken or confusing.

## Current MVP Focus

The current product focus is patient-practitioner conversation for acupuncture care:

- A new patient signs up and is sent the baseline TCM intake questions.
- The patient replies from the portal.
- The practitioner reviews answers, patient age, sex/gender, habits, and follow-up replies.
- The patient's TCM-oriented view should become richer over time as more answers arrive.

### Deferred For Later

Scheduling and booking confirmation are intentionally removed from the primary UI for now so the MVP can stay focused on conversation.

Keep these for a later database-backed phase:

- Patient appointment booking requests.
- Practitioner availability / schedule board.
- Booking confirmation and decline workflow.
- Appointment request inbox metrics.
- Visit date confirmation and reminder workflow.

## Patient-Visible Clinic List

## Currently Open Clinics

These are the clinics currently treated as open for beta testing and patient selection:

| Clinic | Practitioner | Location | Status |
|---|---|---|---|
| Seong Acupuncture Center | Dr. Hugo Seong | Fort Lee, NJ | Open for beta |
| iSaw Acu | Hugo Seong | Not entered yet | Open for beta |

Notes:

- Patients use `Patient Home` -> `Change clinic` / `Search clinic` to choose one of these clinics.
- The live app currently stores clinic visibility in browser-local demo storage, so the exact picker list can still differ by browser/device until the backend clinic registry is connected.
- If a patient cannot find their clinic, they can use `Request to open`; those requests appear in the practitioner `Inbox`.

## Bundled Clinic Templates

Patients only see clinics that were explicitly saved by a practitioner in `Clinic Profile`. If a clinic is not connected to a practitioner account yet, it will not appear in the patient clinic picker.

Bundled clinic templates that practitioners can register:

- Seong Acupuncture Center — Dr. Hugo Seong — Fort Lee, NJ
- Midtown Balance Clinic — Dr. Jane Kim — Midtown Manhattan, NY
- Elm Wellness Acupuncture — Dr. Min Park — Palisades Park, NJ

Important note:

- These clinic names do not automatically appear to patients on GitHub Pages.
- A practitioner must sign in first and save/link the clinic in `Clinic Profile`.
- After that, patients using the same browser context can see and choose that clinic.

## New Clinic Open Requests

Patients who cannot find their clinic can use `Request to open` in the clinic picker.

### Requested Clinic Leads

Use this table as Hugo's mediator/outreach list. When a patient asks to open a clinic, review it in the practitioner inbox and copy the useful lead details here before reaching out to the clinic.

| Requested Clinic | Practitioner | Location | Patient / Contact | Note | Status | Next Action |
|---|---|---|---|---|---|---|
| No active README-tracked lead yet | - | - | - | Check the live practitioner inbox for browser/Firebase requests | Waiting | Add the next real request here |

Where requests appear:

- Patient side: `Patient Home` -> `Change clinic` / `Search clinic` -> `Request to open`
- Practitioner side: `Practitioner Dashboard` -> `Inbox` -> `Patient clinic open requests`

Current demo behavior:

- Requests are saved in browser-local storage and Firestore when available.
- They show as "new clinic requests" inside the practitioner inbox.
- The static GitHub README cannot update itself from a browser click without a backend automation or GitHub write token.
- For now, treat the practitioner inbox as the live source of truth and this README table as the outreach tracker.

Suggested outreach workflow:

1. Open `Practitioner portal`.
2. Go to `Inbox`.
3. Review `Patient clinic open requests`.
4. Copy real clinic leads into the README table above.
5. Contact the clinic and update `Status` / `Next Action`.

## Repository

- GitHub: `https://github.com/HugoSeong0721/test-mvp.git`
- Deployment: GitHub Pages served from the `docs/` folder

## Local Development

```bash
git clone https://github.com/HugoSeong0721/test-mvp.git
cd test-mvp
flutter pub get
flutter run -d chrome
```

## Sync Changes

```bash
git add .
git commit -m "Describe your update"
git push
```
