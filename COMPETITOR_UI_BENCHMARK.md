# Competitor UI Benchmark

Last updated: 2026-04-23

## Goal
- Use current official competitor pages as the default reference before changing major UI.
- Match information architecture, task flow, and visual hierarchy as closely as practical.
- Borrow structure, not branding. Do not copy logos, screenshots, illustrations, or proprietary marketing copy.

## Official Pages Reviewed
- Jane App scheduling
  - https://jane.app/features/scheduling
- SimplePractice Client Portal setup
  - https://support.simplepractice.com/hc/en-us/articles/207925883-Setting-up-the-Client-Portal
- Practice Better client portal navigation
  - https://help.practicebetter.io/hc/en-us/articles/360004032552-Navigating-Your-Client-Portal
- Healthie scheduling
  - https://www.gethealthie.com/scheduling
- Tebra patient experience
  - https://www.tebra.com/patient-experience
- Epic appointment scheduling
  - https://www.epic.com/software/appointment-scheduling/
- MyChart messaging help
  - https://preview.mychart.org/l/en-us/help/messaging/

## What These Products Repeatedly Do

### 1. The first screen explains itself immediately
- Practice Better describes the dashboard as the user's home base.
- Jane frames scheduling as the home base for daily work.
- Tebra explains the workflow in a clear 1-2-3 sequence.

Project rule:
- Every important screen needs a top section that answers:
  - what this page is for
  - what matters right now
  - what to do first

### 2. Quick actions appear near the top
- Practice Better puts quick action buttons directly below top navigation.
- Healthie keeps self-booking and reminders close to the top of scheduling workflows.
- MyChart and Epic both keep scheduling and appointment actions highly visible.

Project rule:
- Put 2-4 meaningful actions above secondary detail.
- Do not make the user scroll through history before they can do the next task.

### 3. The layout moves from summary to action to detail
- Practice Better shows dashboard summary, then quick actions, then appointments and resources.
- Jane shows schedule context, patient context, then deeper detail.
- MyChart keeps appointments, folders, automated messages, and records in a clear top-down structure.

Project rule:
- Preferred order:
  1. page purpose
  2. status / metrics
  3. quick actions
  4. active task
  5. supporting detail
  6. history / archived items

### 4. Scheduling is always prominent
- Jane, Healthie, Epic, and MyChart all treat scheduling as one of the most important actions.
- Tebra links scheduling with reminders and intake rather than isolating it as a separate task.

Project rule:
- Both patient and practitioner flows should expose next visit status, booking context, or visit window near the top.

### 5. Patient context is visible without drilling too deep
- Jane shows patient context directly from the schedule.
- Healthie connects scheduling to paperwork, charting, and billing.
- MyChart shows appointment reminders, automated messages, and questionnaire events in nearby folders.

Project rule:
- Practitioner pages should surface patient status, alerts, and last-visit context before deep navigation.
- Patient pages should surface requests, current intake state, next visit, and recent submissions near the top.

### 6. Onboarding copy matters
- SimplePractice includes a welcome email and first-sign-in greeting.
- Practice Better even provides a default welcome video for first-time portal users.

Project rule:
- First-use screens must orient the user.
- Beta auth and entry screens should explain what happens next, not just show fields.

## Visual Direction To Reuse

### Layout
- One large hero / command-center band at the top.
- Strong title plus one sentence explaining the purpose.
- Metrics or status chips immediately below the explanation.
- Quick actions before long detail sections.
- Fewer, larger panels instead of many small unrelated cards.

### Hierarchy
- Primary action should be visible without scrolling.
- Supporting detail can live in a side panel or below the main task.
- Empty states still need to explain what the page does and what to do next.

### Tone
- Premium clinic software, not a toy prototype.
- Calm, trustworthy, operational.
- Warm healthcare palette is fine, but clarity beats decoration.

### Navigation
- User should know where they are in 2-3 seconds.
- Role separation must stay obvious:
  - practitioner workflow
  - patient portal workflow
  - beta onboarding workflow

## Screen-Specific Translation For This Project

### Entry / Home Hub
- Top hero explains the 3 main flows.
- First click must be obvious.
- Include a `Start here` sequence rather than just showing cards.

### Beta Auth
- Follow the same pattern as competitor client portal onboarding:
  1. explain the page
  2. show next steps
  3. then show sign up / login form
- Form alone is not enough.

### Patient Home
- Must answer:
  - what is waiting for me
  - what should I do first
  - how do I continue my visit prep
- Order should usually be:
  1. requests
  2. intake
  3. appointments
  4. visit history

### Patient Intake
- The main task should dominate the screen.
- Support panels can show:
  - request summary
  - profile readiness
  - last visit
  - recent submissions
- The question flow should stay in one obvious main panel.

### Patient Requests
- Must clearly explain that this is the follow-up inbox from the practitioner.
- Each card should show:
  - when it was requested
  - how many questions were selected
  - what to do next

### Visit History
- History should come after the active task flow, not before.
- Use simple top-down reading order:
  1. review last record
  2. check Q&A / notes
  3. request corrections if needed

### Practitioner Dashboard
- Top must answer:
  - what visit window is active
  - how many patients need attention
  - where to start
- Preferred order:
  1. date window / filter
  2. patient list
  3. patient context
  4. detail drill-down

### Patient Brief
- Keep the top readable as a scan layer.
- History first, structured intake next, practitioner notes after.
- If the page is dense, number sections explicitly.

## Working Rule For Future UI Changes
- Before changing a major screen, compare it against at least 2 official patterns from the list above.
- Prefer structural matching over decorative matching.
- If a page feels confusing, fix this order first:
  1. page purpose
  2. next action clarity
  3. section order
  4. quick actions near top
  5. color / spacing / polish

## Current Translation Already Applied
- Global premium theme and command-center top sections added.
- `Start here` guidance added to key patient and practitioner entry screens.
- Beta auth updated to explain the flow before the form.
- Patient intake updated so the main task sits in a clearer primary panel with support context around it.

## Next Recommended Screens To Align
- practitioner-side patient card layout inside dashboard
- `patient_requests_screen.dart`
- `visit_history_screen.dart`
- practitioner insights / analytics surfaces
