# Firestore Rules Next Step

## 왜 지금 바로 완전 잠그지 않았나
현재 앱은:
- 지인 환자 계정: Firebase Authentication 사용 시작
- 침술사 계정: 아직 Firebase Authentication 미사용

그래서 `intake_submissions`, `answer_requests`까지 바로 강하게 잠그면
현재 침술사 대시보드가 깨질 수 있습니다.

## 지금 바로 적용해도 되는 것
`patients/{uid}` 문서는 가입한 본인만 읽고 수정 가능하게 잠그기

이것만으로도:
- 지인 베타 사용자의 프로필이 서로 섞여 보이는 문제를 줄일 수 있습니다.

## 파일
- `firestore.rules`
- `firebase.json`
- `.firebaserc`

## 콘솔에서 적용하는 방법
1. Firebase 콘솔 열기
2. `Firestore Database`
3. 상단 `규칙`
4. 현재 규칙 전체 삭제
5. `firestore.rules` 내용 붙여넣기
6. `게시`

## 현재 규칙의 의미
- `patients/{uid}`: 본인만 읽기/쓰기 가능
- `intake_submissions`, `answer_requests`: 아직 열어둠

## 다음 단계
침술사도 Firebase Authentication으로 로그인하게 바꾸기

그 다음에는:
- 침술사 role 문서
- 환자별 제출 읽기 권한
- 답변 요청 생성/읽기 권한
을 role 기반으로 제대로 잠글 수 있습니다.
