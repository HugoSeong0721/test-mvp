import 'package:flutter/material.dart';

import 'solunar.dart';

class Palette {
  static const ink = Color(0xFF1C2A22); // dark pine text
  static const sub = Color(0xFF55665B);
  static const faint = Color(0xFF97A39A);
  static const pine = Color(0xFF2F6B4F); // primary
  static const pineLight = Color(0xFFDDEBE2);
  static const bg = Color(0xFFF4F5EF);
  static const card = Colors.white;
  static const line = Color(0xFFE3E7DF);
  static const major = Color(0xFFD9822B); // amber-orange: Major periods
  static const minor = Color(0xFFF2C46B); // light amber: Minor periods
  static const night = Color(0xFF243447);
  static const dayLight = Color(0xFFFFF6DA);
  static const moonLit = Color(0xFFF2E3A6);
  static const moonDark = Color(0xFF3A4A63);
  static const warn = Color(0xFFB54708);
  static const warnBg = Color(0xFFFFF4E5);

  static Color rating(Rating r) => switch (r) {
    Rating.best => const Color(0xFF1E7B3C),
    Rating.good => const Color(0xFF6AA84F),
    Rating.fair => const Color(0xFFE0A030),
    Rating.slow => const Color(0xFFA7B0A9),
  };
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Palette.pine, primary: Palette.pine, surface: Palette.bg),
    scaffoldBackgroundColor: Palette.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}
