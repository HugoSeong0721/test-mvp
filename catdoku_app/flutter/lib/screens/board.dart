import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../game/game.dart';

/// 판. 누르면 고른 붓대로 칠하고, ✕ 붓으로 끌면 지나간 빈칸에 ✕ 가 이어진다.
/// 규칙을 어기면 부딪힌 고양이와 누른 칸이 빨갛게 번쩍이고 판이 흔들린다.
class Board extends StatefulWidget {
  const Board({super.key, required this.game});
  final Game game;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> with TickerProviderStateMixin {
  late final AnimationController _bad = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _seenViolation = 0;
  int _seenHint = 0;
  (int, int)? _popCell;
  DragMode _drag = DragMode.none;
  (int, int)? _lastDragCell;

  Game get g => widget.game;

  @override
  void initState() {
    super.initState();
    g.addListener(_onGame);
  }

  @override
  void didUpdateWidget(covariant Board old) {
    super.didUpdateWidget(old);
    if (old.game != g) {
      old.game.removeListener(_onGame);
      g.addListener(_onGame);
      _seenViolation = g.violationSeq;
      _seenHint = g.hintSeq;
      _win.reset();
    }
  }

  void _onGame() {
    if (g.violationSeq != _seenViolation) {
      _seenViolation = g.violationSeq;
      _bad.forward(from: 0);
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
    if (g.hintSeq != _seenHint) {
      _seenHint = g.hintSeq;
      _popCell = g.lastHint;
      _pop.forward(from: 0);
      _glow.forward(from: 0);
    }
    if (g.status == GameStatus.won && !_win.isAnimating) {
      _win.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    g.removeListener(_onGame);
    _bad.dispose();
    _shake.dispose();
    _pop.dispose();
    _glow.dispose();
    _win.dispose();
    super.dispose();
  }

  (int, int)? _cellAt(Offset p, double size) {
    final cs = size / g.n;
    final r = (p.dy / cs).floor(), c = (p.dx / cs).floor();
    if (r < 0 || c < 0 || r >= g.n || c >= g.n) return null;
    return (r, c);
  }

  void _down(Offset p, double size) {
    if (g.inputBlocked) return;
    final cell = _cellAt(p, size);
    if (cell == null) return;
    final before = g.cats;
    _drag = g.tap(cell.$1, cell.$2);
    _lastDragCell = cell;
    if (g.cats > before) {
      _popCell = cell;
      _pop.forward(from: 0);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _move(Offset p, double size) {
    if (_drag == DragMode.none) return;
    final cell = _cellAt(p, size);
    if (cell == null || cell == _lastDragCell) return;
    _lastDragCell = cell;
    g.dragPaint(cell.$1, cell.$2, _drag);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([g, _bad, _shake, _pop, _glow, _win]),
            builder: (context, _) {
              final t = _shake.value;
              final dx = _shake.isAnimating
                  ? math.sin(t * math.pi * 6) * 7 * (1 - t)
                  : 0.0;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: shadow,
                  ),
                  child: Semantics(
                    container: true,
                    label: 'Puzzle board, ${g.n} by ${g.n}',
                    child: Listener(
                      key: const Key('board'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _down(e.localPosition, size - 10),
                      onPointerMove: (e) => _move(e.localPosition, size - 10),
                      onPointerUp: (_) => _drag = DragMode.none,
                      onPointerCancel: (_) => _drag = DragMode.none,
                      child: SizedBox.square(
                        dimension: size - 10,
                        child: CustomPaint(
                          painter: _BoardPainter(
                            g,
                            _bad.value,
                            _bad.isAnimating,
                            _popCell,
                            _glow.isAnimating ? _glow.value : 1.0,
                          ),
                          child: _marks(size - 10),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _marks(double size) {
    final n = g.n;
    final cs = size / n;
    final kids = <Widget>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final m = g.cells[r][c];
        Widget? w;
        if (m == Mark.cat) {
          var scale = 1.0;
          if (_popCell == (r, c) && _pop.isAnimating) {
            final v = _pop.value;
            scale = v < 0.7
                ? 0.4 + v / 0.7 * 0.85
                : 1.25 - (v - 0.7) / 0.3 * 0.25;
          }
          if (g.status == GameStatus.won) scale *= 1 + 0.12 * _win.value;
          w = Transform.scale(
            scale: scale,
            child: Text('🐱', style: TextStyle(fontSize: cs * 0.6, height: 1)),
          );
        } else if (m == Mark.cross) {
          w = Text(
            '✕',
            style: TextStyle(
              fontSize: cs * 0.46,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x55000000), blurRadius: 2)],
            ),
          );
        } else if (g.isAutoCross(r, c)) {
          w = Text(
            '✕',
            style: TextStyle(
              fontSize: cs * 0.36,
              height: 1,
              fontWeight: FontWeight.w800,
              color: C.ink.withValues(alpha: 0.42),
            ),
          );
        }
        if (w != null) {
          kids.add(
            Positioned(
              key: ValueKey('m$r-$c'),
              left: c * cs,
              top: r * cs,
              width: cs,
              height: cs,
              child: Center(child: w),
            ),
          );
        }
      }
    }
    return Stack(children: kids);
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.g, this.bad, this.badOn, this.glowCell, this.glow);
  final Game g;
  final double bad;
  final bool badOn;
  final (int, int)? glowCell;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final n = g.n;
    final cs = size.width / n;
    final reg = g.puzzle.region;
    final fill = Paint();
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        fill.color = C.regions[reg[r][c] % C.regions.length];
        canvas.drawRect(
          Rect.fromLTWH(c * cs, r * cs, cs + 0.5, cs + 0.5),
          fill,
        );
      }
    }
    // 얇은 칸 선
    final thin = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cs, 0), Offset(i * cs, size.height), thin);
      canvas.drawLine(Offset(0, i * cs), Offset(size.width, i * cs), thin);
    }
    // 구역 경계는 굵게 — 색을 잘 구분 못 해도 구역이 보이게
    final thick = Paint()
      ..color = C.ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (c < n - 1 && reg[r][c] != reg[r][c + 1]) {
          canvas.drawLine(
            Offset((c + 1) * cs, r * cs),
            Offset((c + 1) * cs, (r + 1) * cs),
            thick,
          );
        }
        if (r < n - 1 && reg[r][c] != reg[r + 1][c]) {
          canvas.drawLine(
            Offset(c * cs, (r + 1) * cs),
            Offset((c + 1) * cs, (r + 1) * cs),
            thick,
          );
        }
      }
    }
    // 막다른 줄·색: 빨갛게 칠하고 바깥 테두리를 그어 "여기가 막혔다"를 보여 준다
    final st = g.stuckLine;
    if (st != null) {
      final set = st.cells.toSet();
      final tint = Paint()..color = const Color(0x33E02020);
      final edge = Paint()
        ..color = const Color(0xFFD1342A)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final (r, c) in st.cells) {
        canvas.drawRect(Rect.fromLTWH(c * cs, r * cs, cs, cs), tint);
        final x = c * cs, y = r * cs;
        if (!set.contains((r - 1, c))) {
          canvas.drawLine(Offset(x, y + 2), Offset(x + cs, y + 2), edge);
        }
        if (!set.contains((r + 1, c))) {
          canvas.drawLine(
            Offset(x, y + cs - 2),
            Offset(x + cs, y + cs - 2),
            edge,
          );
        }
        if (!set.contains((r, c - 1))) {
          canvas.drawLine(Offset(x + 2, y), Offset(x + 2, y + cs), edge);
        }
        if (!set.contains((r, c + 1))) {
          canvas.drawLine(
            Offset(x + cs - 2, y),
            Offset(x + cs - 2, y + cs),
            edge,
          );
        }
      }
    }
    // 힌트·새 고양이 자리 반짝임
    final gc = glowCell;
    if (gc != null && glow < 1) {
      final p = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.7 * (1 - glow));
      canvas.drawRect(Rect.fromLTWH(gc.$2 * cs, gc.$1 * cs, cs, cs), p);
    }
    // 위반 번쩍임
    final v = g.lastViolation;
    if (v != null && badOn) {
      // 녹색·노랑 위에서도 빨강으로 읽히게: 진한 채움 + 굵은 빨간 테두리
      final a = (1 - bad).clamp(0.0, 1.0);
      final p = Paint()..color = Color.fromRGBO(220, 20, 20, 0.78 * a);
      final edge = Paint()
        ..color = Color.fromRGBO(170, 0, 0, a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      for (final (r, c) in [...v.culprits, (v.r, v.c)]) {
        final rect = Rect.fromLTWH(c * cs, r * cs, cs, cs);
        canvas.drawRect(rect, p);
        canvas.drawRect(rect.deflate(2), edge);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
