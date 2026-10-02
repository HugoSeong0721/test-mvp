import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/theme.dart';

/// 차트 글자 스타일 — 테마 글꼴을 이어받아야 테스트 스크린샷에서도 네모가 안 된다 (대출 앱 교훈).
TextStyle _axis(BuildContext context, Color c) =>
    (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(fontSize: 11, color: c);

/// 날짜별 값 선 그래프 (연비·단가). 점을 누르면 그 값이 위에 뜬다.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.color,
    required this.label,
    required this.semantics,
    this.average,
    this.height = 190,
  });

  final List<(DateTime, double)> points;
  final double? average;
  final Color color;

  /// 값 → 글자 ("31.2", "$3.459")
  final String Function(double) label;
  final String semantics;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _sel;

  @override
  void didUpdateWidget(TrendChart old) {
    super.didUpdateWidget(old);
    if (old.points.length != widget.points.length) _sel = null;
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final p = widget.points;
    final sel = _sel != null && _sel! < p.length ? _sel : null;
    final shown = sel ?? (p.isEmpty ? null : p.length - 1);
    return Semantics(
      container: true,
      label: widget.semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 22,
            child: shown == null
                ? null
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.label(p[shown].$2),
                          style: TextStyle(fontWeight: FontWeight.w700, color: tk.text),
                        ),
                        TextSpan(
                          text: '  ${fmtDate(p[shown].$1)}${sel == null ? ' · latest' : ''}',
                          style: TextStyle(color: tk.muted),
                        ),
                      ],
                    ),
                    key: const Key('chart-readout'),
                    style: const TextStyle(fontSize: 13, fontFeatures: tabular),
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (p.length < 2) return;
              final box = context.findRenderObject() as RenderBox?;
              final w = box?.size.width ?? 1;
              final x = (d.localPosition.dx - _TrendPainter.left) / (w - _TrendPainter.left - _TrendPainter.right);
              final i = (x * (p.length - 1)).round().clamp(0, p.length - 1);
              setState(() => _sel = i);
            },
            child: SizedBox(
              height: widget.height,
              child: CustomPaint(
                painter: _TrendPainter(
                  points: p,
                  average: widget.average,
                  color: widget.color,
                  grid: tk.line,
                  muted: tk.muted,
                  surface: tk.surface,
                  label: widget.label,
                  axis: _axis(context, tk.muted),
                  selected: shown,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.average,
    required this.color,
    required this.grid,
    required this.muted,
    required this.surface,
    required this.label,
    required this.axis,
    required this.selected,
  });

  static const left = 44.0, right = 10.0, top = 8.0, bottom = 22.0;

  final List<(DateTime, double)> points;
  final double? average;
  final Color color, grid, muted, surface;
  final String Function(double) label;
  final TextStyle axis;
  final int? selected;

  void _text(Canvas c, String s, Offset at, {TextAlign align = TextAlign.left, TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style ?? axis),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width - left - right, h = size.height - top - bottom;
    var lo = points.map((e) => e.$2).reduce(math.min);
    var hi = points.map((e) => e.$2).reduce(math.max);
    if (average != null) {
      lo = math.min(lo, average!);
      hi = math.max(hi, average!);
    }
    final pad = math.max((hi - lo) * 0.15, hi.abs() * 0.03 + 0.01);
    lo -= pad;
    hi += pad;
    double y(double v) => top + h - (v - lo) / (hi - lo) * h;
    double x(int i) => left + (points.length == 1 ? w / 2 : i / (points.length - 1) * w);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final v = lo + (hi - lo) * k / 3;
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), gridPaint);
      _text(canvas, label(v), Offset(left - 6, y(v)), align: TextAlign.right);
    }
    if (average != null) {
      final dash = Paint()
        ..color = muted
        ..strokeWidth = 1.2;
      for (var xx = left; xx < left + w; xx += 8) {
        canvas.drawLine(Offset(xx, y(average!)), Offset(math.min(xx + 4, left + w), y(average!)), dash);
      }
    }
    // 처음·끝 날짜
    final first = points.first.$1, last = points.last.$1;
    _text(canvas, '${monShort(first.month)} ${first.year}', Offset(left, size.height - 8));
    if (points.length > 1) {
      _text(canvas, '${monShort(last.month)} ${last.year}', Offset(left + w, size.height - 8), align: TextAlign.right);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(i), y(points[i].$2));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    if (points.length > 1) {
      final fill = Path.from(path)
        ..lineTo(x(points.length - 1), top + h)
        ..lineTo(x(0), top + h)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(left, top, w, h)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      if (points.length <= 40 || i == selected) {
        canvas.drawCircle(Offset(x(i), y(points[i].$2)), i == selected ? 5.5 : 3, dot);
      }
    }
    if (selected != null) {
      final o = Offset(x(selected!), y(points[selected!].$2));
      canvas.drawCircle(o, 2.6, Paint()..color = surface);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.selected != selected || old.color != color || old.average != average;
}

/// 달마다 연료비(아래) + 정비비(위) 막대. 막대를 누르면 그 달 합계가 뜬다.
class MonthBars extends StatefulWidget {
  const MonthBars({super.key, required this.months, required this.semantics, this.height = 190});
  final List<MonthCost> months;
  final String semantics;
  final double height;

  @override
  State<MonthBars> createState() => _MonthBarsState();
}

class _MonthBarsState extends State<MonthBars> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final m = widget.months;
    final tapped = _sel != null && _sel! < m.length ? _sel : null;
    // 누르기 전에는 돈을 쓴 마지막 달을 보여 주고, 막대는 흐리게 하지 않는다
    final lastSpent = m.lastIndexWhere((e) => e.total > 0);
    final sel = tapped ?? (m.isEmpty ? null : (lastSpent >= 0 ? lastSpent : m.length - 1));
    return Semantics(
      container: true,
      label: widget.semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 22,
            child: sel == null
                ? null
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${fmtMonthYear(m[sel].year, m[sel].month)}  ',
                          style: TextStyle(color: tk.muted),
                        ),
                        TextSpan(
                          text: money(m[sel].total),
                          style: TextStyle(fontWeight: FontWeight.w700, color: tk.text),
                        ),
                        if (m[sel].service > 0)
                          TextSpan(
                            text: '  (fuel ${money(m[sel].fuel)} · service ${money(m[sel].service)})',
                            style: TextStyle(color: tk.muted),
                          ),
                      ],
                    ),
                    key: const Key('bars-readout'),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(fontSize: 13, fontFeatures: tabular),
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (m.isEmpty) return;
              final box = context.findRenderObject() as RenderBox?;
              final w = (box?.size.width ?? 1) - _BarsPainter.left;
              final i = ((d.localPosition.dx - _BarsPainter.left) / w * m.length).floor().clamp(0, m.length - 1);
              setState(() => _sel = i);
            },
            child: SizedBox(
              height: widget.height,
              child: CustomPaint(
                painter: _BarsPainter(
                  months: m,
                  fuel: tk.fuel,
                  service: tk.service,
                  grid: tk.line,
                  axis: _axis(context, tk.muted),
                  selected: tapped,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.fuel,
    required this.service,
    required this.grid,
    required this.axis,
    required this.selected,
  });

  static const left = 44.0, top = 8.0, bottom = 22.0;
  final List<MonthCost> months;
  final Color fuel, service, grid;
  final TextStyle axis;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;
    final w = size.width - left, h = size.height - top - bottom;
    final maxV = months.map((e) => e.total).fold(0.0, math.max);
    final top0 = maxV <= 0 ? 10.0 : _niceCeil(maxV);
    double y(double v) => top + h - v / top0 * h;
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final v = top0 * k / 2;
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), g);
      final tp = TextPainter(
        text: TextSpan(text: moneyShort(v).replaceAll('.00', ''), style: axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y(v) - tp.height / 2));
    }
    final slot = w / months.length;
    final bw = math.min(28.0, slot * 0.64);
    final every = (months.length / 6).ceil();
    for (var i = 0; i < months.length; i++) {
      final mc = months[i];
      final cx = left + slot * (i + 0.5);
      final alpha = selected == null || selected == i ? 1.0 : 0.55;
      final fuelTop = y(mc.fuel);
      final r = Radius.circular(math.min(4, bw / 3));
      if (mc.fuel > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(cx - bw / 2, fuelTop, cx + bw / 2, y(0)),
            topLeft: mc.service > 0 ? Radius.zero : r,
            topRight: mc.service > 0 ? Radius.zero : r,
          ),
          Paint()..color = fuel.withValues(alpha: alpha),
        );
      }
      if (mc.service > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(cx - bw / 2, y(mc.total), cx + bw / 2, fuelTop),
            topLeft: r,
            topRight: r,
          ),
          Paint()..color = service.withValues(alpha: alpha),
        );
      }
      if (i % every == 0 || i == months.length - 1) {
        final label = mc.month == 1 || i == 0 ? '${monShort(mc.month)} ${mc.year % 100}' : monShort(mc.month);
        final tp = TextPainter(
          text: TextSpan(text: label, style: axis),
          textDirection: TextDirection.ltr,
        )..layout();
        final x0 = (cx - tp.width / 2).clamp(left - 4, size.width - tp.width);
        if (i == months.length - 1 && i % every != 0 && months.length > 1) {
          // 마지막 달 글자가 앞 글자와 겹치면 생략
          final prev = left + slot * ((i ~/ every) * every + 0.5);
          if (x0 < prev + 34) continue;
        }
        tp.paint(canvas, Offset(x0, size.height - 8 - tp.height / 2));
      }
    }
  }

  static double _niceCeil(double v) {
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final s in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (s * mag >= v) return s * mag;
    }
    return 10 * mag;
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.months != months || old.selected != selected;
}
