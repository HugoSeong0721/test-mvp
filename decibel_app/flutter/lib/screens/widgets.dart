import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../core/meter.dart';
import '../core/theme.dart';

/// 게이지 눈금 범위 (dB). 휴대폰 마이크는 20 dB 아래를 못 잰다.
const gaugeMin = 20.0, gaugeMax = 130.0;

/// 큰 반원형 게이지. 숫자를 몰라도 색과 바늘 위치로 읽힌다.
class Gauge extends StatelessWidget {
  const Gauge({
    super.key,
    required this.value,
    required this.max,
    required this.unit,
    required this.active,
  });

  /// 지금 값 (없으면 null → "--").
  final double? value;
  final double? max;
  final String unit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final color = v == null ? C.muted : bandOf(v).color;
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight / 0.86);
        return Center(
          child: SizedBox(
            width: size,
            height: size * 0.86,
            child: Semantics(
              label: v == null ? 'No reading yet' : '${v.round()} $unit',
              child: CustomPaint(
                painter: _GaugePainter(value: v, max: max, color: color),
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text(
                          v == null ? '--' : fmtDb(v),
                          key: const Key('current'),
                          style: TextStyle(
                            fontSize: size * 0.22,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: v == null
                                ? C.muted
                                : (active ? C.ink : C.sub),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: size * 0.065,
                          color: C.sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.max, required this.color});
  final double? value, max;
  final Color color;

  static const start = math.pi * 0.75; // 왼쪽 아래
  static const sweep = math.pi * 1.5; // 270°

  double _t(double db) =>
      ((db - gaugeMin) / (gaugeMax - gaugeMin)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final r = w * 0.40;
    final stroke = w * 0.055;
    final rect = Rect.fromCircle(center: center, radius: r);

    // 바탕 트랙
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = C.card2
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // 구간 색 띠 (바깥 얇은 링)
    final outer = Rect.fromCircle(center: center, radius: r + stroke * 0.95);
    for (var i = 0; i < bands.length; i++) {
      final a = math.max(bands[i].from, gaugeMin);
      final b = i + 1 < bands.length ? bands[i + 1].from : gaugeMax;
      if (b <= gaugeMin) continue;
      canvas.drawArc(
        outer,
        start + sweep * _t(a),
        sweep * (_t(b) - _t(a)),
        false,
        Paint()
          ..color = bands[i].color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.22,
      );
    }

    // 눈금·숫자
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var db = gaugeMin; db <= gaugeMax; db += 10) {
      final a = start + sweep * _t(db);
      final major = db % 20 == 0;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (r - stroke * 0.9);
      final p2 =
          center +
          Offset(math.cos(a), math.sin(a)) * (r - stroke * (major ? 1.6 : 1.3));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = C.muted
          ..strokeWidth = major ? 2 : 1,
      );
      if (major) {
        tp.text = TextSpan(
          text: db.toInt().toString(),
          style: TextStyle(color: C.muted, fontSize: w * 0.04),
        );
        tp.layout();
        final lp =
            center + Offset(math.cos(a), math.sin(a)) * (r - stroke * 2.45);
        tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
      }
    }

    final v = value;
    if (v != null) {
      // 지금 값까지 채움
      canvas.drawArc(
        rect,
        start,
        math.max(0.001, sweep * _t(v)),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      // 끝 점
      final a = start + sweep * _t(v);
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * r,
        stroke * 0.32,
        Paint()..color = Colors.white,
      );
    }

    // 최대 표시 (작은 삼각형)
    final m = max;
    if (m != null && m.isFinite && m > gaugeMin) {
      final a = start + sweep * _t(m);
      final dir = Offset(math.cos(a), math.sin(a));
      final tip = center + dir * (r + stroke * 0.55);
      final perp = Offset(-dir.dy, dir.dx);
      final base = center + dir * (r + stroke * 1.35);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (base + perp * stroke * 0.38).dx,
          (base + perp * stroke * 0.38).dy,
        )
        ..lineTo(
          (base - perp * stroke * 0.38).dx,
          (base - perp * stroke * 0.38).dy,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = C.ink);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.max != max || old.color != color;
}

/// 최근 1분 그래프 (0.1초 간격 점). 오른쪽 끝이 지금.
class LiveChart extends StatelessWidget {
  const LiveChart({super.key, required this.points});
  final List<double> points;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Last minute chart',
    child: CustomPaint(painter: _LivePainter(points), size: Size.infinite),
  );
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.points) : _n = points.length;
  final List<double> points;
  final int _n;
  static const lo = 20.0, hi = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0;
    final w = size.width - left, h = size.height;
    double y(double db) => h - ((db.clamp(lo, hi) - lo) / (hi - lo)) * h;
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var db = 40.0; db <= 100; db += 20) {
      canvas.drawLine(Offset(left, y(db)), Offset(size.width, y(db)), grid);
      tp.text = TextSpan(
        text: db.toInt().toString(),
        style: const TextStyle(color: C.muted, fontSize: 10),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y(db) - tp.height / 2));
    }
    if (_n < 2) return;
    const total = MeterEngine.recentPoints;
    final dx = w / (total - 1);
    final x0 = left + w - (_n - 1) * dx;
    final path = Path()..moveTo(x0, y(points[0]));
    for (var i = 1; i < _n; i++) {
      path.lineTo(x0 + i * dx, y(points[i]));
    }
    final fill = Path.from(path)
      ..lineTo(x0 + (_n - 1) * dx, h)
      ..lineTo(x0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            C.accent.withValues(alpha: 0.35),
            C.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LivePainter old) => true;
}

/// 리포트 그래프: 시간에 따른 평균(막대, 구간 색) + 최대(점선).
class ReportChart extends StatelessWidget {
  const ReportChart({super.key, required this.stats, required this.labels});
  final List<SecondStat> stats;

  /// 아래 축 글자 (처음·가운데·끝).
  final List<String> labels;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ReportPainter(stats, labels), size: Size.infinite);
}

class _ReportPainter extends CustomPainter {
  _ReportPainter(this.stats, this.labels);
  final List<SecondStat> stats;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, bottom = 18.0;
    final w = size.width - left, h = size.height - bottom;
    var hi = 100.0, lo = 30.0;
    for (final s in stats) {
      if (s.max > hi - 5) hi = (s.max / 10).ceil() * 10 + 10;
      if (s.leq < lo + 5) lo = math.max(0, (s.leq / 10).floor() * 10 - 10);
    }
    double y(double db) => h - ((db.clamp(lo, hi) - lo) / (hi - lo)) * h;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final grid = Paint()
      ..color = C.paperLine
      ..strokeWidth = 1;
    final step = (hi - lo) > 70 ? 20.0 : 10.0;
    for (var db = (lo / step).ceil() * step; db <= hi; db += step) {
      canvas.drawLine(Offset(left, y(db)), Offset(size.width, y(db)), grid);
      tp.text = TextSpan(
        text: db.toInt().toString(),
        style: const TextStyle(color: C.paperSub, fontSize: 9),
      );
      tp.layout();
      tp.paint(canvas, Offset(0, y(db) - tp.height / 2));
    }
    if (stats.isNotEmpty) {
      final bw = w / stats.length;
      for (var i = 0; i < stats.length; i++) {
        final s = stats[i];
        canvas.drawRect(
          Rect.fromLTRB(
            left + i * bw + bw * 0.12,
            y(s.leq),
            left + (i + 1) * bw - bw * 0.12,
            h,
          ),
          Paint()..color = bandOf(s.leq).color,
        );
      }
      final peak = Path();
      for (var i = 0; i < stats.length; i++) {
        final p = Offset(left + (i + 0.5) * bw, y(stats[i].max));
        i == 0 ? peak.moveTo(p.dx, p.dy) : peak.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        peak,
        Paint()
          ..color = C.paperInk.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    for (var i = 0; i < labels.length; i++) {
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: C.paperSub, fontSize: 9),
      );
      tp.layout();
      final fx = labels.length == 1 ? 0.0 : i / (labels.length - 1);
      final x = left + w * fx - tp.width * fx;
      tp.paint(canvas, Offset(x, h + 4));
    }
  }

  @override
  bool shouldRepaint(_ReportPainter old) => old.stats != stats;
}

/// 숫자 칸 (AVG·MAX·TIME).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
  });
  final String label, value, unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.sub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: C.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 둥근 원형 버튼 + 아래 글자.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 56,
    this.color = C.card2,
    this.iconColor = C.ink,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color color, iconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // excludeSemantics 로 아래 GestureDetector 의 동작까지 지워지므로 VoiceOver 용 tap 을 여기 단다
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: size * 0.45),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: C.sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
