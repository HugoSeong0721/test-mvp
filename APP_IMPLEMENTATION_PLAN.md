# APP Implementation Plan (No-Design First)

## 목표
- 화면 확인이 안 되는 상황에서도 개발을 진행할 수 있게, 기능 중심으로 MVP를 구현한다.

## Tech 선택 (고정)
- Frontend: Flutter
- Backend: Firebase (Auth + Firestore + Functions)
- AI 요약: Cloud Function에서 LLM 호출

## 1단계: 프로젝트 골격
1. Flutter 프로젝트 생성
2. `lib/features/` 기준 기능 폴더 분리
3. 더미 데이터로 3개 화면 라우팅만 연결

## 2단계: 데이터/권한
1. Firestore 컬렉션 생성
   - `users`, `clinics`, `appointments`, `intake_responses`, `ai_summaries`
2. 역할 분리
   - `patient`, `practitioner`
3. 보안 규칙
   - 본인 환자 데이터만 조회 허용

## 3단계: 핵심 기능 구현
1. 환자 문진 제출
2. 요약 생성 트리거
3. 침술사 대시보드 리스트 조회
4. 환자 상세 브리핑 조회

## 4단계: 예외 처리
1. 요약 `pending` 표시
2. 요약 `failed` 재시도 버튼
3. 미응답 카테고리 강조

## 5단계: MVP 완료 조건
1. 테스트 계정으로 End-to-End 동작
2. 제출 -> 요약 -> 대시보드 반영까지 1분 내 확인
3. 진단성 문구 없이 요약형 텍스트만 노출

## 폴더 구조(권장)
```txt
lib/
  app.dart
  core/
    constants/
    models/
    services/
  features/
    patient_intake/
      presentation/
      data/
    practitioner_dashboard/
      presentation/
      data/
    patient_brief/
      presentation/
      data/
```

## 내일 바로 할 일 (실행 순서)
1. Flutter 설치/프로젝트 생성
2. 라우트 3개 만들기
3. 더미 데이터 연결
4. Firebase 연결
