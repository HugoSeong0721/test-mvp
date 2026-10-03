import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/solunar.dart';
import '../core/theme.dart';

/// Moon disk drawn from the illuminated fraction (no emoji fonts needed).
class MoonIcon extends StatelessWidget {
  const MoonIcon({super.key, required this.illumination, required this.waxing, this.size = 18});

  final double illumination;
  final bool waxing;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _MoonPainter(illumination, waxing)),
  );
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.f, this.waxing);
  final double f;
  final bool waxing;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.translate(r, r);
    canvas.drawCircle(Offset.zero, r, Paint()..color = Palette.moonDark);
    if (f < 0.01) {
      canvas.drawCircle(
        Offset.zero,
        r - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.moonLit.withValues(alpha: 0.35),
      );
      return;
    }
    if (!waxing) canvas.scale(-1, 1); // lit limb on the left when waning
    final rx = r * (2 * f - 1).abs();
    final lit = Path()
      ..moveTo(0, -r)
      ..arcToPoint(Offset(0, r), radius: Radius.circular(r), clockwise: true)
      ..arcToPoint(Offset(0, -r), radius: Radius.elliptical(math.max(rx, 0.01), r), clockwise: f > 0.5);
    canvas.drawPath(lit, Paint()..color = Palette.moonLit);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.f != f || old.waxing != waxing;
}

/// White rounded card used for every block on the main screen.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Palette.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Palette.line),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Palette.sub),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Small pill used for notices.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Palette.warnBg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Palette.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Palette.warn)),
        ),
      ],
    ),
  );
}

/// Round score badge: number on a ring filled to the score.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 120, this.stroke = 11});
  final Score score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final color = Palette.rating(score.rating);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(score.total / 100, color, stroke),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.total}',
                key: const Key('score-number'),
                style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, height: 1, color: Palette.ink),
              ),
              const SizedBox(height: 2),
              Text(
                score.rating.label.toUpperCase(),
                key: const Key('score-rating'),
                style: TextStyle(fontSize: size * 0.105, fontWeight: FontWeight.w800, letterSpacing: 1, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.color, this.stroke);
  final double f;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Palette.line,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * f.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.f != f || old.color != color;
}

/// Small colored score chip for day rows and calendar cells.
class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key, required this.score, this.width = 44});
  final Score score;
  final double width;

  @override
  Widget build(BuildContext context) {
    final r = score.rating;
    final dark = r == Rating.best || r == Rating.good;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: Palette.rating(r), borderRadius: BorderRadius.circular(8)),
      child: Text(
        '${score.total}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : Palette.ink),
      ),
    );
  }
}

/// 24-hour bar for one local day: night shading, Major/Minor blocks, "now".
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.day, this.now, this.height = 74});
  final SolunarDay day;
  final DateTime? now;
  final double height;

  @override
  Widget build(BuildContext context) {
    final z = day.zone;
    final parts = <String>[for (final p in day.periods) '${p.kind.label} ${span(p.start, p.end, z)}'];
    return Semantics(
      container: true,
      label: 'Timeline: ${parts.isEmpty ? 'no periods' : parts.join(', ')}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TimelinePainter(day, now, DefaultTextStyle.of(context).style)),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.day, this.now, this.textStyle);
  final SolunarDay day;
  final DateTime? now;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 16.0;
    final barTop = 4.0;
    final barH = size.height - labelH - barTop - 2;
    final total = day.end.difference(day.start).inSeconds.toDouble();
    double x(DateTime t) => (t.difference(day.start).inSeconds / total).clamp(0.0, 1.0) * size.width;

    final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, barTop, size.width, barH), const Radius.circular(10));
    canvas.save();
    canvas.clipRRect(bar);
    // Night everywhere, daylight between sunrise and sunset.
    canvas.drawRect(bar.outerRect, Paint()..color = Palette.night);
    final sr = day.sun.sunrise, ss = day.sun.sunset;
    if (day.sun.alwaysUp) {
      canvas.drawRect(bar.outerRect, Paint()..color = Palette.dayLight);
    } else if (sr != null && ss != null) {
      canvas.drawRect(Rect.fromLTRB(x(sr), barTop, x(ss), barTop + barH), Paint()..color = Palette.dayLight);
    }
    // Minor periods half height, Majors full height.
    for (final p in day.periods) {
      final major = p.kind == PeriodKind.major;
      final h = major ? barH * 0.78 : barH * 0.48;
      final r = Rect.fromLTRB(x(p.start), barTop + barH - h, x(p.end), barTop + barH);
      canvas.drawRRect(
        RRect.fromRectAndCorners(r, topLeft: const Radius.circular(5), topRight: const Radius.circular(5)),
        Paint()..color = major ? Palette.major : Palette.minor,
      );
    }
    canvas.restore();

    // Hour ticks and labels.
    final tick = Paint()
      ..color = Palette.faint
      ..strokeWidth = 1;
    for (final (h, label) in [(0, '12a'), (6, '6a'), (12, '12p'), (18, '6p'), (24, '12a')]) {
      final wall = DateTime.utc(day.wallDay.year, day.wallDay.month, day.wallDay.day, h);
      final t = h == 24 ? day.end : day.zone.fromWall(wall);
      final px = h == 24 ? size.width : x(t);
      canvas.drawLine(Offset(px, barTop + barH), Offset(px, barTop + barH + 4), tick);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: textStyle.copyWith(fontSize: 11, color: Palette.sub),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (px - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, barTop + barH + 4));
    }
    final n = now;
    if (n != null && day.contains(n)) {
      final px = x(n);
      canvas.drawLine(
        Offset(px, barTop - 3),
        Offset(px, barTop + barH + 2),
        Paint()
          ..color = const Color(0xFFE53935)
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(Offset(px, barTop - 1), 4, Paint()..color = const Color(0xFFE53935));
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.day != day || old.now != now;
}

/// Legend under the timeline.
class TimelineLegend extends StatelessWidget {
  const TimelineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Palette.faint, width: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 12, color: Palette.sub)),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(Palette.major, 'Major'),
        item(Palette.minor, 'Minor'),
        item(Palette.dayLight, 'Daylight'),
        item(Palette.night, 'Night'),
      ],
    );
  }
}
