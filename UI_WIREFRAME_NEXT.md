# UI Wireframe Next

## Goal
Turn the current MVP into a cleaner clinic workflow by separating:
- practitioner operations
- patient portal home
- intake form flow
- request inbox / visit history

This document maps the current app to the next UI version.

---

## 1. Home / Entry Screen
Reference:
- Jane

### Current problem
- entry screen still feels like a developer switchboard
- useful for us, but not ideal for real testers

### Next structure

#### Top
- App name: Test MVP
- Right: Language

#### Main cards
1. Practitioner
- small helper text
- button: Log In

2. Patient
- small helper text
- button: Patient Login

3. Friend Beta
- small helper text
- button: Sign Up / Log In

### Layout notes
- one centered column
- 3 cards max
- no extra guide blocks by default
- keep helper text short

### Copy direction
- less "test flow" language
- more "who are you / what do you need"

---

## 2. Practitioner Dashboard
Reference:
- Jane overall
- Acusimple for acupuncture-specific structure

### Current problem
- too much is happening on one page
- dashboard, analytics, requests, and patient management all compete

### Next structure

#### Top row
Left:
- Today / This Week heading
- practitioner name or clinic name later

Right:
- Language
- Patient Management
- Insights

#### Row 1: KPI strip
- Total visits
- Intake response rate
- Incomplete profiles
- Pending answer requests

#### Row 2: schedule control bar
- quick filters: Today / 7 days / 14 days / 30 days
- date picker
- range picker
- search patient

#### Row 3: patient visit list
Each card:
- patient name
- appointment date + time
- last visit summary line
- response status chip
- missing info badge if needed
- buttons:
  - Request Answers
  - View Detail

#### Right-side future panel or separate tab
- Upcoming patients
- Recent submissions
- Beta signups overview

### Layout principle
- dashboard should answer: who needs attention right now?
- insights should be secondary, not mixed into main operational view

---

## 3. Practitioner Patient Detail Brief
Reference:
- Acusimple
- WebPT structure

### Current problem
- useful data is present, but the screen still feels like a long stack

### Next structure

#### Header
- patient name
- appointment time
- last visit date
- profile basics
- badges:
  - incomplete info
  - intake complete / in progress / not started

#### Section A: clinical snapshot
- current top concerns
- main categories asked
- categories not yet asked
- quick practitioner summary

#### Section B: full visit timeline
Each entry:
- date/time
- treatment area
- note summary
- intake summary

#### Section C: current session planning
Fields:
- treatment area today
- session note today
- what to observe next time
- advice given today
- adherence follow-up

#### Section D: shared patient message
Fields:
- patient-facing summary
- this week must-do
- current status explanation
- action guide

### Layout principle
- top = scan fast
- middle = history
- bottom = documentation

---

## 4. Patient Home
Reference:
- athenahealth patient portal
- Jane patient portal feel

### Current problem
- patient intake screen is doing too many jobs:
  - profile
  - alerts
  - visit summary
  - checklist
  - actual intake form
  - submission history

### Next structure
Make this a separate home screen from the intake form.

#### Header
- patient name
- right: Language, Profile

#### Section A: next visit
- appointment date/time
- practitioner name later
- pre-visit status
- button: Continue Intake

#### Section B: requests
- new requests count
- latest note from practitioner
- button: Open Requests

#### Section C: this week plan
- checklist summary
- completion percentage
- button: Update Weekly Checklist

#### Section D: last visit summary
- treatment area
- practitioner note
- button: View Visit History

#### Section E: recent submissions
- last completed intake
- date / number of answers

### Layout principle
- patient home should feel reassuring and simple
- only show next action first

---

## 5. Patient Intake Form
Reference:
- WebPT

### Current problem
- better than before, but still mixed with dashboard-like content

### Next structure

#### Top
- question progress
- initial / follow-up label
- save status later

#### Main form area
- current question
- answer field
- optional note field
- tags:
  - main pain
  - remember this

#### Bottom controls
- previous
- next
- submit

#### Optional side or expandable section
- why this is being asked
- practitioner request note

### What should move out of this page
- profile card
- full visit summary
- submission history
- big checklist block

Those belong on patient home.

---

## 6. Patient Requests Inbox
Reference:
- portal inbox patterns

### Why we need it
Instead of only showing pending requests as a box inside intake, make them a dedicated screen.

### Structure
Each request card:
- date requested
- question count
- practitioner note
- status: pending / completed
- button: open related intake

### Benefit
- easier for patient to understand what is new
- easier for practitioner to test workflow

---

## 7. Patient Visit History
Reference:
- athenahealth portal

### Structure
Each visit row:
- date/time
- treatment area
- practitioner shared summary
- what to continue this week
- submitted intake snapshot if any

### Benefit
- separates history from active intake
- helps patient track progress over time

---

## 8. Friend Beta Sign Up / Login
Reference:
- simple auth card

### Current problem
- works, but still a little too "tool-like"

### Next structure
- one clean auth card
- short intro text only
- switch between sign up / login
- later add privacy reassurance text

### Keep
- simple form
- no extra clutter

---

## 9. Navigation Recommendation

### Practitioner
Top nav or left rail later:
1. Dashboard
2. Schedule
3. Patients
4. Requests
5. Notes
6. Insights
7. Settings

### Patient
Bottom nav later or tab layout:
1. Home
2. Intake
3. Requests
4. History
5. Profile

---

## 10. Immediate UI Build Order

### Build next in this order
1. Split Patient Home from Patient Intake
2. Create Patient Requests screen
3. Create Patient Visit History screen
4. Rebuild Practitioner Dashboard layout
5. Clean Patient Detail Brief layout

---

## 11. What To Change In The Current App Right Away

### Keep as-is for now
- login behavior
- Firebase auth structure
- basic request/submission flow

### Refactor next
- patient intake page becomes form-only
- new patient home page becomes the portal landing page
- dashboard becomes less analytics-heavy and more action-oriented

---

## 12. Simple Page Sketches

### Practitioner Dashboard sketch
[Header: Dashboard | Language | Patient Mgmt | Insights]
[KPIs]
[Date / Range / Search]
[Patient Card List]

### Patient Home sketch
[Header: Name | Language | Profile]
[Next Visit]
[Pending Requests]
[This Week Checklist]
[Last Visit Summary]
[Recent Submissions]

### Patient Intake sketch
[Progress]
[Question]
[Answer box]
[Main pain / Remember]
[Previous | Next | Submit]

### Patient Requests sketch
[Request card]
[Request card]
[Request card]

### Patient History sketch
[Visit row]
[Visit row]
[Visit row]
