import 'package:flutter/material.dart';

class Palette {
  static const ink = Color(0xFF0E2A47); // deep navy text
  static const sub = Color(0xFF5B6F86);
  static const faint = Color(0xFF9AA8B8);
  static const sea = Color(0xFF1677C9); // curve
  static const seaLight = Color(0xFFD6EBFA);
  static const bg = Color(0xFFF4F8FC);
  static const card = Colors.white;
  static const line = Color(0xFFE2EAF2);
  static const rising = Color(0xFF0F9D8A); // teal
  static const falling = Color(0xFFE07A2E); // orange
  static const night = Color(0xFF0E2A47);
  static const moonLit = Color(0xFFF2E3A6);
  static const moonDark = Color(0xFF3A4A63);
  static const warn = Color(0xFFB54708);
  static const warnBg = Color(0xFFFFF4E5);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.sea,
      primary: Palette.sea,
      surface: Palette.bg,
    ),
    scaffoldBackgroundColor: Palette.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}
