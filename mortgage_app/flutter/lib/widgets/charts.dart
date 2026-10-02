import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/loan.dart';
import '../core/theme.dart';

/// 차트 눈금 글씨 — 테마 글꼴을 이어받아야 기기 글꼴(SF)로 그려진다.
TextStyle _labelStyle(BuildContext context, Tk tk) =>
    (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      color: tk.muted,
      fontFeatures: tabular,
      height: 1.2,
    );

/// 한 덩어리 (색 + 값).
class Slice {
  const Slice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// 가로 누적 막대 — 월 납입액이 무엇으로 이뤄졌는지.
class StackBar extends StatelessWidget {
  const StackBar({super.key, required this.slices, this.height = 10});
  final List<Slice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final shown = slices.where((s) => s.value > 0).toList();
    final total = shown.fold<double>(0, (a, s) => a + s.value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(color: tk.surface2)
            : Row(
                // stretch 가 없으면 자식 없는 ColoredBox 높이가 0 이 돼 막대가 안 보인다
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < shown.length; k++) ...[
                    if (k > 0)
                      SizedBox(width: 2, child: ColoredBox(color: tk.surface)),
                    Expanded(
                      flex: math.max(
                        1,
                        (shown[k].value / total * 1000).round(),
                      ),
                      child: ColoredBox(color: shown[k].color),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// 도넛 — 가운데에 합계.
class Donut extends StatelessWidget {
  const Donut({
    super.key,
    required this.slices,
    required this.center,
    this.caption,
    this.size = 132,
  });
  final List<Slice> slices;
  final String center;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DonutPainter(slices, tk.surface2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: tk.text,
                    fontFeatures: tabular,
                  ),
                ),
              ),
              if (caption != null)
                Text(caption!, style: TextStyle(fontSize: 11, color: tk.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.track);
  final List<Slice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = slices.fold<double>(0, (a, s) => a + math.max(0, s.value));
    if (total <= 0) {
      canvas.drawArc(arc, 0, math.pi * 2, false, p..color = track);
      return;
    }
    final shown = slices.where((s) => s.value > 0).toList();
    final gap = shown.length > 1 ? 0.035 : 0.0;
    var a = -math.pi / 2;
    for (final s in shown) {
      final sweep = s.value / total * math.pi * 2;
      canvas.drawArc(
        arc,
        a + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        p..color = s.color,
      );
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

/// 남은 원금 곡선 — 추가 상환 없을 때(회색 점선) vs 있을 때(초록).
class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key, required this.base, this.withExtra});
  final LoanResult base;
  final LoanResult? withExtra;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _BalancePainter(base, withExtra, tk, _labelStyle(context, tk)),
        size: Size.infinite,
      ),
    );
  }
}

class _BalancePainter extends CustomPainter {
  _BalancePainter(this.base, this.extra, this.tk, this.label);
  final LoanResult base;
  final LoanResult? extra;
  final Tk tk;
  final TextStyle label;

  static const left = 44.0, bottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (base.isEmpty) return;
    final w = size.width - left, h = size.height - bottom;
    final n = base.months;
    final top = base.loanAmount;
    Offset pt(int k, double bal) =>
        Offset(left + w * k / n, h - h * (bal / top).clamp(0, 1));

    // 가로 눈금 3줄
    final grid = Paint()
      ..color = tk.line
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final y = h * g / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _text(canvas, moneyShort(top * (2 - g) / 2), Offset(0, y - 6), label, 40);
    }
    // 연도 눈금: 처음 · 가운데 · 끝
    final years = [
      (0, base.input.startYear),
      (n ~/ 2, base.schedule[n ~/ 2].year),
      (n, base.schedule.last.year),
    ];
    for (final (k, y) in years) {
      final x = left + w * k / n;
      final tp = _layout('$y', label);
      final dx = (x - tp.width / 2).clamp(left, size.width - tp.width);
      tp.paint(canvas, Offset(dx, h + 5));
    }

    Path line(LoanResult r) {
      final p = Path()..moveTo(left, pt(0, r.loanAmount).dy);
      final step = math.max(1, r.months ~/ 120);
      for (var k = 0; k < r.months; k += step) {
        final o = pt(k + 1, r.schedule[k].balance);
        p.lineTo(o.dx, o.dy);
      }
      final end = pt(r.months, 0);
      p.lineTo(end.dx, end.dy);
      return p;
    }

    final hasExtra = extra != null && extra!.months < base.months;
    final basePath = line(base);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = hasExtra ? tk.muted : tk.accent;
    if (hasExtra) {
      _dashed(canvas, basePath, basePaint);
      final ep = line(extra!);
      final fill = Path.from(ep)
        ..lineTo(pt(extra!.months, 0).dx, h)
        ..lineTo(left, h)
        ..close();
      canvas.drawPath(fill, Paint()..color = tk.accentSoft);
      canvas.drawPath(
        ep,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = tk.accent,
      );
    } else {
      final fill = Path.from(basePath)
        ..lineTo(left + w, h)
        ..lineTo(left, h)
        ..close();
      canvas.drawPath(fill, Paint()..color = tk.accentSoft);
      canvas.drawPath(basePath, basePaint..strokeWidth = 2.5);
    }
  }

  void _dashed(Canvas c, Path p, Paint paint) {
    for (final m in p.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        c.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  TextPainter _layout(String s, TextStyle st) => TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
  )..layout();

  void _text(Canvas c, String s, Offset o, TextStyle st, double width) {
    final tp = _layout(s, st);
    tp.paint(c, Offset(o.dx + width - tp.width, o.dy));
  }

  @override
  bool shouldRepaint(_BalancePainter old) => true;
}

/// 해마다 낸 원금·이자 누적 막대.
class YearlyBars extends StatelessWidget {
  const YearlyBars({super.key, required this.rows});
  final List<YearRow> rows;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _BarsPainter(rows, tk, _labelStyle(context, tk)),
        size: Size.infinite,
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.rows, this.tk, this.st);
  final List<YearRow> rows;
  final Tk tk;
  final TextStyle st;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    const bottom = 18.0;
    final h = size.height - bottom;
    final maxV = rows.fold<double>(
      0,
      (m, r) => math.max(m, r.totalPrincipal + r.interest),
    );
    if (maxV <= 0) return;
    final slot = size.width / rows.length;
    final bw = math.max(1.5, slot * 0.68);
    final pPaint = Paint()..color = tk.principal;
    final iPaint = Paint()..color = tk.interest;
    for (var k = 0; k < rows.length; k++) {
      final r = rows[k];
      final x = k * slot + (slot - bw) / 2;
      final ih = h * r.interest / maxV;
      final ph = h * r.totalPrincipal / maxV;
      canvas.drawRect(Rect.fromLTWH(x, h - ph, bw, ph), pPaint);
      canvas.drawRect(Rect.fromLTWH(x, h - ph - ih, bw, ih), iPaint);
    }
    for (final k in {0, rows.length ~/ 2, rows.length - 1}) {
      final tp = TextPainter(
        text: TextSpan(text: '${rows[k].year}', style: st),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = k * slot + slot / 2 - tp.width / 2;
      tp.paint(canvas, Offset(cx.clamp(0, size.width - tp.width), h + 4));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}

/// 범례 한 줄: ● 이름 ........ 값
class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.slice,
    this.value,
    this.bold = false,
  });
  final Slice slice;
  final String? value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              // 큰 금액이면 이름이 두 줄로 — '…' 로 자르지 않는다
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: tk.text2, height: 1.2),
            ),
          ),
          Text(
            value ?? money(slice.value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: tk.text,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}
