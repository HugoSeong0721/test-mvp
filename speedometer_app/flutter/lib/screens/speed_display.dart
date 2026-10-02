import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/engine.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/units.dart';
import 'widgets.dart';

/// 지금 화면에 띄울 큰 글자 (속도 또는 달리기 페이스).
class Reading {
  Reading(SpeedController c)
    : mode = c.mode,
      unit = c.unit,
      ms = c.engine.speed,
      state = c.engine.state,
      over = c.alert.over;
  final Mode mode;
  final SpeedUnit unit;
  final double? ms;
  final GpsState state;
  final bool over;

  String get big => mode.showsPace
      ? formatPace(ms, unit)
      : formatSpeed(ms, unit, mode.decimals);
  String get bigLabel => mode.showsPace ? unit.paceLabel : unit.label;

  /// 가장 넓은 표본 — 글자 크기 고정용.
  String get sample =>
      mode.showsPace ? '88:88' : (mode.decimals > 0 ? '88.8' : '188');

  /// 신호가 약하면 숫자를 흐리게 (숫자는 진짜지만 믿을 만하지 않다는 표시).
  double get opacity => state == GpsState.weak ? 0.55 : 1;
}

/// 디지털 — 아주 큰 숫자 + 단위 (탭하면 단위 전환).
class DigitalSpeed extends StatelessWidget {
  const DigitalSpeed({super.key, required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final r = Reading(c);
    return LayoutBuilder(
      builder: (context, box) {
        const style = TextStyle(
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -2,
          fontFeatures: tabular,
        );
        final size = fitFontSize(
          r.sample,
          Size(box.maxWidth, box.maxHeight * 0.62),
          style,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Speed ${r.big} ${r.bigLabel}',
              excludeSemantics: true,
              child: Opacity(
                opacity: r.opacity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    r.big,
                    key: const Key('speed'),
                    style: style.copyWith(fontSize: size, color: C.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            UnitPill(c: c, label: r.bigLabel),
            if (r.mode.showsPace) ...[
              const SizedBox(height: 10),
              Text(
                '${formatSpeed(r.ms, r.unit, 1)} ${r.unit.label}',
                key: const Key('run-speed'),
                style: const TextStyle(
                  color: C.sub,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabular,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 단위 글자. 탭하면 mph ↔ km/h (보트는 노트 → mph → km/h).
class UnitPill extends StatelessWidget {
  const UnitPill({super.key, required this.c, required this.label});
  final SpeedController c;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Unit $label, tap to change',
    excludeSemantics: true,
    child: InkWell(
      key: const Key('unit'),
      borderRadius: BorderRadius.circular(20),
      onTap: c.cycleUnit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: c.alert.over ? C.ink : C.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: C.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.swap_horiz, size: 18, color: C.sub),
          ],
        ),
      ),
    ),
  );
}

/// 아날로그 게이지 — 바늘은 GPS 측정 사이(1초)를 부드럽게 이어 움직인다.
class GaugeSpeed extends StatelessWidget {
  const GaugeSpeed({super.key, required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final r = Reading(c);
    final max = r.mode.gaugeMax(r.unit);
    final v = r.ms == null ? 0.0 : r.unit.fromMs(r.ms!);
    final limit = c.alert.enabled ? c.alert.limit.toDouble() : null;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Semantics(
              label: 'Gauge ${r.big} ${r.bigLabel}',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: v),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOut,
                builder: (context, val, _) => CustomPaint(
                  key: const Key('gauge'),
                  painter: GaugePainter(
                    value: val,
                    max: max,
                    limit: limit,
                    over: r.over,
                    dim: r.ms == null,
                  ),
                  child: Align(
                    alignment: const Alignment(0, 0.62),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: r.opacity,
                          child: Text(
                            r.big,
                            key: const Key('speed'),
                            style: TextStyle(
                              color: C.ink,
                              fontSize: side * 0.2,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                        SizedBox(height: side * 0.02),
                        UnitPill(c: c, label: r.bigLabel),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GaugePainter extends CustomPainter {
  GaugePainter({
    required this.value,
    required this.max,
    required this.limit,
    required this.over,
    required this.dim,
  });
  final double value, max;
  final double? limit;
  final bool over, dim;

  static const startAngle = math.pi * 0.75; // 왼쪽 아래에서 시작
  static const sweep = math.pi * 1.5; // 270°

  double _angle(double v) => startAngle + sweep * (v / max).clamp(0.0, 1.0);

  static double majorStep(double max) => max <= 15
      ? 3
      : max <= 25
      ? 5
      : max <= 60
      ? 10
      : 20;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 10;
    final stroke = r * 0.07;
    final rect = Rect.fromCircle(center: c, radius: r);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = over ? const Color(0x55FFFFFF) : C.line;
    canvas.drawArc(rect, startAngle, sweep, false, track);
    if (!dim && value > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        _angle(value) - startAngle,
        false,
        track..color = over ? C.ink : C.accent,
      );
    }

    // 눈금·숫자
    final major = majorStep(max);
    final minor = major / 2;
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var v = 0.0; v <= max + 1e-6; v += minor) {
      final isMajor = (v / major - (v / major).round()).abs() < 1e-6;
      final a = _angle(v);
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = r - stroke * 1.2;
      final inner = outer - (isMajor ? r * 0.09 : r * 0.05);
      tick
        ..strokeWidth = isMajor ? 2.5 : 1.5
        ..color = isMajor
            ? C.ink.withValues(alpha: 0.9)
            : C.sub.withValues(alpha: 0.6);
      canvas.drawLine(c + dir * inner, c + dir * outer, tick);
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: v.round().toString(),
            style: TextStyle(
              color: C.sub,
              fontSize: r * 0.085,
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = c + dir * (inner - r * 0.11);
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // 경고 속도 표시 (빨간 눈금)
    final l = limit;
    if (l != null && l <= max) {
      final a = _angle(l);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r - stroke * 1.6),
        c + dir * (r + stroke * 0.6),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = over ? C.ink : C.red,
      );
    }

    // 바늘
    if (!dim) {
      final a = _angle(value);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c - dir * r * 0.1,
        c + dir * (r * 0.78),
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = over ? C.ink : C.red,
      );
    }
    canvas.drawCircle(c, r * 0.05, Paint()..color = C.ink);
  }

  @override
  bool shouldRepaint(GaugePainter o) =>
      o.value != value ||
      o.max != max ||
      o.limit != limit ||
      o.over != over ||
      o.dim != dim;
}

/// 표시 방식에 맞는 속도 위젯.
Widget speedView(SpeedController c) =>
    c.display == Display.gauge ? GaugeSpeed(c: c) : DigitalSpeed(c: c);
