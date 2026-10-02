import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/format.dart';
import '../../core/rate_service.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../converter/currency_picker_sheet.dart';

/// 기간별 실제 환율 추이 (RateService.history — 날짜별 공개 환율 파일).
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  String _period = '1M';

  static const _periods = ['1W', '1M', '3M', '1Y'];

  String? _key;
  Future<List<(DateTime, double)>>? _future;

  (String, String) _pair() {
    final s = AppStore.i;
    final from = s.chartFrom ?? s.base;
    var to = s.chartTo;
    if (to == from || !currencyByCode.containsKey(to)) {
      to = [...s.targets, s.base, 'USD', 'EUR'].firstWhere((t) => t != from);
    }
    return (from, to);
  }

  Future<void> _pick(bool left) async {
    final (a, b) = _pair();
    final code = await CurrencyPickerSheet.show(context,
        mode: PickMode.chart, exclude: left ? b : a);
    if (code == null || code == kRemoveResult) return;
    left ? AppStore.i.setChartPair(code, b) : AppStore.i.setChartPair(a, code);
  }

  Future<List<(DateTime, double)>> _historyFor(String a, String b) {
    final key = '$a$b$_period${RateService.i.date}';
    if (key != _key) {
      _key = key;
      _future = RateService.i.history(a, b, _period);
    }
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([AppStore.i, RateService.i]),
      builder: (context, _) {
        final (a, b) = _pair();
        final r = RateService.i;
        final rate = r.convert(1, a, b);

        return FutureBuilder<List<(DateTime, double)>>(
          future: _historyFor(a, b),
          builder: (context, snap) {
        final data = [for (final (_, v) in snap.data ?? const <(DateTime, double)>[]) v];
        final hasData = data.length >= 2;
        final min = hasData ? data.reduce(math.min) : 0.0;
        final max = hasData ? data.reduce(math.max) : 0.0;
        final pchg = hasData ? (data.last - data.first) / data.first * 100 : 0.0;
        final col = pchg >= 0 ? fx.pos : fx.neg;
        final loading = snap.connectionState != ConnectionState.done;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CodeChip(code: a, onTap: () => _pick(true)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward,
                              size: 15, color: fx.muted),
                        ),
                        _CodeChip(code: b, onTap: () => _pick(false)),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Swap',
                          onPressed: () => AppStore.i.setChartPair(b, a),
                          icon: Icon(Icons.swap_horiz,
                              size: 20, color: fx.text2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(fmtAmount(rate),
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -.6,
                                color: fx.text,
                                fontFeatures: tabularNums)),
                        const SizedBox(width: 6),
                        Text(b,
                            style: TextStyle(fontSize: 16, color: fx.text2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('1 $a · vs. yesterday ',
                            style: TextStyle(fontSize: 12.5, color: fx.text2)),
                        ChangeText(r.pairChange(a, b), fontSize: 12.5),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    for (final k in _periods)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _period = k),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _period == k
                                  ? fx.accentSoft
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(k,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _period == k
                                        ? fx.accent
                                        : fx.text2)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: 360 / 190,
                  child: hasData
                      ? CustomPaint(
                          painter: _ChartPainter(
                            data: data,
                            color: col,
                            gridColor: fx.text.withValues(alpha: .07),
                            labelColor: fx.text.withValues(alpha: .45),
                          ),
                        )
                      : Center(
                          child: loading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: fx.accent))
                              : Text('Chart needs an internet connection',
                                  style: TextStyle(
                                      fontSize: 13, color: fx.muted)),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    _Stat('High', hasData ? fmtAmount(max) : '—'),
                    const SizedBox(width: 8),
                    _Stat('Low', hasData ? fmtAmount(min) : '—'),
                    const SizedBox(width: 8),
                    _Stat(
                      'Change',
                      hasData
                          ? '${pchg >= 0 ? '+' : ''}${pchg.toStringAsFixed(2)}%'
                          : '—',
                      color: hasData ? col : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: fx.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fx.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color ?? fx.text,
                    fontFeatures: tabularNums)),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.data,
    required this.color,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> data;
  final Color color;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const p = 10.0;
    const footer = 26.0;
    final w = size.width, h = size.height;
    final min = data.reduce(math.min), max = data.reduce(math.max);
    final span = (max - min) == 0 ? max * .001 : (max - min);
    double x(int i) => p + i * (w - 2 * p) / (data.length - 1);
    double y(double v) => h - footer - (v - min) * (h - footer - p) / span;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final t in [.25, .5, .75]) {
      final gy = p + t * (h - footer - p);
      canvas.drawLine(Offset(p, gy), Offset(w - p, gy), grid);
    }

    final line = Path()..moveTo(x(0), y(data[0]));
    for (var i = 1; i < data.length; i++) {
      line.lineTo(x(i), y(data[i]));
    }
    final area = Path.from(line)
      ..lineTo(x(data.length - 1), h - footer)
      ..lineTo(x(0), h - footer)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h - footer)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(x(data.length - 1), y(data.last)),
      3.5,
      Paint()..color = color,
    );

    _label(canvas, 'Low ${fmtAmount(min)}', Offset(p, h - 8), false);
    _label(canvas, 'High ${fmtAmount(max)}', Offset(w - p, h - 8), true);
  }

  void _label(Canvas canvas, String text, Offset at, bool alignRight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: 10, color: labelColor, fontFeatures: tabularNums),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(alignRight ? at.dx - tp.width : at.dx, at.dy - tp.height),
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.data != data || old.color != color;
}

/// 차트 통화 선택 칩 — 눌러서 아무 통화로나 바꾼다.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final c = currencyByCode[code]!;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
        decoration: BoxDecoration(
          color: fx.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fx.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlagDot(c, size: 22),
            const SizedBox(width: 6),
            Text(code,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: fx.text)),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: fx.muted),
          ],
        ),
      ),
    );
  }
}
