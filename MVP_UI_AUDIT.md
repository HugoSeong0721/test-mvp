# MVP UI Audit

This document is the working map for rebuilding the MVP around one core job:
helping patients and acupuncture practitioners exchange questions and answers.

## Product North Star

Patient:

`Sign up / log in -> choose clinic -> receive questions -> answer questions -> know what is done`

Practitioner:

`Log in -> see patients -> send baseline or custom questions -> read replies -> refine patient TCM view`

Anything outside that loop should be hidden from the main UI until the conversation flow is reliable.

## Current Route Map

| Route | Screen | Audience | Current job | MVP decision |
|---|---|---|---|---|
| `/` | Role home | Both | Choose practitioner or patient portal | Keep, simplify copy |
| `/clinic` | Practitioner login shortcut | Practitioner | Open practitioner auth | Keep |
| `/login` | Practitioner login/register | Practitioner | Local account auth | Keep |
| `/dashboard` | Practitioner dashboard | Practitioner | Mixed dashboard, patients, questions, inbox, clinic tools | Rebuild around Questions first |
| `/insights` | Practitioner insights | Practitioner | Analytics | Defer from primary nav |
| `/symptom-trend` | Symptom trends | Practitioner | Analytics | Defer from primary nav |
| `/patient` | Patient auth shortcut | Patient | Open patient auth | Keep |
| `/patient-beta-auth` | Patient auth | Patient | Sign up/login/find ID/reset | Keep, simplify next-step handoff |
| `/patient-home` | Patient home | Patient | Clinic, next action, requests, appointment traces | Rebuild as simple question inbox home |
| `/patient-requests` | Questions | Patient | Shows question requests and links to answer flow | Keep as main patient screen |
| `/intake` | Intake/questions | Patient | Answer request/intake questions | Keep, rename mentally to Answer Questions |
| `/patient-history` | Visit history | Patient | Visit records and feedback | Defer |
| `/brief` | Patient brief | Practitioner/share | Snapshot of patient details | Keep as secondary |
| `/tester-feedback-inbox` | Feedback inbox | Admin/tester | QA feedback | Keep hidden from normal flow |

## Current Connection Map

```text
Role home
  -> Practitioner login -> Practitioner dashboard
       -> Questions panel
            -> Send basic 10
            -> Custom question
       -> Patient record / brief
       -> Clinic profile
       -> Deferred appointment/inbox sections still present

  -> Patient auth -> Patient home
       -> Choose clinic modal
       -> Questions tab
            -> Patient intake / answer screen
       -> Deferred appointment/history traces still present
```

## Main Problems Found

1. The product says conversation, but the UI still thinks in visits, schedules, dashboards, and clinic admin.
2. The patient home can still show appointment requests, upcoming visits, intake due, clinic panels, and request history. That creates the feeling of getting lost after contact/profile updates.
3. The practitioner dashboard has the right `Questions` panel, but it competes with patient-date filters, visit summaries, inbox panels, clinic open requests, schedule code, and analytics nav.
4. Booking and confirmation are marked as deferred in README, but code paths and labels still exist in visible areas.
5. Clinic selection is necessary, but the modal has too much clinic-opening/request behavior for the current MVP.
6. The answer flow is split between `Questions` and `Intake`, which makes the user's mental model fuzzy. In the MVP this should feel like answering a message, not filling a separate medical intake module.
7. Mobile is the primary risk. The app has many wide dashboard assumptions and dense cards that can bury the next action.

## Target MVP Screens

### Patient

1. Patient auth
   - Sign up, log in, find ID, reset password.
   - After sign up/login, go to clinic choice if no clinic is connected.
   - If clinic is connected, go directly to Questions.

2. Clinic choice
   - Use a full page or bottom sheet, not a complex modal.
   - Show existing clinics first.
   - Allow "choose later", but make the consequence clear: questions need a clinic.
   - Defer "request to open clinic" from the main path.

3. Questions home
   - First card: next question/request to answer.
   - Secondary: answered history.
   - Minimal header: clinic, language, sign out.
   - No appointment status, visit schedule, or booking request cards.

4. Answer questions
   - One question at a time.
   - Clear progress.
   - Save draft or submit.
   - On submit, return to Questions with a "sent" state.

### Practitioner

1. Practitioner auth
   - Login/register only.

2. Questions dashboard
   - First screen after login.
   - Patient list with conversation state:
     - Not sent
     - Waiting
     - Answered
   - Primary actions:
     - Send basic 10
     - Custom question
     - Open answers

3. Patient conversation detail
   - Patient profile basics.
   - Sent question history.
   - Patient answers.
   - TCM notes/pattern view placeholder.

4. Clinic settings
   - Secondary, not a main daily screen.

## Deferred Features

Keep these out of primary UI for now:

- Appointment booking requests.
- Availability board.
- Booking confirmation/decline.
- Visit calendar.
- Visit history feedback workflow.
- Patient clinic open request workflow.
- Analytics/insights/symptom trend nav.
- Membership approval status labels.

## First Implementation Batch

1. Practitioner dashboard
   - Make `Questions` the default and dominant view.
   - Hide analytics nav and appointment inbox actions from primary shell.
   - Remove schedule/date filter surfaces from the default mobile view.

2. Patient home
   - Redirect or visually collapse home into Questions.
   - Remove appointment request/upcoming visit cards.
   - Make next action only one of:
     - Choose clinic
     - Answer questions
     - Waiting for practitioner

3. Clinic choice
   - Keep existing clinic suggestions.
   - Replace "request to open clinic" with a deferred/hidden path.
   - Close reliably after selecting a clinic.

4. Answer flow naming
   - Rename visible "Intake" labels in patient flow to "Questions" or "Answer".
   - Keep route `/intake` internally for now to avoid risky routing churn.

5. Documentation
   - README points here as the source of truth for MVP scope.
   - Deferred features stay documented here so they are not forgotten.

## QA Checklist

Run this after each batch on mobile width:

1. New patient signs up.
2. Patient chooses a clinic.
3. Practitioner sees patient in Questions.
4. Practitioner taps `Send basic 10`.
5. Patient sees the basic questions.
6. Patient answers and submits.
7. Practitioner sees answered state and can open the answers.
8. No booking, approval, or schedule UI blocks the path.

## Visual Board

Open `docs/mvp-ui-flow-board.html` in a browser to see the page-by-page flow as connected mobile screen cards.

The first version uses structured screen sketches because the current GitHub Pages app can hang at `Loading Test MVP...` in automated capture. Replace those sketches with real screenshots after the boot/capture path is stable.
