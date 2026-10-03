# 낚시·사냥 시간 (솔루나) — App Store 등록 문구 초안

**대상: 미국 App Store. 기본 언어 English (U.S.).** 이름은 사용자 확인 전 — 확정되면 이 파일과 `ios-metadata.json` 을 같이 만든다.

## 경쟁 앱 조사 (2026-10-03, 웹 검색 요약 — App Store 직접 접속은 작업 환경에서 막힘, 평점·가격은 등록 때 다시 확인)

| 앱 | 평점 | 돈 |
|---|---|---|
| Fishing & Hunting Solunar Time (id1056000899) | 4.7★ / 약 1.6만 | 무료+광고, Pro 구독 (무료는 2~3일 앞까지만) |
| Solunar Best Fishing Time (id886074803) | 4.6★ / 약 1.1천 | $3.99/월, $24.99/년 |
| Solunar Best Hunting Times (id883164832) | 4.7★ / 약 5.8천 | $2.99/월, $19.99/년 |
| Hunt & Fish Times by iSolunar (id853063648) | 4.6★ / 666 | 3일 체험 후 구독 |
| Fishing Times Calendar (id419841407) | 4.7★ / 3.7천 | 무료+광고, Pro $3.99 |
| Fishing Points (id1203032512) | 4.7★ / 약 3.1만 | 구독 (솔루나는 일부 기능) |

리뷰 불만 3가지: ①구독·재결제("pay more", 플랫폼마다 다시 구매, 무료는 며칠 앞까지만) ②"내 지역에 안 맞는다"·GPS 위치 오류
③새 UI 가 "bloated, hard to read mess", 글씨가 작다, 몇 달 뒤 날짜로 가려면 수백 번 탭.

**우리 차별점 = 그 반대**: 구독 없음·전부 무료(7일 + 오늘 상세), 30일 달력은 영상 하나로 24시간, 큰 글씨 한 화면, 점수 계산식 공개("How is this scored?"),
GPS 대신 마을 검색(2만 곳, 오프라인)과 저장한 곳.

## 이름 후보 (사용자 A/B)
검색어: "solunar" 가 상위 앱 제목 9개, "fishing times"/"best fishing times" 7개, "hunting times" 5개 (Semrush: fishing forecast 약 2.8만/월, fishing times 약 1.3만/월 — 구글 검색 기준).

| | 이름 (30자) | 부제 (30자) |
|---|---|---|
| A (추천) | `Glance Solunar: Fishing Times` (29) | `Hunting Times & Moon Phases` (27) |
| B | `Glance Moon: Fishing & Hunting` (30) | `Solunar Times & Shooting Light` (30) |
| C | `Solunar Day: Fish & Hunt Times` (30) | `Fishing Forecast & Moon Phase` (29) |

피할 이름(이미 있음): "Solunar Time: Hunt & Fish", "Solunar: Best Fishing Times", "BiteTime: Best Fishing Times", "Solunar".

키워드 필드 후보: `forecast,calendar,tables,deer,bass,duck,bite,shooting,light,sunrise,sunset,moonrise,major,minor,tide`
(이름·부제 단어와 겹치지 않게. 출시 후 App Analytics 의 실제 검색어로 고친다.)

## 정직하게 쓸 것
- 점수는 "해·달 주기 계산 결과", 물고기·사냥감을 약속하지 않는다 ("A guide, not a promise").
- 사냥 허용 시간은 주·종·시즌마다 다르다 → 사용자가 직접 정하는 오프셋, "check your state's regulations".
- 설명 초안(영문):
  > Free solunar fishing & hunting times — no subscription. See today's score, Major and Minor feeding periods, sunrise, sunset,
  > moonrise, moonset and moon phase, plus a big legal shooting light countdown. Works offline: everything is worked out on your
  > phone from the sun and moon. Search 20,000 US & Canadian towns or use your location, and save your lake, lease or deer stand.
