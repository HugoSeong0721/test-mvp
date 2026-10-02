import 'package:flutter/material.dart';

/// 앱 이름 — 스토어 이름이 정해지면 여기 한 곳만 바꾼다.
const kAppName = 'Path Puzzle';

/// 연보라 종이 바탕 + 진남색 글씨. 줄은 청록 → 남보라로 번진다.
class C {
  static const bg = Color(0xFFF2F0F9);
  static const ink = Color(0xFF251E4A);
  static const sub = Color(0xFF4F4778);
  static const muted = Color(0xFF6E6894);
  static const card = Colors.white;
  static const line = Color(0xFFDCD8EC);
  static const gold = Color(0xFFFFC94D);
  static const red = Color(0xFFD1342A);
  static const green = Color(0xFF1E9E63);
  static const pathStart = Color(0xFF22B8A7);
  static const pathEnd = Color(0xFF5B4FE0);

  /// 줄의 [t] (0 = 시작, 1 = 끝) 위치 색.
  static Color pathAt(double t) => Color.lerp(pathStart, pathEnd, t)!;
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: C.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: C.ink,
    surface: C.bg,
    primary: C.ink,
  ),
);

const shadow = [
  BoxShadow(color: Color(0x22251E4A), blurRadius: 8, offset: Offset(0, 2)),
];

String fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

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

String fmtDay(DateTime t) =>
    '${_days[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}';
String fmtDayShort(DateTime t) => '${_months[t.month - 1]} ${t.day}';
