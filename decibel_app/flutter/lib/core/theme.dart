import 'package:flutter/material.dart';

/// 앱 이름 — 정해지면 여기 한 곳만 바꾼다 (스토어 이름은 store/ios-listing.md).
const kAppName = 'Glance dB';

/// 개인정보처리방침 (GitHub Pages).
const kPrivacyUrl =
    'https://soulfulfillable.github.io/test-mvp/decibel-privacy.html';

/// 측정기 느낌의 어두운 화면. 리포트 이미지만 흰 종이(인쇄·전달용).
class C {
  static const bg = Color(0xFF0E131C);
  static const card = Color(0xFF19202C);
  static const card2 = Color(0xFF232C3A);
  static const line = Color(0xFF2E3848);
  static const ink = Color(0xFFF2F5F9);
  static const sub = Color(0xFFA7B1C2);
  static const muted = Color(0xFF7D889B);
  static const accent = Color(0xFF4FC3F7);
  static const red = Color(0xFFFF6B5B);

  // 리포트(흰 종이)
  static const paper = Colors.white;
  static const paperInk = Color(0xFF17202B);
  static const paperSub = Color(0xFF5B6675);
  static const paperLine = Color(0xFFE3E7EC);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: C.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: C.accent,
    brightness: Brightness.dark,
    surface: C.bg,
    primary: C.accent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: C.bg,
    foregroundColor: C.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Fri, Oct 2, 2026"
String fmtDate(DateTime t) =>
    '${_days[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}, ${t.year}';

/// "Oct 2"
String fmtDateShort(DateTime t) => '${_months[t.month - 1]} ${t.day}';

/// "10:42 PM" (seconds: "10:42:13 PM")
String fmtClock(DateTime t, {bool seconds = false}) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final s = seconds ? ':${t.second.toString().padLeft(2, '0')}' : '';
  return '$h:$m$s ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// 측정 시간: "0:42", "12:05", "1:02:33"
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// 말로 쓴 시간: "42 sec", "12 min 5 sec", "1 hr 2 min"
String fmtDurationWords(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  if (h > 0) return m > 0 ? '$h hr $m min' : '$h hr';
  if (m > 0) return s > 0 ? '$m min $s sec' : '$m min';
  return '$s sec';
}

/// 휴대폰 마이크가 잴 수 있는 바닥. 이보다 작으면 숫자 대신 "<20".
const kFloorDb = 20.0;

/// 화면에 보이는 dB 숫자 (소수점 없이).
String fmtDb(double v) =>
    !v.isFinite || v < kFloorDb ? '<${kFloorDb.toInt()}' : v.round().toString();
