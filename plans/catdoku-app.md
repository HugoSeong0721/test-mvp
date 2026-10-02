# Catdoku 앱 — 기획서 (기획 파트너 작성, 2026-10-02)

## 왜 이 앱인가
- 같은 장르 **Meowdoku!** 가 2026-10 미국 App Store 무료 차트 상위 → 수요 확인됨.
- 웹판 `docs/catdoku.html` 이 이미 완성(규칙·생성기·유일해 보장·하트·타이머). 앱으로 옮기기만 하면 된다.
- 매일 퍼즐 → 매일 다시 오는 이유 → 광고 노출일 증가.

## 게임 (웹판 그대로 + 앱용 보강)
- 규칙: 색 구역마다 🐱 1마리, 행·열마다 1마리, 고양이끼리 대각선 포함 인접 금지. (웹판과 동일)
- 조작: 웹판의 탭 순환(✕→🐱→해제)은 `CLAUDE.md` "탭 순환 + 페널티 금지" 교훈과 충돌할 수 있다
  → 개발 세션이 웹판을 실제로 해 보고, 필요하면 팔레트(✕ / 🐱) 선택 방식으로 바꾼다.
- **오늘의 퍼즐**: 날짜 시드로 매일 모두 같은 판 (미국 대상이므로 기기 현지 날짜 기준).
- **단계 모드(추천)**: 5×5 → 6×6 → 7×7 → 8×8 … 무한 단계. 퍼즐을 많이 풀수록 광고도 많이 본다.
- 오프라인 동작, 서버 없음 (선교 가서도 손 안 가는 앱).

## 수익
- 하단 배너.
- 보상형: ❤️ 다 잃으면 "영상 보고 이어하기", 막히면 "영상 보고 힌트(고양이 1마리 자리 공개)".
- 단계 모드에서 몇 판마다 전면 광고는 TestFlight 느낌 보고 결정.

## 스토어
- 이름은 미국 검색어 조사로 정한다 (예: "Catdoku: Cat Logic Puzzle" 류). "Meowdoku" 등 남의 이름 금지.
- 번들 ID 후보 `com.soulfulfill.catdoku` — 등록 전 사용자 확인.
- 영어 UI, 아이폰 전용·세로 고정.

## 사용자 결정 필요 (A/B)
1. 게임 양: **A. 오늘의 퍼즐 + 무한 단계 (추천)** / B. 오늘의 퍼즐만
2. 앱 이름은 개발 세션이 검색어 조사 후 2~3개 후보로 다시 묻는다.

## 진행 순서
①웹판 직접 해 보고 조작 점검 → ②테스트 로봇 → ③Flutter 이식(생성기·유일해 검증 포함) → ④광고
→ ⑤`Release iOS` 일반화(앱 폴더·번들 ID 입력) → ⑥TestFlight → 사용자 '느낌' 피드백 → ⑦스토어 등록

## 진행 기록 (개발 세션이 추가, 최신이 위)

### 2026-10-03 개발 세션 1 (이어서) — TestFlight
- ASC 앱 `Kitty Queens: Cat Sudoku`(id 6818637278) 생성(사용자), AdMob(`soulfulfillable` 계정) 앱·단위 3개 → 실제 ID 반영.
- TestFlight 빌드 10(첫 설치 확인) → 11(점검 3차: 연타·저장 손상·Mark 붓) → 12(영상 없으면 무료 보상, 막다른 길 안내).
- 점검 워크플로 `catdoku-button-qa`: 5명 426회 누름 + 재현 검증 46건. 테스트 로봇 28개 통과.
- 사용자 첫 TestFlight 캡처: Level 3 막다른 판 + "No video available" → 위 빌드 12 로 대응.
- 남은 것: 사용자 '느낌' 피드백 → 스크린샷(1290×2796)·`catdoku_app/store/ios-metadata.json` → `App Store 등록 정보 채우기`(app=catdoku) → 심사.
  출시 뒤: AdMob 앱에 App Store 링크 연결(광고 재고 정상화).

### 2026-10-02 개발 세션 1
- 웹판 점검: 직접 찍은 ✕ 를 지우려 다시 탭하면 고양이 시도로 처리돼 하트 손실(재현) → 앱은 🐱/✕ 팔레트 + ✕ 끌어 칠하기.
- `catdoku_app/flutter/`: 퍼즐 엔진(`lib/core/puzzle.dart`, xorshift32 시드라 iOS·웹 같은 판, 유일해 보정 생성기 9×9 ≤60ms),
  오늘의 퍼즐(7×7, 기기 현지 날짜, 실패해도 시계 이어짐, 연속 기록) + 단계(1-3:5×5, 4-10:6×6, 11-25:7×7, 26-50:8×8, 51+:9×9).
- 광고: 배너 + 보상형 2자리(힌트, 이어하기 ❤️+3 판 유지). 영상 미도착 시 최대 8초 "Loading video…", 중간에 닫으면 보상 없음 안내,
  실패 시 10→120초 백오프 재로딩. **지금은 Google 테스트 ID** — AdMob 앱 만들면 `lib/core/ads.dart`·Info.plist·AndroidManifest 교체.
- 테스트 로봇 `test/robot_test.dart` (17개 통과): 모든 버튼, 3개 기기 크기, 9×9, 한글 노출, 광고 지연/없음/중간 닫기/두 번 탭.
- 웹 미리보기 `docs/catdoku-app/` (`?ads=slow|none|early` 로 광고 상황 흉내). 빌드: `flutter build web --release --base-href /test-mvp/catdoku-app/` 후 canvaskit 폴더는 빼고 복사(CDN 사용).
- 이름 **Kitty Queens: Cat Sudoku**, 번들 `com.soulfulfill.catdoku` (사용자 확인). 스토어 초안 `catdoku_app/store/ios-listing.md`, 방침 `docs/catdoku-privacy.html`.
- Actions: `Release iOS`·`App Store 등록 정보 채우기` 에 앱 선택(currency/catdoku), `iOS 번들 ID 등록 · 앱 레코드 확인` 추가.
- 남은 것: ASC 앱 레코드(사용자), AdMob 앱·광고 단위 3개(사용자) → 실제 ID 교체 → Release iOS(catdoku) → TestFlight.
