# UI Reference Mapping

## Core Reference Stack

### 1. Jane App
Primary use:
- patient booking flow
- intake form flow
- patient portal layout
- clinic-friendly scheduling UX

Best pages to study:
- https://jane.app/features/online-booking
- https://jane.app/guide/intake-forms
- https://jane.app/physicaltherapy

What to borrow:
- calm, clean healthcare layout
- clear patient action buttons
- strong separation between practitioner tools and patient actions
- appointment-first navigation

### 2. Acusimple
Primary use:
- acupuncture-specific practice management concepts
- charting / patient info / scheduling feature grouping

Best page to study:
- https://acusimple.com/index.php

What to borrow:
- acupuncture-specific menu categories
- practitioner workflow language
- clinic operations framing

### 3. WebPT
Primary use:
- digital intake flow
- first visit vs follow-up intake logic
- patient self-completion UX

Best pages to study:
- https://www.webpt.com/products/digital-patient-intake
- https://www.webpt.com/products/online-scheduling

What to borrow:
- structured intake progression
- progress visibility
- checklist / completion state

### 4. athenahealth patient portal
Primary use:
- patient app home structure
- visit history / reminders / messages
- portal-style organization

Best pages to study:
- https://www.athenahealth.com/patient-login
- https://www.athenahealth.com/solutions/patient-engagement/athenapatient-app

What to borrow:
- patient dashboard sections
- reminders / to-do / upcoming visit grouping
- profile and history placement

---

## Screen-by-Screen Mapping

### A. Home / Entry Screen
Target reference:
- Jane App

Why:
- it is simple, calm, and immediately task-oriented
- good model for separating user paths without overwhelming people

What our version should do:
- top area: app title + language switch
- primary cards only:
  - Practitioner Login
  - Patient Test Login
  - Friend Beta Sign Up / Login
- no modal popup on entry
- short one-line helper text under each card

Keep:
- minimal and clean
- healthcare tone, not tech-product tone

### B. Practitioner Dashboard
Target reference:
- Jane App + Acusimple

Why:
- Jane gives the best scheduling / clinic dashboard feel
- Acusimple gives the best acupuncture-specific feature framing

What our version should do:
- left/top summary area:
  - total visits
  - response rate
  - incomplete profiles
  - pending answers
- right/top date controls:
  - day range
  - week range
  - quick filters
- below: patient list with clear cards

Card content priority:
- patient name
- appointment date/time
- intake response status
- missing required info badge
- recent summary line
- actions:
  - Request Answers
  - View Detail

Menu direction to eventually mirror:
- Dashboard
- Patients
- Schedule
- Intake Requests
- Notes / Chart
- Insights

### C. Patient Detail Brief
Target reference:
- Acusimple + WebPT

Why:
- this is the most practitioner-facing clinical review screen
- needs both structured categories and visit history

What our version should do:
- top header:
  - patient name
  - appointment time
  - last visit
  - profile basics
- section 1: full visit history
- section 2: 10-category intake coverage
- section 3: current session notes
- section 4: shared message for patient

Design principle:
- structured and dense, but readable
- more like a working chart than a marketing page

### D. Patient Intake Screen
Target reference:
- WebPT + athenahealth

Why:
- WebPT gives the strongest intake structure
- athenahealth gives better patient self-service dashboard organization

What our version should do:
- top area:
  - profile snapshot
  - pending requests alert
  - last visit summary
- middle:
  - weekly checklist / adherence
  - question mode toggle (initial / follow-up)
  - progress bar
- bottom:
  - answer field
  - extra note
  - main pain / remember chips
  - previous / next / submit

Important behavior:
- question count and remaining count visible
- patient always knows what to do next
- avoid overly clinical look; should feel safe and understandable

### E. Friend Beta Sign Up / Login
Target reference:
- Jane App + simple SaaS auth pages

Why:
- needs to be easy enough for non-technical friends

What our version should do:
- one clean auth card
- register/login toggle
- short reassurance text
- no clutter

Future additions:
- invite text block
- privacy note
- "test wording is okay" helper note

### F. Insights Dashboard
Target reference:
- healthcare analytics dashboards, but visually lighter
- current inspiration can stay close to Jane style rather than enterprise BI tools

What our version should do:
- KPI row
- symptom trend cards
- advice frequency cards
- practitioner-only product opportunity section

Important:
- keep compact
- should feel like clinic insight, not finance dashboard

### G. Symptom Trend Screen
Target reference:
- supporting analytics page, not main homepage content

What our version should do:
- simple bar or line trend view
- readable date range label
- 3 to 5 key symptom groups only
- keep this page secondary

---

## Menu Structure Recommendation

### Practitioner side
1. Dashboard
2. Schedule
3. Patients
4. Intake Requests
5. Visit Notes
6. Insights
7. Settings

### Patient side
1. Home
2. Intake
3. Requests
4. Visit History
5. Profile
6. Help

---

## Visual Direction Recommendation

### Overall feel
- calm clinic software
- clean medical spacing
- not flashy
- not generic startup purple

### Good direction
- soft off-white background
- muted teal as primary action color
- subtle grey section cards
- strong typography hierarchy

### Avoid
- too many floating cards
- too many badges at once
- dense admin-table look on patient screens
- popup-heavy flow

---

## What We Should Actually Copy First

### Phase 1: copy Jane-style layout decisions
Use for:
- home screen
- practitioner dashboard structure
- patient portal grouping

### Phase 2: copy WebPT-style intake decisions
Use for:
- intake progress
- initial vs follow-up question flow
- completion and checklist behavior

### Phase 3: copy Acusimple-style acupuncture framing
Use for:
- practitioner terminology
- note sections
- category naming and charting emphasis

---

## Recommended Next UI Work

1. Rebuild practitioner dashboard layout closer to Jane
2. Rebuild patient home screen into a portal-style landing page
3. Separate patient intake from patient home more clearly
4. Add a proper patient requests inbox screen
5. Add a visit history screen instead of overloading the intake page

---

## Decision Summary

If we choose only one main reference:
- choose Jane App

If we want the best blended direction:
- Jane for overall UX
- WebPT for intake flow
- Acusimple for acupuncture-specific structure
- athenahealth for patient portal organization
