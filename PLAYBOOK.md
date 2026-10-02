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
