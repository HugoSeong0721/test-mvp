# 한눈환율 — App Store 등록 문구

App Store Connect → My Apps → 한눈환율 → iOS App 1.0 에 그대로 붙여넣는 용도.
**기본 언어: Korean.** 앱 UI 가 한국어라 그에 맞춘다. 영어는 두 번째 로컬라이제이션으로 추가.

---

## 앱 정보 (App Information)

| 항목 | 값 |
|---|---|
| Name (30자) | `한눈환율` |
| Subtitle (30자) | `달러·엔·유로 환율 계산기` |
| Bundle ID | `com.mgseong.currency` |
| SKU | `somrate` |
| Primary Category | Finance |
| Secondary Category | Travel |
| Content Rights | 제3자 콘텐츠 없음 |
| Age Rating | 모든 설문 "없음" → **4+** |
| Price | 무료 |

## 버전 정보 (Korean)

### Promotional Text (170자, 심사 없이 수시 변경 가능)

```
실시간 환율로 바로 계산. 달러·엔·유로·위안을 원화와 한 화면에서. 해외여행·직구·송금 전에.
```

### Description (4000자)

```
한 번 입력하면 여러 나라 금액이 동시에 바뀝니다.

한눈환율은 기준 통화 하나를 맨 위에 두고, 아래에 원하는 나라를 원하는 만큼 늘어놓는 환율 계산기입니다. 숫자를 치는 순간 모든 줄이 같이 바뀝니다. 변환 버튼은 없습니다.

■ 어느 줄이든 입력
위의 기준 금액만 고치는 게 아닙니다. 아래 줄의 금액을 누르면 그 통화로 바로 입력할 수 있고, 나머지가 전부 따라옵니다. "직구 99달러면 원화로 얼마"와 "여행 경비 50만 원이면 엔화로 얼마"를 오가며 계산할 때 편합니다.

■ 전일 대비 ▲▼
모든 줄에 어제보다 올랐는지 내렸는지 퍼센트로 표시합니다. 환전을 오늘 할지 내일 할지 판단할 때 봅니다.

■ 소수점이 사라지지 않습니다
1 미만 금액은 유효 숫자 기준으로 보여줍니다. 비트코인이나 금처럼 단위가 큰 자산도 0.00 으로 뭉개지지 않습니다.

■ 그 나라 지금 몇 시
통화 이름 옆에 그 나라 현지 시각이 붙습니다. 송금이나 전화를 걸기 전에 한 번 보면 됩니다.

■ 오프라인
마지막으로 받은 환율을 저장해 두어 비행기 안이나 로밍이 안 되는 곳에서도 계산됩니다. 헤더에 환율이 언제 것인지 항상 표시합니다.

■ 차트
1일부터 1년까지 기간별 환율 흐름, 최고·최저, 기간 변동률.

■ 통화
법정통화(USD, KRW, EUR, JPY, CNY, GBP, HKD, TWD, THB, VND, AUD, CAD 등 20여 개), 암호화폐(BTC, ETH, DOGE), 귀금속(금·은·백금·팔라듐).

■ 가벼움
계정 없음, 로그인 없음, 추적 없음. 설정은 기기 안에만 저장됩니다. 하단에 작은 배너 광고가 하나 있습니다.

다크 모드와 라이트 모드를 시스템 설정에 따라 자동으로 바꿉니다.
```

### Keywords (100자, 쉼표 구분, 앱 이름에 있는 단어는 넣지 않음)

```
환율계산기,환전,달러,엔화,유로,위안,원화,해외직구,여행,송금,오프라인,비트코인,금시세,currency
```

### Support URL

```
https://github.com/HugoSeong0721/test-mvp/issues
```

### Privacy Policy URL

```
https://hugoseong0721.github.io/test-mvp/somrate-privacy.html
```

### What's New (1.0)

```
첫 출시.
```

## 버전 정보 (English — 두 번째 언어)

| 항목 | 값 |
|---|---|
| Name | `Glance FX` |
| Subtitle | `Currency Converter & Rates` |
| Keywords | `exchange rate,dollar,euro,yen,pound,travel,money,forex,offline,bitcoin,gold,calculator` |

```
Type once and every currency on screen updates together.

Glance FX pins one base currency at the top and lets you stack as many countries below it as you like. There is no convert button — amounts change as you type.

■ Edit any row
Tap the amount on any row to type in that currency; everything else follows.

■ Daily change
Every row shows how the rate moved since yesterday.

■ Smart precision
Amounts below 1 are shown by significant digits, so Bitcoin or gold never collapses to 0.00.

■ Local time
Each currency shows the current time in its country.

■ Works offline
The last rates are cached; the header always tells you how fresh they are.

■ Charts
1 day to 1 year, with high, low and period change.

Fiat (USD, EUR, JPY, GBP, CNY, KRW, CAD, AUD, CHF, MXN, INR and more), crypto (BTC, ETH, DOGE) and metals (gold, silver, platinum, palladium).

No account, no sign-in, no tracking. One small banner ad at the bottom.
```

---

## 스크린샷

필수: **6.7형 iPhone**(1290×2796) 최소 1장 — 이걸 올리면 다른 크기는 자동으로 쓰인다.
권장 3~4장: 변환 화면(여러 나라) / 아래 줄 입력 중(키패드) / 통화 선택 시트 / 차트.
맥에서 iPhone 15 Pro Max 시뮬레이터로 실행해 ⌘S 로 저장하면 정확히 이 크기가 나온다.

## App Privacy (개인정보 영양표)

AdMob 이 있으므로 "데이터를 수집함"으로 답한다. 개발자가 아니라 Google SDK 가 수집하는 것이지만 Apple 은 앱 단위로 묻는다.

| 질문 | 답 |
|---|---|
| Do you collect data from this app? | **Yes** |
| 수집 항목 | **Identifiers → Device ID** · **Usage Data → Advertising Data** · **Diagnostics → Crash Data**(SDK 기본) |
| 각 항목 용도 | Third-Party Advertising |
| Linked to the user? | No |
| Used for tracking? | **No** (ATT 요청을 하지 않으므로 — Info.plist 에 NSUserTrackingUsageDescription 없음) |

## 심사 노트 (App Review Information)

```
환율 계산기입니다. 계정이 없어 로그인 정보가 필요 없습니다.
하단 배너는 Google AdMob 입니다. 환율은 공개 API(cdn.jsdelivr.net / currency-api.pages.dev)에서 받습니다.
```

## 수출 규정 (Export Compliance)

Info.plist 에 `ITSAppUsesNonExemptEncryption = NO` 가 들어 있어 업로드할 때마다 묻지 않는다. 물어보면 "HTTPS 외 암호화 없음 → 면제".

## 이름 일치

`한눈환율` 은 아래 세 곳에서 같아야 한다.
- App Store Connect 앱 이름
- `ios/Runner/Info.plist` 의 CFBundleDisplayName (CI 가 넣어 둠)
- `docs/somrate-privacy.html` 제목
