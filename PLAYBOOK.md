# PLAYBOOK.md — 앱 개발 플레이북 (시행착오를 다음 앱에 물려주는 곳)

**개발 세션은 시작할 때 이 파일을 끝까지 읽고, 끝날 때 새로 배운 것을 여기에 추가한다.**
같은 실수를 두 번 하지 않게 하는 게 목적이다. 방향·우선순위는 `PRODUCT.md`, 공통 규칙은 `CLAUDE.md`.

---

## 0. 세션 역할 나누기

| 세션 | 하는 일 | 하지 않는 일 |
|---|---|---|
| 🧭 기획 파트너 (한 개, 계속 유지) | 방향·후보 고르기·기획서·결정 기록(`PRODUCT.md`, `plans/`)·주간 점검 | 코드 개발 |
| 개발 세션 (앱/작업마다 새로) | `plans/<앱>.md` 대로 개발·테스트·출시, 배운 것을 이 파일에 기록 | 방향 바꾸기 (필요하면 사용자에게 A/B 로 묻고 `PRODUCT.md` 결정 로그에 기록) |

## 1. 새 앱 시작 체크리스트

1. `CLAUDE.md` → `PRODUCT.md` → 이 파일 → `plans/<앱>.md` 순서로 읽는다.
2. 앱 폴더를 `<앱이름>_app/` 로 만든다 (환율 앱 `currency_app/` 구조를 따른다: 웹 원형 + `flutter/` + `store/`).
3. 번들 ID `com.soulfulfill.<앱>` — 정하기 전에 사용자에게 확인 (Apple 에 등록하면 바꿀 수 없다).
4. **테스트 로봇 먼저** — 모든 화면·모든 버튼을 누르는 Flutter 위젯 테스트 (`currency_app/flutter/test/` 참고).
   iPhone 13 크기(1170×2532), 키보드가 뜬 상태도 흉내.
5. 앱마다 AdMob 앱·광고 단위를 새로 만든다 (사용자가 콘솔에서 해야 하는 일 → 클릭 단위 안내).
6. 개인정보처리방침 페이지 `docs/<앱>-privacy.html` (Pages 로 공개).
7. 진행 기록은 `plans/<앱>.md` 아래 "진행 기록"에 남긴다 (세션이 바뀌어도 이어지게).

## 2. iOS 출시 경로 (맥 없이) — 환율 앱에서 검증됨

- 업로드: GitHub Actions `Release iOS` (`.github/workflows/release-ios.yml`, 서명 스크립트 `.github/scripts/asc_signing.py`).
  **지금은 환율 앱 경로가 박혀 있다 → 새 앱이면 앱 폴더·번들 ID 를 입력값으로 받게 일반화부터.**
- 등록 정보·스크린샷·빌드 연결: Actions `App Store 등록 정보 채우기` (`asc-metadata.yml`, 데이터는 `<앱>/store/`).
- 비밀값(ASC API 키 등)은 GitHub 리포 Secrets 에 이미 있다 — 새 앱도 같은 키 재사용.
- 실제로 겪은 실패 (다시 하지 말 것):
  - 자동 서명은 등록 기기가 없으면 개발용 프로파일을 못 만든다 → 실패.
  - 서명 없이 아카이브하면 Google 광고 SDK 프레임워크가 재서명되지 않아 업로드 거부(ITMS 90035).
  - → 해결: 실행마다 API 로 임시 배포 인증서·App Store 프로파일을 만들어 Runner 만 수동 서명, 끝나면 삭제.
  - Podfile 은 `flutter pub get` 이후에 생긴다 → 있을 때만 수정.
  - iOS 는 SwiftPM 이라 CocoaPods 설치 불필요.
- 첫 출시는 범위를 줄인다: 아이폰 전용·세로 고정, EU 제외(trader 신고는 사용자 확인 필요).

## 3. 스토어 등록

- 이름·부제·키워드는 **미국 검색량이 큰 검색어** 기준 (`currency_app/store/ios-listing.md` 가 예시).
- 스크린샷 6.7형 1290×2796, 첫 장에 앱의 가장 매력적인 순간 (환율 앱은 금·비트코인이 보이는 화면으로 교체했다).
- Copyright `2026 Soulfulfill`. 회사명·실명 금지.
- 화면 숫자는 진짜만. 가짜 데이터·"Coming soon" 버튼은 심사 거절 사유.

## 4. 광고 (수익 = 성공 기준)

- 배너 + 보상형(영상 보고 계속/힌트/해금). 결제(광고 제거) 없이 시작하는 게 기본 방침 (색칠 앱 결정).
- 광고는 사용자가 '원해서' 보는 자리(보상형)에 둔다. 강제 전면 광고는 신중히.

## 5. 게임/퍼즐 설계 교훈 (웹게임에서 배운 것, 자세한 건 `CLAUDE.md`)

- 한눈에 읽혀야 한다. 규칙 2개까지, 규칙은 화면에 상시 보이게(남은 개수 카운터 등).
- 탭 순환 + 페널티 조합 금지 → 팔레트에서 고르고 탭.
- 모바일 터치로 반드시 테스트.

## 6. 시행착오 기록 (최신이 위, 개발 세션이 추가)

| 날짜 | 앱 | 무슨 일이 있었나 | 다음엔 이렇게 |
|---|---|---|---|
| 2026-10-03 | 대출 | 인구조사국 API 가 키 없이 'Missing Key' HTML 을 돌려줌 + 이 환경에서 census 차단 | 키 없는 ACS 표 단위 요약 파일(.dat)을 Actions 로 받아 데이터 브랜치에 (`tools/mortgage/fetch_census_counties.py`) |
| 2026-10-03 | 대출 | 테스트가 화면 밖(시트 맨 아래) 항목을 탭하고도 경고만 내고 진행 | `WidgetController.hitTestWarningShouldBeFatal = true` 로 실패시키기 |
| 2026-10-03 | 대출 | 로컬 Flutter 3.47.6 으로 `flutter create` → `sdk: ^3.13.5` 가 박혀 Actions(Flutter 3.47.2, Dart 3.13.2)의 `Release iOS` 가 `pub get` 에서 실패 | 새 앱은 `pubspec.yaml` 의 `sdk:` 를 CI 버전(`^3.13.2`)에 맞춘다. 로컬도 workflow 의 `flutter-version` 과 같은 버전을 깔면 더 안전 |
| 2026-10-03 | 연비 | 주유를 저장해도 기록 탭 숫자가 그대로 — 위에서 `ListenableBuilder` 로 감쌌지만 `const HomeShell()`·`const _Summary()` 는 **같은 const 위젯이라 다시 안 그려짐** | 저장소를 읽는 화면은 **각자 구독**(`build` 를 `ListenableBuilder` 로)하거나 바뀌는 데이터를 인자로 넘긴다. 로봇이 "저장 → 화면 숫자" 를 검사해서 잡았다 |
| 2026-10-03 | 연비 | 거리 알림의 예상 날짜가 이미 지난 날(기록이 뜸할 때) → `notifyAt` 이 과거라 **알림이 예약조차 안 됨**. 테스트는 통과, **스크린샷의 "about Sep 29"(오늘 Oct 2)** 로 발견 | 예상일은 오늘보다 앞이면 오늘로, 알림은 다음 날 아침. 로봇에 "알림 켠 정비는 전부 미래 시각에 예약됐나" 검사. 고치기 전 실패 확인 |
| 2026-10-03 | 연비 | `Semantics(button: true, excludeSemantics: true)` 로 감싼 버튼이 VoiceOver 에선 **누르기 동작이 없음**(앱 바 제목에 합쳐짐). 웹 점검 `getByRole('button')` 이 못 찾아서 발견 | `Semantics` 에 `onTap`(+앱 바 안이면 `container: true`). 로봇 `expectButtonsTappable`: 버튼인데 tap 액션 없는 노드 = 실패 (`fuellog_app/flutter/test/robot_test.dart`) |
| 2026-10-03 | 연비 | 앱 바 제목·탭 글자가 스크린샷에서 검은 네모 → 잘림 검사 오탐. `appBarTheme.titleTextStyle: TextStyle(...)` 처럼 **빈 TextStyle 은 테마 글꼴을 안 이어받는다** | `base.textTheme.titleMedium!.copyWith(...)` 로 만든다 (기기에선 시스템 글꼴로 보여 눈치 못 챔) |
| 2026-10-03 | 연비 | 큰 글씨(135%)에서 단가 칸 숫자가 1.5px 모자라 잘림 | 입력 칸 폭을 `MediaQuery.textScalerOf` 에 비례(화면 62% 까지). 3칸 요약은 `FittedBox(scaleDown)` |
| 2026-10-03 | 연비 | `pkill -f "flutter test"`·`pkill -f flutter_tester` 가 **그 글자가 든 내 bash 명령까지 죽여** 뒤 명령이 안 돎 | 멈춘 테스트는 `pkill -9 -x flutter_tester` (프로세스 이름 정확히) |
| 2026-10-03 | 연비 | 다른 앱 CSV 가져오기 형식을 알 길이 없음(사이트 막힘) | 오픈소스 가져오기 도구 코드(Hammond·LubeLogger)에서 Fuelly 열 이름을 읽었다 → 머리글 별칭으로 맞추고 엔진 테스트에 그 형식 그대로 고정 (`fuellog_app/flutter/lib/core/csv.dart`) |
| 2026-10-03 | 캣도쿠(Kitty Queens) | TestFlight 에서 "No video available" 연속 — 새 AdMob 앱은 스토어 출시·링크 전 광고 재고가 거의 없고, 그 사이 틀린 고양이로 막다른 판에 갇힘 | 보상형 광고가 **안 오면 보상을 그냥 준다**(중간 닫기만 안 줌). 막다른 상태는 화면에 이유 표시. 출시 뒤 AdMob 에 스토어 링크 연결 |
| 2026-10-03 | 캣도쿠 | 점검 팀 426회 누름에서 가장 많이 나온 버그 = **연타**: 다음 레벨 연타로 레벨 건너뛰기·저장 중단, 새 판에 엉뚱한 고양이, 반칙 칸 연타로 하트 3개, 마지막 칸 연타로 승리 패널 버튼이 눌림, 힌트 연타로 창 즉시 닫힘 | 결과 패널은 0.9~1.1초 뒤에, 새 판·반칙·창 닫힘 뒤 0.45~0.7초 입력 잠금(**Timer 로** — DateTime.now 는 위젯 테스트 가짜 시계에서 안 풀림), "다음 단계"는 저장값에서 계산, 확인 창 `barrierDismissible:false`. 로봇에 연타 테스트 |
| 2026-10-03 | 캣도쿠 | 뒤로 갔다 오면 홈 카드 숫자가 옛 값 — `await Navigator.push` 뒤 setState 는 다음 화면 dispose 저장보다 먼저 돈다(`pushReplacement` 도 같음) | 홈은 저장소(ChangeNotifier)를 구독해 다시 그린다. 자정 넘김은 앱 복귀 + 주기 확인 |
| 2026-10-03 | 캣도쿠 | Flutter 웹(ensureSemantics)에서 반투명 패널 뒤 버튼이 눌림 | 패널이 뜨면 뒤 화면을 `AbsorbPointer` + `ExcludeSemantics` |
| 2026-10-02 | 캣도쿠 | 웹판 탭 순환(✕→🐱→해제)은 ✕ 를 지우려다 하트를 잃음(재현) | 팔레트(🐱/✕) + ✕ 끌어 칠하기·끌어 지우기. ✕ 붓은 고양이를 지우지 않는다 |
| 2026-10-02 | 캣도쿠 | 유일해 퍼즐을 다시 뽑기로 찾으면 8×8 부터 수천 번 | "다른 해의 칸을 이웃 구역으로 넘기기" 보정 → 9×9 ≤60ms. 난수는 xorshift32(곱셈 없음)라 Dart VM·웹이 같은 판 |
| 2026-10-02 | 캣도쿠 | 폰으로 바로 해 보고 싶다는 요청 | Flutter 웹 빌드를 `docs/<앱>/` 로(`canvaskit/` 빼면 40→3.6MB), 광고는 kIsWeb 이면 가짜. 샌드박스 점검은 `catdoku_app/qa/flutter-web-harness.js` |
| 2026-10-02 | 캣도쿠 | 웹게임 이름 "Catdoku" 가 스토어에 동명 앱 여럿 | 이름은 먼저 스토어 검색. 번들 ID 등록은 API(`iOS 번들 ID 등록` Actions), 앱 레코드는 사람이 ASC 웹에서 |
| 2026-10-03 | 솔루나 | 다른 날을 누르면(위쪽 "지금" 카드가 빠짐) 목록을 맨 위로 보냈는데 230px 에서 멈춤 — `animateTo`/`jumpTo`/다음 프레임 모두 실패 | 내용이 바뀌는 목록은 `KeyedSubtree(key: 날짜·장소)` 로 새로 만들고 `ScrollController(keepScrollOffset: false)`. 로봇에서 "누른 뒤 제목이 화면 안" 을 검사 |
| 2026-10-03 | 솔루나 | `timezone` 패키지 `latest_all.dart` 가 웹 스크립트를 1.8MB 키움 | `.tzf` 를 자산으로 넣고 `tz.initializeDatabase(bytes)` |
| 2026-10-03 | 솔루나 | 다른 앱에서 복사한 코드에 "station" 문구가 남음 — 테스트 통과, 웹 스크린샷에서만 보임 | 복사해 온 파일은 문구를 grep, 로봇에 "옛 앱 단어 없음" 검사 |
| 2026-10-03 | 솔루나 | AppBar 제목 자리 InkWell 이 웹/VoiceOver 에서 버튼이 아니라 제목으로만 읽힘 | `Semantics(container: true, button: true, label: …)` 로 감싸고 로봇에서 `find.bySemanticsLabel` 로 확인 |
| 2026-10-03 | 경로 퍼즐 | 웹 실제 터치 점검에서 "드래그가 전혀 안 먹음" — 원인은 앱이 아니라 점검 스크립트가 부모 `flt-semantics`(화면 전체 상자)를 판으로 잡아 엉뚱한 곳을 끈 것 | 접근성 트리에서 요소를 찾을 땐 글자가 맞는 것 중 **가장 작은 상자**. 실패하면 스크린샷과 좌표부터 확인하고 앱을 고친다 |
| 2026-10-03 | 경로 퍼즐 | 유일해 풀이기를 빠르게 하려고 가지치기를 넣을수록 해를 빠뜨려 "해가 하나"라고 잘못 믿을 위험 | 무식한 풀이(가지치기 없음)와 해 개수를 맞춰 보는 테스트를 같이 둔다 (`kittypath_app/flutter/test/puzzle_test.dart`) |
| 2026-10-03 | 경로 퍼즐 | 날짜 시드 생성기가 VM 에선 빠른데 크롬(JS) 테스트에선 50~100배 느림 | `flutter test --platform chrome` 로 웹 속도·같은 판(지문)을 따로 잰다. 풀이기를 증분 계산으로 바꿔 8×8 105→16ms |
| 2026-10-03 | 물때 | 작업 환경에서 NOAA API 가 막힘 (WebFetch 도) | Actions 워크플로로 받아 데이터 브랜치에 커밋 → 그 실제 응답으로 테스트·웹 점검 (`fetch-noaa.yml`) |
| 2026-10-03 | 물때 | NOAA 관측소 메타데이터(서머타임·시간대)가 수십~천여 곳 틀리거나 빔 | 공공 데이터도 "모든 항목을 화면에 띄우는" 테스트로 훑고, 틀린 건 규칙으로 보정 + 대표값 고정 테스트 |
| 2026-10-03 | 물때 | 테스트 헬퍼 일괄 치환이 헬퍼 자신을 바꿔 무한 재귀 → flutter_tester 5GB·무응답 | 일괄 치환 뒤 헬퍼 본문 확인. 멈추면 `pkill -9 -f flutter_tester`, 단계 print 로 위치 찾기 |
| 2026-10-03 | 속도계 | 차로 달린 최고 속도가 달리기 모드로 넘어가 "BEST 0:50/mi" — 테스트는 통과, **웹 스크린샷에서만** 보임 | 단위·의미가 다른 모드는 기록을 따로 저장. 스크린샷을 화면마다 직접 보고, 찾으면 고치기 전 코드에서 실패하는 테스트부터 |
| 2026-10-03 | 속도계 | 잘린 글자 검사를 테스트 기본 글꼴(Ahem)로 돌려 오탐 6건 | SDK Roboto 를 `FontLoader` 로 넣고 재면 진짜 잘림만 남는다. 버튼 글자는 '…' 대신 `FittedBox(scaleDown)` |
| 2026-10-03 | 속도계 | 위젯 테스트에서 가짜 GPS 이벤트 직후 화면이 한 박자 늦음 | 스트림 이벤트 뒤엔 `pump(Duration.zero)` (그냥 `pump()` 는 프레임이 없으면 안 그림). 시간은 `package:clock` |
| 2026-10-03 | 속도계 | 큰 글씨(135%) + iPhone SE 에서 아래 시트가 넘쳐 Done 이 화면 밖 | 시트는 제목 줄 오른쪽에 Done, 내용은 스크롤. 로봇의 `press()` 가 버튼이 화면 안·안 가려졌는지 hit test 로 확인 |
| 2026-10-03 | 대출 | 숫자 칸이 좁아 "18.75 %"·비싼 집의 "Principal & interest" 가 잘림 — 기본값·한 기기 테스트는 통과 | 로봇에 **잘림 자동 검사**(`RenderParagraph.didExceedMaxLines`, `RenderEditable` 글자 폭 > 칸 폭)를 넣고 큰 값·3개 기기로 돈다 (`mortgage_app/flutter/test/robot_test.dart`) |
| 2026-10-03 | 대출 | `Semantics(textField: true)` 로 TextField 를 감쌌더니 VoiceOver 에 입력 칸이 두 개씩 생김 (웹 접근성 트리 덤프로 발견) | `MergeSemantics` 로 합치고, 로봇에서 화면 읽기 입력 칸 수 == 실제 칸 수 검사 |
| 2026-10-03 | 대출 | 위젯 테스트 스크린샷이 3배 확대된 일부만 / 차트 글씨가 네모 | 루트 레이어를 `physicalSize` 로 찍고 SDK Roboto 를 `FontLoader` 로 넣기, `TextPainter` 에 테마 글꼴 전달 |
| 2026-10-03 | 대출 | Playwright `proxy` bypass 가 localhost 에 안 먹어 로컬 미리보기가 405 | `--proxy-server=https=<프록시>` 로 https 만 프록시. gstatic 은 `page.route` 로 로컬 canvaskit |
| 2026-10-03 | 소음 | 화면 켜짐(wakelock) 같은 플러그인 호출을 `await` 했더니 위젯 테스트에서 응답이 안 와 **그 뒤 자동 저장이 통째로 안 돎** (실기기에서도 응답 지연 시 같은 위험) | 부가 기능 플랫폼 호출은 기다리지 말고 `.catchError` 로 흘려보내고, 저장·상태 변경을 먼저 한다 |
| 2026-10-03 | 소음 | 긴 `ListView` 아래쪽 입력칸은 키보드가 뜨며 화면이 줄면 목록에서 빠져(dispose) 포커스가 날아감 | 입력칸은 화면 위쪽에 두거나 `SingleChildScrollView`. 로봇 테스트에서 `viewInsets` 로 키보드를 흉내 내 잡았다 |
| 2026-10-03 | 소음 | `SizedBox(height)` 안 `Row` 의 `Expanded(ColoredBox)` 막대가 높이 0 으로 안 보임 — 테스트는 통과, **스크린샷에서만** 보임 | `crossAxisAlignment: stretch`. 웹 빌드 스크린샷을 화면마다 직접 본다 → 찾으면 높이 검사 테스트 추가(고치기 전 실패 확인) |
| 2026-10-03 | 소음 | 마이크 앱을 헤드리스로 점검할 방법 | 크롬 `--use-fake-device-for-media-stream --use-fake-ui-for-media-stream` + `grantPermissions(['microphone'])` 이면 진짜 getUserMedia 경로를 탄다. 거부는 `--deny-permission-prompts`. `decibel_app/qa/web-check.js` |
| 2026-10-02 | 공통 | 새 세션형 루틴은 저장소 쓰기 권한이 안 붙어 푸시 403 | 루틴은 저장소가 붙은 세션을 깨우는 방식으로 |
| 2026-10 | 환율 | iOS 서명 두 번 실패 (자동 서명·무서명 아카이브) | 위 2장의 API 수동 서명 방식 |
