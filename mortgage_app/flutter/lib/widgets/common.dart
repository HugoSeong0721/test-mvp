import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// iOS 식 알약 모양 선택 (Mortgage | Auto | Personal, Yearly | Monthly, $ | %).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.height = 36,
    this.keyPrefix = 'seg',
    this.fontSize = 14,
  });

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final String keyPrefix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tk.surface2,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  key: Key('$keyPrefix-$v'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (v != value) {
                      HapticFeedback.selectionClick();
                      onChanged(v);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == value ? tk.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: v == value
                          ? const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: v == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: v == value ? tk.text : tk.text2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 흰 카드 + 제목.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tk.text,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// 왼쪽 이름 + 오른쪽 입력 칸.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.fieldWidth = 168,
  });
  final String label;
  final String? hint;
  final Widget child;
  final double fieldWidth;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좁은 화면(iPhone SE)에서도 이름은 한 줄 — 넘치면 살짝 줄인다
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(fontSize: 15, color: tk.text),
                  ),
                ),
                if (hint != null)
                  Text(hint!, style: TextStyle(fontSize: 12, color: tk.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: fieldWidth, child: child),
        ],
      ),
    );
  }
}

/// 빠른 선택 칩 (15 / 20 / 30 yr, +$100 …).
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
    this.keyPrefix = 'chip',
  });
  final List<(T, String)> items;
  final T? selected;
  final ValueChanged<T> onTap;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final (v, label) in items)
          Semantics(
            button: true,
            selected: v == selected,
            child: GestureDetector(
              key: Key('$keyPrefix-$v'),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(v);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                constraints: const BoxConstraints(minHeight: 36),
                decoration: BoxDecoration(
                  color: v == selected ? tk.accent : tk.surface2,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: v == selected ? tk.onAccent : tk.text2,
                    fontFeatures: tabular,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 키보드 바로 위 막대 — 숫자 키패드에는 '완료' 키가 없어서 직접 단다.
class KeyboardBar extends StatelessWidget {
  const KeyboardBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    Widget arrow(IconData icon, String key, VoidCallback f, String label) =>
        IconButton(
          key: Key(key),
          tooltip: label,
          onPressed: f,
          icon: Icon(icon, color: tk.accent),
        );
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: tk.surface,
        border: Border(top: BorderSide(color: tk.line)),
      ),
      child: Row(
        children: [
          arrow(
            Icons.keyboard_arrow_up_rounded,
            'kb-prev',
            () => moveToField(context, forward: false),
            'Previous',
          ),
          arrow(
            Icons.keyboard_arrow_down_rounded,
            'kb-next',
            () => moveToField(context, forward: true),
            'Next',
          ),
          const Spacer(),
          TextButton(
            key: const Key('kb-done'),
            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tk.accent,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// 다음/이전 숫자 칸으로 — 사이의 버튼(접기·칩 등)은 건너뛴다.
void moveToField(BuildContext context, {required bool forward}) {
  final scope = FocusScope.of(context);
  final start = FocusManager.instance.primaryFocus;
  for (var k = 0; k < 30; k++) {
    final moved = forward ? scope.nextFocus() : scope.previousFocus();
    // 포커스 이동은 원래 다음 마이크로태스크에 반영된다 → 바로 반영해야 다음 칸을 이어서 찾는다
    FocusManager.instance.applyFocusChangesIfNeeded();
    final now = FocusManager.instance.primaryFocus;
    if (!moved || now == null || now == start) return;
    if (now.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }
  }
}
