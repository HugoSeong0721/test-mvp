# Firebase Beta Setup

친구들이 직접 회원가입해서 제출해보게 하려면 아래 2가지를 먼저 켜야 합니다.

## 1. Firebase Authentication 켜기
1. Firebase 콘솔 열기
2. 왼쪽 `빌드` -> `Authentication`
3. `시작하기`
4. `Sign-in method`
5. `이메일/비밀번호` 활성화
6. 저장

## 2. 앱에서 들어가는 경로
1. 첫 비밀번호: `Daisy`
2. 홈 화면에서 `지인 베타 회원가입/로그인`
3. 이메일/비밀번호로 가입
4. 바로 환자 화면으로 진입

## 지금 되는 것
- 회원가입
- 로그인
- 내 프로필 Firestore 저장
- 환자 문진 제출 Firestore 저장
- 침술사 대시보드에서 최근 베타 제출 보기

## 아직 남은 것
- Firestore 보안 규칙을 사용자별로 더 엄격하게 분리
- 침술사도 Firebase Auth 계정으로 관리
- 이메일/SMS 실제 발송

## 권장 테스트 방식
- 이름: 실명 또는 별칭
- 이메일: 실제 이메일
- 전화번호: 실제 번호 또는 테스트 번호
- 증상: 민감한 실제 건강정보 대신 테스트용 문구로 먼저 확인

## Firestore Rules 초안
아래는 `patients` 컬렉션만 먼저 자기 문서만 읽고 쓰게 하는 초안입니다.

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /patients/{userId} {
      allow read, create, update: if request.auth != null && request.auth.uid == userId;
      allow delete: if false;
    }

    match /intake_submissions/{documentId} {
      allow create: if request.auth != null;
      allow read: if true;
      allow update, delete: if false;
    }

    match /answer_requests/{documentId} {
      allow read: if true;
      allow create: if true;
      allow update, delete: if false;
    }
  }
}
```

주의:
- 이 규칙은 지금 구조를 최대한 덜 깨면서 임시로 쓰는 초안입니다.
- 진짜 공개 베타 전에는 침술사 계정도 Firebase Auth로 바꾸고 규칙을 다시 정교하게 잡는 것이 좋습니다.
