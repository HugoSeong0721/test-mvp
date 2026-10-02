# 연비·정비 기록 (fuel-log 앱, `fuellog_app/`) — 개발 세션 게시판
마지막 갱신: 2026-10-03 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`fuellog_app/flutter/`): 주유 한 화면(둘 넣으면 셋째 자동·이번 탱크 연비 미리보기)·부분/누락 주유 연비·정비 알림(거리/개월, 로컬 알림)·차트·여러 대·단위·로드트립·CSV 내보내기/가져오기.
**테스트 47개 통과**(엔진 29 + 로봇 18), 웹 점검 7/7·콘솔 에러 0. 웹 미리보기 https://soulfulfillable.github.io/test-mvp/fuel-log-app/index.html (`?demo=1` 예시 기록).
이름·번들 ID 사용자 확인 대기(임시 `Glance MPG`, `com.soulfulfill.fuellog` — Apple 미등록) → 번들 등록 → ASC·AdMob(사용자) → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 이름 A/B/C (추천 A `Glance MPG: Gas Mileage Log`), 번들 `com.soulfulfill.fuellog`(추천) — `fuellog_app/store/ios-listing.md`.
- [사용자] 웹 미리보기 '느낌' 한마디 (주유 두 번 넣어 보면 MPG 가 나온다).
- [세션, 이름 정해지면] 번들 등록 Actions → `Release iOS`·`App Store 등록 정보 채우기` 선택지에 `fuellog` 추가 → ASC 앱 레코드·AdMob 안내(클릭 단위) → TestFlight.
- 검수 증거 페이지: https://soulfulfillable.github.io/test-mvp/fuel-log-qa.html

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "연비·정비 기록 앱 개발 시작해줘. plans/fuel-log-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/fuel-log.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 기획서 순서 ①조사 ②테스트 로봇 ③Flutter 까지 1차 완료, 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (다른 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터. 결정은 2지선다 + 추천 이유 한 줄. 이름은 Glance 시리즈로 통일되는 중.
- 이 앱에서 새로 알게 된 것은 아직 없음 (첫 피드백 대기).

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **`const` 화면은 저장소가 바뀌어도 다시 안 그려진다.** 맨 위에서 `ListenableBuilder` 로 감싸도 `const HomeShell()`·`const _Summary()` 는 건너뛴다
  → 저장소를 읽는 화면마다 `build` 를 `ListenableBuilder(listenable: store, builder: …)` 로, 또는 바뀌는 데이터를 인자로. 로봇이 "저장 → 숫자 바뀜" 을 검사해서 잡았다.
- **VoiceOver 로 못 누르는 버튼 자동 검사** (`expectButtonsTappable`, `fuellog_app/flutter/test/robot_test.dart`): `Semantics(button: true, excludeSemantics: true)` 는
  아래 GestureDetector 의 누르기를 지운다 → `Semantics` 에 `onTap` 을 직접. 앱 바 제목 안이면 `container: true` (아니면 머리글에 합쳐짐). 웹 점검 `getByRole('button')` 실패로 처음 발견.
- **테마의 글자 스타일은 `base.textTheme.xxx!.copyWith(...)` 로.** `appBarTheme.titleTextStyle: TextStyle(...)` 처럼 새로 만들면 테마 글꼴을 안 이어받아
  테스트 스크린샷에서 네모(Ahem) → 잘림 검사 오탐. 기기에선 시스템 글꼴이라 눈치 못 챈다.
- **"예상 날짜" 로 알림을 걸 땐 과거가 되는 경우를 막아라.** 기록이 뜸하면 예상일이 지난 날이 돼서 알림이 예약조차 안 됐다(스크린샷의 "about Sep 29" 로 발견).
- **테스트 사이에 남는 Future**: 저장을 `_saving = _saving.then(write)` 로 줄 세웠더니, 앞 테스트(가짜 시계)에서 만든 Future 가 안 끝나 다음 테스트의 `runAsync(flush)` 가
  영원히 기다림 — 혼자 돌리면 통과, 전체로 돌리면 멈춤. 앱을 켤 때(load) 줄을 새로 시작. 그리고 `flutter test … | grep > 파일` 은 4KB 씩 버퍼링돼 **멈춘 위치가 틀리게 보인다**
  → `-r expanded > 파일` 로 그대로 받기.
- `pkill -f flutter_tester` 는 그 글자가 든 **내 bash 명령까지 죽인다** → `pkill -9 -x flutter_tester`.
- **ListTile 을 색 칠한 Container 안에 두면 assert**(배경·물결 안 보임) → `Material(color:, borderRadius:, clipBehavior:)`.
- **큰 글씨 대응**: 입력 칸 폭을 `MediaQuery.textScalerOf(context).scale(1)` 에 비례(화면 62% 까지), 요약 숫자 칸은 `FittedBox(scaleDown)`, 목록 줄은 자르지 말고 2줄.
- **다른 앱 CSV 형식은 오픈소스 가져오기 코드에서**: Fuelly 웹 형식 `fuelup_date,odometer|miles,gallons|litres,price,partial_fuelup(1/0),missed_fuelup(1/0),notes`,
  Fuelly 앱 형식 `Type(Gas/Service),MPG,Date,Time,Vehicle,Odometer,Filled Up(Full/Partial),Price($),Gallons,Total Cost,…,Notes,Services`. 머리글 이름 별칭으로 맞춘다 (`lib/core/csv.dart`).
- `share_plus` 는 안에서 `path_provider` → `path_provider_foundation` 2.6(FFI, `objective_c` 네이티브 에셋)을 끌고 온다 — 소음·속도계도 같음.
  **처음 `Release iOS` 를 돌리는 세션이 이 부분 빌드 성공/실패를 여기 남겨 주자.**
- 웹 미리보기 `?demo=1` 예시 기록은 **저장 칸을 따로**(`PrefsPersist('fuellog.demo')`) — 예시를 본 뒤 진짜 링크를 열어도 예시가 안 섞인다.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 기획서대로 **배너만**(입력 화면엔 광고 없음, 전면 광고 없음). 보상형 자리는 일부러 안 만들었다 — 경쟁 앱이 유료로 막은 CSV·차량 수·차트를 무료로 푸는 게 차별점이라.
  1차는 이대로 내고 다운로드·리뷰 보고 정해도 될지?
- 기획 파트너: iCloud 동기화는 안 넣음(계정·서버 없음 원칙 + 경쟁 앱의 "동기화로 기록 날아감" 불만). 대신 "폰 바꾸기 전 CSV" 안내를 More 탭·스토어 설명에 정직하게 적음.
