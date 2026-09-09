import 'package:flutter/material.dart';

/// 웹 프로토타입의 CSS 토큰을 그대로 옮긴 색상 세트.
/// 다크가 기본이고, 라이트는 시스템 설정을 따른다.
@immutable
class Fx extends ThemeExtension<Fx> {
  const Fx({
    required this.appBg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.glass,
    required this.glassLine,
    required this.pos,
    required this.neg,
    required this.keyBg,
    required this.keyPress,
  });

  final Color appBg, surface, surface2, surface3, line;
  final Color text, text2, muted;
  final Color accent, accentInk, accentSoft;
  final Color glass, glassLine;
  final Color pos, neg;
  final Color keyBg, keyPress;

  static const dark = Fx(
    appBg: Color(0xFF0E1116),
    surface: Color(0xFF161B22),
    surface2: Color(0xFF1E252E),
    surface3: Color(0xFF252D38),
    line: Color(0xFF242C36),
    text: Color(0xFFE8EBEF),
    text2: Color(0xFF9AA4B2),
    muted: Color(0xFF6B7684),
    accent: Color(0xFFE8B44C),
    accentInk: Color(0xFF141008),
    accentSoft: Color.fromRGBO(232, 180, 76, .13),
    glass: Color.fromRGBO(232, 235, 239, .055),
    glassLine: Color.fromRGBO(232, 235, 239, .14),
    pos: Color(0xFF4CC38A),
    neg: Color(0xFFE5645F),
    keyBg: Color(0xFF161B22),
    keyPress: Color(0xFF252D38),
  );

  static const light = Fx(
    appBg: Color(0xFFF6F5F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFEDE8),
    surface3: Color(0xFFE4E1DA),
    line: Color(0xFFE3E0D9),
    text: Color(0xFF1B222B),
    text2: Color(0xFF5B6570),
    muted: Color(0xFF8A929C),
    accent: Color(0xFFA97C1F),
    accentInk: Color(0xFFFFFDF6),
    accentSoft: Color.fromRGBO(169, 124, 31, .12),
    glass: Color.fromRGBO(27, 34, 43, .045),
    glassLine: Color.fromRGBO(27, 34, 43, .14),
    pos: Color(0xFF178A55),
    neg: Color(0xFFC74540),
    keyBg: Color(0xFFFFFFFF),
    keyPress: Color(0xFFEFEDE8),
  );

  static Fx of(BuildContext context) => Theme.of(context).extension<Fx>()!;

  @override
  Fx copyWith() => this;

  @override
  Fx lerp(ThemeExtension<Fx>? other, double t) =>
      other is Fx && t >= .5 ? other : this;
}

/// 숫자는 항상 같은 폭으로 — 금액이 바뀔 때 자릿수가 흔들리지 않게.
const tabularNums = [FontFeature.tabularFigures()];

ThemeData buildTheme(Fx fx, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: fx.appBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: fx.accent,
      brightness: brightness,
      surface: fx.appBg,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [fx],
  );
}
