import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../game/game.dart';

/// 판. 손가락으로 끌면 줄 끝에서 줄이 따라오고, 지난 칸으로 되돌아가면 그 뒤가 지워진다.
/// 순서가 아닌 숫자로 들어가려 하면 그 숫자가 빨갛게 번쩍이고 판이 살짝 흔들린다.
class Board extends StatefulWidget {
  const Board({super.key, required this.game});
  final Game game;

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> with TickerProviderStateMixin {
  late final AnimationController _bad = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  // 다음 숫자·줄 끝을 은은하게 깜빡여 "여기서 이어 그리세요"를 보여 준다
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final AnimationController _win = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int _seenBlock = 0;
  int _seenHint = 0;
  int? _pointer;
  Offset? _last;
  int _lastLen = 1;

  Game get g => widget.game;

  @override
  void initState() {
    super.initState();
    _seenBlock = g.blockSeq;
    _seenHint = g.hintSeq;
    g.addListener(_onGame);
    if (g.status == GameStatus.won) _win.value = 1;
  }

  @override
  void didUpdateWidget(covariant Board old) {
    super.didUpdateWidget(old);
    if (old.game != g) {
      old.game.removeListener(_onGame);
      g.addListener(_onGame);
      _seenBlock = g.blockSeq;
      _seenHint = g.hintSeq;
      _win.reset();
      _pointer = null;
    }
  }

  void _onGame() {
    if (g.blockSeq != _seenBlock) {
      _seenBlock = g.blockSeq;
      _bad.forward(from: 0);
      if (g.lastBlock != Block.notNext) _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    if (g.hintSeq != _seenHint) {
      _seenHint = g.hintSeq;
      _glow.forward(from: 0);
    }
    if (g.path.length != _lastLen) {
      final grew = g.path.length > _lastLen;
      _lastLen = g.path.length;
      if (grew && g.puzzle.numberAt[g.head] > 0) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    if (g.status == GameStatus.won && !_win.isAnimating && _win.value == 0) {
      _win.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    g.removeListener(_onGame);
    _bad.dispose();
    _shake.dispose();
    _glow.dispose();
    _pulse.dispose();
    _win.dispose();
    super.dispose();
  }

  int? _cellAt(Offset p, double size) {
    final cs = size / g.n;
    final r = (p.dy / cs).floor(), c = (p.dx / cs).floor();
    if (r < 0 || c < 0 || r >= g.n || c >= g.n) return null;
    return r * g.n + c;
  }

  void _down(PointerDownEvent e, double size) {
    if (_pointer != null || g.inputBlocked) return;
    final cell = _cellAt(e.localPosition, size);
    if (cell == null) return;
    _pointer = e.pointer;
    _last = e.localPosition;
    if (cell == g.head) return;
    // 줄 위의 칸이면 거기까지 되돌리고 거기서 이어 그린다. 줄 끝 옆 칸이면 한 칸 나아간다.
    g.step(cell);
  }

  void _move(PointerMoveEvent e, double size) {
    if (e.pointer != _pointer) return;
    final from = _last ?? e.localPosition;
    final to = e.localPosition;
    _last = to;
    // 빠르게 그으면 이벤트 사이에 칸을 건너뛴다 → 지나간 선을 잘게 나눠 칸을 순서대로 밟는다
    final cs = size / g.n;
    final steps = math.max(1, ((to - from).distance / (cs / 4)).ceil());
    int? prev;
    for (var i = 1; i <= steps; i++) {
      final p = Offset.lerp(from, to, i / steps)!;
      final cell = _cellAt(p, size);
      if (cell == null || cell == prev) continue;
      prev = cell;
      if (cell == g.head) continue;
      // 줄 끝과 붙어 있거나 줄 위의 칸일 때만 따라간다 (판 아무 데나 쓸어도 엉뚱한 줄이 생기지 않게)
      if (g.isOnPath(cell) || g.adjacent(g.head, cell)) {
        g.dragTo(cell);
      }
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer == _pointer) {
      _pointer = null;
      _last = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final font = DefaultTextStyle.of(context).style.fontFamily;
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        final inner = size - 12;
        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([g, _bad, _shake, _glow, _pulse, _win]),
            builder: (context, _) {
              final t = _shake.value;
              final dx = _shake.isAnimating
                  ? math.sin(t * math.pi * 6) * 6 * (1 - t)
                  : 0.0;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: shadow,
                  ),
                  child: Semantics(
                    container: true,
                    label:
                        'Puzzle board, ${g.n} by ${g.n}. '
                        '${g.filled} of ${g.puzzle.cells} squares filled.',
                    child: Listener(
                      key: const Key('board'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _down(e, inner),
                      onPointerMove: (e) => _move(e, inner),
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      child: SizedBox.square(
                        dimension: inner,
                        child: CustomPaint(
                          painter: BoardPainter(
                            n: g.n,
                            numberAt: g.puzzle.numberAt,
                            lastNumber: g.puzzle.lastNumber,
                            path: g.path,
                            nextNumber: g.nextNumber,
                            won: g.status == GameStatus.won,
                            pulse: _pulse.value,
                            win: _win.value,
                            bad: _bad.isAnimating ? 1 - _bad.value : 0,
                            badCell: g.blockedCell,
                            glow: _glow.isAnimating ? 1 - _glow.value : 0,
                            glowCells: g.lastHintCells,
                            fontFamily: font,
                          ),
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
}

/// 판 그리기 — 게임 화면과 "How to play" 의 작은 시범 판이 같이 쓴다.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.n,
    required this.numberAt,
    required this.lastNumber,
    required this.path,
    required this.nextNumber,
    this.won = false,
    this.pulse = 0,
    this.win = 0,
    this.bad = 0,
    this.badCell,
    this.glow = 0,
    this.glowCells = const [],
    this.fontFamily,
  });

  final int n;
  final List<int> numberAt;
  final int lastNumber;
  final List<int> path;
  final int nextNumber;
  final bool won;
  final double pulse, win, bad, glow;
  final int? badCell;
  final List<int> glowCells;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / n;
    Offset center(int cell) =>
        Offset((cell % n + 0.5) * cs, (cell ~/ n + 0.5) * cs);
    Rect rect(int cell) =>
        Rect.fromLTWH((cell % n) * cs, (cell ~/ n) * cs, cs, cs);
    final total = n * n;
    final denom = math.max(1, total - 1);

    // 지난 칸은 줄 색으로 옅게 칠한다 — 빈칸이 한눈에 보이게
    final fill = Paint();
    for (var i = 0; i < path.length; i++) {
      fill.color = C.pathAt(i / denom).withValues(alpha: won ? 0.30 : 0.18);
      canvas.drawRect(rect(path[i]).inflate(0.3), fill);
    }
    // 칸 선
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1.2;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cs, 0), Offset(i * cs, size.height), grid);
      canvas.drawLine(Offset(0, i * cs), Offset(size.width, i * cs), grid);
    }
    // 힌트로 그어 준 칸 반짝임
    if (glow > 0) {
      final p = Paint()..color = C.gold.withValues(alpha: 0.75 * glow);
      for (final c in glowCells) {
        canvas.drawRect(rect(c).deflate(1), p);
      }
    }
    // 줄 — 칸마다 색이 조금씩 바뀐다
    final w = cs * (0.34 + (won ? 0.06 * math.sin(win * math.pi) : 0));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 1; i < path.length; i++) {
      stroke.color = C.pathAt((i - 0.5) / denom);
      canvas.drawLine(center(path[i - 1]), center(path[i]), stroke);
    }
    // 줄 끝 — 손가락을 대고 이어 그릴 자리
    if (path.isNotEmpty && !won) {
      final h = center(path.last);
      final hc = C.pathAt((path.length - 1) / denom);
      canvas.drawCircle(
        h,
        cs * (0.30 + 0.05 * pulse),
        Paint()..color = hc.withValues(alpha: 0.28),
      );
      canvas.drawCircle(h, w * 0.62, Paint()..color = hc);
    }
    // 숫자
    for (var cell = 0; cell < total; cell++) {
      final num = numberAt[cell];
      if (num == 0) continue;
      final c = center(cell);
      final reached = num < nextNumber;
      final isNext = num == nextNumber && !won;
      if (isNext) {
        // 다음 숫자는 금색 고리가 숨 쉬듯 커졌다 작아진다
        canvas.drawCircle(
          c,
          cs * (0.40 + 0.05 * pulse),
          Paint()..color = C.gold.withValues(alpha: 0.55 + 0.35 * pulse),
        );
      }
      final idx = path.indexOf(cell);
      final color = reached && idx >= 0 ? C.pathAt(idx / denom) : C.ink;
      canvas.drawCircle(c, cs * 0.33, Paint()..color = color);
      if (reached) {
        canvas.drawCircle(
          c,
          cs * 0.33,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$num',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: cs * (num >= 10 ? 0.30 : 0.36),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    // 막힌 칸 — 빨간 고리
    final b = badCell;
    if (b != null && bad > 0) {
      canvas.drawCircle(
        center(b),
        cs * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = C.red.withValues(alpha: bad),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
