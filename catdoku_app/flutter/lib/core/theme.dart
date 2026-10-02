import 'package:flutter/material.dart';

/// 웹판(docs/catdoku.html) 색을 그대로 가져온다 — 크림 바탕, 진갈색 글씨.
class C {
  static const bg = Color(0xFFF6EFE4);
  static const ink = Color(0xFF4A3B28);
  static const sub = Color(0xFF6B5A41);
  static const muted = Color(0xFF8A7A5F);
  static const card = Colors.white;
  static const gold = Color(0xFFFFD98A);
  static const red = Color(0xFFD1342A);
  static const green = Color(0xFF2E9E5B);

  /// 구역 색 9개 (최대 9×9). 이웃 구역끼리 헷갈리지 않게 밝기·색상을 섞었다.
  static const regions = [
    Color(0xFF3EC3AF),
    Color(0xFF63AEE6),
    Color(0xFFC4608C),
    Color(0xFF8FD977),
    Color(0xFFE6B93F),
    Color(0xFFF2A0BF),
    Color(0xFFA48AE0),
    Color(0xFFF0915A),
    Color(0xFFB9A58C),
  ];
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: C.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: C.ink,
    surface: C.bg,
    primary: C.ink,
  ),
  fontFamily: null,
);

const shadow = [
  BoxShadow(color: Color(0x26785A28), blurRadius: 8, offset: Offset(0, 2)),
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
