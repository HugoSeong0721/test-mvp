import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 큰 버튼 — 지하철·버스 손가락 기준으로 최소 56pt.
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
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

/// 규칙 칩 2개 — 규칙이 늘 화면에 보이게.
class RuleChips extends StatelessWidget {
  const RuleChips({super.key, this.big = false});
  final bool big;

  @override
  Widget build(BuildContext context) {
    Widget chip(String icon, String t) => Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: big ? 12 : 7, horizontal: 8),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadow,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: big ? 22 : 18)),
            const SizedBox(width: 6),
            Flexible(
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
          ],
        ),
      ),
    );
    // 좁은 화면에서 한 칩만 두 줄로 접혀도 둘의 높이가 같게
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chip('⬜', 'Fill every\nsquare'),
          const SizedBox(width: 8),
          chip('🔢', 'Connect\n1 → 2 → 3 …'),
        ],
      ),
    );
  }
}
