# Glance: Currency Converter — App Store 등록 문구

**대상: 미국 App Store. 기본 언어 English (U.S.).** 앱 UI 도 영어.
App Store Connect → Apps → Glance → iOS App 1.0 에 그대로 붙여넣는다.

## 키워드 전략 (ASO)

App Store 검색은 **이름 > 부제 > 키워드 필드** 순으로 가중치를 준다. 세 칸에 같은 단어를 반복하면
낭비라서 겹치지 않게 나눠 담는다. 단수/복수는 Apple 이 알아서 묶는다.

| 칸 | 담은 검색어 | 이유 |
|---|---|---|
| 이름 | currency, converter | 이 분야 미국 검색어 1위 "currency converter" 를 그대로 |
| 부제 | exchange, rate, money, calculator | "exchange rate", "currency exchange", "money converter", "currency calculator" 가 이름 단어와 조합돼 걸린다 |
| 키워드 | 나머지 | 통화 이름(euro, peso, yen…), 여행, forex, crypto/gold 등 |

> 순위는 App Store 검색 자동완성과 상위 경쟁 앱 이름에서 반복되는 패턴 기준이다. 실제 검색량 숫자는
> 유료 ASO 도구(AppTweak, Sensor Tower 등)에만 있다. 출시 후 App Analytics → Sources →
> App Store Search 에서 실제로 들어온 검색어를 보고 키워드 필드를 고친다 (업데이트마다 변경 가능).

---

## App Information

| 항목 | 값 |
|---|---|
| Name (30) | `Glance: Currency Converter` |
| 이름 중복 시 | `Glance FX: Currency Converter` |
| Subtitle (30) | `Exchange Rate Money Calculator` |
| Bundle ID | `com.soulfulfill.currency` |
| SKU | `currency` |
| Primary Language | English (U.S.) |
| Primary Category | Finance |
| Secondary Category | Travel |
| Content Rights | 제3자 콘텐츠 없음 |
| Age Rating | 설문 전부 "None" → **4+** |
| Price | Free |

## Version 1.0 — English (U.S.)

### Promotional Text (170, 심사 없이 수시 변경)

```
Live exchange rates for 20+ world currencies, Bitcoin and gold. Type once, see every currency update instantly — even offline.
```

### Description (4000)

```
Type an amount once and every currency on your screen updates instantly.

Glance is a fast, clean currency converter. Pin your home currency at the top, add as many others as you like below it, and see them all at a glance. No convert button, no waiting.

■ EDIT ANY ROW
Tap the amount on any row to type in that currency — everything else follows. Check "how much is 50 euros in dollars" and "what's $200 in pesos" without switching screens.

■ DAILY CHANGE
Every currency shows how its exchange rate moved since yesterday, so you know whether to exchange money today or wait.

■ REAL RATE HISTORY
Charts for 1 week, 1 month, 3 months and 1 year with high, low and period change.

■ WORKS OFFLINE
The latest rates are saved on your device, so the calculator keeps working on a plane or abroad without data. The header always shows how fresh your rates are.

■ PRECISE SMALL AMOUNTS
Values below 1 keep their significant digits, so Bitcoin and gold never collapse to 0.00.

■ LOCAL TIME
Each currency shows the current time in its country — handy before you call or send money.

■ CURRENCIES
US Dollar, Euro, British Pound, Canadian Dollar, Mexican Peso, Japanese Yen, Chinese Yuan, Swiss Franc, Australian Dollar, Indian Rupee, Korean Won, Brazilian Real and more — plus Bitcoin, Ethereum, Dogecoin, gold, silver, platinum and palladium.

■ SIMPLE AND PRIVATE
No account. No sign-in. Your settings stay on your device. One small banner ad.

Dark and light mode follow your system setting.

Great for travel, shopping from overseas stores, sending money abroad, and freelancers paid in foreign currency.
```

### Keywords (100, 쉼표만·공백 없음, 이름/부제 단어 제외)

```
euro,peso,yen,pound,dollar,travel,forex,fx,cash,usd,eur,gbp,mxn,cad,bitcoin,crypto,gold,offline
```

### Support URL

```
https://github.com/soulfulfillable/test-mvp/issues
```

### Privacy Policy URL

```
https://soulfulfillable.github.io/test-mvp/somrate-privacy.html
```

### What's New (1.0)

```
First release.
```

---

## 스크린샷

필수: **6.9형 iPhone 1320×2868**(또는 6.7형 1290×2796) 최소 1장. 있으면 작은 기기용은 자동 축소된다.
권장 4장, 각 장 위에 큰 문구 (검색 결과에서 첫 2~3장이 보인다):

1. 변환 화면 — "Every currency at a glance"
2. 아래 줄 입력 중(키패드) — "Type in any currency"
3. 차트 — "Real rate history"
4. 통화 선택 — "20+ currencies, crypto & gold"

## App Privacy

AdMob 이 있으므로 "데이터를 수집함". 개발자가 아니라 Google SDK 가 수집하지만 Apple 은 앱 단위로 묻는다.

| 질문 | 답 |
|---|---|
| Do you or your third-party partners collect data from this app? | **Yes** |
| Data types | **Identifiers → Device ID** · **Usage Data → Advertising Data** · **Diagnostics → Crash Data**, **Performance Data** |
| 각 항목 용도 | Third-Party Advertising (Crash/Performance 는 App Functionality 도) |
| Linked to the user's identity? | No |
| Used for tracking? | **No** — 앱이 ATT(추적 허용) 요청을 하지 않는다 |

## App Review Information — Notes

```
Currency converter. No account or login required.
The banner at the bottom is Google AdMob.
Exchange rates come from a public API (cdn.jsdelivr.net/npm/@fawazahmed0/currency-api, mirror currency-api.pages.dev).
```

## 출시 국가 (Pricing and Availability)

**United States** 먼저. EU 국가는 끈다 — EU 에 내려면 판매자(trader) 신고로 주소·전화번호가
EU 스토어에 공개된다.

## 수출 규정

Info.plist 에 `ITSAppUsesNonExemptEncryption = NO` 가 있어 업로드 때 묻지 않는다.

## 이름 일치

- App Store Connect 앱 이름: `Glance: Currency Converter`
- 홈 화면 이름(Info.plist CFBundleDisplayName / Android label): `Glance`
- 개인정보처리방침 제목: Glance
