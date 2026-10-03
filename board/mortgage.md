# Glance: Mortgage Calculator (대출 계산기, mortgage 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 06:20 (KST)

## 지금 상태 (3줄 이내)
1.0(빌드 22) 등록 정보 입력 완료 → 사용자 심사 제출 단계. **1.1 개발 완료**: 주(50+DC) 선택 → 재산세·판매세 자동(Tax Foundation 2026), 추가 상환 시작 달·한 번 갚기·격주 납부.
테스트 32개 통과(엔진 15 + 로봇·1.1 로봇). **1.1 빌드 25(카운티 포함) TestFlight 업로드 성공** — 1.0 승인 뒤 새 버전으로 제출.
웹 미리보기(1.1) https://soulfulfillable.github.io/test-mvp/mortgage-app/index.html

## 다음 할 일 / 사용자에게 받을 것
- ✅ [사용자] 이름 A `Glance: Mortgage Calculator`, 번들 `com.soulfulfill.mortgage` → ✅ [세션] 번들 Apple 등록.
- ✅ [사용자] ASC 앱 레코드 → ✅ [세션] `Release iOS` 빌드 18 업로드 (첫 시도는 Dart SDK 제약 때문에 pub get 실패 → 수정).
- [사용자] TestFlight → 내부 테스팅 그룹에 빌드 18 추가·초대 → 폰 TestFlight 앱에서 설치 → '느낌' 피드백.
- ✅ [사용자] AdMob 앱(Glance Mortgage, `~9582805496`)·배너 `…/4605810985` → ✅ [세션] 코드 반영.
- [사용자] 웹 미리보기 써 보고 '느낌' 한마디.
- [세션] ASC 레코드 생기면 → `Release iOS`(app=mortgage) → TestFlight → 스크린샷 1290×2796 → `App Store 등록 정보 채우기`(`mortgage_app/store/ios-metadata.json` 준비됨).

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "근데 state 에서도 county 마다 텍스가 다른데 그건 왜 없어 넣는게" | 처음엔 데이터 양·검증 때문에 보류했으나 공식 출처(인구조사국 ACS 표 단위 요약 파일, 키 불필요)를 Actions 로 받아 3,135곳 반영. 주 고른 뒤 County 검색 선택, 재산세 \$10,000+ 상한에 걸린 17곳은 '더 높을 수 있음' 표시 |
| 10-03 | "엑스트라 페이에서 기간 넣으면 너무 복잡해지려나. 언제부터 언제까지 얼마더 … 비판적으로. 경쟁사 참고해서" → "저거는 넣지말자 세분화하는거" + 시작 달·한 번 크게 갚기·격주 납부 선택 | 구간 여러 개는 안 넣음(폰 입력·결과 흐림·경쟁 앱 근거). 1.1 에 3가지 추가 |
| 10-03 | "근데 state, county 별로 텍스가 다르잖아 그거도 선택할수 잇게 해야하지 않겠나?" → 주 50+DC (추천) / 1.0 먼저 제출, 주 선택은 1.1 (추천) | 1.1 작업 시작: 공식 통계로 주별 재산세율·판매세율 표, 주 고르면 자동 입력(직접 수정 가능). 카운티는 보류 |
| 10-03 | "괜찮은거같은데 … 쓰는사람은뭐 괜찮지않을까" → "응 아직괜찮아 앱으로낼수잇니" | 출시 진행. 스토어 스크린샷 5장(1290×2796, 로봇이 찍은 화면 + 제목) 만들다 **버그 발견·수정**: 아래로 내린 뒤 대출 종류를 바꾸면 맨 위로 안 가고 380px 아래에서 멈춤(같은 키 카드를 옛 위치째 재사용) → 종류마다 새 목록, 로봇 테스트 추가(고치기 전 실패 확인). 새 빌드 업로드 → 등록 정보 API 입력 |
| 10-03 | TestFlight 빌드 18 실기기 스크린샷(다크) + "저기 맨밑에 광고배너자리가 잇는건가" | 맞음 — 배너 자리(높이 60 + 홈 막대 여백)를 미리 비워 둠(광고가 늦게 와도 화면이 안 출렁이게). 새 광고 단위·스토어 미출시라 아직 광고 없음. **자기 광고 누르지 말 것**(AdMob 정책) 안내. 실기기에서 앱 실행·입력·다크 모드 정상 확인됨 |
| 10-03 | "했어" (ASC 앱 레코드 생성) | `Release iOS`(mortgage) 실행 → 1차 pub get 실패(sdk ^3.13.5) → ^3.13.2 로 고쳐 빌드 18 업로드 성공 |
| 10-03 | 광고 단위 완료 화면 캡처 + "앱 이름 고치기 했어" | iOS 앱 ID `ca-app-pub-4724352880074547~9582805496`(Info.plist), 배너 `…/4605810985`(ads.dart) 반영. 안드로이드는 테스트 ID 유지. AdMob 앱 이름 Glance Mortgage 로 수정됨 |
| 10-03 | AdMob 화면 캡처 2장 + "머지 완료 했더니 이화면나왓는데 맞는건가" | 앱이 이름 `banner` 로 만들어짐(광고 단위 이름을 앱 이름 칸에 넣음) → App settings 에서 이름 고치게 안내. 광고 형식 화면은 맞음 → **Banner** 카드 Select, 이름 `banner`. "Requires review" 는 스토어 연결 전 정상 |
| 10-03 | 이름 A/B → "Glance: Mortgage Calculator (추천)", 번들 → "등록 (추천)" | 앱 안 이름·개인정보처리방침·웹 제목·스토어 문구 반영, `ios-metadata.json` 작성, Actions 로 번들 등록 완료 |
| 10-03 | "대출·주택담보대출 계산기 앱 개발 시작해줘. plans/mortgage-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/mortgage.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 기획서 순서대로 ①조사 ②테스트 로봇 ③개발 ④광고(배너) ⑤워크플로까지. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터 준다. 결정은 추천안을 고른다 → 2지선다 + 추천 이유 한 줄.
- 이 앱에서도 2지선다 + 추천을 바로 골랐다 (이름·번들 둘 다 추천안).

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **잘린 글자·칸을 로봇이 자동으로 잡게** (`mortgage_app/flutter/test/robot_test.dart` 의 `expectNoTruncatedText`·`expectNoClippedFields`):
  화면의 모든 `RenderParagraph.didExceedMaxLines`(… 로 잘림) + 모든 `RenderEditable` 의 `getMaxIntrinsicWidth` > 칸 폭(입력 숫자 잘림)을 검사.
  "18.75 %" 가 "18.7" 로, 비싼 집에서 "Principal & intere…" 로 잘리던 걸 잡았고, 고치기 전 코드에서 실패하는 것도 확인. **큰 값($2.5M)·3개 기기로 돌릴 것** — 작은 값·한 기기에선 안 보였다.
- **ListView 자식을 조건부로 바꿀 때 같은 Key 를 가진 카드가 남아 있으면** 옛 위치째 재사용돼 `jumpTo(0)` 이 중간(380px)에서 멈춘다 → 바뀌는 목록 자체에 `ValueKey(모드)`.
- **미국 인구조사국 API 는 이제 키가 필요**(키 없이 부르면 HTML 'Missing Key'). 키 없이: `www2.census.gov/programs-surveys/acs/summary_file/<연도>/table-based-SF/data/5YRData/acsdt5y<연도>-<표>.dat` (| 구분, GEO_ID `0500000US…` = 카운티) + `documentation/Geos<연도>5YR.txt`(이름). 이 환경에선 census 가 막혀 Actions(`fetch-census.yml`)로 받아 데이터 브랜치에.
- **테스트에서 `WidgetController.hitTestWarningShouldBeFatal = true`** — 화면 밖 칸을 '눌렀다'고 통과하던 걸 잡는다(시트 맨 아래 줄).
- **주별 세율 같은 공공 데이터**: 이 환경은 taxfoundation.org·census.gov 직접 열기가 막혀 있다. 조사 에이전트가 사이트 한정 검색 요약 + 같은 표를 재배포한 npm 패키지(`us-property-tax-data`)로 교차 확인했다. 원본 표는 `mortgage_app/store/state_rates.json` 에 출처와 같이 둔다.
- **VoiceOver 칸 중복**: `Semantics(textField: true)` 로 `TextField` 를 감싸면 입력 칸이 두 개로 읽힌다 → `MergeSemantics` + 앞뒤 글자 `ExcludeSemantics`.
  로봇: `find.semantics.byPredicate((n) => n.flagsCollection.isTextField)` 개수 == `EditableText` 개수.
- **숫자 키패드엔 완료 키가 없다** → 키보드 위 Done 막대(이전/다음 칸 포함). `FocusScope.nextFocus()` 는 다음 마이크로태스크에 반영돼서
  버튼을 건너뛰며 칸을 찾으려면 매번 `FocusManager.instance.applyFocusChangesIfNeeded()`.
- **위젯 테스트에서 진짜 글꼴 스크린샷**: SDK 의 `bin/cache/artifacts/material_fonts/Roboto-*.ttf` 를 `FontLoader('Roboto')` 로 넣고,
  `renderViews.first.debugLayer.toImage(Offset.zero & t.view.physicalSize, pixelRatio: 1)` (논리 크기로 찍으면 3배 확대된 일부만 나온다).
  `CustomPainter` 의 `TextPainter` 는 글꼴을 안 주면 테스트에서 네모로 그려진다 → `Theme.of(context).textTheme.bodySmall` 을 이어받게.
- **Playwright + 이 환경 프록시**: `proxy` 옵션의 bypass 가 localhost 에 안 먹는다(로컬 서버 요청이 프록시로 가서 405).
  `args: ['--proxy-server=https=' + 프록시주소]` 로 https 만 프록시 → `http://127.0.0.1` 은 직접. gstatic 은 막혀 있어 `page.route` 로 로컬 canvaskit (Catdoku 하네스와 같은 방식).
- **Flutter 웹 접근성 트리에는 화면 밖 항목도 들어 있다** → 자동 점검에서 bbox 로 누르기 전에 화면 안으로 쓸어 올려야 한다(안 그러면 허공을 누름).
- 큰 고정 카드는 **내리면 한 줄로 접히게**(스크롤 48px 넘으면 접고 8px 아래면 폄 — 기준을 달리 둬서 출렁임 방지). iPhone SE 에서 입력 칸이 2.5개 → 5개 보임.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 보상형 광고 자리 — 기획서는 "상환표 PDF/이미지 내보내기에만 검토". 1차는 배너만으로 내고, 내보내기(+보상형)는 다운로드·리뷰 보고 2차에 넣을지?
- 기획 파트너: 리서치상 개인 계정 금융 앱 규정(5.1.1(ix))은 "금융 서비스 제공" 앱 대상이라 순수 계산기는 해당 없음(Loan2Me 등 개인 이름 출시 사례). 대출 신청·리드 폼은 절대 넣지 않는 걸로.
- 소음 세션: 막대 높이 0 버그를 나도 똑같이 밟았다(게시판 읽기 전에 짠 코드) — 개발 중간에도 `board/` 를 다시 읽는 게 좋겠다.
