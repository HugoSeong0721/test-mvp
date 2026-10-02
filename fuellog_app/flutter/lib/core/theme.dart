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
    required this.fuel,
    required this.service,
    required this.good,
    required this.warn,
    required this.bad,
  });

  final Color bg, surface, surface2, line;
  final Color text, text2, muted;
  final Color accent, onAccent, accentSoft;

  /// 차트·목록 색: 연료비 / 정비비
  final Color fuel, service;

  /// 알림 상태: 괜찮음 / 곧 / 지남
  final Color good, warn, bad;

  static const light = Tk(
    bg: Color(0xFFF2F4F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF0F4),
    line: Color(0xFFE1E6EC),
    text: Color(0xFF0F1A24),
    text2: Color(0xFF4F5D6B),
    muted: Color(0xFF6E7A87),
    accent: Color(0xFF1665D8),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A1665D8),
    fuel: Color(0xFF1665D8),
    service: Color(0xFFE07B1F),
    good: Color(0xFF178A52),
    warn: Color(0xFFC27A00),
    bad: Color(0xFFD23C32),
  );

  static const dark = Tk(
    bg: Color(0xFF0D1217),
    surface: Color(0xFF161D24),
    surface2: Color(0xFF1F2831),
    line: Color(0xFF27313B),
    text: Color(0xFFE9EEF3),
    text2: Color(0xFFA3AFBB),
    muted: Color(0xFF85919E),
    accent: Color(0xFF5C9DFF),
    onAccent: Color(0xFF05101F),
    accentSoft: Color(0x265C9DFF),
    fuel: Color(0xFF5C9DFF),
    service: Color(0xFFF5A04A),
    good: Color(0xFF3CC580),
    warn: Color(0xFFF2B33D),
    bad: Color(0xFFFF6B61),
  );

  static Tk of(BuildContext context) => Theme.of(context).extension<Tk>()!;

  @override
  Tk copyWith() => this;

  @override
  Tk lerp(ThemeExtension<Tk>? other, double t) => (other is Tk && t >= 0.5) ? other : this;
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
    appBarTheme: AppBarTheme(
      backgroundColor: tk.bg,
      foregroundColor: tk.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      // 테마 글꼴을 이어받아야 한다 (빈 TextStyle 은 기기 기본 글꼴 → 테스트에선 네모로 그려졌다)
      titleTextStyle: base.textTheme.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: tk.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tk.surface,
      indicatorColor: tk.accentSoft,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: tk.text2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tk.accent,
      selectionColor: tk.accentSoft,
      selectionHandleColor: tk.accent,
    ),
  );
}

/// 숫자 칸이 흔들리지 않게 고정폭 숫자.
const tabular = [FontFeature.tabularFigures()];
