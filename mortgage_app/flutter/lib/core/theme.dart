import 'package:flutter/material.dart';

/// 색 토큰. 시스템 설정(라이트/다크)을 따른다.
@immutable
class Tk extends ThemeExtension<Tk> {
  const Tk({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.interest,
    required this.tax,
    required this.insurance,
    required this.hoa,
    required this.pmi,
  });

  final Color bg, surface, surface2, line;
  final Color text, text2, muted;
  final Color accent, onAccent, accentSoft;

  /// 차트·내역 색 — 원금은 accent.
  final Color interest, tax, insurance, hoa, pmi;

  Color get principal => accent;

  static const light = Tk(
    bg: Color(0xFFF2F4F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF0F4),
    line: Color(0xFFE1E6EC),
    text: Color(0xFF0F1A24),
    text2: Color(0xFF4F5D6B),
    muted: Color(0xFF7D8996),
    accent: Color(0xFF0B7A62),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A0B7A62),
    interest: Color(0xFFE8892A),
    tax: Color(0xFF3A78D4),
    insurance: Color(0xFF8A63D2),
    hoa: Color(0xFFD9578E),
    pmi: Color(0xFF8C98A5),
  );

  static const dark = Tk(
    bg: Color(0xFF0D1217),
    surface: Color(0xFF161D24),
    surface2: Color(0xFF1F2831),
    line: Color(0xFF27313B),
    text: Color(0xFFE9EEF3),
    text2: Color(0xFFA3AFBB),
    muted: Color(0xFF75828F),
    accent: Color(0xFF34C29A),
    onAccent: Color(0xFF04140F),
    accentSoft: Color(0x2634C29A),
    interest: Color(0xFFF5A84A),
    tax: Color(0xFF64A0F2),
    insurance: Color(0xFFAB90F2),
    hoa: Color(0xFFF08AB5),
    pmi: Color(0xFF8592A0),
  );

  static Tk of(BuildContext context) => Theme.of(context).extension<Tk>()!;

  @override
  Tk copyWith() => this;

  @override
  Tk lerp(ThemeExtension<Tk>? other, double t) =>
      (other is Tk && t >= 0.5) ? other : this;
}

ThemeData buildTheme(Brightness b) {
  final tk = b == Brightness.dark ? Tk.dark : Tk.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: tk.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tk.accent,
      brightness: b,
      primary: tk.accent,
      onPrimary: tk.onAccent,
      surface: tk.surface,
    ),
    extensions: [tk],
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: tk.text, displayColor: tk.text),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tk.accent,
      selectionColor: tk.accentSoft,
      selectionHandleColor: tk.accent,
    ),
  );
}

/// 숫자 칸이 흔들리지 않게 고정폭 숫자.
const tabular = [FontFeature.tabularFigures()];
