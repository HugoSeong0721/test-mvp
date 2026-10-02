# 연비·정비 기록 앱 — App Store 등록 문구 (초안, 이름은 사용자 결정 대기)

**대상: 미국 App Store. 기본 언어 English (U.S.).** 앱 UI 도 영어. 부제·설명·키워드·URL·심사 메모는 `ios-metadata.json` 을
Actions → **App Store 등록 정보 채우기**(app=fuellog) 로 넣는다. 문구를 고치면 이 파일과 json 을 같이 고친다.

## 시장 조사 요약 (2026-10-03, 검색 스니펫·오픈소스 가져오기 코드 기반 — App Store 페이지는 이 환경에서 직접 못 열었다)

| 앱 | 평점 / 평가 수 | 수익 모델 | 메모 |
|---|---|---|---|
| Fuelly: MPG & Service Tracker (옛 Gas Cubby) | 4.7★ / 약 3만 | 무료 + Premium $0.99/월·$7.99/년 | 업그레이드 팝업, **예전 결제자에게도 광고**, 닫히지 않는 로그인 창, 동기화 중복·삭제 오류, 폰 바꾸면 데이터 날아감 |
| Drivvo | 4.7★ / 968 | $5.99~$49.90/년 등 여러 단계 | 전면 영상 광고 "해마다 더 거슬림", 무료는 차량 수 제한, 구독료 2배 인상, **CSV 내보내기·백업이 유료** |
| Simply Auto | 4.1★ / 867 | Gold $9.99 등 | 결제 인식 오류, 동기화가 "덮어쓰기"만 → 8년치 기록 날아간 사례 |
| Road Trip MPG | 4.9★ / 625 | $6.99 일회 | 칭찬: 광고 없음, 부분·누락 주유 처리, 차트 |
| Fuelio | 4.5★ / 159 | Pro $4.99/월 | |

→ **우리 차별점**: 계정·동기화 없음(덮어쓰기로 날아갈 일 없음) · 전부 무료 · **CSV 내보내기·가져오기 무료**(다른 앱 CSV 도 읽음) ·
부분·누락 주유를 정확히 계산 · 입력 화면엔 광고 없음, 전면 광고 없음 · 차량 수 제한 없음.

## 검색어 (판단, 수치 미확인)

- **"mileage tracker" 는 세금용(IRS) 주행 기록 앱 차지** (MileIQ·Everlance) → 주 검색어로 쓰지 않는다.
- Fuelly 가 1위인 검색어: gas tracker · mpg tracker · fuel tracker · gas mileage · fuel log · fuel economy.
- 추정 순서: gas mileage (tracker) ≥ mpg tracker > car maintenance tracker > gas/fuel tracker > mpg calculator > fuel log > gas log.

## 이름 후보 (사용자 A/B 대기)

| | 이름 (30) | 부제 (30) | 걸리는 검색어 |
|---|---|---|---|
| **A (추천)** | `Glance MPG: Gas Mileage Log` (27) | `Fuel Tracker & Car Maintenance` (30) | mpg · gas mileage · fuel tracker · car maintenance (+tracker 조합). Glance 시리즈 |
| B | `Glance Gas: MPG & Fuel Log` (26) | `Mileage Tracker & Car Service` (29) | gas · mpg · fuel log · mileage tracker(세금 앱과 경쟁) |
| C | `Glance Garage: Car Maintenance` (30) | `MPG Tracker & Gas Mileage Log` (29) | 정비 쪽에 무게 — 연비 검색은 약해짐 |

"Glance MPG"·"Glance Gas"·"Glance Garage" 는 검색에 안 나옴 (ASC 에서 이름을 잡아야 확정).

### 키워드 칸 (100자 이내, A 기준 — 이름·부제에 있는 단어는 뺐다, 경쟁 앱 이름 금지 2.3.7)

```
calculator,economy,oil,change,reminder,service,expense,cost,vehicle,auto,truck,odometer,fillup,tire
```
(99자)

## 설명 (A 기준 초안)

`ios-metadata.json` 의 description 과 같다.

## 스크린샷 계획 (1290×2796, 6.7형)

1. 기록 탭 — 큰 MPG 평균 + 이번 달 비용 + 곧 할 정비 ("Your real MPG, every fill-up")
2. 주유 입력 — "This tank: 30.0 MPG" 미리보기 ("Log a fill-up in 10 seconds")
3. 차트 — 연비 추이·월별 비용 ("See where your money goes")
4. 정비 알림 — 진행 막대 ("Never miss an oil change")
5. More — CSV 내보내기/가져오기 ("Your data is yours — free CSV export")
