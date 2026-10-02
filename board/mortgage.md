# 대출 계산기 (mortgage 앱, 가칭 Glance: Mortgage Calculator) — 개발 세션 게시판
마지막 갱신: 2026-10-03 06:10 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`mortgage_app/flutter/`): 주택·자동차·개인 대출, 세금·보험·HOA·PMI, 추가 상환 시뮬, 상환표(연/월), 차트. 테스트 20개 통과(엔진 10 + 로봇 10).
웹 미리보기 https://soulfulfillable.github.io/test-mvp/mortgage-app/index.html — 광고는 배너만(Google 테스트 ID).
이름·번들 ID 사용자 확인 대기 → 번들 등록 → ASC 앱 레코드·AdMob(사용자) → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 이름 A/B: **A `Glance: Mortgage Calculator` (추천 — 미국 검색 1위 "mortgage calculator" 그대로 + Glance 시리즈)** / B `Glance Loan Calculator`. 번들 `com.soulfulfill.mortgage`.
- [사용자] 웹 미리보기 써 보고 '느낌' 한마디.
- [사용자, 이름 정해지면] App Store Connect → 앱 → ＋ 신규 앱: iOS / 이름 / English (U.S.) / 번들 / SKU `mortgage`.
- [사용자, 이름 정해지면] AdMob(**`soulfulfillable` 계정**) → 앱 추가(iOS, 스토어 미등록) → 광고 단위 1개: 배너 `banner`.
- [세션] 번들 등록 Actions → 실제 광고 ID 교체 → `Release iOS`(app=mortgage) → TestFlight → 스크린샷 1290×2796·`ios-metadata.json`.

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "대출·주택담보대출 계산기 앱 개발 시작해줘. plans/mortgage-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/mortgage.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 기획서 순서대로 ①조사 ②테스트 로봇 ③개발 ④광고(배너) ⑤워크플로까지. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터 준다. 결정은 추천안을 고른다 → 2지선다 + 추천 이유 한 줄.
- (이 앱에서는 아직 피드백 전)

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **잘린 글자·칸을 로봇이 자동으로 잡게** (`mortgage_app/flutter/test/robot_test.dart` 의 `expectNoTruncatedText`·`expectNoClippedFields`):
  화면의 모든 `RenderParagraph.didExceedMaxLines`(… 로 잘림) + 모든 `RenderEditable` 의 `getMaxIntrinsicWidth` > 칸 폭(입력 숫자 잘림)을 검사.
  "18.75 %" 가 "18.7" 로, 비싼 집에서 "Principal & intere…" 로 잘리던 걸 잡았고, 고치기 전 코드에서 실패하는 것도 확인. **큰 값($2.5M)·3개 기기로 돌릴 것** — 작은 값·한 기기에선 안 보였다.
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
