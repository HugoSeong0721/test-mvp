import argparse
import base64
import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

import requests


PROJECT_ID = "test-mvp-app-caec3"
API_KEY = "AIzaSyCLvcqWcVQPGiWd1nbTRaNYdev3PHV9vgU"
DATABASE_ROOT = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}"
    f"/databases/(default)/documents"
)
COLLECTIONS = (
    "answer_requests",
    "intake_submissions",
    "visit_record_feedback",
)


@dataclass
class PatientSeedTarget:
    email: str
    patient_id: str
    patient_name: str
    phone: str
    clinic_id: str


def _local_user_id_for_email(email: str) -> str:
    encoded = base64.urlsafe_b64encode(email.strip().lower().encode("utf-8"))
    return "beta_" + encoded.decode("utf-8").rstrip("=")


def _iso_timestamp(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _firestore_value(value: Any) -> dict[str, Any]:
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, datetime):
        return {"timestampValue": _iso_timestamp(value)}
    if isinstance(value, list):
        return {"arrayValue": {"values": [_firestore_value(item) for item in value]}}
    if isinstance(value, dict):
        return {
            "mapValue": {
                "fields": {
                    key: _firestore_value(item)
                    for key, item in value.items()
                },
            },
        }
    raise TypeError(f"Unsupported Firestore value: {value!r}")


def _doc_fields(payload: dict[str, Any]) -> dict[str, Any]:
    return {"fields": {key: _firestore_value(value) for key, value in payload.items()}}


def _run_query(collection: str, patient_id: str) -> list[dict[str, Any]]:
    query_url = f"{DATABASE_ROOT}:runQuery?key={API_KEY}"
    body = {
        "structuredQuery": {
            "from": [{"collectionId": collection}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "patientId"},
                    "op": "EQUAL",
                    "value": {"stringValue": patient_id},
                },
            },
        },
    }
    response = requests.post(query_url, json=body, timeout=30)
    response.raise_for_status()
    rows = response.json()
    return [row["document"] for row in rows if isinstance(row, dict) and "document" in row]


def _delete_document(doc_name: str) -> None:
    response = requests.delete(f"https://firestore.googleapis.com/v1/{doc_name}?key={API_KEY}", timeout=30)
    response.raise_for_status()


def _create_document(collection: str, payload: dict[str, Any]) -> dict[str, Any]:
    response = requests.post(
        f"{DATABASE_ROOT}/{collection}?key={API_KEY}",
        json=_doc_fields(payload),
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def _upsert_document(collection: str, doc_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    response = requests.patch(
        f"{DATABASE_ROOT}/{collection}/{doc_id}?key={API_KEY}",
        json=_doc_fields(payload),
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def _field_string(document: dict[str, Any], field_name: str) -> str:
    value = document.get("fields", {}).get(field_name, {})
    return (
        value.get("stringValue")
        or value.get("integerValue")
        or value.get("timestampValue")
        or ""
    )


def _infer_clinic_id(patient_id: str, explicit_clinic_id: str | None) -> str:
    if explicit_clinic_id:
        return explicit_clinic_id
    for collection in COLLECTIONS:
        docs = _run_query(collection, patient_id)
        for doc in docs:
            clinic_id = _field_string(doc, "clinicId").strip()
            if clinic_id:
                return clinic_id
    return "seong_acupuncture_center"


def reset_and_seed(target: PatientSeedTarget) -> None:
    deleted = 0
    for collection in COLLECTIONS:
        docs = _run_query(collection, target.patient_id)
        for doc in docs:
            _delete_document(doc["name"])
            deleted += 1

    now = datetime.now(timezone.utc)
    requested_at = now - timedelta(hours=4)
    submitted_at = now - timedelta(days=2, hours=3)
    feedback_submitted_at = now - timedelta(days=5, hours=2)
    feedback_updated_at = now - timedelta(days=4, hours=6)
    feedback_reviewed_at = now - timedelta(days=4, hours=4)

    follow_up_visit_id = f"beta_seed_visit_follow_up_{target.patient_id}"
    follow_up_visit_date = (now - timedelta(days=7)).date().isoformat()
    next_slot_date = (now + timedelta(days=1)).date().isoformat()
    next_slot_label = f"{next_slot_date} 9:00 AM"

    _create_document(
        "answer_requests",
        {
            "patientId": target.patient_id,
            "clinicId": target.clinic_id,
            "patientName": target.patient_name,
            "patientPhone": target.phone,
            "patientEmail": target.email,
            "patientTime": next_slot_label,
            "lastVisitDate": follow_up_visit_date,
            "intakeStatus": "seed_ready",
            "selectedQuestions": [
                "How have your sleep quality and wake-ups changed this week?",
                "What feels most different in your neck / shoulder area before this visit?",
            ],
            "customQuestionsByCategory": {
                "Daily Function": [
                    "Please describe one activity that still feels limited right now.",
                ],
            },
            "note": (
                "Sample follow-up request for beta testing. "
                "Please review the portal flow and continue the intake from the patient side."
            ),
            "requestType": "answer_request",
            "status": "pending",
            "source": "codex_reset_script",
            "requestedAt": requested_at,
        },
    )

    _create_document(
        "intake_submissions",
        {
            "patientId": target.patient_id,
            "clinicId": target.clinic_id,
            "patientName": target.patient_name,
            "visitType": "follow_up",
            "answers": [
                {
                    "questionIndex": 1,
                    "questionText": "How has your sleep been recently?",
                    "answerText": (
                        "I still wake up once around 3 AM, "
                        "but falling back asleep is a little easier now."
                    ),
                    "markedMainPain": False,
                    "markedRemember": True,
                },
                {
                    "questionIndex": 2,
                    "questionText": "What area feels tight or sore before this visit?",
                    "answerText": (
                        "The right shoulder blade and the base of my neck feel tight after desk work."
                    ),
                    "markedMainPain": True,
                    "markedRemember": False,
                },
                {
                    "questionIndex": 3,
                    "questionText": "How is your daytime energy this week?",
                    "answerText": (
                        "Energy is a little better in the morning, "
                        "but I still crash later in the afternoon."
                    ),
                    "markedMainPain": False,
                    "markedRemember": False,
                },
            ],
            "extraMemo": (
                "Sample beta memo: I want to know whether my shoulder tension "
                "is improving enough to reduce the night waking pattern."
            ),
            "adherence": {
                "stretchingDone": True,
                "caffeineDone": False,
                "sleepLogDone": True,
                "percent": 0.67,
            },
            "currentQuestionIndex": 3,
            "source": "codex_reset_script",
            "submittedAt": submitted_at,
        },
    )

    _upsert_document(
        "visit_record_feedback",
        f"{target.patient_id}_{follow_up_visit_id}",
        {
            "patientId": target.patient_id,
            "clinicId": target.clinic_id,
            "patientName": target.patient_name,
            "visitId": follow_up_visit_id,
            "visitDate": follow_up_visit_date,
            "visitTime": "3:30 PM",
            "feedbackText": (
                "Sample beta feedback: sleep was a little better for two nights "
                "after the last visit, but the desk-work shoulder tension returned by the weekend."
            ),
            "status": "reviewed",
            "patientCanEdit": False,
            "reviewedByPractitioner": True,
            "submittedAt": feedback_submitted_at,
            "updatedAt": feedback_updated_at,
            "reviewedAt": feedback_reviewed_at,
            "source": "codex_reset_script",
        },
    )

    print(
        json.dumps(
            {
                "patientId": target.patient_id,
                "clinicId": target.clinic_id,
                "deletedDocs": deleted,
                "seededCollections": list(COLLECTIONS),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True)
    parser.add_argument("--patient-id")
    parser.add_argument("--name", default="Test")
    parser.add_argument("--phone", default="")
    parser.add_argument("--clinic-id")
    args = parser.parse_args()

    email = args.email.strip().lower()
    patient_id = (args.patient_id or _local_user_id_for_email(email)).strip()
    clinic_id = _infer_clinic_id(patient_id, args.clinic_id)
    reset_and_seed(
        PatientSeedTarget(
            email=email,
            patient_id=patient_id,
            patient_name=args.name.strip() or "Test",
            phone=args.phone.strip(),
            clinic_id=clinic_id,
        )
    )


if __name__ == "__main__":
    main()
