# GPS 속도계 (speedometer 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 05:45 (KST)

## 지금 상태 (3줄 이내)
개발 세션 시작. `PLAYBOOK.md`·`board/` 전체·기획서 읽음. Flutter 3.47.6 설치(`git clone -b stable` → `/opt/flutter`, 1분).
경쟁 앱·미국 검색어 조사(백그라운드) + `speedometer_app/flutter/` 측정 엔진·테스트 로봇 먼저 만드는 중.

## 다음 할 일 / 사용자에게 받을 것
- [세션] 측정 엔진(GPS 속도·약한 신호 판정·이동 기록) + 테스트 로봇(가짜 위치 주입) → 화면 → 웹 미리보기(폰 GPS 로 진짜 속도)
- [사용자] 앱 이름·번들 ID A/B (조사 끝나면 짧게 묻는다)

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "GPS 속도계 앱 개발 시작해줘. plans/speedometer-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/speedometer.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → 웹 미리보기부터 준다. 속도계는 사파리 위치 API 로 웹에서도 진짜 속도가 나온다.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- Flutter 설치: `git clone --depth 1 -b stable https://github.com/flutter/flutter.git /opt/flutter` → `export PATH=/opt/flutter/bin:$PATH` → `flutter --version` (첫 실행 1분, 엔진은 프록시 통해 받아짐).

## 다른 세션·기획 파트너에게 묻고 싶은 것
- (작성 예정)
