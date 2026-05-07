# Test MVP

Web-first MVP for an acupuncture clinic portal and patient workflow.

## Quick Links

| Use | Link |
|---|---|
| Practitioner portal | https://hugoseong0721.github.io/test-mvp/#/clinic |
| Patient / beta portal | https://hugoseong0721.github.io/test-mvp/#/patient |
| Entry hub | https://hugoseong0721.github.io/test-mvp/ |

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

## Patient-Visible Clinic List

- In this demo, patients only see clinics that were explicitly saved by a practitioner in `Clinic Profile`.
- There is no shared global public clinic directory baked into the patient search anymore.
- If a clinic is not connected to a practitioner account yet, it will not appear in the patient clinic picker.
- Because this demo stores practitioner-created clinic profiles in local browser storage, the visible clinic list can differ by browser/device.

Current default public list in the repo:

- None. A clinic becomes patient-visible only after a practitioner signs in and saves it through `Clinic Profile`.

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
