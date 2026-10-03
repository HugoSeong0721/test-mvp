# Glance: Mortgage Calculator — App Store 등록 문구

**대상: 미국 App Store. 기본 언어 English (U.S.).** 앱 UI 도 영어. 부제·설명·키워드·URL·심사 메모는 `ios-metadata.json` 을
Actions → **App Store 등록 정보 채우기**(app=mortgage) 로 넣는다. 문구를 고치면 이 파일과 json 을 같이 고친다.

## 시장 조사 요약 (2026-10-03, 검색 스니펫 기반 — App Store 페이지는 이 환경에서 직접 못 열었다)

| 앱 | 평점 / 평가 수 | 마지막 업데이트 | 수익 모델 | 메모 |
|---|---|---|---|---|
| Loan Calculator (Tim O's Studios) | 4.9★ / 약 10.4만 | 2022-02 | 광고 (팝업·소리 나는 영상) | 1등인데 4년 방치. PMI·추가 상환 없음(미확인) |
| Loan Calculator - Debt Planner | 4.6★ / 약 2.2만 | 미확인 | 광고 + 월/연 패스 | 추가 상환·빚 청산일 |
| Loan2Me | 4.8★ / 8.2천 | 미확인 | Pro $9.99 | 판매세·보상 판매·PDF/CSV |
| Mortgage Pal | 4.8★ / 4.7천 | 2026-08 | 광고 + 평생 $14.99 | 기능 많음. "숫자가 아무 데나 들어간다" 입력 불만 |
| Karl's Mortgage Calculator | 4.4★ / 124 | 2026-08 | 광고 + $1.99 | PMI·HOA·추가 상환·차트 |
| Zillow·Bankrate | — | — | — | 독립 계산기 앱 없음 (Zillow 는 본 앱 안에) |

**리뷰 불만 1위 = 광고 강요** ("광고가 인질처럼 기다리게 한다", "Calculate 누르면 결과 대신 시끄러운 광고").
그다음 **숫자 입력이 이상함**, PMI 자동 계산 없음, 저장 안 됨, 유료 벽.
→ 우리 차별점: **배너만, 전면 광고 없음** · 쉼표 자동 숫자 칸 · PMI 자동(78%에 끝) · 추가 상환 "몇 년 빨리, 얼마 절약" · 값 자동 저장 · 전부 무료.

## 키워드 전략 (ASO)

검색 가중치는 이름 > 부제 > 키워드 칸. 세 칸에 같은 단어를 반복하지 않는다.
검색어 점수(asotools, 국가 미확인): mortgage calculator 59 · car loan calculator 53(경쟁 1) · loan calculator 49 ·
home loans calculator 48 · mortgage payment calculator 43(경쟁 2).

### 이름 — **A 로 확정** (사용자 2026-10-03 "Glance: Mortgage Calculator (추천)")

| | 이름 (30) | 부제 (30) | 걸리는 검색어 |
|---|---|---|---|
| **A (추천)** | `Glance: Mortgage Calculator` (27) | `Home Loan & Payment Calculator` (30) | mortgage calculator(1위) 를 이름에 그대로 + home loan / payment / loan calculator. Glance FX 와 시리즈 |
| B | `Glance Loan Calculator` (22) | `Mortgage, Car & Amortization` (28) | loan calculator·car loan calculator 강함, mortgage calculator 는 약해짐 |

이미 쓰이는 이름(못 씀): Mortgage Calculator, Mortgage Calculator™, Mortgage Calculator +, Loan Calculator,
Mortgage Payment Calculator, Car Loan Calculator Plus. "Glance Mortgage"·"Glance Loan" 은 검색에 안 나옴(ASC 에서 이름 잡아야 확정).

### 키워드 칸 (100자, A 기준)

```
amortization,pmi,car,auto,interest,rate,extra,payoff,house,principal,escrow,tax,hoa,piti,schedule
```
- 실제 기능만 넣는다 (2.3.7). refinance 기능은 없으니 넣지 않는다. 남의 상표(Zillow 등) 금지.

## App Information

| 항목 | 값 |
|---|---|
| Name (30) | `Glance: Mortgage Calculator` |
| Subtitle (30) | `Home Loan & Payment Calculator` |
| Bundle ID | `com.soulfulfill.mortgage` (사용자 확인 2026-10-03) |
| SKU | `mortgage` |
| Primary Language | English (U.S.) |
| Primary Category | Finance |
| Secondary Category | Utilities |
| Age Rating | 설문 전부 "None" → 4+ |
| Price | Free |
| Privacy Policy | https://soulfulfillable.github.io/test-mvp/mortgage-privacy.html |
| Copyright | 2026 Soulfulfill |

## Version 1.0 — English (U.S.)

### Promotional Text (170)

```
See your real monthly mortgage payment with taxes, insurance, HOA and PMI — and how many years an extra $100 a month takes off your loan.
```

### Description

```
Your monthly mortgage payment, the moment you type.

Glance is a clean, fast mortgage and loan calculator. No calculate button, no pop-up ads — every number updates as you type.

■ THE WHOLE MONTHLY PAYMENT
Principal and interest plus property tax, home insurance, HOA dues and PMI, with a clear breakdown chart. PMI is added automatically when your down payment is under 20% and drops off when your balance reaches 78% of the home price.

■ PAY OFF YOUR LOAN SOONER
Add an extra $50, $100, $200 or any amount each month and see exactly how many years sooner you'll be debt-free and how much interest you'll save — with a balance chart, with and without extra payments.

■ FULL AMORTIZATION SCHEDULE
Every payment by year or by month: principal, interest and remaining balance, plus a chart of principal vs. interest paid each year.

■ CAR AND PERSONAL LOANS TOO
Switch to Auto for vehicle price, down payment, trade-in and sales tax, or Personal for a simple loan amount, APR and term.

■ MADE FOR IPHONE
• Down payment and property tax in dollars or percent — change one, the other follows
• Numbers get commas as you type; a Done bar sits above the keypad
• Your numbers are saved on your iPhone, for each calculator
• Works offline. No account. Light and dark mode

Estimates only, not financial advice or an offer of credit. Interest rates in the app are examples — enter the rate from your lender.
```

### Review Notes

```
Mortgage / auto / personal loan payment calculator. No account or login. All calculations run on the device; the app makes no network requests except Google AdMob banner ads.
The app does not offer loans, collect financial information or show live interest rates — default rates are labeled as examples the user edits.
```

## App Privacy (설문)

- Data collection: **Yes** — Google AdMob: Device ID(광고), Product Interaction, Advertising Data, Coarse Location(IP) — "Used for Third-Party Advertising", Not linked to identity, **Tracking: No** (ATT 요청 안 함 → 비개인화 광고).
- 개발자 수집: 없음. 입력한 숫자는 기기에만 저장.

## 할 일

- [x] 이름 확정 → `ios-metadata.json` 작성 (스크린샷 목록은 찍은 뒤 채운다)
- [ ] 스크린샷 6.7형 1290×2796: ① 월 납입액+내역 ② 추가 상환 "Debt-free … sooner" ③ 상환표 ④ 자동차 대출 — 테스트 로봇(iPhone 15 Pro Max 3배)으로 뽑는다

## Version 1.1 — What's New (1.0 승인 뒤 새 버전 만들 때 붙여넣기)

```
• Choose your state to fill in its average property tax rate (or sales tax for car loans). You can still edit the rate for your county.
• Start extra payments in a later month.
• Add a one-time payment, like a bonus or tax refund.
• Bi-weekly option: pay half every 2 weeks and see how much sooner you're debt-free.
```
- 주별 세율 출처: Tax Foundation 2026 (`mortgage_app/store/state_rates.json`). 설명(Description) ■ PAY OFF 절에 위 3가지를 한 줄씩 추가할 것.
