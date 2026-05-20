# Next Steps

## P0
- Audit remaining Firestore reads for places that can move from client-side clinic filtering to indexed queries.
- Add focused regression tests for clinic-scoped patient reset/seed and practitioner session restore.

## P1
- Add a soft empty state when a clinic has no slots or no submitted data yet.
- Review patient-facing Korean copy on clinic context and empty states.

## P2
- Move from client-side filtering to indexed clinic queries where needed.
- Add full multi-clinic patient history comparison if desired.
