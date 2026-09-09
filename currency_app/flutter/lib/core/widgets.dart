import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'currencies.dart';
import 'format.dart';
import 'theme.dart';

/// 국기 이모지, 없으면(암호화폐·귀금속) 글자 배지.
class FlagDot extends StatelessWidget {
  const FlagDot(this.currency, {super.key, this.size = 38});
  final Currency currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final flag = currency.flag;
    Color bg = fx.surface2;
    Color fg = fx.text;
    if (flag == null) {
      switch (currency.badgeStyle) {
        case 'au':
          bg = const Color(0xFFE8B44C);
          fg = const Color(0xFF141008);
        case 'ag':
          bg = const Color(0xFFC9CFD6);
          fg = const Color(0xFF232830);
        case 'pm':
          bg = const Color(0xFF8E97A3);
          fg = const Color(0xFF171B21);
        case 'cr':
          bg = const Color(0xFFF7931A);
          fg = const Color(0xFF160D02);
      }
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        flag ?? currency.badge ?? '',
        style: TextStyle(
          fontSize: flag != null ? size * .58 : size * .37,
          fontWeight: flag != null ? FontWeight.w400 : FontWeight.w700,
          color: fg,
          fontFamily: flag != null ? null : 'monospace',
          height: 1,
        ),
      ),
    );
  }
}

/// ▲0.32% 같은 변동률 — 색으로 방향을 함께 말한다.
class ChangeText extends StatelessWidget {
  const ChangeText(this.change, {super.key, this.fontSize = 10});
  final double change;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final color = change > 0.005 ? fx.pos : change < -0.005 ? fx.neg : fx.muted;
    return Text(
      chgText(change),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: tabularNums,
      ),
    );
  }
}

/// 통화 이름 옆에 붙는 그 나라 현지 시각. 15초마다 갱신되고,
/// 날짜가 넘어가면 어제/내일을 붙여 시차를 헷갈리지 않게 한다.
class LocalClock extends StatefulWidget {
  const LocalClock(this.tzName, {super.key, this.style});
  final String tzName;
  final TextStyle? style;

  static String text(String tzName) {
    try {
      final loc = tz.getLocation(tzName);
      final now = DateTime.now();
      final there = tz.TZDateTime.from(now, loc);
      final here = DateTime(now.year, now.month, now.day);
      final thereDay = DateTime(there.year, there.month, there.day);
      final diff = thereDay.difference(here).inDays;
      final prefix = diff > 0 ? '내일 ' : diff < 0 ? '어제 ' : '';
      final hh = there.hour.toString().padLeft(2, '0');
      final mm = there.minute.toString().padLeft(2, '0');
      return '$prefix$hh:$mm';
    } catch (_) {
      return '';
    }
  }

  @override
  State<LocalClock> createState() => _LocalClockState();
}

class _LocalClockState extends State<LocalClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalClock.text(widget.tzName);
    if (t.isEmpty) return const SizedBox.shrink();
    return Text(' · $t',
        style: (widget.style ?? const TextStyle()).copyWith(
          fontFeatures: tabularNums,
        ));
  }
}

/// 입력 중인 금액 끝에 깜빡이는 커서.
class Caret extends StatefulWidget {
  const Caret({super.key, required this.height, required this.color});
  final double height;
  final Color color;

  @override
  State<Caret> createState() => _CaretState();
}

class _CaretState extends State<Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Opacity(
        opacity: _c.value < .5 ? 1 : 0,
        child: Container(
          width: 2,
          height: widget.height,
          margin: const EdgeInsets.only(left: 2),
          color: widget.color,
        ),
      ),
    );
  }
}

/// 헤더 상단 · 시트 제목 등에 쓰는 대문자 소제목
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Fx.of(context).muted,
        letterSpacing: 1.4,
      ),
    );
  }
}

void showToast(BuildContext context, String msg) {
  final fx = Fx.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: fx.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
      backgroundColor: fx.surface3,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      margin: const EdgeInsets.fromLTRB(40, 0, 40, 96),
      duration: const Duration(milliseconds: 2200),
    ));
}
