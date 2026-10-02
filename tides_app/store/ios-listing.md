# Glance Tides: Tide Chart — App Store 등록 문구 (초안)

**대상: 미국 App Store. 기본 언어 English (U.S.).** 앱 UI 도 영어.
**이름 `Glance Tides: Tide Chart`·번들 `com.soulfulfill.tides` 확정 (사용자, 2026-10-03). 번들 ID Apple 등록 완료 (Actions "새로 등록함").**
결제 없음(광고 제거 IAP 없음), 광고 = 배너 + 보상형 1자리(30일 표 24시간 열기). 전면 광고 없음.

## 검색어 조사 (2026-10-03)
| 검색어 | 근거 | 넣은 칸 |
|---|---|---|
| **tides near me** | 미국 월 약 1.5만 (Ahrefs, tidesnear.me 1위) | 부제 |
| tide chart | 미국에서 쓰는 일반 표현, 경쟁 앱 "Tide Charts"(11.2만 평가) | 이름 |
| tide times | 경쟁 앱 다수 이름 | 부제 |
| high tide near me 2.4천 / tide near me 1.3천 | Ahrefs | 키워드 |
| noaa, fishing, beach, surf, moon, sunrise | 경쟁 앱 설명·리뷰 | 키워드 |

이름 중복: "Glance Tides" 검색 결과 없음(검색엔진으로만 확인 — apps.apple.com 직접 접속은 막혀 있음).
"Tides Near Me" 는 1등 앱의 정확한 이름이라 **이름에는 넣지 않고 부제에만** (혼동·심사 위험 회피).

### 경쟁 앱 불만 → 우리 답
| 경쟁 앱 | 불만 | 우리 |
|---|---|---|
| Tides Near Me (4.8★ 약 16.2만) | 물때 한 번 보려는데 30초 전면 광고, 30일 표·광고 제거가 유료 | 전면 광고 없음. 7일 무료, 30일은 짧은 영상 1편 → 24시간 |
| Tide Charts (4.8★ 약 11.2만) | 구독 유도 | 구독 없음 |
| 공통 | 바다 근처에서 신호 약하면 빈 화면 | 받은 예보를 기기에 저장, "Offline — saved …" 표시 |

## App Information
| 항목 | 값 |
|---|---|
| Name (30) | `Glance Tides: Tide Chart` (24) |
| Subtitle (30) | `Tides Near Me & Tide Times` (26) |
| Bundle ID | `com.soulfulfill.tides` |
| SKU | `tides` |
| Primary Language | English (U.S.) |
| Primary Category | Weather |
| Secondary Category | Sports (낚시·서핑) — 또는 Travel |
| Age Rating | 설문 전부 "None" → 4+ |
| Price | Free |
| Privacy Policy URL | https://soulfulfillable.github.io/test-mvp/tides-privacy.html |
| Support URL | https://github.com/soulfulfillable/test-mvp/issues |
| Copyright | `2026 Soulfulfill` |
| 홈 화면 이름 | `Glance Tides` |

- 아이폰 전용·세로 고정, 첫 출시는 EU 제외(trader 신고 전). 미국 해안 + 미국 영토(하와이·알래스카·푸에르토리코·괌 등) 관측소.

## 키워드 (100자) — tide·tides·chart·times·near·me 는 이름·부제에 있어 뺐다
`high,low,noaa,fishing,beach,surf,moon,sunrise,ocean,boating,kayak,clam,table,forecast,coast`

## App Privacy (설문)
- Data Used to Track You: **없음** (ATT 안 띄움)
- AdMob: Identifiers(Device ID), Usage Data(Product Interaction, Advertising Data), Diagnostics → Third-Party Advertising, Not linked to you (다른 앱과 동일)
- **Location: 수집 안 함** — 기기 안에서 가장 가까운 관측소를 고르는 데만 쓰고 보내지 않는다 (NOAA 요청에는 관측소 ID 만).

## 홍보 문구 (170)
Tide times and tide charts for 3,499 NOAA stations. No full-screen ads — see the tide the moment you open the app, even with no signal at the beach.

## 설명 초안
Open the app, see the tide. No 30-second ads.

Glance Tides finds the NOAA tide station nearest you and shows exactly what the water is doing right now — rising or falling, how high it is, and when the next high and low tide come.

TODAY AT A GLANCE
• Big Rising / Falling indicator with the height right now
• Next high and low tide with countdown
• Smooth 24-hour tide chart — drag across it to read any time
• Sunrise and sunset shading, moon phase

7 DAYS FREE, 30 DAYS WHEN YOU NEED IT
• Highs and lows for the whole week, always free
• Planning a fishing trip? Watch one short video to open the 30-day tide table for 24 hours

OFFICIAL NOAA PREDICTIONS
• 3,499 NOAA CO-OPS stations: every US coast, Alaska, Hawaii, Puerto Rico, Guam and more
• Heights in feet or meters above MLLW, times in the station's local time
• Search by beach, city, state or station ID, or save favorites

WORKS AT THE BEACH
• Predictions are saved on your phone, so they still show with weak or no signal
• Your location is used only on your phone to find the nearest station — never sent anywhere

No account. No subscription. One small banner ad.

Tide predictions are astronomical and do not include wind, storms or river flow. Not for navigation.

## 심사 메모 (App Review Notes)
Tide predictions come from NOAA CO-OPS public API (api.tidesandcurrents.noaa.gov, no key). Location ("When In Use") is used once on-device to pick the nearest station; it is not stored or sent — you can also search stations without location. Ads: AdMob banner, and one optional rewarded video that opens a 30-day tide table for 24 hours (7-day tides are always free). No login required.

## 스크린샷 (6.7형 1290×2796) — 계획 (화면 숫자는 NOAA 실제 값으로)
1. 물때 화면: Rising + 곡선 + 다음 만조 — "Open the app. See the tide."
2. 곡선 끌어서 시각 읽기 — "Read any time on the tide chart"
3. 7일 표 + 달 — "7 days free. Highs, lows, sun & moon"
4. 관측소 검색·근처 — "3,499 NOAA stations near you"
5. 30일 표 — "30 days for your next trip"
6. Offline 저장 — "Works at the beach, even with no signal"
