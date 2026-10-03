import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/model.dart';
import '../core/theme.dart';

/// iOS 식 알약 모양 선택 (Odometer | Trip, mi | km …).
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
      decoration: BoxDecoration(color: tk.surface2, borderRadius: BorderRadius.circular(height / 2)),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                label: label,
                excludeSemantics: true,
                // 아래 GestureDetector 의 누르기를 뺐으므로 화면 읽기용 누르기를 여기 단다
                onTap: () {
                  if (v != value) onChanged(v);
                },
                child: GestureDetector(
                  key: Key('$keyPrefix-${v is Enum ? v.name : v}'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: v == value ? tk.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: v == value
                          ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: v == value ? FontWeight.w700 : FontWeight.w500,
                          color: v == value ? tk.text : tk.text2,
                        ),
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
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding, margin;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(16)),
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text),
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

/// 왼쪽 이름(+작은 설명) + 오른쪽 입력 칸.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.label, required this.child, this.hint, this.fieldWidth = 170});
  final String label;
  final String? hint;
  final Widget child;
  final double fieldWidth;

  double _width(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final screen = MediaQuery.sizeOf(context).width - 64; // 화면 여백 + 카드 안쪽 여백
    return (fieldWidth * scale).clamp(0, screen * 0.62).toDouble();
  }

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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, maxLines: 1, style: TextStyle(fontSize: 15, color: tk.text)),
                ),
                if (hint != null) Text(hint!, style: TextStyle(fontSize: 12, color: tk.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 큰 글씨면 칸도 넓힌다 (화면의 62% 까지) — 숫자가 칸 밖으로 잘리지 않게
          SizedBox(width: _width(context), child: child),
        ],
      ),
    );
  }
}

/// 켜기/끄기 줄 (가득 채움, 기록 빠짐, 알림).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    required this.switchKey,
  });
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String switchKey;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 15, color: tk.text)),
                    if (hint != null) Text(hint!, style: TextStyle(fontSize: 12, color: tk.muted)),
                  ],
                ),
              ),
              Switch.adaptive(key: Key(switchKey), value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// 크고 누르기 쉬운 버튼.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed, this.icon, this.filled = true, this.color});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final c = color ?? tk.accent;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
          Text(label, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(c),
              foregroundColor: WidgetStatePropertyAll(tk.onAccent),
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(c),
              side: WidgetStatePropertyAll(BorderSide(color: c.withValues(alpha: 0.5), width: 1.5)),
            ),
            child: child,
          );
  }
}

/// 날짜 칸 (누르면 달력).
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.onTap, this.fieldKey = 'date'});
  final String label;
  final VoidCallback onTap;
  final String fieldKey;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Semantics(
      button: true,
      label: 'Date, $label',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: Key(fieldKey),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: tk.surface2, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tk.text),
                  ),
                ),
              ),
              Icon(Icons.calendar_today_rounded, size: 18, color: tk.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 키보드 바로 위 막대 — 숫자 키패드에는 '완료' 키가 없어서 직접 단다.
class KeyboardBar extends StatelessWidget {
  const KeyboardBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    Widget arrow(IconData icon, String key, VoidCallback f, String label) => IconButton(
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
          arrow(Icons.keyboard_arrow_up_rounded, 'kb-prev', () => moveToField(context, forward: false), 'Previous'),
          arrow(Icons.keyboard_arrow_down_rounded, 'kb-next', () => moveToField(context, forward: true), 'Next'),
          const Spacer(),
          TextButton(
            key: const Key('kb-done'),
            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Text(
              'Done',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tk.accent),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// 다음/이전 입력 칸으로 — 사이의 버튼은 건너뛴다.
void moveToField(BuildContext context, {required bool forward}) {
  final scope = FocusScope.of(context);
  final start = FocusManager.instance.primaryFocus;
  for (var k = 0; k < 30; k++) {
    final moved = forward ? scope.nextFocus() : scope.previousFocus();
    // 포커스 이동은 원래 다음 마이크로태스크에 반영된다 → 바로 반영해야 다음 칸을 이어서 찾는다
    FocusManager.instance.applyFocusChangesIfNeeded();
    final now = FocusManager.instance.primaryFocus;
    if (!moved || now == null || now == start) return;
    if (now.context?.findAncestorWidgetOfExactType<EditableText>() != null) return;
  }
}

/// 정비 종류 아이콘.
IconData kindIcon(String kind) {
  final k = presetKind(kind);
  return switch (k?.icon) {
    'oil' => Icons.oil_barrel_rounded,
    'tire' => Icons.tire_repair_rounded,
    'brake' => Icons.album_rounded,
    'filter' => Icons.air_rounded,
    'battery' => Icons.battery_charging_full_rounded,
    'wiper' => Icons.water_drop_rounded,
    'coolant' => Icons.thermostat_rounded,
    'check' => Icons.fact_check_rounded,
    'doc' => Icons.description_rounded,
    'shield' => Icons.shield_rounded,
    'wash' => Icons.local_car_wash_rounded,
    'parking' => Icons.local_parking_rounded,
    'toll' => Icons.toll_rounded,
    'repair' => Icons.build_rounded,
    _ => Icons.handyman_rounded,
  };
}

/// 예/아니오 확인 창. [destructive] 면 빨간 버튼.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = true,
}) async {
  final tk = Tk.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('confirm-cancel'),
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirm-ok'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            action,
            style: TextStyle(color: destructive ? tk.bad : tk.accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 입력 화면이 닫히며 돌려주는 결과 → 아래 안내 줄(되돌리기 포함).
class FormResult {
  const FormResult(this.message, {this.undo, this.actionLabel, this.action});
  final String message;
  final VoidCallback? undo;
  final String? actionLabel;
  final VoidCallback? action;
}

void showResult(BuildContext context, FormResult r) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  final label = r.undo != null ? 'Undo' : r.actionLabel;
  final act = r.undo ?? r.action;
  m.showSnackBar(
    SnackBar(
      content: Text(r.message, key: const Key('snack')),
      duration: const Duration(seconds: 4),
      action: label == null || act == null
          ? null
          : SnackBarAction(key: const Key('snack-action'), label: label, onPressed: act),
    ),
  );
}

/// 아래에서 올라오는 날짜 고르기. 제목 줄 오른쪽에 Done (큰 글씨·작은 화면에서도 보이게).
Future<DateTime?> pickDate(BuildContext context, DateTime initial, {DateTime? max}) {
  final tk = Tk.of(context);
  var chosen = initial;
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: tk.surface,
    showDragHandle: false,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Date',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tk.text),
                  ),
                ),
                TextButton(
                  key: const Key('date-done'),
                  onPressed: () => Navigator.pop(c, chosen),
                  child: const Text('Done', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(fontSize: 21, color: tk.text)),
              ),
              child: CupertinoDatePicker(
                key: const Key('date-wheel'),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                maximumDate: max,
                minimumYear: 1990,
                onDateTimeChanged: (d) => chosen = DateTime(d.year, d.month, d.day, initial.hour, initial.minute),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
