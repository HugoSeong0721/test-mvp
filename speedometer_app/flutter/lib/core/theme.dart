import 'package:flutter/material.dart';

/// 밤 운전용 어두운 화면. 강조색은 민트, 약한 신호는 주황, 경고는 빨강.
class C {
  static const bg = Color(0xFF0B0E13);
  static const card = Color(0xFF151A21);
  static const line = Color(0xFF262E39);
  static const ink = Color(0xFFF3F6F9);
  static const sub = Color(0xFFA3ADBB);
  static const muted = Color(0xFF6B7585);
  static const accent = Color(0xFF34E0A1);
  static const amber = Color(0xFFFFB547);
  static const red = Color(0xFFFF453A);
  static const alertBg = Color(0xFFB4231B);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.accent,
      brightness: Brightness.dark,
      surface: C.card,
      primary: C.accent,
      onPrimary: C.bg,
    ),
  );
  return base.copyWith(
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.card,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: C.card),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.bg : C.sub,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.accent : C.line,
      ),
    ),
  );
}

const tabular = [FontFeature.tabularFigures()];
