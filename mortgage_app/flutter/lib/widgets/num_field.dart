import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// 쓰는 동안 1,234,567 처럼 쉼표를 넣고, 소수 자릿수·최대 자릿수를 막는다.
/// 커서는 쉼표를 빼고 센 '숫자 몇 번째' 자리에 그대로 둔다.
class GroupingFormatter extends TextInputFormatter {
  GroupingFormatter({required this.decimals, required this.maxIntDigits});
  final int decimals;
  final int maxIntDigits;

  static bool _sig(String ch) {
    final u = ch.codeUnitAt(0);
    return ch == '.' || (u >= 0x30 && u <= 0x39);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final src = newValue.text;
    final cursor = newValue.selection.baseOffset.clamp(0, src.length);
    // 커서 왼쪽의 숫자·점 개수
    var before = 0;
    for (var k = 0; k < cursor; k++) {
      if (_sig(src[k])) before++;
    }
    var raw = src.split('').where(_sig).join();
    final dot = raw.indexOf('.');
    if (dot >= 0) {
      if (decimals == 0) {
        // 붙여 넣은 "12.50" → "12" (센트는 버린다)
        raw = raw.substring(0, dot);
        if (before > raw.length) before = raw.length;
      } else {
        var frac = raw.substring(dot + 1).replaceAll('.', '');
        if (frac.length > decimals) frac = frac.substring(0, decimals);
        raw = '${raw.substring(0, dot)}.$frac';
      }
    }
    var intPart = raw.contains('.') ? raw.substring(0, raw.indexOf('.')) : raw;
    final fracPart = raw.contains('.') ? raw.substring(raw.indexOf('.')) : '';
    // 앞자리 0 정리: "05" → "5", ".5" → "0.5"
    final trimmed = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    before -= intPart.length - trimmed.length;
    intPart = trimmed;
    if (intPart.isEmpty && fracPart.isNotEmpty) {
      intPart = '0';
      before++;
    }
    if (intPart.length > maxIntDigits) {
      // 한 자리씩 칠 때는 더 안 들어가고, 붙여 넣은 긴 숫자는 앞자리만 남긴다
      if (oldValue.text.replaceAll(RegExp(r'[^0-9]'), '').length >=
              maxIntDigits &&
          newValue.text.length == oldValue.text.length + 1) {
        return oldValue;
      }
      intPart = intPart.substring(0, maxIntDigits);
      before = before.clamp(0, intPart.length + fracPart.length);
    }
    final out = group(intPart) + fracPart;
    // before 번째 숫자 뒤로 커서
    var pos = 0, seen = 0;
    while (pos < out.length && seen < before) {
      if (_sig(out[pos])) seen++;
      pos++;
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

double parseNum(String s) => double.tryParse(s.replaceAll(',', '')) ?? 0;

String formatNum(double v, int decimals) {
  final s = decimals == 0 ? v.round().toString() : trimNum(v, decimals);
  final dot = s.indexOf('.');
  return dot < 0 ? group(s) : group(s.substring(0, dot)) + s.substring(dot);
}

/// 숫자 입력 칸. 바깥 값이 바뀌면(예: % ↔ $ 연동) 고치는 중이 아닐 때만 따라간다.
class NumField extends StatefulWidget {
  const NumField({
    super.key,
    required this.value,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.decimals = 0,
    this.max = 999999999,
    this.semanticLabel,
    this.dim = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? prefix, suffix;
  final int decimals;
  final double max;
  final String? semanticLabel;

  /// 기준이 아닌 쪽(자동 계산된 값)은 흐리게.
  final bool dim;

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(
    text: formatNum(widget.value, widget.decimals),
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      // 누르면 전체 선택 — 바로 새 숫자를 치면 바뀐다
      _c.selection = TextSelection(baseOffset: 0, extentOffset: _c.text.length);
    } else {
      _c.text = formatNum(parseNum(_c.text), widget.decimals);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(NumField old) {
    super.didUpdateWidget(old);
    if (_focus.hasFocus) return;
    final shown = formatNum(widget.value, widget.decimals);
    if (_c.text != shown) _c.text = shown;
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final focused = _focus.hasFocus;
    final intDigits = widget.max.floor().toString().length;
    final style = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: widget.dim && !focused ? tk.text2 : tk.text,
      fontFeatures: tabular,
    );
    final affix = TextStyle(
      fontSize: 15,
      color: tk.muted,
      fontWeight: FontWeight.w500,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: tk.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused ? tk.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        // 화면 읽기(VoiceOver)에는 이름 붙은 입력 칸 하나로만 보이게 합친다
        child: MergeSemantics(
          child: Semantics(
            label: widget.semanticLabel,
            child: Row(
              children: [
                if (widget.prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ExcludeSemantics(
                      child: Text(widget.prefix!, style: affix),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _c,
                    focusNode: _focus,
                    style: style,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.decimals > 0,
                    ),
                    inputFormatters: [
                      GroupingFormatter(
                        decimals: widget.decimals,
                        maxIntDigits: intDigits,
                      ),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (s) {
                      final v = parseNum(s).clamp(0, widget.max).toDouble();
                      widget.onChanged(v);
                    },
                  ),
                ),
                if (widget.suffix != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ExcludeSemantics(
                      child: Text(widget.suffix!, style: affix),
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
