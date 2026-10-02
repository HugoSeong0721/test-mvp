# 소음 측정기 (decibel 앱, 가칭 Glance dB) — 개발 세션 게시판
마지막 갱신: 2026-10-03 07:00 (KST)

## 지금 상태 (3줄 이내)
Flutter 1차 완성(`decibel_app/flutter/`): 측정·비유표·리포트(이미지 공유)·기록·설정. 테스트 27개 통과(엔진 14 + 로봇 13).
웹 미리보기 `docs/decibel-app/` — 폰 브라우저에서 **진짜 마이크로** 측정된다. 광고는 배너만(Google 테스트 ID).
이름·번들 ID 사용자 확인 대기 → 번들 등록 → ASC 앱 레코드·AdMob(사용자) → TestFlight.

## 다음 할 일 / 사용자에게 받을 것
- [사용자] 이름 A/B: **A `Glance dB: Decibel Meter` (추천, Glance FX 시리즈 형식)** / B `Decibel Meter: Glance dB`. 번들 `com.soulfulfill.decibel`.
- [사용자, 이름 정해지면] App Store Connect → 앱 → ＋ 신규 앱: iOS / 이름 / English (U.S.) / 번들 / SKU `decibel`.
- [사용자, 이름 정해지면] AdMob → 앱 추가(iOS, 스토어 미등록) → 광고 단위 1개: 배너 `banner`. 앱 ID(`~`) + 단위 ID(`/`) 받으면 `lib/core/ads.dart`·Info.plist 교체.
- [세션] 번들 등록 Actions → `Release iOS`·`App Store 등록 정보 채우기` 선택지에 decibel 추가 → TestFlight.
- [세션, TestFlight 때] **기본 보정 +94 dB 확인** — 같은 아이폰에서 NIOSH SLM(무료)과 나란히 재서 맞춘다. 지금은 공개 자료 추정치(확인 못 함).

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "소음 측정기(데시벨) 앱 개발 시작해줘. plans/decibel-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/decibel.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터 준다.
- (이 앱에서는 아직 피드백 전)

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **플랫폼 플러그인 호출을 `await` 하지 마라 (부가 기능일 때).** wakelock_plus 를 기다렸더니 위젯 테스트에서 응답이 안 와
  자동 저장이 통째로 멈췄다. `.catchError((_) {})` 로 흘려보내고 저장·상태 변경을 먼저.
- **입력칸은 화면 위쪽에.** 긴 ListView 아래 TextField 는 키보드가 뜨면 목록에서 빠져 포커스가 날아간다. 로봇 테스트에서
  `t.view.viewInsets = FakeViewPadding(bottom: 336*3)` 로 키보드를 흉내 내면 잡힌다.
- **테스트 통과 ≠ 화면 정상.** 리포트 막대가 높이 0 으로 안 보였는데 테스트는 통과. 웹 빌드 스크린샷을 화면마다 직접 봐서 잡았고,
  그다음 높이 검사 테스트를 넣어 고치기 전 코드에서 실패하는 것까지 확인했다. (`Row` 안 `Expanded(ColoredBox)` 는 `crossAxisAlignment: stretch` 필요)
- **마이크·카메라 앱 헤드리스 점검**: 크롬 `--use-fake-device-for-media-stream --use-fake-ui-for-media-stream` + `ctx.grantPermissions(['microphone'])`
  → 진짜 getUserMedia 경로. 거부 상황은 `--deny-permission-prompts`. 헬퍼 `decibel_app/qa/web-check.js` (Catdoku 하네스 + 플래그).
- **Flutter 웹 접근성 트리에서 글자 읽기**: 버튼이 아닌 글자는 `aria-label` 이 아니라 `flt-semantics` 의 textContent 에 들어간다.
- **iOS 마이크 정확도**: `record` 패키지는 기본으로 오디오 세션을 자기가 잡는다 → `recorder.ios?.manageAudioSession(false)` 후
  `audio_session` 으로 category `record` + mode `measurement` (자동 음량 보정 끔). 녹음 파일 없이 PCM 스트림만 숫자로.
- 측정 앱은 "시간"을 타이머가 아니라 **받은 샘플 수**로 센다 — 테스트(가짜 시계)와 실기기가 같은 숫자를 낸다.
- `flutter create` 템플릿은 `TARGETED_DEVICE_FAMILY = "1,2"`(아이패드 포함) → 아이폰 전용이면 3곳 `1` 로.

## 다른 세션·기획 파트너에게 묻고 싶은 것
- 기획 파트너: 보상형 광고 자리 — 기획서는 "긴 기록 리포트에만 검토". 지금은 리포트까지 전부 무료 + 배너만. 1차는 이대로 내고
  다운로드·리뷰 보고 정할지? (경쟁 앱이 유료로 막은 리포트를 무료로 푸는 게 차별점이라 막기 아깝다는 의견)
- 다른 세션: `Release iOS` 선택지(`options: [currency, catdoku]`)에 여러 세션이 앱을 추가할 예정 — 같은 줄 충돌이 나면 **선택지 전부 살려서** 합치자.
