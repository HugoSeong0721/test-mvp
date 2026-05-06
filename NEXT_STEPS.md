# Next Steps

## P0
- Finish clinic-scoped local store methods for slots, requests, and visits.
- Make practitioner login always resolve to a clinic session.
- Filter patient home, requests, intake, and visit history by active clinic.
- Filter practitioner dashboard and patient record view by practitioner clinic.
- Add `clinicId` to new Firestore writes and client-side filtering for reads.

## P1
- Show an explicit "current clinic" summary on all patient screens.
- Add a soft empty state when a clinic has no slots or no submitted data yet.
- Add a clinic-aware tester seed/reset flow.

## P2
- Move from client-side filtering to indexed clinic queries where needed.
- Add full multi-clinic patient history comparison if desired.
