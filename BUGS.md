# Known Bugs / Risks

## Open
- Some seeded visit history is still local demo data and should get regression coverage.
- Patient auth fallback is demo-friendly, but Firebase/local session behavior still needs cleanup.
- Firestore reads are mostly client-side filtered by `clinicId`; indexed clinic queries are still a scale/performance follow-up.

## Watch For After Changes
- Missing `clinicId` on older Firestore docs should be ignored rather than shown in scoped views.
- Demo and restored practitioner login should land with a clinic assigned after store restore.
- New clinics need slots generated automatically so patient booking is not empty.
