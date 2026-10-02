# 대출·주택담보대출 계산기 (Flutter)

기획서 `plans/mortgage-app.md`, 게시판 `board/mortgage.md`. 아이폰 전용·세로, UI 영어, 오프라인, 서버 없음.

- 번들 ID(가안): `com.soulfulfill.mortgage` — **Apple 에 등록하기 전 사용자 확인** (등록하면 못 바꾼다)
- 앱 이름: `lib/core/brand.dart` 의 `appName` (홈 화면 이름은 `ios/Runner/Info.plist` 의 `CFBundleDisplayName`)
- 광고: 배너만 (`lib/core/ads.dart`). 계산하는 동안 전면 광고 없음. 지금은 **Google 테스트 ID**.

## 폴더

```
lib/
  main.dart                     앱 진입 (라이트/다크 시스템 따름)
  core/
    loan.dart                   계산 엔진 — 원리금 균등, 센트 반올림, PMI(78%·기간 절반에 종료), 추가 상환
    store.dart                  입력값(대출 종류별) 저장·기본값 — 금리는 예시값(오늘의 금리 아님)
    format.dart                 $1,234 · Oct 2056 표기
    theme.dart                  색 토큰
    ads.dart                    배너 (테스트·웹에서는 가짜)
    brand.dart                  앱 이름·버전·개인정보처리방침 주소
  screens/
    calculator_screen.dart      한 화면 계산기 (위 고정 카드는 내리면 한 줄로 접힘)
    schedule_screen.dart        상환표 연/월 + 해마다 원금·이자 막대
    about_sheet.dart            계산 방식·면책 문구
  widgets/
    num_field.dart              숫자 칸 (쉼표 자동, 자릿수 제한, 누르면 전체 선택)
    charts.dart                 도넛·누적 막대·잔액 곡선
    common.dart                 알약 선택·카드·칩·키보드 위 Done 막대
test/
  loan_test.dart                엔진 — 알려진 납입액($200k 6% 30년 = $1,199.10 등)과 비교
  robot_test.dart               테스트 로봇 — 모든 버튼·칸, 3개 기기, 키보드, 다크, 잘림 검사, 스크린샷
../tool_icon.py                 앱 아이콘 원본 그리기
```

## 실행

```
flutter test                                   # 엔진 10 + 로봇 (스크린샷 → build/robot_shots/)
flutter build web --release --base-href /test-mvp/mortgage-app/
  → build/web 을 docs/mortgage-app/ 로 복사, canvaskit/ 폴더는 빼고 (엔진은 CDN)
python3 ../tool_icon.py && dart run flutter_launcher_icons   # 아이콘 다시 만들 때
```
