import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 큰 버튼 — 어르신·지하철 손가락 기준으로 최소 56pt.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = C.ink,
    this.textColor = C.gold,
    this.icon,
    this.height = 58,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color, textColor;
  final String? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Center(
            // 좁은 화면에서 긴 문구가 넘치지 않게 줄여서라도 한 줄로
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  icon == null ? label : '$icon  $label',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 규칙 칩 3개 — 규칙이 늘 화면에 보이게.
class RuleChips extends StatelessWidget {
  const RuleChips({super.key, this.big = false});
  final bool big;

  @override
  Widget build(BuildContext context) {
    Widget chip(String t) => Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: big ? 12 : 7, horizontal: 4),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadow,
        ),
        alignment: Alignment.center,
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: big ? 15 : 14,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: C.sub,
          ),
        ),
      ),
    );
    // 좁은 화면에서 한 칩만 세 줄로 접혀도 셋의 높이가 같게
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chip('1 cat\nper color'),
          const SizedBox(width: 6),
          chip('1 cat per\nrow & column'),
          const SizedBox(width: 6),
          chip('Cats\ncan’t touch'),
        ],
      ),
    );
  }
}

class Hearts extends StatelessWidget {
  const Hearts(this.n, {super.key, this.max = 3});
  final int n, max;
  @override
  Widget build(BuildContext context) => Text(
    [for (var i = 0; i < max; i++) i < n ? '❤️' : '🤍'].join(),
    semanticsLabel: '$n hearts',
    style: const TextStyle(fontSize: 20, letterSpacing: 1),
  );
}
