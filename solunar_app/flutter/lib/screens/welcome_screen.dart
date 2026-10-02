import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'places_screen.dart';
import 'widgets.dart';

/// First launch: use my location, or search a town.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _error;

  Future<void> _nearMe() async {
    if (AppStore.i.locating) return;
    setState(() => _error = null);
    final r = await AppStore.i.useMyLocation();
    if (!mounted) return;
    setState(() => _error = r.ok ? null : r.message);
  }

  void _search() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlacesScreen()));

  @override
  Widget build(BuildContext context) {
    final locating = AppStore.i.locating;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        ClipRRect(borderRadius: BorderRadius.circular(24), child: const DawnArt(height: 170)),
                        const SizedBox(height: 28),
                        const Text(
                          'Best fishing & hunting times',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Solunar periods, a daily score, sunrise and moon times, and a legal shooting light countdown — '
                          'all free, worked out right on your phone.',
                          style: TextStyle(fontSize: 16.5, color: Palette.sub, height: 1.4),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Notice(key: const Key('welcome-error'), text: _error!, icon: Icons.location_off_outlined),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          key: const Key('welcome-near-me'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            textStyle: Theme.of(context).textTheme.titleMedium!
                                .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          onPressed: _nearMe,
                          icon: locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(locating ? 'Finding your location…' : 'Use My Location'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('welcome-search'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            textStyle: Theme.of(context).textTheme.titleMedium!
                                .copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                          label: const Text('Search a Town'),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your location stays on this device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Palette.faint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dawn over a treeline with the moon — drawn, no image files.
class DawnArt extends StatelessWidget {
  const DawnArt({super.key, this.height = 140});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _DawnPainter()),
  );
}

class _DawnPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF243447), Color(0xFF5B6E8C), Color(0xFFF2B36B)],
        stops: [0, 0.55, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    // Sun just under the horizon, moon high on the left.
    canvas.drawCircle(Offset(w * 0.68, h * 0.86), h * 0.2, Paint()..color = const Color(0xFFFFD58A));
    // Crescent = moon disc minus an offset disc (cut out, so the sky shows through).
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(w * 0.2, h * 0.26), radius: h * 0.1)),
      Path()..addOval(Rect.fromCircle(center: Offset(w * 0.2 + h * 0.045, h * 0.24), radius: h * 0.088)),
    );
    canvas.drawPath(moon, Paint()..color = Palette.moonLit);
    // Pine treeline.
    final trees = Path()..moveTo(0, h);
    final rnd = math.Random(4);
    var x = 0.0;
    while (x < w) {
      final tw = 14 + rnd.nextDouble() * 18;
      final th = h * (0.18 + rnd.nextDouble() * 0.22);
      trees
        ..lineTo(x, h * 0.92)
        ..lineTo(x + tw / 2, h * 0.92 - th)
        ..lineTo(x + tw, h * 0.92);
      x += tw * 0.8;
    }
    trees
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(trees, Paint()..color = const Color(0xFF1C2A22));
    // Water.
    canvas.drawRect(Rect.fromLTWH(0, h * 0.92, w, h * 0.08), Paint()..color = const Color(0xFF3B4F63));
  }

  @override
  bool shouldRepaint(_DawnPainter old) => false;
}
