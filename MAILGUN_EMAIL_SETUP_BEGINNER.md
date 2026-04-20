# Mailgun Email Setup Beginner

이 문서는 `답변 요청 -> 이메일 실제 발송`을 켜기 위한 가장 쉬운 경로입니다.

현재 앱은 이미 아래까지 준비되어 있습니다.
- 침술사 화면에서 `답변 요청` 저장
- 환자 이메일 주소가 있으면 Firestore `mail` 컬렉션에 발송 큐 문서 추가

즉, 아래 설정만 끝나면 실제 메일 발송으로 이어집니다.

## 추천 이유
- Mailgun 무료 플랜: 하루 100통
- 신용카드 없이 시작 가능
- Firebase 공식 Trigger Email 확장에서 SMTP로 연결 가능

## 1. 먼저 알아둘 점
- Firebase 공식 Trigger Email 확장을 설치하려면 Firebase 프로젝트를 `Blaze` 플랜으로 올려야 합니다.
- Mailgun 무료 플랜은 공식 도움말 기준 하루 100통입니다.

## 2. Mailgun 계정 만들기
1. Mailgun 가입
2. Free plan으로 시작
3. 도메인 추가 또는 발신 도메인 설정

## 3. Mailgun에서 준비할 값
아래 4개를 기록해둡니다.
- SMTP host
- SMTP port
- SMTP username
- SMTP password

보통 Mailgun 콘솔의 Sending / SMTP credentials 쪽에서 확인합니다.

## 4. Firebase Blaze 플랜으로 변경
1. Firebase 콘솔
2. 프로젝트 선택
3. 사용량/결제 또는 플랜 변경
4. Blaze (pay as you go) 연결

주의:
- Blaze는 "사용량 기반"입니다.
- 소규모 베타에서 Firestore/Auth 자체 비용은 작을 가능성이 높지만, 메일은 실제 발송량에 따라 달라집니다.

## 5. Firebase Trigger Email 확장 설치
1. Firebase 콘솔
2. Extensions
3. `Trigger Email` 검색
4. `firestore-send-email` 설치

설치 중 입력할 값 예시:
- Cloud Firestore collection path: `mail`
- Default FROM address: 본인 발신 주소
- Default REPLY-TO address: 본인 회신 주소
- SMTP connection URI 또는 host/port/user/password: Mailgun 값 입력

## 6. 앱에서 이미 준비된 부분
현재 코드상 아래가 이미 들어가 있습니다.
- 환자 이메일이 있으면 `answer_requests` 저장과 함께 `mail` 컬렉션에도 문서 생성
- 메일 내용:
  - 환자 이름
  - 방문 예정 시간
  - 지난 방문일
  - 요청 질문 목록
  - 침술사 메모
  - 앱 링크

## 7. 테스트 방법
1. 환자 프로필에 실제 이메일 입력
2. 침술사 화면에서 `답변 요청`
3. Firestore `mail` 컬렉션에 문서 생기는지 확인
4. Trigger Email 확장이 정상 설치된 경우 실제 메일 도착 확인

## 8. 지금 단계에서 가장 현실적인 운영 방식
- 일단 지인 3~5명 정도로 베타
- 하루 100통 이내에서 테스트
- 문구/흐름이 안정되면 그때 유료 전환 검토

## 공식 참고 링크
- Firebase Trigger Email extension:
  - https://firebase.google.com/docs/extensions/official/firestore-send-email
- Firebase extension 설치 조건(Blaze 필요):
  - https://firebase.google.com/docs/extensions/install-extensions
- Mailgun Free plan:
  - https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer
- Mailgun pricing:
  - https://www.mailgun.com/pricing
