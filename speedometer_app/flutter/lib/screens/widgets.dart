import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/engine.dart';
import '../core/theme.dart';

/// GPS 막대 3개 (강·보통·약). 끊기면 빈 막대.
class GpsBars extends StatelessWidget {
  const GpsBars(this.state, {super.key});
  final GpsState state;

  @override
  Widget build(BuildContext context) {
    final (n, color) = switch (state) {
      GpsState.strong => (3, C.accent),
      GpsState.good => (2, C.accent),
      GpsState.weak => (1, C.amber),
      GpsState.lost => (0, C.red),
      GpsState.searching => (0, C.muted),
    };
    return SizedBox(
      width: 18,
      height: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 5.0 + i * 4.5,
              decoration: BoxDecoration(
                color: i < n ? color : C.line,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}

/// 아래 버튼 줄의 큰 버튼 (운전 전에 누르기 쉽게 크게).
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.semantic,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final fg = active ? C.bg : C.ink;
    return Semantics(
      button: true,
      label: semantic ?? label,
      excludeSemantics: true,
      child: Material(
        color: active ? C.accent : C.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 3),
                // 길면 '…' 로 자르지 않고 살짝 줄인다 ("Alert 155 KM/H" 의 숫자가 잘리면 안 된다).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 이동 기록 한 칸 (MAX / AVG / DIST / TIME).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.onRed = false,
  });
  final String label, value, unit;

  /// 경고로 빨개진 화면 위 — 회색 글자가 안 보여서 흰색 계열로.
  final bool onRed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value $unit',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: onRed ? const Color(0xCCFFFFFF) : C.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: C.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: onRed ? const Color(0xCCFFFFFF) : C.sub,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(fontFeatures: tabular),
          ),
        ),
      ],
    ),
  );
}

/// 큰 숫자 글자 크기 — [sample] (가장 넓은 경우, 예: "188") 이 칸에 꼭 맞게. 숫자 자릿수가 바뀌어도
/// 글자 크기가 출렁이지 않게 표본으로 한 번 정한다.
double fitFontSize(String sample, Size box, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: sample, style: style.copyWith(fontSize: 100)),
    textDirection: TextDirection.ltr,
  )..layout();
  final byW = box.width * 0.94 / tp.width * 100;
  final byH = box.height / tp.height * 100;
  return math.max(24, math.min(byW, byH));
}

/// 아래에서 올라오는 창의 틀 — 제목 줄 오른쪽에 Done 이 항상 보이고, 내용은 길어지면 스크롤된다
/// (큰 글씨 설정 + 작은 화면에서도 닫기 버튼이 화면 밖으로 밀려나지 않게).
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.doneKey,
    required this.children,
  });
  final String title;
  final String doneKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: C.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  key: Key(doneKey),
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(minimumSize: const Size(72, 48)),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
