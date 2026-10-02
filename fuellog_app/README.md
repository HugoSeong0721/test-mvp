# 연비·정비 기록 (임시 이름 Glance MPG)

- 기획서·진행 기록: `plans/fuel-log-app.md` · 게시판: `board/fuel-log.md` · 스토어 문구: `store/`
- 앱: `flutter/` (iOS 전용·세로, 웹 미리보기는 `docs/fuel-log-app/`)
  - 엔진(화면과 분리): `lib/core/calc.dart`(연비·비용·정비 알림), `csv.dart`(내보내기·가져오기), `model.dart`, `units.dart`
  - 저장: `lib/core/persist*.dart` (아이폰: 앱 지원 폴더 JSON + .bak, 웹: localStorage), 알림: `notify.dart`, 파일: `files*.dart`
- 테스트: `cd flutter && flutter test` (엔진 `test/engine_test.dart` + 로봇 `test/robot_test.dart` → `build/robot_shots/`)
- 웹 미리보기 빌드: `flutter build web --release --base-href /test-mvp/fuel-log-app/` → `build/web` 을 `docs/fuel-log-app/` 로(canvaskit 폴더 빼고)
- 웹 점검: `NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node qa/web-check.js <폴더>` (머리말에 준비 방법)
- 아이콘: `python3 tool_icon.py` → `flutter/assets/icon/icon-1024.png` → `cd flutter && dart run flutter_launcher_icons`
