# APP 개발 명세 (초보자용 v1)

## 0) 이 문서 목적
- 개발이 처음이어도 "무엇을 먼저 만들지"를 헷갈리지 않게 하는 실행 문서.
- MVP 범위는 [APP_MVP_SCOPE.md](C:/Users/mgseo/iottie_automation/APP_MVP_SCOPE.md) 기준.

## 1) 먼저 답변: 실제 화면 볼 수 있나요?
- 가능해요. 개발 중에 실제 화면을 계속 볼 수 있습니다.
- 방법은 3가지:
1. 와이어프레임(정적): 레이아웃만 빠르게 확인.
2. 프로토타입(클릭형): 버튼 누르면 화면 이동 확인.
3. 앱 빌드 화면(실기기/에뮬레이터): 실제 앱처럼 동작 확인.

## 2) 초보자 추천 개발 경로
1. 이번 주: 정적 화면 확인(HTML 미리보기)
2. 다음 주: 클릭형 프로토타입(Figma or FlutterFlow)
3. 그다음: 실제 앱 개발(Flutter + Firebase 권장)

## 3) MVP 화면 목록
1. 환자 문진 입력 화면
2. 침술사 대시보드(환자 리스트)
3. 침술사 환자 상세(세션 전 브리핑)

## 4) 데이터 모델 (MVP 최소)

### 4.1 users
- id (string, pk)
- role (`patient` | `practitioner`)
- name (string)
- clinic_id (string, nullable)
- created_at (datetime)

### 4.2 clinics
- id (string, pk)
- name (string)
- timezone (string, e.g. `America/New_York`)

### 4.3 appointments
- id (string, pk)
- clinic_id (string)
- patient_id (string)
- practitioner_id (string)
- scheduled_at (datetime)
- status (`scheduled` | `completed` | `cancelled`)

### 4.4 intake_responses
- id (string, pk)
- appointment_id (string)
- patient_id (string)
- category_key (string, e.g. `sleep`, `pain`, `digestion`)
- answer_text (text)
- is_main_pain (boolean)
- remember_me (boolean)
- submitted_at (datetime)

### 4.5 ai_summaries
- id (string, pk)
- appointment_id (string)
- patient_id (string)
- summary_3lines (text)
- highlights_json (json)
- missing_categories_json (json)
- generated_at (datetime)
- status (`ready` | `pending` | `failed`)

## 5) API 설계 (MVP 최소)

### 5.1 환자 문진 제출
- `POST /api/v1/intake/submit`
- request:
```json
{
  "appointmentId": "apt_001",
  "patientId": "pat_001",
  "responses": [
    {
      "categoryKey": "sleep",
      "answerText": "새벽 3시에 자주 깹니다.",
      "isMainPain": false,
      "rememberMe": true
    }
  ]
}
```
- response:
```json
{
  "ok": true,
  "summaryStatus": "pending"
}
```

### 5.2 침술사 대시보드 리스트
- `GET /api/v1/practitioner/dashboard?date=2026-04-14&clinicId=...`
- response:
```json
{
  "patients": [
    {
      "appointmentId": "apt_001",
      "patientName": "Jane Kim",
      "scheduledAt": "2026-04-14T15:30:00-04:00",
      "intakeSubmitted": true,
      "summaryPreview": "수면 중 각성 증가, 오후 피로, 어깨 통증 호소",
      "hasHighlight": true
    }
  ]
}
```

### 5.3 환자 상세 브리핑
- `GET /api/v1/practitioner/patient-brief?appointmentId=apt_001`
- response:
```json
{
  "summary3Lines": [
    "최근 2주간 수면 질 저하",
    "오후 피로와 목/어깨 통증 악화",
    "카페인 섭취 후 심계항진 느낌 보고"
  ],
  "highlights": [
    "이게 메인 통증이에요: 오른쪽 어깨",
    "침술사가 기억해줬으면 해요: 새벽 각성"
  ],
  "missingCategories": ["digestion", "emotion"],
  "categories": [
    { "key": "sleep", "answerText": "새벽에 2~3회 깹니다." }
  ]
}
```

## 6) AI 요약 규칙 (중요)
- 출력은 반드시 "요약/정리" 톤.
- 진단처럼 들리는 단어 금지.
- 최대 3줄 + 강조항목 + 미응답 카테고리만 반환.

## 7) 개발 순서 (초보자 실행형)
1. 화면 3개를 먼저 만든다 (데이터 없이 더미 텍스트).
2. 더미 데이터를 붙여 화면 전환을 확인한다.
3. API 연결 (제출 -> 요약 생성 -> 대시보드 반영).
4. 예외처리 (요약 pending/failed).
5. 텍스트/버튼 크기 등 접근성 정리.

## 8) 지금 당장 할 일
1. [SCREEN_PREVIEW.html](C:/Users/mgseo/iottie_automation/SCREEN_PREVIEW.html) 열어서 화면 구조 체감.
2. 화면 보고 문구/순서 수정 포인트 5개 메모.
3. 그 수정본으로 실제 Flutter 화면 구현 시작.
