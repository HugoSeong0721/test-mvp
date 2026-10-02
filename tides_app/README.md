# 물때 시간 (Tides) 앱

기획서 `plans/tides-app.md` · 게시판 `board/tides.md` · 웹 미리보기 https://soulfulfillable.github.io/test-mvp/tides-app/index.html

| 폴더 | 내용 |
|---|---|
| `flutter/` | 앱 (Flutter 3.47.2). `lib/core/` 엔진, `lib/screens/` 화면, `assets/stations.json` NOAA 관측소 3,499곳 |
| `flutter/test/` | `engine_test.dart` (시간대·NOAA 해석·일출일몰·달·검색·캐시), `robot_test.dart` (모든 버튼·3기종·키보드·오프라인) |
| `flutter/test/fixtures/` | Actions 로 받은 **실제 NOAA 응답** (2026-10-01~11 UTC) |
| `qa/` | 웹 미리보기 클릭 점검(`web-check.js`) + 화면별 스크린샷(`shots/`) |

## 데이터
- NOAA CO-OPS API (무료, 키 없음, CORS `*`). 요청은 GMT·MLLW·feet, `application=soulfulfill_tides`. 위치는 보내지 않는다.
- 기준(R) 관측소 1,256곳: hilo + 6분 예보 곡선. 보조(S) 2,243곳: NOAA 가 hilo 만 줌 → 곡선은 코사인 보간(화면에 "estimated" 표기).
- 관측소 목록은 작업 환경에서 NOAA 가 막혀 있어 Actions `Fetch NOAA tides data` → `tides-noaa-data` 브랜치 → `tools/tides/make_asset.py`.
  NOAA 의 시간대(timezonecorr)·서머타임 메타데이터가 일부 틀려서 지역 규칙으로 보정한다(스크립트 주석).

## 돌려 보기
```
cd tides_app/flutter && flutter test                     # 31개
flutter build web --release --base-href /test-mvp/tides-app/   # canvaskit 폴더 빼고 docs/tides-app 으로 복사
NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node tides_app/qa/web-check.js   # docs 를 :8765/test-mvp/ 로 띄운 뒤
```
