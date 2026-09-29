import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 전화 키패드 배열(1·2·3 상단). 첫 화면에는 없고 금액을 눌러야 올라온다.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.hint,
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
    required this.onClear,
    required this.onDone,
  });

  final String hint;
  final ValueChanged<String> onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Container(
      decoration: BoxDecoration(
        color: fx.appBg,
        border: Border(top: BorderSide(color: fx.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: fx.muted,
                    fontFeatures: tabularNums,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  foregroundColor: fx.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('완료',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['.', '0', '⌫'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _key(context, row[i])),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(BuildContext context, String k) {
    final fx = Fx.of(context);
    final isFn = k == '.' || k == '⌫';
    return Material(
      color: fx.keyBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        highlightColor: fx.keyPress,
        onTap: () {
          if (k == '⌫') {
            onBackspace();
          } else if (k == '.') {
            onDot();
          } else {
            onDigit(k);
          }
        },
        // ⌫ 길게 누르면 전체 지우기
        onLongPress: k == '⌫' ? onClear : null,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fx.line),
          ),
          child: k == '⌫'
              ? Icon(Icons.backspace_outlined, size: 22, color: fx.text2)
              : Text(
                  k,
                  style: TextStyle(
                    fontSize: isFn ? 18 : 22,
                    color: isFn ? fx.text2 : fx.text,
                    fontFeatures: tabularNums,
                  ),
                ),
        ),
      ),
    );
  }
}
