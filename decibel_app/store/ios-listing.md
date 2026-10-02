# Glance dB: Decibel Meter — App Store 등록 문구 (초안)

**대상: 미국 App Store. 기본 언어 English (U.S.).** 앱 UI 도 영어.
**이름 `Glance dB: Decibel Meter`·번들 `com.soulfulfill.decibel` 확정 (사용자, 2026-10-03). 번들 ID Apple 등록 완료.**

## 검색어 조사 (2026-10-03, 개발 세션)

ASO 도구 공개 요약(ASOTools, Decibel X 키워드) 기준 — 국가·날짜는 확인 못 함, 순위만 참고:

| 검색어 | 인기 점수 | 비고 |
|---|---|---|
| **decibel meter** | 54 | 1위 → 이름에 그대로 |
| sound meter | 35 | 부제 |
| noise meter | 33 | 부제 |
| decibel | 31 | 이름에 포함 |
| sound level meter | 28 | 부제(sound + level + meter 조합) |
| db meter | (4,608, 단위 다름) | 이름의 "dB" 로 걸림 |

이름 중복 확인: "Decibel Meter - Sound Meter"(있음), "dB Meter: Sound Level Meter"(사실상 있음) → 일반명만으로는 못 쓴다.
"Glance dB" 는 검색에 안 나옴(확인 못 함 — Apple 페이지 직접 접속이 막혀 검색엔진으로만 확인).

### 경쟁 앱에서 본 것 (리뷰 불만 → 우리 답)
| 경쟁 앱 | 불만 | 우리 |
|---|---|---|
| Decibel X (약 16만 평가) | 첫 실행 구독 화면(연 $49.99), 흐린 닫기 버튼, 무료판 dBA 잠금, "무료 체험이 바로 결제" | 구독 없음. dBA·dBC·dBZ 전부 무료 |
| Decibel (Vlad P., 약 3.6만) | 저장·내보내기 유료($19.99) | 리포트 이미지·기록 전부 무료 |
| NIOSH SLM (약 1.7만, 무료) | 투박, 배터리, 기록 약함 | 쉬운 비유("Like a lawnmower"), 기록 자동 저장 |
| 광고형 앱들 | 30초마다 전면 광고 + **광고 소리가 측정을 망침** | 배너만. 측정 중 전면·소리 광고 없음 |
| 이웃 소음 전용 앱(Noise Log 등) | 증거용 리포트 수요 확인 | 날짜·시각·평균·최대·가장 시끄러운 순간·그래프 한 장 |

## 이름 후보 (사용자 A/B) → A 선택

| | Name (30) | Subtitle (30) | 이유 |
|---|---|---|---|
| **A (추천)** | `Glance dB: Decibel Meter` (24) | `Sound Level & Noise Meter` (25) | Glance FX 와 같은 시리즈 형식. 1위 검색어 decibel meter 가 이름에, 2~5위가 부제에 |
| B | `Decibel Meter: Glance dB` (24) | `Sound Meter & Noise Level` (25) | 1위 검색어를 맨 앞에. 비슷한 일반명 앱이 많아 묻힐 위험 |

번들 ID 후보: `com.soulfulfill.decibel` (등록하면 못 바꾼다). SKU `decibel`. 홈 화면 이름(CFBundleDisplayName): `Glance dB`.

## 키워드 전략 (ASO)

| 칸 | 담은 검색어 |
|---|---|
| 이름 | glance, db, decibel, meter |
| 부제 | sound, level, noise |
| 키워드(100자) | `spl,dba,loud,neighbor,report,detector,reader,volume,hearing,monitor,quiet,analyzer,measure,app,mic` |

> 출시 후 App Analytics → Sources → App Store Search 에서 실제로 들어온 검색어를 보고 키워드 칸을 고친다.

---

## App Information

| 항목 | 값 |
|---|---|
| Name (30) | `Glance dB: Decibel Meter` (확정) |
| Subtitle (30) | `Sound Level & Noise Meter` |
| Bundle ID | `com.soulfulfill.decibel` (Apple 등록 완료 2026-10-03) |
| SKU | `decibel` |
| Primary Language | English (U.S.) |
| Primary Category | Utilities |
| Secondary Category | Lifestyle |
| Content Rights | 제3자 콘텐츠 없음 |
| Age Rating | 설문 전부 "None" → **4+** |
| Price | Free |
| Privacy Policy URL | https://soulfulfillable.github.io/test-mvp/decibel-privacy.html |
| Copyright | `2026 Soulfulfill` |

- 아이폰 전용·세로 고정, 첫 출시는 EU 제외(trader 신고 전)

## App Privacy (설문)
- Data Used to Track You: **없음** (ATT 안 띄움)
- Data Linked/Not Linked to You: AdMob — Identifiers(Device ID), Usage Data(Product Interaction, Advertising Data), Diagnostics → 목적 Third-Party Advertising (환율·Catdoku 앱과 동일하게 답)
- 마이크 오디오: **수집 안 함** (기기 안에서 숫자로만 바꾸고 버림)

## 설명 초안

A free decibel meter that tells you how loud it really is — in plain English.

Point your iPhone at the noise and see the level instantly on a big, easy-to-read gauge. Not sure what 72 dB means? Glance dB tells you: "Like a vacuum cleaner."

NO SUBSCRIPTION. NO PAYWALL.
Every feature is free: dBA, dBC and dBZ weighting, average and max, charts, reports and history.

NOISE REPORTS FOR NEIGHBORS & LANDLORDS
• One tap makes a clean report: date, start and end time, average, max and min
• Shows the loudest moment, a chart over time, and how long it stayed at each level
• Add a note like "Upstairs neighbor, Apt 4B"
• Save it to Photos or share it by text or email

EASY TO READ
• Big live number with color: Quiet, Moderate, Loud, Very loud…
• Everyday comparisons from whisper to fireworks
• Last-minute chart, plus AVG, MAX and measuring time
• Hearing safety tips based on the NIOSH 85 dBA guideline

HONEST & PRIVATE
• The microphone is only used to measure. Audio is never recorded or saved.
• Works offline. No account.
• Adjust calibration to match a trusted meter

Phone microphones are not certified sound level meters. Readings are estimates for everyday use, not for legal or medical measurements.

## 홍보 문구 (170)
Free decibel meter with no subscription. See how loud it is, what it sounds like, and save a noise report for your neighbor or landlord.

## 심사 메모 (App Review Notes)
The app uses the microphone only to compute sound level (dB) on-device in real time; no audio is recorded, stored or transmitted. Measuring stops when the app leaves the foreground (no background audio mode). Ads are AdMob banners only. No login required.

## 스크린샷 (6.7형 1290×2796) — 계획
1. 측정 화면, 큰 숫자 + "Like a vacuum cleaner" (가장 매력적인 순간) — 문구 "How loud is it? Know instantly."
2. 리포트 이미지 — "Free noise reports for neighbors & landlords"
3. 비유표 — "From whisper to fireworks"
4. 기록 — "Every measurement saved automatically"
5. 설정(dBA/dBC/dBZ, 보정) — "All features free. No subscription."
→ 화면 숫자는 실제 측정값으로 찍는다 (가짜 데이터 금지). TestFlight 실기기 또는 시뮬레이션 마이크로.
