# 낚시·사냥 시간 (solunar 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 07:40 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`solunar_app/flutter/`): 오늘 점수(0~100)·Major/Minor 구간·24시간 막대·지금/다음 구간·사냥 허용 시간 카운트다운·해/달·7일 띠·30일 달력(영상 보고 24시간)·장소 검색(미국·캐나다 2만 곳, 오프라인)·저장한 곳.
테스트 34개 통과(엔진 22: PyEphem 대조 1,800건+·공개 솔루나 표 3곳 2분 이내 / 로봇 12), 웹 클릭 점검 39/39. 웹 미리보기 https://soulfulfillable.github.io/test-mvp/solunar-app/index.html
이름·번들 ID 사용자 확인 대기 → 번들 등록 → ASC 앱 레코드·AdMob(사용자) → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 이름 A/B: **A `Glance Solunar: Fishing Times` (추천)** / B `Glance Moon: Fishing & Hunting` / C `Solunar Day: Fish & Hunt Times`. 번들 `com.soulfulfill.solunar`.
- [사용자] 웹 미리보기 열어 보고 '느낌' 한마디 (위치 허용하면 지금 있는 곳 기준).
- [세션, 이름 정해지면] 번들 등록 Actions → `Release iOS`·`App Store 등록 정보 채우기` 선택지에 solunar 추가 → ASC 앱 레코드·AdMob(배너 + 보상형 1개) 안내 → TestFlight.

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "낚시·사냥 시간(솔루나) 앱 개발 시작해줘. plans/solunar-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어 (특히 board/tides.md — 일출일몰·달 계산 재사용). 네 게시판은 board/solunar.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 물때 앱 일출일몰·위상 코드 재사용 + 달 위치·월출월몰·남중 새로 만듦. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (다른 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터. 결정은 추천안 + 이유 한 줄. 이름은 Glance 시리즈로 통일되는 중.
- (이 앱) 아직 피드백 없음.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **물때 세션에: 월출·월몰·달 남중/북중이 생겼다** → `solunar_app/flutter/lib/core/astro.dart` 의 `moonEvents(start, end, lat, lng)` (Meeus 47장 달 위치 + USNO 정의).
  PyEphem 대조 13곳·1,839건: 남중 ±1초, 월출·월몰 최대 30초(71°N). 파일 하나라 그대로 복사해 쓰면 된다 (해·위상 부분은 물때 코드와 같음).
  기준값 생성기 `tools/solunar/make_reference.py` — **PyEphem 은 북극권에서 월출을 놓치는 일이 있다**(앞 남중 때 달이 지평선 아래면 NeverUpError). 고도를 직접 찍어 우리 값이 맞는 걸 확인하고 테스트에 예외 1건으로 적었다.
- **공개 솔루나 표 대조**: solunarforecast.com 의 Major = 달 남중/북중 ±60분, Minor = 월출/월몰 ±30분 (Tool TX 2026-09-03 표와 2분 이내 일치). 신문 Knight 표는 '시작 시각'을 싣는다 — 가운데 시각이 아니니 대조할 때 주의.
- **ListView 를 맨 위로 보내는 순간에 위쪽 항목이 빠지면(조건부 카드) 스크롤이 엉뚱한 곳(230px)에서 멈춘다** — 그 프레임에 남은 옛 위치로 보정하기 때문. `animateTo`·`jumpTo`·다음 프레임 `jumpTo` 다 실패.
  → 날짜/장소가 바뀌면 `KeyedSubtree(key: 날짜)` 로 목록을 새로 만들고 `ScrollController(keepScrollOffset: false)`. 로봇 테스트가 "다른 날 눌렀는데 점수가 화면 밖" 으로 잡았다.
- **`timezone` 패키지의 `latest_all.dart`(Dart 문자열 내장)는 웹 main.dart.js 를 1.8MB 키운다** → `.tzf` 파일을 자산으로 넣고 `tz.initializeDatabase(bytes)`. (4.1MB → 2.7MB)
- **Flutter 웹 접근성 트리**: 카드 안 글자들은 그룹의 `aria-label` 한 덩어리로 합쳐지거나 `span` 에 들어간다 → 점검 스크립트는 `flt-semantics, span, h2` 의 aria-label·글자를 정규식으로 찾는다(`solunar_app/qa/web-check.js` 의 `has()`).
  ChoiceChip 은 role `checkbox`. **AppBar 제목 자리의 InkWell 은 버튼이 아니라 제목(h2)으로만 읽힌다** → `Semantics(container: true, button: true, label: …)` 로 감싸야 VoiceOver·자동 점검이 버튼으로 찾는다.
- **도시 목록이 필요하면** GeoNames(download.geonames.org)는 막혀 있지만 PyPI `geonamescache` 휠에 cities500/1000/5000/15000 JSON(시간대 포함)이 들어 있다 → `tools/solunar/make_places.py`. CC BY 4.0 이라 앱 안에 출처 표기.
- **GPS 위치의 이름은 "가장 가까운 곳"이 아니라 큰 도시 가중**: GeoNames 에 "University of Texas" 같은 항목이 있어 오스틴 한복판이 "near University of Texas" 로 나왔다 → 거리 − 1.5마일×log10(인구)로 고른다.
- **시간대**: GPS 지점은 폰 시간대(`flutter_timezone`), 검색한 마을은 그 마을 시간대 — 다른 주를 볼 때 그곳 시각으로 보여 준다(Bozeman 은 MDT).
- **복사해 온 문구 확인**: 물때 앱 `location.dart` 를 가져왔더니 "search for a station" 이 남아 있었다(웹 스크린샷에서 발견) → 로봇에 "station 글자 없음" 검사를 넣었다.
- 이 작업 환경에서 WebFetch 는 대부분 막히지만 **WebSearch 는 된다** — 경쟁 앱 평점·리뷰 불만은 백그라운드 조사 에이전트에게 WebSearch 로 맡기면 15분 안에 나온다.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 30일 달력 보상형에서 **영상이 없을 때(오프라인·광고 재고 없음)는 그냥 열어 준다**(8초 기다린 뒤). 사용자 탓이 아닌데 막는 건 1등 앱 불만과 같은 결이라 판단. 괜찮은지?
- 기획 파트너: 점수 분포가 정직하게 나오면 1년 중 약 40% 가 "Slow"(반달 무렵). 계산식을 부풀리지 않고 그대로 두었다 — 너무 박하다는 느낌이면 TestFlight 때 다시 본다.
- 기획 파트너: 주별 사냥 시간 프리셋은 넣지 않았다(출처 확인 못 한 주가 대부분). 대신 오프셋 직접 설정 + 빠른 설정 3개(30/30, 30/일몰, 일출/일몰) + "주 규정 확인" 안내.
