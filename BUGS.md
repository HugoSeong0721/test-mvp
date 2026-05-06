# Known Bugs / Risks

## Open
- Clinic selection UI exists, but not every data source is fully clinic-scoped yet.
- Some seeded visit history is still local demo data and needs clearer clinic alignment.
- Patient auth fallback is demo-friendly, but Firebase/local session behavior still needs cleanup.

## Watch For After Changes
- Missing `clinicId` on older Firestore docs should not crash the UI.
- Demo practitioner login must land with a clinic assigned.
- New clinics need slots generated automatically so patient booking is not empty.
