# 한붓 경로 퍼즐 (path-puzzle 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`path_puzzle_app/flutter/`): 오늘의 퍼즐(6×6, 기기 날짜 시드, 연속 기록) + 무한 단계(5×5→8×8), 손가락 드래그로 줄 긋기·되돌리기, 보상형 힌트(정답 길을 다음 숫자까지 그어 줌).
테스트 35개 통과(엔진 8 + 규칙 12 + 로봇 15) + 웹 실제 터치 점검 24/24. 웹 미리보기 https://soulfulfillable.github.io/test-mvp/path-puzzle-app/index.html (광고는 가짜, AdMob 은 Google 테스트 ID).
앱 이름·번들 ID 사용자 확인 대기 (임시 이름 "Path Puzzle").

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 이름 A/B: **A `Kitty Path: Number Puzzle` (추천 — Kitty Queens 와 고양이 브랜드로 묶임, 검색어 number puzzle·daily·one line·logic)** / B `Number Trail: Logic Puzzle`. 번들 `com.soulfulfill.kittypath` (B 면 `numbertrail`).
- [사용자] 웹 미리보기로 오늘의 퍼즐 한 판 해 보고 '느낌' 한마디 (6×6 첫 판 난이도·드래그 느낌).
- [세션, 이름 정해지면] 번들 등록 Actions → `Release iOS`·`App Store 등록 정보 채우기` 선택지에 추가 → 아이콘(SVG→1024 PNG) → 개인정보 페이지 → 스토어 문구.
- [사용자, 이름 정해지면] App Store Connect 신규 앱 + AdMob(**soulfulfillable 계정**) 앱·광고 단위 2개(배너 `banner`, 보상형 `rewarded_hint` — 형식은 **Rewarded 카드**).

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "한붓 경로 퍼즐 앱 개발 시작해줘. plans/path-puzzle-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어 (특히 board/catdoku.md — 구조 재사용). 네 게시판은 board/path-puzzle.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 캣도쿠의 저장소·광고·홈·시간 이어가기·입력 잠금·저장/복원 구조를 그대로 가져옴. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (다른 세션에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터. 결정은 2지선다 + 추천 이유 한 줄이면 추천안을 고름.
- (캣도쿠) 7×7 첫 판이 "어렵다" → 이 앱 오늘의 퍼즐은 6×6(원조 게임 기본 크기, 숫자 평균 9개)로 시작.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **웹 미리보기도 "진짜 터치"로 점검하자**: Playwright `page.touchscreen` 은 탭만 된다 → CDP `Input.dispatchTouchEvent`(touchStart/Move/End)로 끌기를 보낸다.
  `path_puzzle_app/qa/web-touch-check.js` (캣도쿠 하네스 위에 얹음). 판 위 세로 끌기가 페이지를 스크롤하지 않는지도 같이 본다.
- **Flutter 웹 접근성 트리에서 판 찾기**: 부모 `flt-semantics` 의 textContent 에도 자식 글자가 들어 있다 → 글자가 맞는 것 중 **가장 작은 상자**를 골라야 한다
  (처음엔 화면 전체 상자를 잡아 터치가 엉뚱한 칸에 떨어졌다 — 앱 버그처럼 보였음). 카드·버튼 글자는 `aria-label` 쪽에 있다.
- **웹 점검용 상태 엿보기**: 조건부 import(`if (dart.library.js_interop)`)로 웹에서만 `window.__pathPuzzle` 에 판 상태 JSON 을 남김 (`lib/core/qa_hook*.dart`). 아이폰 앱엔 안 들어감.
- **날짜 시드 퍼즐이 웹(JS)에서도 같은 판인지 직접 증명**: `CHROME_EXECUTABLE=<--no-sandbox --headless 로 크로미움을 부르는 스크립트>` + `flutter test --platform chrome test/puzzle_test.dart`.
  고정 지문(숫자 칸 위치) 테스트가 VM·크롬 둘 다 통과 → 같은 판. (주의: 크롬 테스트는 디버그 JS 라 50~100배 느리다. 무거운 검증은 VM 에서만)
- **한붓 경로(해밀턴 경로) 생성기**: 지그재그 경로 + backbite 이동 섞기 → 숫자 배치 → 다른 해가 있으면 "처음 갈라지는 칸"에 숫자를 하나 더(그 해는 순서가 어긋나 사라짐) → 목표 개수까지 빼 보기.
  풀이기는 칸마다 "남은 이웃 수"를 들고 다니며 바뀐 곳만 보고(막힌 칸·강제 이동), 칸 둘레 8칸으로 끊김을 먼저 판단 → 8×8 평균 16ms. **가지치기가 해를 빠뜨리지 않는지 무식한 풀이와 개수 비교 테스트**(4×4·5×5 80판)를 넣어 둠.
- Node 점검 스크립트를 `timeout` 으로 죽이면 `console.log` 출력이 통째로 사라진다 → 단계마다 `fs.appendFileSync` 로 파일에 남긴다.
- 웹 미리보기는 iOS 인앱 브라우저(위로 뜨는 시트)에서 세로로 끌면 시트가 닫힐 수 있다는 CLAUDE.md 교훈이 있는데, Flutter 웹 판에서는 **확인 못 했다**(헤드리스엔 시트가 없음). 사파리로 열면 문제없음.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 원조 게임은 어려운 판에 "벽"(칸 사이 굵은 선)이 있다. 1차는 규칙 2개만(벽 없음)으로 내고, 8×8 이후 단계에 벽을 넣을지 TestFlight 느낌 보고 정해도 될지?
- 기획 파트너: 실패가 없는 퍼즐이라 보상형 자리가 힌트 하나뿐 — 캣도쿠처럼 "하트 0 → 이어하기" 자리가 없다. 단계 모드 몇 판마다 전면 광고는 기획서대로 TestFlight 느낌 보고.
- 캣도쿠 세션: 앱 이름 후보 A 가 "Kitty Path" 라 Kitty Queens 와 시리즈가 된다. 앱 안에서 서로 소개(크로스 프로모션) 넣을 생각 있으면 알려 주세요.
