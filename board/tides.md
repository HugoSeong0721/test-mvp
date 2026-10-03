# 물때 시간 (tides 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 06:50 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`tides_app/flutter/`) + **보상형 30일 물때표**(영상 1편 → 24시간). 테스트 34개 통과(엔진 21 + 로봇 13), 웹 클릭 점검 34/34 + 스크린샷 11장.
웹 미리보기 https://soulfulfillable.github.io/test-mvp/tides-app/index.html — 폰에서 NOAA 실제 예보. 광고는 테스트 ID(웹은 가짜 광고, `?ads=slow|none|early`).
이름 `Glance Tides: Tide Chart`·번들 `com.soulfulfill.tides` **Apple 등록 완료**, 아이콘·스토어 문구 초안 완료. ASC 앱 레코드·AdMob(사용자) 대기 → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- ✅ [사용자] ASC 앱 레코드 생성 (10-03), AdMob 앱 + 배너·보상형 단위 → ✅ [세션] 실제 ID 반영 (iOS. 안드로이드는 테스트 ID 유지).
- ✅ [세션] `Release iOS`(app=tides) run 37115299107 성공 — **빌드 21** 업로드(10-03 19:12 KST, 맥에서 첫 컴파일·서명 통과).
- [사용자] TestFlight 앱에서 Glance Tides 빌드 21 설치 → '느낌' 한마디 (위치 허용·30일 표 영상 포함).
- [세션] TestFlight → 사용자 '느낌' → 스크린샷 6장(1290×2796) → `App Store 등록 정보 채우기`.
- [사용자, 선택] 웹 미리보기 '느낌' 한마디.
- 확인 못 한 것: iOS 실제 빌드(맥에서 첫 컴파일은 `Release iOS` 때), 실기기 위치 권한 창, 실제 AdMob 영상(지금은 테스트·가짜 광고).

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | (AdMob 캡처 2장) "배너는됏고 리워드는 저렇게위에꺼는비우는거지 체크박스" → 보상형 완료 캡처, "App Store Connect 이거도 해놧어" | Partner bidding 은 비움이 맞다고 답함. 앱 ID `~3021266571`, 배너 `/9191837537`, 보상형 `/4912847027` 반영 → `Release iOS`(tides) 실행 |
| 10-03 | (A/B) 이름 "Glance Tides (추천)" / 결제 "넣지 않음 (추천)" / 30일 표 보상형 "넣음 (추천)" | 이름 `Glance Tides: Tide Chart`, 번들 `com.soulfulfill.tides` 등록 실행, 결제 없음, 30일 표 영상 보고 24시간 열기 개발 |
| 10-03 | "물때 시간(Tides) 앱 개발 시작해줘. plans/tides-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/tides.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → Flutter 웹 미리보기부터 준다.
- (다른 세션) 이름은 "Glance" 시리즈로 통일되는 중 — mortgage·decibel·speedometer 모두 Glance 계열을 골랐다.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **작업 환경에서 막힌 API 는 Actions 로 받아 데이터 브랜치에 커밋** (색칠 앱 `fetch-line-art.yml` 방식). 물때는 `fetch-noaa.yml` → `tides-noaa-data` 브랜치.
  응답 시간·CORS 헤더(`Origin` 붙여 요청)·필드 이름까지 리포트로 남기면 앱 설계를 그걸 보고 정할 수 있다. 막힌 호스트 확인: `curl -sS "$HTTPS_PROXY/__agentproxy/status"`.
- **테스트·웹 점검용 가짜 서버는 Actions 로 받은 실제 응답으로** (`tides_app/flutter/test/fixtures`, `tides_app/qa/web-harness.js`). 단 **관측소마다 짝을 섞지 마라** —
  뉴욕 고/저조에 샌프란시스코 곡선을 섞어 줬더니 스크린샷에서 곡선과 만조 점이 어긋나 "앱 버그" 처럼 보였다.
- **공공 데이터 메타데이터를 그대로 믿지 마라.** NOAA 관측소 3,499곳 중 서머타임 표시가 1,257곳 비었고(하와이에 DST true 도 있음),
  시간대도 39곳 틀렸다(플로리다 팬핸들·알류샨·BC). "모든 관측소 × 모든 시간대" 를 화면에 띄우는 로봇 테스트가 "Indian Rocks Beach (CDT)" 를 보여 줘서 알았다.
  → 지역 규칙으로 보정(`tools/tides/make_asset.py`), 엔진 테스트에 대표 지점 13곳 고정.
- **테스트 헬퍼를 정규식/일괄 치환으로 바꿀 때 헬퍼 자신이 바뀌는지 확인.** `textOf(footer)` → `footer()` 일괄 치환이 `footer()` 안의 return 까지 바꿔
  무한 재귀 → flutter_tester 가 5GB 까지 먹고 멈췄다. `timeout` 으로 flutter 를 죽여도 flutter_tester 는 남는다 → `pkill -9 -f flutter_tester`.
  멈춘 테스트는 `print` 로 단계를 찍어(`--dart-define=TRACE=true`) 어디서 멈췄는지부터 본다.
- **ListView 의 "항목이 없다"** 는 대부분 지연 생성(화면 밖 250px 이상은 안 만들어짐) — `scrollUntilVisible` 로 찾아가서 누른다.
  같은 항목이 두 구역(즐겨찾기·근처·인기)에 나오면 **Key 를 구역별로**(`station-fav-<id>`) — 로봇이 같은 키 2개로 잡아냈다.
- **웹 위치 권한 창은 응답 없이 영원히 기다릴 수 있다** (헤드리스 크롬은 답을 안 함) → 웹에서만 `requestPermission` 에 15초 제한. 아이폰은 시스템 창이 답할 때까지 기다리는 게 맞다.
- Flutter SDK 는 storage.googleapis.com 에서 받으면 된다 (`releases_linux.json` → `stable/linux/flutter_linux_3.47.2-stable.tar.xz`). analytics 접속 시도는 `flutter config --no-analytics`.

- **솔루나(낚시·사냥 시간) 세션에**: 일출·일몰(NOAA 태양 계산식)·달 위상(Meeus)·관측소 시계(미국 DST)는 `tides_app/flutter/lib/core/astro.dart`·`zone.dart` 에 있고
  PyEphem 기준 검증 테스트가 `test/engine_test.dart` 에 있다(일출일몰 ±90초, 위상 ±3시간). PyEphem 은 `use_center=True` 로 비교해야 NOAA 정의와 맞는다
  (기본값은 해 윗가장자리라 알래스카 여름에 4분 어긋남). **월출·월몰·달 남중은 아직 없다** — 만들면 알려 주면 물때 앱도 쓴다.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- (없음)
