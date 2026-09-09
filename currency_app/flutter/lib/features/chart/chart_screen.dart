import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rate_service.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// 기간별 환율 추이. 실제 과거 데이터 API가 붙기 전까지는 현재 환율에서
/// 거슬러 올라가는 결정적(시드 고정) 랜덤워크로 모양만 보여준다.
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  String _period = '1M';
  bool _inverted = false;

  static const _periods = [
    ('1D', '1일'),
    ('1W', '1주'),
    ('1M', '1개월'),
    ('3M', '3개월'),
    ('1Y', '1년'),
  ];
  static const _points = {'1D': 24, '1W': 28, '1M': 30, '3M': 45, '1Y': 52};
  static const _vol = {'1D': .002, '1W': .004, '1M': .006, '3M': .008, '1Y': .012};

  (String, String) _pair() {
    final s = AppStore.i;
    var to = s.chartTo;
    if (to == s.base || !s.targets.contains(to)) {
      to = s.targets.firstWhere((t) => t != s.base, orElse: () => 'USD');
    }
    return _inverted ? (to, s.base) : (s.base, to);
  }

  List<double> _series(String from, String to) {
    final n = _points[_period]!;
    final end = RateService.i.convert(1, from, to);
    final rnd = _Mulberry32(_hashSeed('$from$to$_period'));
    final vol = _vol[_period]!;
    var v = end;
    final out = <double>[end];
    for (var i = 1; i < n; i++) {
      v = v * (1 + (rnd.next() - .5) * 2 * vol);
      out.insert(0, v);
    }
    return out;
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
        final data = _series(a, b);
        final min = data.reduce(math.min);
        final max = data.reduce(math.max);
        final pchg = (data.last - data.first) / data.first * 100;
        final col = pchg >= 0 ? fx.pos : fx.neg;

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
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => _inverted = !_inverted),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: fx.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: fx.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$a → $b',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: fx.text)),
                            const SizedBox(width: 6),
                            Icon(Icons.swap_horiz, size: 14, color: fx.muted),
                          ],
                        ),
                      ),
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
                        Text('1 $a 기준 · 전일 대비 ',
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
                    for (final (k, label) in _periods)
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
                            child: Text(label,
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
                  child: CustomPaint(
                    painter: _ChartPainter(
                      data: data,
                      color: col,
                      gridColor: fx.text.withValues(alpha: .07),
                      labelColor: fx.text.withValues(alpha: .45),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    _Stat('최고', fmtAmount(max)),
                    const SizedBox(width: 8),
                    _Stat('최저', fmtAmount(min)),
                    const SizedBox(width: 8),
                    _Stat(
                      '기간 변동',
                      '${pchg >= 0 ? '+' : ''}${pchg.toStringAsFixed(2)}%',
                      color: col,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      showToast(context, '실제 앱에서 푸시 알림으로 제공 예정'),
                  icon: Icon(Icons.notifications_none, size: 15, color: fx.accent),
                  label: const Text('목표 환율 도달 시 알림 받기',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fx.text2,
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(color: fx.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
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

    _label(canvas, '최저 ${fmtAmount(min)}', Offset(p, h - 8), false);
    _label(canvas, '최고 ${fmtAmount(max)}', Offset(w - p, h - 8), true);
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

// 웹 프로토타입과 같은 결정적 랜덤워크 — 같은 통화쌍·기간이면 늘 같은 모양.
int _hashSeed(String s) {
  var h = 2166136261;
  for (final cu in s.codeUnits) {
    h ^= cu;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

class _Mulberry32 {
  _Mulberry32(this._a);
  int _a;

  static int _imul(int x, int y) =>
      ((x & 0xFFFFFFFF) * (y & 0xFFFFFFFF)) & 0xFFFFFFFF;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >>> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) ^ t) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}
