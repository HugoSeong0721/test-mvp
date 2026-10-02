# GPS 속도계 앱 — App Store 등록 정보 초안 (미국, English U.S.)

> 이름은 사용자 선택 대기. 선택되면 이 파일·`lib/app.dart` 의 title·`ios/Runner/Info.plist` 의 CFBundleDisplayName·
> `docs/speedometer-privacy.html` 제목·설정 화면 문구를 함께 바꾼다.

## 경쟁 앱 조사 (2026-10-03, 웹 검색 요약 — apps.apple.com 직접 접속은 이 환경에서 막혀 대략치)

| 스토어 이름 | 평가 수(US) | 무료 vs 유료 |
|---|---|---|
| Speedometer Simple (Accurate GPS speed tracker) | 4.7★ 약 12.9만 | 광고 + "무료 체험" 동의해야 쓰는 구조 → **$19.99/년** 자동 결제 불만 |
| Speedometer 55 GPS Speed & HUD | 4.8★ 약 6.5만 | 경고·HUD 무료, Pro 별도 앱 $3.99. 운전 중 30초 전면 광고 불만 |
| Speedometer» (Tim O's) | 4.8★ 약 5만 | 잠금화면 Live Activity·Watch, Pro 구독 |
| GPS Speedometer MPH Tracker (BITHAUS) | 4.7★ 1.4만 | 제한속도·카메라 경고는 PRO 구독, 운전 중 구독 팝업 |
| Speed Tracker: GPS Speedometer (Oxagile) | 4.6★ 6.2천 | PRO $17.99/년 |

**리뷰 불만 순서**: ① 구독 함정 ② 운전 중 전면 광고 ③ 운전 중 결제 팝업 ④ 산 걸 잊음 ⑤ 늦게 따라옴·0 으로 떨어짐
⑥ 서 있을 때 튀는 숫자("walking 40 mph"), 터널 뒤 엉뚱한 값 ⑦ **도로 제한속도 데이터가 틀림** (→ 우리는 안 넣는다).
**칭찬**: 정확함, 큰 숫자, 군더더기 없음, 밤 HUD.

→ 우리 차별점(심사 메모에도 적는다): 체험·구독 없음, 운전 중 전면 광고·팝업 0, 정직한 신호 표시(Weak GPS·끊기면 '--'),
정지 시 0 고정·튄 값은 최고속도에서 제외, 차·자전거·달리기(페이스)·보트(노트) 모드, 좌우 반전 HUD, 내가 정한 속도 경고.

## 검색어 (추정, 신뢰도 낮음~중간 — 경쟁 앱 이름 빈도)

1. **speedometer** (기호를 붙여서까지 이름을 차지하려는 단어) 2. **gps speedometer** 3. speedometer app / **speed tracker**
4. **hud** 5. mph / speedometer for car 6. odometer / digital speedometer. "speed limit" 은 기능이 없으니 넣지 않는다(2.3.7).
출시 전 Apple Search Ads(무료 계정) 키워드 추천으로 인기도 숫자 확인 가능. 출시 후 App Analytics 검색어로 고친다.

## 이름 후보 (30자 이내, 웹 검색으로 같은 이름 못 찾음 — 최종 확인은 ASC 에 이름 등록할 때)

| | 이름 | 부제 | 키워드 (100자) |
|---|---|---|---|
| **A (추천)** | `Glance Speed: GPS Speedometer` (29) | `Car HUD, MPH Tracker, Odometer` (30) | `digital,bike,cycling,run,boat,knots,kph,kmh,trip,mileage,meter,gauge,dashboard,alert,driving,display` |
| B | `Speedometer: Big MPH & HUD` (26) | `GPS Speed Tracker & Odometer` (28) | `digital,car,bike,cycling,run,boat,knots,kph,kmh,trip,mileage,meter,gauge,dashboard,alert,driving` |
| C | `Steady Speed: GPS Speedometer` (29) | `HUD, MPH Tracker & Odometer` (27) | B 와 같음 |

- A: Glance FX 와 같은 시리즈로 읽히고, 이름에 "GPS Speedometer" 가 통째로 들어가 1·2위 검색어를 같이 잡는다.
- B: 첫 단어가 "Speedometer" 라 순위엔 조금 유리할 수 있지만 브랜드가 약하다.
- 쓰지 않는 것: DigiHUD(안드로이드 앱 상표), Waze, Speedo(수영복 상표), Clearspeed(회사 상표).

## 기본 정보

- 번들 ID 후보: `com.soulfulfill.speedometer` (사용자 확인 후 Actions `iOS 번들 ID 등록 · 앱 레코드 확인` — 등록하면 못 바꿈)
- 카테고리: Navigation (보조: Utilities) · 연령 4+ · 무료 · 광고 있음(배너만)
- 아이폰 전용·세로 고정. 위치는 "앱 사용 중"만, 백그라운드 위치 없음(UIBackgroundModes 없음)
- 개인정보처리방침: https://soulfulfillable.github.io/test-mvp/speedometer-privacy.html
- Copyright: `2026 Soulfulfill`
- 앱 개인정보 라벨: 위치 = **수집 안 함**(기기 밖으로 안 나감). AdMob: 식별자·사용 데이터·진단(제3자 광고) — 환율 앱과 같은 방식.

## 설명 초안 (English)

```
A big, clear GPS speedometer — free, no subscription, no trial.

• Huge numbers you can read at a glance, or a classic analog gauge
• MPH or km/h (knots in Boat mode) — tap the unit to switch
• HUD mode: mirrored numbers for your windshield at night
• Speed alert: pick your own number; the screen turns red and beeps when you go over
• Trip stats: top speed, average, distance and time — kept separately for Car, Bike, Run and Boat
• Run mode shows your pace (min/mi or min/km)
• Honest GPS: shows "Weak GPS" or "No GPS signal" instead of guessing
• Reads 0 when you're stopped — no jumping numbers at red lights
• Works offline. Your location never leaves your iPhone.
• The screen stays on while the app is open

No full-screen ads, ever. Just a small banner at the bottom.

Please don't interact with your phone while driving. The app does not show road speed limits — always follow posted limits.
```

## 심사 메모 (App Review Notes) 초안

```
The app measures speed with the iPhone's GPS while the app is open (When In Use only; no background location).
To see speed, please move (walk or drive) — when stationary it correctly shows 0.
Unlike many speedometer apps: no subscription or trial, no interstitial/video ads (banner only), honest
GPS accuracy display ("Weak GPS" / "No GPS signal"), spike-filtered top speed, Car/Bike/Run (pace)/Boat (knots)
modes, mirrored HUD mode and a user-set speed alert. A one-time safety notice asks users not to interact while driving.
```

## 스크린샷 (6.7형 1290×2796) — 1.4.4 과속 조장 금지 → 45~65 mph 정도만

1. 큰 숫자 45 MPH + 기록 2. 게이지 3. HUD(반전) 4. 속도 경고(빨간 화면, 66 MPH / 65 경고) 5. 달리기 페이스 6. 보트 노트
(웹 점검 스크린샷 `speedometer_app/qa/shots/` 를 바탕으로 1290×2796 로 다시 찍는다.)
