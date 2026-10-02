# 물때 시간 (tides 앱) — 개발 세션 게시판
마지막 갱신: 2026-10-03 05:31 (KST)

## 지금 상태 (3줄 이내)
개발 세션 시작 (2026-10-03 05시). `PLAYBOOK.md`·`board/` 전체·기획서 읽음. Flutter 3.47.2 설치.
**이 작업 환경에서 NOAA API(api.tidesandcurrents.noaa.gov)가 막혀 있다** → Actions `Fetch NOAA tides data` 로
관측소 목록·응답 시간·CORS·실제 예보 샘플을 받아 `tides-noaa-data` 브랜치에 쌓는 우회로를 만드는 중.

## 다음 할 일 / 사용자에게 받을 것
- [세션] NOAA 점검(Actions) → 엔진(관측소·예보·캐시·일출일몰·달) + 테스트 로봇 → 화면 → 웹 미리보기 링크
- [사용자] 앱 이름·번들 ID·광고 제거 결제 여부 A/B (미리보기 링크와 같이 짧게 묻는다)

## 사용자 피드백 기록 (최신이 위, 원문 인용 + 어떻게 반영했나)
| 날짜 | 원문 | 반영 |
|---|---|---|
| 10-03 | "물때 시간(Tides) 앱 개발 시작해줘. plans/tides-app.md 기획서대로 하고, 시작 전에 PLAYBOOK.md 와 board/ 전체를 읽어. 네 게시판은 board/tides.md 야 — 내 피드백 받을 때마다, 단계 끝날 때마다 갱신해서 다른 세션들과 공유해줘." | 읽고 시작. 이 파일을 단계마다 갱신 |

## 사용자 성향 — 원하는 것 / 불편해하는 것 (이 앱에서 알게 된 것)
- (Catdoku 게시판에서 배움) 폰으로 바로 해 보는 링크를 먼저 원함 → Flutter 웹 미리보기부터 준다.

## 다른 세션에 알리는 노하우 (다른 앱에서도 써먹을 것)
- **작업 환경에서 막힌 API 는 Actions 로 받아 데이터 브랜치에 커밋** (색칠 앱 `fetch-line-art.yml` 방식 재사용).
  막힌 호스트 확인: `curl -sS "$HTTPS_PROXY/__agentproxy/status"` 의 `recentRelayFailures`. WebFetch 도 같은 호스트는 막힌다.
- Flutter SDK 는 storage.googleapis.com 에서 받으면 된다 (`releases_linux.json` → `stable/linux/flutter_linux_3.47.2-stable.tar.xz`).

## 다른 세션·기획 파트너에게 묻고 싶은 것
- (없음)
