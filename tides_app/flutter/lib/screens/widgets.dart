import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/day.dart';
import '../core/format.dart';
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
      canvas.drawCircle(Offset.zero, r - 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Palette.moonLit.withValues(alpha: 0.35));
      return;
    }
    if (!waxing) canvas.scale(-1, 1); // lit limb on the left when waning
    final rx = r * (2 * f - 1).abs();
    final lit = Path()
      ..moveTo(0, -r)
      ..arcToPoint(Offset(0, r), radius: Radius.circular(r), clockwise: true)
      ..arcToPoint(Offset(0, -r),
          radius: Radius.elliptical(math.max(rx, 0.01), r), clockwise: f > 0.5);
    canvas.drawPath(lit, Paint()..color = Palette.moonLit);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.f != f || old.waxing != waxing;
}

/// 24-hour tide curve for one station-local day. Drag or tap to read any time.
class TideChart extends StatefulWidget {
  const TideChart({super.key, required this.day, required this.units, this.now});

  final DayInfo day;
  final Units units;
  final DateTime? now; // UTC, only when [day] is today

  @override
  State<TideChart> createState() => _TideChartState();
}

class _TideChartState extends State<TideChart> {
  double? _scrub; // 0…1 across the day

  @override
  void didUpdateWidget(TideChart old) {
    super.didUpdateWidget(old);
    if (old.day.wallDay != widget.day.wallDay) _scrub = null;
  }

  void _set(Offset p, double width) {
    final x = ((p.dx - _ChartPainter.padX) / (width - 2 * _ChartPainter.padX)).clamp(0.0, 1.0);
    setState(() => _scrub = x);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final pts = day.curve();
    final known = [for (final p in pts) if (p.$2 != null) p.$2!];
    String? readout;
    if (_scrub != null) {
      final t = day.start.add(Duration(
          milliseconds: (day.end.difference(day.start).inMilliseconds * _scrub!).round()));
      final h = day.data?.heightAt(t);
      readout = h == null
          ? '${clock(t, day.station.zone)} · no data'
          : '${clock(t, day.station.zone)} · ${height(h, widget.units)}';
    }
    return LayoutBuilder(builder: (context, c) {
      return Semantics(
        container: true,
        label: 'Tide chart for ${dayLabel(day.wallDay)}',
        child: GestureDetector(
          key: const Key('tide-chart'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _set(d.localPosition, c.maxWidth),
          onHorizontalDragStart: (d) => _set(d.localPosition, c.maxWidth),
          onHorizontalDragUpdate: (d) => _set(d.localPosition, c.maxWidth),
          onHorizontalDragEnd: (_) {},
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ChartPainter(
                  day: day,
                  pts: pts,
                  minFt: known.isEmpty ? 0 : known.reduce(math.min),
                  maxFt: known.isEmpty ? 1 : known.reduce(math.max),
                  units: widget.units,
                  now: widget.now,
                  scrub: _scrub,
                ),
              ),
            ),
            if (readout != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    key: const Key('chart-readout'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(readout,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.day,
    required this.pts,
    required this.minFt,
    required this.maxFt,
    required this.units,
    required this.now,
    required this.scrub,
  });

  static const padX = 8.0;
  static const padTop = 30.0; // room for high-tide labels / readout
  static const padBottom = 40.0; // low-tide labels + hour axis

  final DayInfo day;
  final List<(DateTime, double?)> pts;
  final double minFt, maxFt;
  final Units units;
  final DateTime? now;
  final double? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - 2 * padX;
    final top = padTop, bottom = size.height - padBottom;
    final total = day.end.difference(day.start).inSeconds.toDouble();
    final span = math.max(maxFt - minFt, 0.5);
    final lo = minFt - span * 0.12, hi = maxFt + span * 0.12;
    double xOf(DateTime t) => padX + w * (t.difference(day.start).inSeconds / total).clamp(0.0, 1.0);
    double yOf(double ft) => bottom - (ft - lo) / (hi - lo) * (bottom - top);

    // Night shading from the sun times.
    final night = Paint()..color = Palette.night.withValues(alpha: 0.06);
    final sun = day.sun;
    if (sun.alwaysDown) {
      canvas.drawRect(Rect.fromLTRB(padX, top - 6, padX + w, bottom), night);
    } else if (!sun.alwaysUp) {
      if (sun.sunrise != null && sun.sunrise!.isAfter(day.start)) {
        canvas.drawRect(Rect.fromLTRB(padX, top - 6, xOf(sun.sunrise!), bottom), night);
      }
      if (sun.sunset != null && sun.sunset!.isBefore(day.end)) {
        canvas.drawRect(Rect.fromLTRB(xOf(sun.sunset!), top - 6, padX + w, bottom), night);
      }
    }

    // Hour grid: 6 AM, noon, 6 PM (station clock).
    final grid = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    final z = day.station.zone;
    for (final (h, label) in [(0, '12a'), (6, '6a'), (12, '12p'), (18, '6p')]) {
      final t = z.fromWall(DateTime.utc(day.wallDay.year, day.wallDay.month, day.wallDay.day, h));
      final x = xOf(t);
      if (h > 0) canvas.drawLine(Offset(x, top - 6), Offset(x, bottom), grid);
      _text(canvas, label, Offset(x, bottom + 22), 11, Palette.faint, align: h == 0 ? 0 : 0.5);
    }
    // MLLW zero line when it is inside the range.
    if (lo < 0 && hi > 0) {
      final y0 = yOf(0);
      canvas.drawLine(Offset(padX, y0), Offset(padX + w, y0), grid);
    }

    // Curve (only where NOAA data exists — never drawn past it).
    final line = Path(), fill = Path();
    var started = false;
    double? lastX;
    for (final (t, ft) in pts) {
      if (ft == null) {
        if (started && lastX != null) {
          fill.lineTo(lastX, bottom);
          fill.close();
        }
        started = false;
        continue;
      }
      final x = xOf(t), y = yOf(ft);
      if (!started) {
        line.moveTo(x, y);
        fill.moveTo(x, bottom);
        fill.lineTo(x, y);
        started = true;
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
      lastX = x;
    }
    if (started && lastX != null) {
      fill.lineTo(lastX, bottom);
      fill.close();
    }
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.sea.withValues(alpha: 0.30), Palette.sea.withValues(alpha: 0.04)],
          ).createShader(Rect.fromLTRB(0, top, size.width, bottom)));
    canvas.drawPath(
        line,
        Paint()
          ..color = Palette.sea
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round);

    // High/low markers with time and height.
    for (final e in day.events) {
      final x = xOf(e.time), y = yOf(e.feet);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);
      canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()
            ..color = Palette.sea
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      final label = '${clock(e.time, z, compact: true)}  ${height(e.feet, units)}';
      final align = x < padX + 40 ? 0.0 : (x > padX + w - 40 ? 1.0 : 0.5);
      if (e.isHigh) {
        _text(canvas, label, Offset(x, y - 8), 11.5, Palette.ink, align: align, above: true, bold: true);
      } else {
        _text(canvas, label, Offset(x, y + 8), 11.5, Palette.ink, align: align, bold: true);
      }
    }

    // Now marker.
    final n = now;
    if (n != null && day.contains(n)) {
      final x = xOf(n);
      final ft = day.data?.heightAt(n);
      final p = Paint()
        ..color = Palette.ink.withValues(alpha: 0.55)
        ..strokeWidth = 1.4;
      for (var y = top - 6; y < bottom; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3, bottom)), p);
      }
      if (ft != null) {
        final y = yOf(ft);
        canvas.drawCircle(Offset(x, y), 7, Paint()..color = Palette.sea.withValues(alpha: 0.25));
        canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = Palette.ink);
      }
    }

    // Scrub line.
    final s = scrub;
    if (s != null) {
      final x = padX + w * s;
      canvas.drawLine(Offset(x, top - 6), Offset(x, bottom),
          Paint()
            ..color = Palette.ink
            ..strokeWidth = 1.2);
      final t = day.start.add(Duration(seconds: (total * s).round()));
      final ft = day.data?.heightAt(t);
      if (ft != null) canvas.drawCircle(Offset(x, yOf(ft)), 4, Paint()..color = Palette.ink);
    }
  }

  void _text(Canvas c, String s, Offset at, double size, Color color,
      {double align = 0.5, bool above = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = at.dx - tp.width * align;
    final dy = above ? at.dy - tp.height : at.dy;
    tp.paint(c, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.day != day || old.units != units || old.now != now || old.scrub != scrub;
}

/// Small pill used for notices ("Offline — showing saved predictions").
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.icon = Icons.cloud_off_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Palette.warnBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 18, color: Palette.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Palette.warn))),
        ]),
      );
}

/// Wave drawing for the welcome screen.
class WaveArt extends StatelessWidget {
  const WaveArt({super.key, this.height = 140});
  final double height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _WavePainter()));
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void wave(double baseY, double amp, double phase, Color color) {
      final p = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        p.lineTo(x, baseY + amp * math.sin(x / size.width * 2 * math.pi * 1.3 + phase));
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.28), size.height * 0.16,
        Paint()..color = const Color(0xFFFFC857));
    wave(size.height * 0.55, 10, 0.4, Palette.sea.withValues(alpha: 0.25));
    wave(size.height * 0.66, 12, 2.0, Palette.sea.withValues(alpha: 0.45));
    wave(size.height * 0.78, 9, 3.6, Palette.sea);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
