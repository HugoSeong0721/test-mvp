# Kitty Queens: Cat Sudoku (Catdoku 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 13:30 (KST)

## 지금 상태 (3줄 이내)
TestFlight 빌드 12까지 설치. 이번에 **단계 목록 화면 + 1~30 무료 → 20단계마다 영상 또는 $1.99 전부 열기(배너 제거)** 추가 → 빌드 13.
결제 상품 `com.soulfulfill.catdoku.unlockall` 은 Actions `iOS 앱 내 구입 상품 만들기` 로 생성. 판매엔 사용자의 유료 앱 계약(은행·세금) 필요.
테스트 로봇 32개 통과.

## 다음 할 일 / 사용자에게 받을 것
- [v1.1 아이디어, 사용자 관심] 뉴스레터 구독: "Get new puzzles & apps first" 선택형 이메일 칸(로그인 없음) → 무료 뉴스레터 서비스, 모든 앱 공용 목록. 이메일 판매는 안 됨(Apple 규칙·주 개인정보법)으로 안내함. 넣을 때 개인정보처리방침·App Privacy(Email) 갱신.
- ✅ [사용자] ASC 앱 레코드 생성 (id 6818637278), ✅ AdMob 앱·광고 단위 3개, ✅ TestFlight 내부 그룹 "me" 설치.
- [사용자] TestFlight 빌드로 해 보고 '느낌' 피드백 (광고는 누르지 않기).
- [세션] 점검 워크플로 남은 3명(단계 모드·화면 크기·극단 상황) 결과 반영 → 광고 상황 전담 점검 팀(`?ads=slow|none|early`) 한 번 더.
- [세션] `Release iOS`(app=catdoku) → TestFlight → 사용자 '느낌' 피드백 → 스크린샷(1290×2796)·`catdoku_app/store/ios-metadata.json` → 심사.
- 기록: 진행 상세는 `plans/catdoku-app.md` 진행 기록, 스토어 초안·이름 조사 `catdoku_app/store/ios-listing.md`.

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | 폰 캡처(Level 11, 고양이 3마리, 위쪽에 빈칸 남음, "No spot left") + "스팟 남아잇는데 안남아잇다고나오네" | 계산은 맞았다(5·7번째 줄이 전부 막힘). 하지만 '어디가' 막혔는지 안 보여 틀린 말로 읽힘 → "Row 5 has no spot left — move a cat" 처럼 막힌 줄/열/색을 짚고, 판에 빨간 테두리. 캡처 판을 그대로 재현하는 테스트 추가. 빌드 14 |
| 10-03 | "내가 깼던 이전거로 돌아가거나 앞으로 몇개나 남았는지 볼수는 없나? 그리고 한 20개정도씩이나 … 1.99 이렇게 돈 내기 … 결제하면 또 얼마만큼 열리고" → A/B "영상 or $1.99 (추천)" | 단계 목록 화면(✓ 깬 단계 다시 하기, n/500, 잠긴 묶음 🔒), 1~30 무료 → 20단계마다 영상 1개 또는 $1.99 전부+배너 제거, Restore purchase. 결제 상품은 API 로 생성 |
| 10-03 | 폰 캡처(Level 3, 4/5 고양이, 남은 칸 전부 ✕, "No video available right now") + "이거지금만 안되는거겟지?" | 새 광고 단위(최대 1시간)·AdMob 새 앱 검토(출시·스토어 링크 전엔 광고 적음) 때문 → **영상이 없으면 보상을 그냥 준다**("this one’s on us 🎁"). 캡처는 틀린 고양이로 막다른 길 → "🤔 No spot left — move a cat or try 💡 Hint" 표시 추가. 빌드 12 |
| 10-02 | (점검 워크플로 완료: 5명 426회 누름, 46건 보고 → 재현 검증 46건) | 남은 주요 2건(마지막 칸 연타로 승리 패널 건너뜀, 반칙 칸 연타로 하트 여러 개) + 깨진 저장 회색 화면 + Mark 붓 고양이 삭제·끌어 지우기 수정 → 빌드 11 |
| 10-02 | "아 테스트앱에서 받아서 열엇어" | TestFlight 빌드 10 설치 확인. 느낌 피드백 대기 |
| 10-02 | TestFlight 그룹 화면 캡처 + "어떻게 test flight 에서 들어가는거엿지 … 번호누르고 햇던거같은데" | 내부 그룹 → Invite Testers → 초대 메일 "View in TestFlight" → 8자리 Redeem 코드 → TestFlight 앱에서 입력, 이라고 안내 |
| 10-02 | "그거 뭐엿지 저 앱스토어 커넥트 그거 주소좀" | https://appstoreconnect.apple.com/apps/6818637278/testflight/ios |
| 10-02 | 보상형 2개 생성 캡처 + "rewarded continue는안보이는데" → "done 눌럿어" | 이름(rewarded_continue)과 광고 형식(Rewarded 카드)이 헷갈림 → 형식은 4번째 Rewarded 카드라고 안내. 힌트 `…/7250576612`, 이어하기 `…/7933102895` 반영 |
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
- **새 앱 iOS 출시 순서 (이 세션에서 실제로 된 순서, 총 1시간 안쪽)**: ① `iOS 번들 ID 등록 · 앱 레코드 확인` Actions 로 번들 등록
  → ② 사용자가 ASC 웹에서 신규 앱(이름·언어·번들·SKU·Full Access) → ③ 같은 Actions 재실행으로 "앱 레코드: 있음" 확인
  → ④ `Release iOS` (앱 선택) — 서명~업로드 6분 → ⑤ 사용자: TestFlight 내부 그룹 + Invite Testers → 메일 "View in TestFlight" 의 Redeem 코드.
- **'막혔다' 같은 판정 메시지는 *어디가* 그런지 짚어라**: "No spot left" 만 띄웠더니 다른 줄의 빈칸을 보고 "자리 남아 있는데?" — 판정은 맞았는데 틀린 말로 읽혔다. 줄/열/색 이름 + 판 위 테두리.
- **보상형 광고는 '영상 없음'을 막힘으로 만들지 마라**: 새 AdMob 앱은 스토어 출시·링크 전까지 광고 재고가 거의 없다(TestFlight 에서 "No video" 연속).
  영상이 안 오면 보상을 그냥 주고(중간에 닫은 경우만 안 줌), 막다른 상태(더 놓을 칸 없음)는 화면에 이유를 띄운다.
- **앱 내 구입(IAP)은 API 로 만들 수 있다**: `.github/scripts/asc_iap.py` + Actions `iOS 앱 내 구입 상품 만들기` (상품·현지화·가격 USD·판매국·심사 스크린샷).
  사람이 꼭 해야 하는 건 ASC → 비즈니스 → **유료 앱 계약(은행·세금)** 뿐. 첫 IAP 는 앱 새 버전과 함께 심사. 앱에는 Restore purchase 버튼 필수.
  Flutter 는 `in_app_purchase` — 테스트·웹은 FakePurchases 로 바꿔 끼워 결제/취소/복원 흐름을 로봇이 누른다.
- **AdMob 안내할 때**: 사용자가 광고 단위 *이름*(rewarded_continue)을 *형식* 목록에서 찾았다 — "형식은 Rewarded 카드(4번째, Rewarded interstitial 아님), 이름은 직접 입력"이라고 분리해서 말할 것.
  완료 화면 캡처를 받으면 ID 를 읽어 바로 코드에 넣는다(사용자: "너가 이거보고 기억하면되지않냐"). 새 광고 단위는 첫 광고까지 최대 1시간.
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
  ⑦ **연타(두 번·세 번 탭)는 모든 버튼에서 사고를 낸다** (점검 426회 중 가장 많이 나온 유형): 다음 레벨 버튼 연타 → 레벨 건너뛰기+저장 중단,
     새 판 버튼 연타 → 새 판에 엉뚱한 고양이, 반칙 칸 연타 → 하트 2~3개 한꺼번에, 마지막 칸 연타 → 바로 뜬 승리 패널 버튼이 눌려 축하 건너뜀,
     힌트 연타 → 창이 열리자마자 바깥 탭으로 닫힘. 대응: 결과 패널은 0.9~1.1초 뒤에 띄우고, 새 판·반칙·창 닫힘 뒤 0.45~0.7초 입력 잠금,
     "다음 단계"는 level++ 대신 저장된 진행에서 계산, 확인 창은 barrierDismissible:false.
  ⑧ Flutter 웹(ensureSemantics 켠 상태)에서는 Stack 위 반투명 패널이 뒤의 버튼 접근성 노드를 못 막는다 — AbsorbPointer + ExcludeSemantics 로 감쌀 것.
  ⑨ 저장 데이터 복원은 형식 검사 + try/catch — 깨진 저장 한 줄로 회색 화면에 갇혔다.
- **점검 워크플로 팁**: 점검 대상 서버를 하나로 고정하라 — 작업 중에 새 빌드를 다른 포트에 띄웠더니 작업자들이 옛 빌드/새 빌드를 섞어 보고했다(그래도 재현 검증 단계가 구분해 줬다).
  CPU 2개 환경에서는 동시 2명씩만 돌아 5명+검증 1명이 2시간 반 걸렸다.
- **생성형 퍼즐**: 유일해 퍼즐을 다시 뽑기로 찾으면 8×8 부터 수천 번 걸린다. "다른 해의 칸을 이웃 구역으로 넘기기" 보정이면 9×9 도 수십 ms.
  난수는 xorshift32(시프트·XOR 만) — Dart 네이티브·웹(JS 숫자)에서 같은 시드가 같은 판을 낸다 (곱셈 기반 mulberry 는 웹에서 어긋날 수 있음).
- **스토어 이름은 먼저 검색**: "Catdoku" 는 App Store·플레이에 동명 앱이 여럿이었다. 웹게임 이름을 그대로 쓰기 전에 검색할 것.
- **번들 ID 등록은 API 로 된다**(`asc_signing.py register`), **앱 레코드는 사람이 ASC 웹에서** 만들어야 한다.
- 앱 아이콘은 이모지 이미지 대신 SVG 를 직접 그려 Playwright 로 1024 PNG 렌더 (이모지 아트는 저작권 문제).

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 첫 사용자에게 오늘의 퍼즐(7×7)보다 5×5 단계를 먼저 권할지 — 사용자 "어렵다" 피드백. TestFlight 느낌 보고 결정해도 될지.
- 기획 파트너: 단계 모드 몇 판마다 전면 광고를 넣을지(기획서엔 "TestFlight 느낌 보고") — 지금은 배너+보상형만.
- 다른 세션: AdMob 앱/광고 단위 만드는 안내를 공용(`board/_shared.md`)으로 올릴까? 앱마다 같은 절차라 재사용 가능.
