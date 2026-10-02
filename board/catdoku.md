# Kitty Queens: Cat Sudoku (Catdoku 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 05:40 (KST)

## 지금 상태 (3줄 이내)
Flutter 앱(`catdoku_app/flutter/`) 1차 완성 + 점검 팀 1차 수정 반영, 테스트 로봇 21개 통과, 웹 미리보기 `docs/catdoku-app/`.
번들 ID `com.soulfulfill.catdoku` Apple 에 등록 완료(Actions `iOS 번들 ID 등록 · 앱 레코드 확인` 로그로 확인).
광고는 아직 Google 테스트 ID — ASC 앱 레코드·AdMob 앱을 사용자가 만들면 TestFlight 로.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] App Store Connect → 앱 → ＋ → 신규 앱: iOS / `Kitty Queens: Cat Sudoku` / English (U.S.) / 번들 `com.soulfulfill.catdoku` / SKU `catdoku`.
  이게 없으면 `Release iOS` 업로드가 실패한다 (앱 레코드는 API 로 못 만든다).
- [사용자] AdMob(**`soulfulfillable` 계정**) → 앱 추가(iOS, 스토어 미등록, 이름 Kitty Queens) → 광고 단위 3개: 배너 `banner`, 보상형 `rewarded_hint`, 보상형 `rewarded_continue`.
  앱 ID(`~`) + 단위 ID 3개(`/`) 받으면 `lib/core/ads.dart`·`ios/Runner/Info.plist`(GADApplicationIdentifier) 교체.
- [세션] 점검 워크플로 남은 3명(단계 모드·화면 크기·극단 상황) 결과 반영 → 광고 상황 전담 점검 팀(`?ads=slow|none|early`) 한 번 더.
- [세션] `Release iOS`(app=catdoku) → TestFlight → 사용자 '느낌' 피드백 → 스크린샷(1290×2796)·`catdoku_app/store/ios-metadata.json` → 심사.
- 기록: 진행 상세는 `plans/catdoku-app.md` 진행 기록, 스토어 초안·이름 조사 `catdoku_app/store/ios-listing.md`.

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-02 | AdMob 배너 생성 화면 캡처 + "너가 이거보고 기억하면되지않냐 done 누르까" | 앱 ID `ca-app-pub-4724352880074547~4704304321`(Info.plist), 배너 `…/8563658282`(ads.dart) 반영. 보상형 2개는 "Create another ad unit" 으로 이어 만들게 안내 |
| 10-02 | "오 soulfulfillable이엇던거같애 기억하고 다른애들한테도 나중에 알려놔주라" (AdMob 계정) | `ops/README.md` 계정 표 + `board/_shared.md` "계정" 절에 기록 (게시자 ID `pub-4724352880074547`) |
| 10-02 | ASC 신규 앱 화면 캡처 + "일단 여기는 이렇게하면되지?" | iOS / Kitty Queens: Cat Sudoku / English (U.S.) / com.soulfulfill.catdoku / SKU catdoku / Full Access — 맞다고 확인, Create 안내 |
| 10-02 | "이제부터 세션끼리 board/ 게시판으로 공유해" | 이 파일 작성 |
| 10-02 | "그래 뭐 내가 해야하는거잇으면 알려줘" | 사용자 할 일은 위 "다음 할 일"에 [사용자] 로 클릭 단위로 적어 둠 |
| 10-02 | "와 어렵다 아그래도 했네 오케이 내볼까" | 7×7 오늘의 퍼즐이 첫 판으로 어려움 → `PRODUCT.md` 결정 로그에 기록, 처음 사용자에게 5×5 단계부터 권할지 TestFlight 때 재검토. 출시 진행 |
| 10-02 | "광고보기 그런거 watch video 이런거 잘 되게 해보자 … 하트 다쓰거나 힌트로 비디오(광고) 보면 알려주고 그런거 맞지?" | 보상형 2자리(힌트 / 하트 0 → ❤️+3 이어하기, 판 유지). 영상 미도착 시 최대 8초 "Loading video…", 중간 닫기 = 보상 없음 + 안내, 실패 시 백오프 재로딩, 두 번 탭해도 1회, 광고 중 시계 정지. 자리별 광고 단위 분리(수익 비교용) |
| 10-02 | 앱 이름 A/B/C → "Kitty Queens (추천)", 번들 → "catdoku 로 등록 (추천)" | 이름 `Kitty Queens: Cat Sudoku`, 번들 `com.soulfulfill.catdoku` 등록 |
| 10-02 | "내가 핸폰으로 해볼수있는 링크가 뭐니" | Flutter 웹 빌드를 `docs/catdoku-app/` 로 배포 → https://soulfulfillable.github.io/test-mvp/catdoku-app/index.html |
| 10-02 | "어느정도 가닥 잡으면 워크플로로 버튼 하나씩 다 눌러보고 작동 확인해봐줘" | 워크플로 `catdoku-button-qa`: 점검 5명(홈/오늘 퍼즐/단계/화면 크기/극단 상황) + 재현 검증 1명. 1차 2명 결과로 주요 4건·자잘한 6건 수정 |
| 10-02 | "아니 그 새 세션이 너야" | 기획 세션 안내문을 받은 이 세션이 곧 개발 세션 — 바로 개발 시작 |
| 10-02 | (기획 세션 안내) "게임 양은 A(오늘의 퍼즐 + 무한 단계)로" | 오늘의 퍼즐 7×7 + 단계 5×5→9×9 무한 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- **직접 폰으로 해 보고 싶어 한다** → 앱 빌드 전이라도 Flutter 웹 빌드를 Pages 로 올려 링크를 준다. 첫 질문이 "핸폰으로 해볼수있는 링크".
- 결정은 **추천을 고른다**(이름·번들 둘 다 추천안). AskUserQuestion 으로 2지선다를 주면 바로 답한다.
- "워크플로/팀"으로 **여러 작업자가 버튼을 다 눌러 보는 검증**을 좋아한다 — 기능을 얹을 때마다 돌려 달라고 함.
- 본인이 해야 할 일은 **물어보기 전에 정리해서** 알려 주길 원한다 ("내가 해야하는거잇으면 알려줘").
- 광고는 "영상 보면 보상" 구조를 이해하고 원한다 — 보상형이 수익의 핵심.
- 퍼즐 난이도: 7×7 첫 판은 "어렵다" 했지만 풀어냄. 너무 쉽게 만들 필요는 없지만 첫 경험은 조심.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **Flutter 웹 미리보기 = 폰으로 바로 해 보는 링크.** `flutter create . --platforms web` → `flutter build web --release --base-href /test-mvp/<폴더>/`
  → `build/web` 을 `docs/<폴더>/` 로 복사하되 **`canvaskit/` 폴더는 빼라**(40MB → 3.6MB, 엔진은 gstatic CDN 에서 받음).
  광고 SDK(google_mobile_ads)는 웹 미지원 → `kIsWeb` 이면 가짜 광고(FakeAds)로 갈아끼운다.
- **샌드박스에서 Flutter 웹 테스트**: www.gstatic.com·github.io 가 프록시에서 막힌다. Playwright `page.route` 로
  `flutter-canvaskit/<rev>/…` 요청을 로컬 `build/web/canvaskit/` 사본으로 응답, 나머지 https 는 node fetch(`NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt`)로 대신 받아 fulfill.
  헬퍼: `catdoku_app/qa/flutter-web-harness.js` (사용법은 파일 머리말).
- **Flutter 웹을 자동 점검하려면** `SemanticsBinding.instance.ensureSemantics()` (kIsWeb 일 때) → `page.getByRole('button', {name})` 로 버튼을 누를 수 있다.
  CustomPaint 판은 `Semantics(container: true, label: …)` 로 감싸야 위치(boundingBox)를 찾을 수 있다.
  localStorage 키는 `flutter.` 접두 + JSON 값 (`flutter.level='60'`) → 상태를 미리 깔고 시험.
- **웹 미리보기에서 광고 상황 흉내**: `?ads=slow|none|early` 쿼리로 가짜 광고 동작을 바꾸게 해 두면 점검 팀이 실패 경로까지 누른다.
- **테스트 로봇에서 시간**: 위젯 테스트는 가짜 시계 — `DateTime.now()` 로 입력 잠금 같은 걸 만들면 테스트에서 안 풀린다. `Timer` 로 만들 것.
  `pumpAndSettle` 은 무한 애니메이션(승리 바운스)·주기 타이머가 있으면 안 끝난다 → `pump(Duration)` 을 쓴다.
- **점검 팀이 잡은 흔한 버그 (다른 앱도 확인할 것)**:
  ① `await Navigator.push` 직후 setState 로 홈을 갱신하면 늦다 — 다음 화면의 dispose 저장이 pop 뒤에 일어난다. 홈은 저장소(ChangeNotifier)를 구독해 다시 그려라.
  ② `pushReplacement` 로 바꾼 화면은 원래 push 의 Future 를 바로 끝낸다 → 홈이 옛 값으로 남는다(같은 원인).
  ③ 앱을 켜 둔 채 자정이 지나면 "오늘" 카드가 어제 그대로 → 앱 복귀(resumed) + 주기 확인으로 날짜 바뀜 감지.
  ④ 다이얼로그 버튼을 두 번 누르면 두 번째 탭이 아래 화면(판)에 떨어진다 — 창 닫힌 뒤 0.45초 입력 잠금.
  ⑤ 마지막 실수와 동시에 결과 패널을 띄우면 "왜 졌는지"가 안 보인다 — 1초쯤 뒤에 띄운다.
  ⑥ 뒤로 가기 한 번에 진행이 날아가면 안 된다 — 판 상태를 저장/복원(하트 0 인 채 나갔다 오면 그대로 0, 우회 차단).
- **생성형 퍼즐**: 유일해 퍼즐을 다시 뽑기로 찾으면 8×8 부터 수천 번 걸린다. "다른 해의 칸을 이웃 구역으로 넘기기" 보정이면 9×9 도 수십 ms.
  난수는 xorshift32(시프트·XOR 만) — Dart 네이티브·웹(JS 숫자)에서 같은 시드가 같은 판을 낸다 (곱셈 기반 mulberry 는 웹에서 어긋날 수 있음).
- **스토어 이름은 먼저 검색**: "Catdoku" 는 App Store·플레이에 동명 앱이 여럿이었다. 웹게임 이름을 그대로 쓰기 전에 검색할 것.
- **번들 ID 등록은 API 로 된다**(`asc_signing.py register`), **앱 레코드는 사람이 ASC 웹에서** 만들어야 한다.
- 앱 아이콘은 이모지 이미지 대신 SVG 를 직접 그려 Playwright 로 1024 PNG 렌더 (이모지 아트는 저작권 문제).

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 첫 사용자에게 오늘의 퍼즐(7×7)보다 5×5 단계를 먼저 권할지 — 사용자 "어렵다" 피드백. TestFlight 느낌 보고 결정해도 될지.
- 기획 파트너: 단계 모드 몇 판마다 전면 광고를 넣을지(기획서엔 "TestFlight 느낌 보고") — 지금은 배너+보상형만.
- 다른 세션: AdMob 앱/광고 단위 만드는 안내를 공용(`board/_shared.md`)으로 올릴까? 앱마다 같은 절차라 재사용 가능.
