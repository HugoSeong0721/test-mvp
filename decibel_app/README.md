# decibel_app — Glance dB (소음 측정기)

기획서 `plans/decibel-app.md`, 게시판 `board/decibel.md`, 스토어 초안 `store/ios-listing.md`.

```
flutter/            Flutter 앱 (iOS 출시 대상, 웹은 미리보기용)
  lib/core/meter.dart       측정 엔진: A/C/Z 가중(IEC 61672, 쌍일차 변환), Fast 125 ms, 평균(Leq)·최대·최소·1초 기록
  lib/core/mic.dart         마이크 (record 패키지 PCM16 스트림, iOS measurement 모드) + 테스트용 가짜 마이크
  lib/core/controller.dart  시작·멈춤·이어서·초기화, 10초마다 자동 저장, 앱 나감·전화 끊김 처리
  lib/core/history.dart     기록(1초당 1바이트, 0.5 dB 단위) — 리포트·기록 목록
  lib/core/store.dart       설정(보정·가중·화면 켜짐)·기록 저장 (shared_preferences)
  lib/screens/              측정 / 비유표 / 리포트 / 기록 / 설정 / 첫 안내
  test/meter_test.dart      엔진 검증 (가중 곡선이 IEC 표와 ±0.2 dB, 시간 가중, 에너지 평균)
  test/robot_test.dart      테스트 로봇 (모든 버튼, 3개 기기 크기, 키보드, 권한 거부, 앱 나감, 전화)
  tool/print_weighting.dart 가중 필터 응답을 IEC 표와 나란히 출력
qa/web-check.js     웹 미리보기를 헤드리스 크롬 + 가짜 마이크로 눌러 보고 화면을 찍는다
store/              App Store 등록 문구 초안
```

## 자주 쓰는 명령

```
cd decibel_app/flutter
flutter test                                   # 27개 (엔진 14 + 로봇 13)
dart run tool/print_weighting.dart
flutter build web --release --base-href /test-mvp/decibel-app/
#  → build/web 을 docs/decibel-app/ 로 복사하되 canvaskit/ 은 빼기 (CDN 에서 받음)
```

## 보정값

`AppStore.defaultOffset = 94` — 아이폰 내장 마이크(measurement 모드)에서 dBFS(RMS) → dB SPL 추정치(공개 자료 +92~94).
**실기기(TestFlight)에서 NIOSH SLM 과 나란히 재서 확인할 것.** 사용자는 설정에서 ±20 dB 조절 가능.
