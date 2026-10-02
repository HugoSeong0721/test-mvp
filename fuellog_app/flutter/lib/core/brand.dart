import 'package:flutter/foundation.dart';

/// 앱 이름 — 스토어 이름이 정해지면 여기만 바꾼다 (홈 화면 이름은 ios/Runner/Info.plist 의 CFBundleDisplayName).
const appName = 'Glance MPG';
const appVersion = '1.0';
const privacyUrl = 'https://soulfulfillable.github.io/test-mvp/fuellog-privacy.html';

/// 기록이 사는 곳 — 웹 미리보기는 브라우저에 남는다.
String get deviceWord => kIsWeb ? 'this browser' : 'this iPhone';
