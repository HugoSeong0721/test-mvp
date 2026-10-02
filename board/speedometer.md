# GPS 속도계 (speedometer 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 06:45 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`speedometer_app/flutter/`): 큰 숫자/게이지·HUD·속도 경고·모드 4개·이동 기록. 테스트 37개 통과(엔진 18 + 로봇 19).
웹 미리보기 https://soulfulfillable.github.io/test-mvp/speedometer-app/index.html — 폰 위치로 **진짜 속도**, `?demo=1` 은 가짜 주행. 광고는 배너만(테스트 ID).
이름 **Glance Speed: GPS Speedometer** 확정, 번들 `com.soulfulfill.speedometer` **Apple 등록 완료**(Actions 로그 "새로 등록함"). 다음: ASC 앱 레코드·AdMob(사용자) → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 웹 미리보기를 차에서(조수석) 켜 보고 '느낌' 한마디.
- [사용자] App Store Connect → 앱 → ＋ 신규 앱: iOS / `Glance Speed: GPS Speedometer` / English (U.S.) / 번들 `com.soulfulfill.speedometer` / SKU `speedometer`.
- [사용자] AdMob(**`soulfulfillable` 계정**) → 앱 추가(iOS, 스토어 미등록, 이름 Glance Speed) → 광고 단위 1개: 배너 `banner`. 앱 ID(`~`)·단위 ID(`/`)를 알려 주면 교체.
- [세션] ASC 앱 레코드 생기면 `Release iOS`(app=speedometer) → TestFlight → 스크린샷 1290×2796·`speedometer_app/store/ios-metadata.json`.

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | 이름 A/B → "Glance Speed (추천)", 번들 → "speedometer 로 등록 (추천)" | 이름 `Glance Speed: GPS Speedometer`(홈 화면 `Glance Speed`), 번들 `com.soulfulfill.speedometer` 등록 Actions 실행. 앱·방침·웹 제목 반영, `Release iOS` 선택지에 speedometer 추가 |
| 10-03 | "GPS 속도계 앱 개발 시작해줘. plans/speedometer-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/speedometer.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터 준다. 속도계는 사파리 위치 API 로 웹에서도 진짜 속도가 나온다.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **위치(GPS) 앱 헤드리스 점검**: Playwright 의 `setGeolocation` 은 속도(`coords.speed`)를 못 준다 → `addInitScript` 로
  `navigator.geolocation`(watchPosition/getCurrentPosition/clearWatch)과 `navigator.permissions.query` 를 바꿔 끼워
  `window.__gps={mph,acc,on,speed}` 대로 1초마다 측정값을 보낸다. 거절·신호 끊김·속도 없음까지 흉내. `speedometer_app/qa/web-qa.js`.
- **geolocator 웹판은 속도가 없으면 0 을 넣는다**(서 있음과 모름이 구분 안 됨) → 웹은 `package:web` 으로 브라우저 위치 API 를 직접 쓰고
  조건부 import(`if (dart.library.js_interop)`)로 아이폰판과 갈아끼운다. `speedometer_app/flutter/lib/core/platform_location.dart`.
- **잘림 검사는 실제 글꼴로**: 대출 세션의 `didExceedMaxLines` 검사를 기본 테스트 글꼴(Ahem, 글자가 정사각형)로 돌리면 "Alert off" 같은 짧은 글자도
  잘렸다고 나온다(오탐 6건). SDK Roboto 를 `FontLoader` 로 넣으니 진짜 잘림 1건("Alert 155 KM/H", SE·글씨 135%)만 남았다.
- **위젯 테스트에서 스트림 이벤트 뒤엔 `pump(Duration.zero)`**: 그냥 `pump()` 는 예약된 프레임이 없으면 그리지 않고 끝나고, 이벤트는 그 뒤 마이크로태스크에서 처리된다
  → 화면이 한 박자 늦은 값으로 검사된다. `pump(Duration.zero)` 는 마이크로태스크를 먼저 흘려보낸 뒤 그린다.
- **위젯 테스트 시간은 `package:clock` 의 `clock.now()`** — testWidgets 안에서 가짜 시계를 따라간다(`DateTime.now()` 는 안 따라감).
- **앱이 백그라운드(paused)면 프레임이 안 그려진다** → 그 상태의 화면 글자를 검사하지 말고, 돌아왔을 때(resumed) 화면을 검사.
- 화면에 큰 '--' 는 글자 간격을 줄이면 막대 하나로 붙어 보인다(스크린샷에서 발견) → 모르는 값은 회색·간격 넓게.
- 아이폰 위치 권한: `NSLocationWhenInUseUsageDescription` 만 써도 geolocator 안에 "항상" 권한 코드가 있어 업로드 검사(ITMS-90683)에 걸릴 수 있다고 알려져
  `NSLocationAlwaysAndWhenInUseUsageDescription` 도 정직한 문구로 넣어 둠(요청은 안 함). `UIRequiredDeviceCapabilities` 에 `gps`·`location-services`.
- Flutter 설치: `git clone --depth 1 -b stable https://github.com/flutter/flutter.git /opt/flutter` 도 된다 (첫 실행 1분).

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 1차는 **백그라운드 위치 없이**(화면 켜둠만) 내려 한다 — 심사 2.5.4 위험·배터리. 경쟁 1등들은 잠금화면 Live Activity·백그라운드 기록이 있다.
  2차에 넣을지 TestFlight 느낌 보고 정해도 될지?
- 기획 파트너: 수익이 배너뿐이다(기획서대로 운전 중 전면 광고 금지). 보상형 자리가 마땅치 않음 — 예: "기록 공유 이미지" 같은 건 1.4.4(과속 조장) 위험이라 안 넣었다.
