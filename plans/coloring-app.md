# 색칠 앱 (Cozy Coloring 정식판) — 보류 (2026-10-02)

> 나중에 다시 하려면 맨 아래 **"다시 시작하는 법"**의 문장을 새 세션 첫 메시지로 붙여넣으면 된다.

## 왜 보류했나

막힌 곳은 코드가 아니라 **그림 공급**이었다.
- 색칠 앱은 결국 좋은 그림을 계속 대는 앱이다 (경쟁 앱은 수만 장 + 매일 새 그림).
- Claude 작업 환경은 그림 사이트에 직접 접속이 안 되고(Actions 로 우회, 그것도 페이지당 20초대),
  그림을 그리거나 생성할 수 없고, "예쁜가·저작권 괜찮은가"는 사람이 한 장씩 봐야 한다.
- "Claude 주도, 사용자는 A/B 만", "손 안 가는 앱" 방침과 반대로 계속 손이 간다.
- 그래서 코드로 콘텐츠가 무한히 나오는 Catdoku(날짜 시드 퍼즐)를 먼저 하기로 했다.

## 이미 정해진 것 (사용자 결정)

- 기획서 OK: `docs/coloring-plan.html` (조사 근거·화면·출처 판정 전부 여기)
- 나이 표현("for Seniors") 쓰지 않는다. 큰 글씨는 화면으로 보여 주고 글로 말하지 않는다.
- 결제(광고 제거) 없음. **그림 3장 완성마다 "영상 보고 계속 칠하기"**(보상형), 칠하는 중엔 광고 없음,
  오늘의 그림은 무료, 광고 못 불러오면 그냥 계속(오프라인), 배너는 홈에만.
- 그림당 60~100칸(큰 그림 최대 150).

## 만들어 둔 것

| 무엇 | 어디 |
|---|---|
| 기획서 (조사 결과 포함) | `docs/coloring-plan.html` → https://soulfulfillable.github.io/test-mvp/coloring-plan.html |
| 변환기 미리보기 5장 (폰으로 칠해 보기) | `docs/coloring-preview.html` → https://soulfulfillable.github.io/test-mvp/coloring-preview.html |
| 웹 원형 (생성기 그림 6장) | `docs/coloring-book.html` |
| 선화 수집 (Actions, 수동 실행) | `.github/workflows/fetch-line-art.yml` + `tools/coloring/fetch_openclipart.py` → 결과는 **`coloring-line-art` 브랜치** `coloring_app/line_art/openclipart/` (SVG + 그림마다 출처 JSON) |
| 접속 진단 | `tools/coloring/probe.py` (Openclipart·Hugging Face·Wikimedia 응답 확인) |
| 칸 변환기 | `tools/coloring/convert.py` (PNG → 칸·번호·팔레트 JSON) |
| SVG → PNG | `tools/coloring/rasterize.js` (헤드리스 Chromium) |
| 미리보기 만들기 | `tools/coloring/build_preview.py` + `preview_template.html` |
| 테스트 로봇 | `tools/coloring/robot.js` (iPhone 13 터치로 모든 색·모든 칸 탭, 완성·콘솔 에러·스크린샷) |

돌리는 법 (샌드박스):
```
pip install opencv-python-headless scikit-image shapely numpy
PW=$(npm root -g)/playwright
node tools/coloring/rasterize.js $PW work work/*.svg
python3 tools/coloring/convert.py work/<id>.png work/<id>.json      # <id>.meta.json = 출처 JSON
WORK=work python3 tools/coloring/build_preview.py docs/coloring-preview.html <id> <id> ...
node tools/coloring/robot.js $PW $PWD/docs/coloring-preview.html <스크린샷폴더>
```

## 시험 결과 (2026-10-02, 증거)

- Openclipart 에서 38장 수집(태그 coloring book·coloring page·line art).
- 만다라·젠탱글·coloring page·colouring 최대 80장 수집 실행이 보류 시점에 **진행 중**이었다
  (Actions `Fetch coloring line art` 실행 37053355381). 끝나면 같은 브랜치에 쌓인다 — 재개 시 몇 장 왔는지부터
  확인하고, 비어 있으면 같은 워크플로를 tags=`mandala,zentangle` 로 다시 수동 실행.
- 38장 변환 결과 **칸 0~24개** — 목표 60~100칸에 한참 못 미침. 대부분 그림이 단순하거나, 손가락으로
  못 누르는 작은 칸(반지름 18px 미만 @1024)뿐이라 걸러짐.
- 로봇: 미리보기 5장(산타 20칸·꽃 9·나비 15·강아지 7·체스 22) 모든 칸 탭 성공, 놓친 칸 0, 완성 도달,
  콘솔 에러 0.
- 이미 색이 칠해진 클립아트는 **작가의 색을 팔레트로** 쓰면 자연스럽다(강아지). 색 없는 선화의 자동 배색은
  여전히 이상하다(산타 모자가 초록) → 그림마다 사람이 색을 정해야 한다.
- 라이선스: "CC0"로 올라왔는데 그림 안에 `(c) 사이트주소`가 찍힌 것(284790), 옛 만화 주인공을 닮은
  슈퍼히어로(324889) → 제외. **한 장씩 사람 확인이 필요하다**는 검증 결과가 실제로 맞았다.
- 문어(325250)처럼 선이 끊긴 그림은 칸이 바깥과 이어져 1칸이 됨 → 끊긴 선 잇기 보강 필요.
- Openclipart 페이지의 라이선스 문구는 "public domain"으로만 잡혔다(CC0 문자열 미검출) — 사이트 정책상
  전부 CC0 이지만 출시 전 페이지 캡처로 재확인할 것.

## 다시 할 때 먼저 풀 것 (택1, 사용자 A/B)

1. **칸 기준을 30~60칸으로 낮추기** — 지금 그림으로도 가능, 한 장 1~2분. 어르신 속도면 3분 근처일 수 있음
   (TestFlight 시간 측정으로 확인).
2. **만다라·젠탱글 위주** — 수집해 둔 80장을 변환해서 60칸 넘는 게 30장 모이는지부터 확인.
3. **박물관 CC0 판화(Smithsonian·Met)** — 가장 안전하고 고급스럽지만 빗금 정리 작업이 많다.
4. 사용자가 직접 고른 그림/구매한 상업 라이선스 그림팩을 넣는 방식 — 그림 공급을 사람이 맡는다.

## 다시 시작하는 법

새 세션(저장소 `soulfulfillable/test-mvp`) 첫 메시지로 붙여넣기:

```
색칠 앱 다시 하자. plans/coloring-app.md 읽고 이어서 해.
먼저 coloring-line-art 브랜치에 받아 둔 만다라 80장을 변환해서
60칸 넘는 그림이 몇 장인지 로봇 결과·스크린샷과 같이 보여줘.
그다음 "다시 할 때 먼저 풀 것" 중에 뭘 할지 A/B로 물어봐.
```
