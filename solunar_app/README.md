# 낚시·사냥 시간 (솔루나) 앱

기획서 `plans/solunar-app.md` · 게시판 `board/solunar.md` · 웹 미리보기 https://soulfulfillable.github.io/test-mvp/solunar-app/index.html

| 폴더 | 내용 |
|---|---|
| `flutter/` | 앱 (Flutter 3.47.2). `lib/core/` 엔진, `lib/screens/` 화면 |
| `flutter/lib/core/astro.dart` | 해(NOAA 식, 물때 앱과 같은 코드)·달 위치(Meeus 47장)·월출월몰(USNO 정의)·남중/북중·위상 |
| `flutter/lib/core/solunar.dart` | Major(달 남중·북중 ±1시간)·Minor(월출·월몰 ±30분), 점수(위상 60 + 일출일몰 겹침 25 + 달 거리 15), 사냥 허용 시간 |
| `flutter/assets/places.tsv` | 미국·캐나다 1,000명 이상 마을 20,102곳 + IANA 시간대 (GeoNames CC BY 4.0) — 오프라인 검색 |
| `flutter/assets/tz/latest_all.tzf` | IANA 시간대 DB 2025c (`timezone` 패키지 사본, 웹 스크립트 1.8MB 절약용 자산 로딩) |
| `flutter/test/` | `engine_test.dart` (PyEphem 대조 1,800건+·공개 솔루나 표 3곳·점수·시간대·검색·저장), `robot_test.dart` (모든 버튼·3기종·135% 글씨·키보드·24시간·자정·북극권·광고 실패) |
| `flutter/test/fixtures/ephem_reference.json` | `tools/solunar/make_reference.py` 가 PyEphem 으로 만든 기준값 |
| `qa/` | 웹 미리보기 클릭 점검(`web-check.js`, 결과 `web-check-result.txt`) + 스크린샷(`shots/`, 로봇 스크린샷 `shots/robot/`) |
| `store/` | 경쟁 앱 조사·이름 후보·문구 초안 |

## 돌려 보기
```
cd solunar_app/flutter && flutter test                                   # 34개
flutter build web --release --base-href /test-mvp/solunar-app/          # canvaskit 폴더 빼고 docs/solunar-app 으로 복사
NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node solunar_app/qa/web-check.js   # docs 를 :8765/test-mvp/ 로 띄운 뒤
python3 tools/solunar/make_reference.py      # 기준값 다시 만들기 (pip install ephem)
python3 tools/solunar/make_places.py <cities1000.json>   # 마을 목록 다시 만들기 (geonamescache 휠에서)
```
웹 미리보기 점검 스위치: `?ads=slow|none|early` (가짜 광고 상황), `?loc=lat,lng` (가짜 위치).
