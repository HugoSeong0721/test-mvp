# EMAIL_SETUP_CLICK_BY_CLICK.md

이 문서는 `답변 요청 -> 실제 이메일 발송`을 켜기 위한 클릭 순서만 적어둔 문서입니다.

## 목표
- Mailgun 무료 구간(하루 100통)으로 시작
- Firebase Trigger Email 확장 연결
- 앱에서 `답변 요청` 누르면 실제 이메일 발송

공식 참고:
- Mailgun Free plan: https://help.mailgun.com/hc/en-us/articles/203068914-What-does-the-Free-plan-offer
- Mailgun SMTP credentials: https://help.mailgun.com/hc/en-us/articles/203409084-Adding-SMTP-credentials
- Firebase Trigger Email: https://firebase.google.com/docs/extensions/official/firestore-send-email
- Firebase Extensions install (Blaze 필요): https://firebase.google.com/docs/extensions/install-extensions

## A. Mailgun에서 할 것
### 1. 가입
1. https://www.mailgun.com/ 접속
2. `Start for free` 또는 가입 버튼 클릭
3. Free plan으로 시작

### 2. 도메인/샌드박스 확인
1. Mailgun 콘솔 로그인
2. `Sending` 또는 `Domains` 메뉴 이동
3. 기본 샌드박스 도메인이 보이면 그걸 먼저 써도 됨
4. 나중에 실제 운영하면 커스텀 도메인 추가 권장

### 3. SMTP 값 찾기
공식 도움말 기준으로 domain settings의 SMTP credentials에서 확인합니다.

보통 경로:
1. `Domains` 또는 `Sending`
2. 사용할 도메인 클릭
3. `Domain settings`
4. `SMTP credentials`

여기서 필요한 값 4개:
- SMTP host
- SMTP port
- SMTP username
- SMTP password

없으면 새 SMTP credential 생성

## B. Firebase에서 할 것
### 1. Blaze 플랜으로 전환
1. Firebase 콘솔 열기
2. 프로젝트 `test-mvp-app` 선택
3. 왼쪽 아래 `업그레이드` 또는 결제 관련 메뉴 클릭
4. `Blaze (pay as you go)` 선택
5. 카드/결제 연결

주의:
- Extensions 설치는 Blaze 필요
- 아주 작은 베타는 비용이 거의 없거나 작을 가능성이 높지만, 0원을 보장하진 않음

### 2. Trigger Email 확장 설치
1. Firebase 콘솔
2. `Extensions`
3. 검색창에 `Trigger Email`
4. `firestore-send-email` 선택
5. 설치

### 3. 설치할 때 넣을 값
추천값:
- Cloud Firestore collection path: `mail`
- Default FROM address: 본인 발신 이메일
- Default REPLY-TO address: 본인 회신 이메일
- SMTP host: Mailgun 값
- SMTP port: Mailgun 값
- SMTP username: Mailgun 값
- SMTP password: Mailgun 값

가능하면 FROM 주소는 Mailgun에서 허용된 발신 주소로 맞추기

## C. Firestore 규칙 반영
앱이 `mail` 컬렉션에 쓸 수 있어야 함

1. Firebase 콘솔
2. `Firestore Database`
3. 상단 `규칙`
4. 현재 프로젝트의 `firestore.rules` 내용으로 교체
5. `게시`

현재 규칙 파일 경로:
- `C:\Users\mgseo\OneDrive\Desktop\MG\Personal\99 Tracking\Test_MVP\firestore.rules`

## D. 테스트
### 1. 환자 쪽
1. 링크 열기
2. 비밀번호 `Daisy`
3. `지인 베타 회원가입/로그인`
4. 실제 이메일로 가입
5. 프로필에서 이메일 입력 확인

### 2. 침술사 쪽
1. `123 / 123` 로그인
2. 환자 정보 관리에서 해당 사람 정보 확인
3. `답변 요청`
4. 질문 1개 이상 선택 후 전송

### 3. Firebase 확인
1. Firestore
2. `answer_requests` 문서 생성 확인
3. `mail` 컬렉션 문서 생성 확인

### 4. 이메일 확인
- Trigger Email 확장이 정상 연결되면 실제 메일 도착

## E. 지금 이미 코드로 준비된 것
- 환자 이메일이 있으면 `mail` 컬렉션에 자동 문서 생성
- 메일에는 아래 내용 포함
  - 환자 이름
  - 방문 예정 시간
  - 지난 방문일
  - 요청 질문 목록
  - 침술사 메모
  - 앱 링크
  - 첫 비밀번호 안내

## F. 막히면 가장 먼저 볼 것
- Mailgun SMTP 값 정확한지
- Firebase 프로젝트가 Blaze인지
- Trigger Email 확장 설치됐는지
- Firestore `mail` 문서가 생기는지
- 환자 이메일이 비어있지 않은지
