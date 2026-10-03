# 대출·주택담보대출 계산기 — 기획서 (기획 파트너, 2026-10-02)

## 왜
- "mortgage calculator" 전 세계 월 약 335만 검색, "mortgage payment calculator" 월 약 24.6만 (`plans/utility-research.md`).
- 1등 Loan Calculator™ 4.9★ 약 10.4만 평가인데 **2022-02 이후 업데이트 없음** → 낡은 디자인을 최신 iOS 감성으로.
- 순수 계산이라 서버·콘텐츠 없음, 오프라인 → 손 안 가는 앱. 금융 분야라 광고 단가가 높을 가능성(미확인).

## 핵심 화면 (한 화면에서 끝나게)
- 입력: 집값, 계약금(% 또는 $), 금리, 기간(15/20/30년), 시작 월. 선택: 재산세·보험·HOA·PMI.
- 결과: **월 납입액 크게**(원금+이자 / 세금·보험 내역), 총이자, 상환 끝나는 날짜.
- 상환표(연·월 단위) + 원금/이자 차트.
- **추가 상환 시뮬레이션**: "매달 $200 더 내면 몇 년 빨리, 이자 얼마 절약" — 1등 앱 대비 차별점.
- 자동차·개인 대출 모드(같은 계산, 다른 기본값).
- 입력값은 기기에 저장, 여러 시나리오 비교(2~3개 나란히)는 2차.

## 원칙
- 화면 숫자는 진짜 계산 결과만. 금리를 "오늘의 금리"처럼 보여 주지 않는다(실시간 데이터 아님 → 오해 소지·심사 위험).
  "Estimates only, not financial advice" 한 줄 표기.
- 광고: 배너만. 계산하는 동안 전면 광고 금지. 보상형은 "상환표 PDF/이미지 내보내기" 같은 부가 기능에만 검토.
- 미국 단위·표기($, 월 납입 관례), 영어 UI, 아이폰 전용·세로.

## 결정 (2026-10-03 사용자 확인)
- 앱 이름: **Glance: Mortgage Calculator** (부제 Home Loan & Payment Calculator) — Glance 시리즈.
- 번들 ID `com.soulfulfill.mortgage` — Apple 등록 완료.

## 진행 순서
①경쟁 앱 화면·리뷰 불만 확인 → ②테스트 로봇 → ③Flutter 개발 → ④광고 → ⑤`Release iOS`(앱 선택형)에 추가 → ⑥TestFlight → ⑦스토어

## 진행 기록 (개발 세션이 추가, 최신이 위)

### 2026-10-03 개발 세션 1
- ①경쟁 앱 조사 → `mortgage_app/store/ios-listing.md`. 1등 Loan Calculator(4.9★ 10.4만, 2022-02 방치) 리뷰 불만 1위가 **팝업·영상 광고 강요**,
  다음이 숫자 입력 이상함·PMI 자동 계산 없음·저장 안 됨 → 배너만·쉼표 자동 칸·PMI 자동·값 자동 저장으로 대응.
- 기본값(예시값, "오늘의 금리" 아님): 집 $400k·20%·7%·30년·재산세 0.9%(ATTOM 2025 미국 평균)·보험 $2,400/년·PMI 0.6%,
  자동차 $40k·$5k·7%·72개월(Experian 평균 69.5개월), 개인 $10k·12%·36개월.
- `mortgage_app/flutter/`: 엔진(`lib/core/loan.dart` 원리금 균등·센트 반올림·PMI 78% 또는 기간 절반에 종료·추가 상환 비교),
  한 화면 계산기(위 월 납입액 고정, 내리면 한 줄로 접힘·키보드 위 Done/이전/다음), 세금·보험·HOA·PMI 접는 카드,
  추가 상환(+$50/100/200/500 칩·직접 입력 → "Debt-free N yr sooner, Save $X"·잔액 곡선), 상환표(연/월·해마다 원금/이자 막대),
  Auto(보상 판매·판매세 = (가격−보상)×%)·Personal 모드, 종류별 값 저장, 라이트/다크.
- 광고: 배너만(Google 테스트 ID). 키보드가 뜨면 배너 숨김. 보상형(상환표 내보내기)은 1차에 안 넣음.
- 테스트 20개 통과: 엔진 10(알려진 납입액 $200k 6% 30년 = $1,199.10 등, 따로 짠 파이썬 계산과 센트까지 일치) +
  로봇 10(모든 버튼·칸, 3개 기기, 키보드, 다크, 접힘, $2.5M 집, 빈 값·0·최대값, 잘린 글자·칸 자동 검사, VoiceOver 칸 수).
  스크린샷 → `build/robot_shots/` (30여 장).
- 웹 미리보기 `docs/mortgage-app/` — 헤드리스 크롬(아이폰 13 크기·터치)으로 모드 전환·입력·칩·상환표·뒤로 확인, 콘솔 에러 0.
- iOS: 아이폰 전용·세로, Info.plist 에 AdMob(테스트)·암호화 없음·SKAdNetwork, 아이콘(`../tool_icon.py` 로 직접 그림).
- Actions: `Release iOS`·`App Store 등록 정보 채우기` 선택지에 mortgage 추가, 번들 ID 를 `com.soulfulfill.<앱>` 규칙으로 일반화.
- 개인정보처리방침 `docs/mortgage-privacy.html`.
- 이름 **Glance: Mortgage Calculator** · 번들 `com.soulfulfill.mortgage` (사용자 확인, Apple 등록 완료). `mortgage_app/store/ios-metadata.json` 작성.
- ASC 앱 레코드(사용자), AdMob iOS 앱 `~9582805496`·배너 `/4605810985` 반영, `Release iOS` 빌드 18 업로드 성공.
- 사용자 실기기 확인(빌드 18) "괜찮은 것 같다" → 출시 진행. 스크린샷 만들다 종류 전환 스크롤 버그 발견·수정(테스트 추가) → 빌드 22.
- 스토어 스크린샷 5장(`mortgage_app/store/screenshots/`, `test/store_shots_test.dart` + `make.js`), `App Store 등록 정보 채우기`(빌드 22) 전부 ✓.
- 남은 것: 사용자가 ASC 에서 저작권·카테고리·App Privacy·연령 등급·가격/판매국·심사 제출.
