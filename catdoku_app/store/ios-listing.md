# Catdoku 앱 — App Store 등록 정보 초안 (미국, English U.S.)

> 이름은 사용자 선택 대기. 선택되면 이 파일·`lib/main.dart` 의 title·Info.plist 의 CFBundleDisplayName 을 함께 바꾼다.

## 이름 조사 (2026-10-02)

같은 장르(색 구역마다 고양이 1마리, Queens/Star Battle 계보)가 미국 스토어에 이미 많다.
**"Catdoku" 는 App Store·구글 플레이에 같은/비슷한 이름이 여러 개** 있어 그대로 쓰면 거절되거나 묻힌다.

| 이미 있는 앱 | 비고 |
|---|---|
| Meowdoku! (Oakever, 2026-05) | 장르를 띄운 원조. 밈 광고로 무료 차트 상위 |
| Meowdoku: Sudoku Cat Puzzle | 부제에 "Sudoku Cat Puzzle" |
| Catdoku! Cat Sudoku Puzzle / Catdoku: Find the kitty puzzle / Catdoku (mwm) | "Catdoku" 선점 |
| Cat Sudoku: Doku Brain Puzzle / Cat Sudoku! (CyberGame) | "Cat Sudoku" 가 핵심 검색어로 쓰임 |
| Cat Queens: Logic Puzzle | "Cat Queens" 선점 |
| Purrdoku (구글 플레이 2종) | "Purrdoku" 선점 |
| Queens Game / Queens Puzzle 다수 | LinkedIn Queens 덕에 "queens" 검색이 큼 |

검색어 우선순위(경쟁 앱 제목·부제에서 반복되는 순): **cat sudoku**, **queens**, **logic puzzle**, cat puzzle, brain puzzle.
(정확한 월간 검색량 숫자는 유료 도구 없이 확인 못 했다 — 경쟁 앱 제목 빈도로 추정.)

## 이름 후보 (30자 이내, 선점 검색에서 같은 이름 없음)

| 후보 | 담긴 검색어 | 장단점 |
|---|---|---|
| **A. Kitty Queens: Cat Sudoku** (추천) | kitty, queens, cat, sudoku | 두 큰 검색어(queens·cat sudoku)를 다 담음. 짧고 기억하기 쉬움 |
| B. Catdoku Daily: Cat Sudoku | catdoku, daily, cat, sudoku | 웹판 이름 유지. 하지만 "Catdoku" 앱이 이미 여럿이라 묻힐 수 있음 |
| C. Meow Queens: Cat Logic Puzzle | meow, queens, cat, logic puzzle | "logic puzzle" 까지 담지만 Meowdoku 와 헷갈려 보일 수 있음 |

부제(30자) 초안: `Daily Queens Logic Puzzle` · 키워드(100자): `catdoku,meow,kitty,star battle,brain,daily,puzzle game,cats,queens game,sudoku cat,logic,zen`
(남의 상표 "Meowdoku" 는 키워드에도 넣지 않는다.)

## 기본 정보

- 번들 ID: `com.soulfulfill.catdoku` (사용자 확인 후 developer.apple.com 에 등록 — 등록하면 못 바꿈)
- 카테고리: Games → Puzzle (보조: Board)
- 연령: 4+ · 가격: 무료 · 광고 있음
- 개인정보처리방침: https://soulfulfillable.github.io/test-mvp/catdoku-privacy.html
- Copyright: `2026 Soulfulfill`
- 아이폰 전용·세로 고정, 첫 출시는 EU 제외(trader 신고 전)

## 설명 초안

Place one cat in every color — that's it!

Catdoku is a cozy logic puzzle with simple rules:
• Each color gets exactly 1 cat
• Each row and column gets 1 cat
• Cats can't touch — not even corners

A new Daily Puzzle every day, the same for everyone. Keep your streak going!
Endless Levels that grow from a quick 5×5 to a brain-bending 9×9.

• Big, easy-to-tap squares and clear rules always on screen
• Mark squares with ✕ — drag to mark many at once
• Stuck? Watch a short video for a hint
• Works offline — perfect for the bus or subway
