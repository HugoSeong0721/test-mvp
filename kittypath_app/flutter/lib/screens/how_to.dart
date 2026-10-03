import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'board.dart';
import 'widgets.dart';

/// 처음 켰을 때 한 번, 그리고 홈의 "How to play" 에서.
/// 글보다 그림 — 3×3 작은 판에서 줄이 1 → 2 → 3 으로 저절로 그어지는 걸 보여 준다.
Future<void> showHowTo(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: C.bg,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How to play',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Draw one line through every square.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: C.sub,
                  ),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 150,
                  height: 150,
                  child: _Demo(key: Key('howto-demo')),
                ),
                const SizedBox(height: 10),
                _row('⬜', 'Fill every square — each one exactly once.'),
                _row('🔢', 'Pass the numbers in order: 1 → 2 → 3 …'),
                _row('🏁', 'Start at 1. Finish on the biggest number.'),
                const Divider(height: 26),
                _row('👆', 'Drag from the end of your line to draw.'),
                _row('↩️', 'Slide back over your line to erase. No mistakes!'),
                _row('💡', 'Stuck? Watch a short video to see the way.'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
          child: BigButton(
            key: const Key('howto-ok'),
            label: 'Got it!',
            onTap: () => Navigator.pop(ctx),
          ),
        ),
      ],
    ),
  ),
);

Widget _row(String icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 42,
        child: Text(icon, style: const TextStyle(fontSize: 24)),
      ),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, height: 1.3, color: C.ink),
        ),
      ),
    ],
  ),
);

/// 3×3 시범 판: 1 → 2 → 3 을 지나며 9칸을 다 채우는 줄이 그어졌다 지워지기를 반복한다.
class _Demo extends StatefulWidget {
  const _Demo({super.key});

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> with SingleTickerProviderStateMixin {
  // 0 1 2 / 5 4 3 / 6 7 8 순서의 지그재그 — 숫자는 0번(1), 4번(2), 8번(3) 칸
  static const _order = [0, 1, 2, 5, 4, 3, 6, 7, 8];
  static const _numbers = [1, 0, 0, 0, 2, 0, 0, 0, 3];
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final font = DefaultTextStyle.of(context).style.fontFamily;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        // 앞 70% 동안 한 칸씩 그어지고, 나머지는 다 채운 채로 잠깐 멈춘다
        final t = (_a.value / 0.7).clamp(0.0, 1.0);
        final len = 1 + (t * (_order.length - 1)).floor();
        final path = _order.sublist(0, len);
        var next = 1;
        for (final c in path) {
          if (_numbers[c] > 0) next = _numbers[c] + 1;
        }
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadow,
          ),
          child: CustomPaint(
            painter: BoardPainter(
              n: 3,
              numberAt: _numbers,
              lastNumber: 3,
              path: path,
              nextNumber: next,
              won: len == _order.length,
              fontFamily: font,
            ),
          ),
        );
      },
    );
  }
}
