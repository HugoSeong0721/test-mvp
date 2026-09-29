import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/format.dart';
import '../../core/rate_service.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'currency_picker_sheet.dart';
import 'keypad.dart';

/// 변환 화면.
///
/// 맨 위에 기준 통화·금액이 고정되고, 아래 여러 국가가 동시에 변환된다.
/// 어느 행이든 금액을 누르면 그 통화로 입력할 수 있고 나머지 전부가 따라 바뀐다.
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  bool _kbdOpen = false;

  /// 키패드 위로 끌어올릴 때 행을 찾기 위한 키 (통화 코드별)
  final Map<String, GlobalKey> _rowKeys = {};

  GlobalKey _keyFor(String code) => _rowKeys.putIfAbsent(code, GlobalKey.new);

  void _setKbd(bool open) {
    setState(() => _kbdOpen = open);
    if (open) _revealActiveRow();
  }

  /// 키패드가 덮어버린 자리에 입력 중인 행이 숨지 않도록 위로 끌어올린다.
  /// 키패드가 자리를 차지한 뒤의 높이로 계산해야 해서 다음 프레임에 실행.
  void _revealActiveRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppStore.i;
      if (!s.targets.contains(s.active)) return; // 기준 행은 항상 보인다
      final ctx = _rowKeys[s.active]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _startEdit(String code) {
    final s = AppStore.i;
    if (s.active == code) {
      _setKbd(!_kbdOpen);
      return;
    }
    s.startEdit(code);
    _setKbd(true);
  }

  Future<void> _pick(PickMode mode, {int? index}) async {
    _setKbd(false);
    final code = await CurrencyPickerSheet.show(
      context,
      mode: mode,
      replaceIndex: index,
    );
    if (code == null || !mounted) return;
    final s = AppStore.i;
    switch (mode) {
      case PickMode.base:
        s.setBase(code);
      case PickMode.add:
        s.addTarget(code);
        showToast(context, '$code 추가됨');
      case PickMode.replace:
        if (code == kRemoveResult) {
          s.removeTarget(index!);
        } else {
          s.replaceTarget(index!, code);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppStore.i, RateService.i]),
      builder: (context, _) {
        final s = AppStore.i;
        final base = currencyByCode[s.base]!;
        return Column(
          children: [
            _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 7),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Eyebrow('내 돈 · 기준 금액'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BaseCard(
                currency: base,
                editing: _kbdOpen && s.active == s.base,
                amount: s.active == s.base
                    ? fmtBuf(s.buf)
                    : fmtAmount(s.amountIn(s.base)),
                onPick: () => _pick(PickMode.base),
                onAmount: () => _startEdit(s.base),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    for (var i = 0; i < s.targets.length; i++) ...[
                      _TargetRow(
                        key: _keyFor(s.targets[i]),
                        currency: currencyByCode[s.targets[i]]!,
                        base: s.base,
                        editing: _kbdOpen && s.active == s.targets[i],
                        amount: s.active == s.targets[i]
                            ? fmtBuf(s.buf)
                            : fmtAmount(s.amountIn(s.targets[i])),
                        onPick: () => _pick(PickMode.replace, index: i),
                        onAmount: () => _startEdit(s.targets[i]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _AddButton(onTap: () => _pick(PickMode.add)),
                  ],
                ),
              ),
            ),
            if (_kbdOpen)
              Keypad(
                hint: '${s.active} 입력 중 · ⌫ 길게 누르면 전체 지우기',
                onDigit: s.typeDigit,
                onDot: s.typeDot,
                onBackspace: s.backspace,
                onClear: s.clearBuf,
                onDone: () => _setKbd(false),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final r = RateService.i;
    final dot = switch (r.status) {
      RateStatus.live => fx.pos,
      RateStatus.cache || RateStatus.loading => fx.accent,
      RateStatus.offline => fx.muted,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('환율',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: fx.text)),
                const SizedBox(height: 2),
                const Eyebrow('Currency'),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showToast(context, r.statusHelp),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: fx.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: fx.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(r.stampText,
                      style: TextStyle(
                          fontSize: 11,
                          color: fx.text2,
                          fontFeatures: tabularNums)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 통화 이름 + 현지 시각 한 줄
class _NameLine extends StatelessWidget {
  const _NameLine(this.currency, {required this.fontSize});
  final Currency currency;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final style = TextStyle(fontSize: fontSize, color: fx.muted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currency.name, style: style),
        if (currency.tz != null)
          LocalClock(currency.tz!, style: style.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine(this.code, {required this.fontSize});
  final String code;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(code,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                fontFamily: 'monospace',
                color: fx.text)),
        const SizedBox(width: 5),
        Text('›', style: TextStyle(fontSize: fontSize, color: fx.muted)),
      ],
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({
    required this.currency,
    required this.editing,
    required this.amount,
    required this.onPick,
    required this.onAmount,
  });

  final Currency currency;
  final bool editing;
  final String amount;
  final VoidCallback onPick;
  final VoidCallback onAmount;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: fx.surface,
        borderRadius: BorderRadius.circular(20),
        // 금색 테두리는 "지금 입력 중"이라는 뜻 — 기준 행이든 아래 행이든 같다
        border: Border.all(color: editing ? fx.accent : fx.line, width: 1.5),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
              child: Row(
                children: [
                  FlagDot(currency),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CodeLine(currency.code, fontSize: 14),
                      const SizedBox(height: 1),
                      _NameLine(currency, fontSize: 11),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onAmount,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(amount,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -.3,
                              color: fx.text,
                              fontFeatures: tabularNums)),
                    ),
                  ),
                  if (editing) Caret(height: 29, color: fx.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    super.key,
    required this.currency,
    required this.base,
    required this.editing,
    required this.amount,
    required this.onPick,
    required this.onAmount,
  });

  final Currency currency;
  final String base;
  final bool editing;
  final String amount;
  final VoidCallback onPick;
  final VoidCallback onAmount;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final r = RateService.i;
    // "1 USD = 1,385 KRW" 방향으로 단위 환율, 같은 방향의 전일 대비
    final unit = r.convert(1, currency.code, base);
    final d = r.pairChange(currency.code, base);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: fx.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: editing ? fx.accent : fx.line),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
              child: Row(
                children: [
                  FlagDot(currency, size: 34),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CodeLine(currency.code, fontSize: 13.5),
                      const SizedBox(height: 1),
                      _NameLine(currency, fontSize: 11),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onAmount,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(amount,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 21,
                                  letterSpacing: -.2,
                                  color: fx.text,
                                  fontFeatures: tabularNums)),
                        ),
                      ),
                      if (editing) Caret(height: 19, color: fx.accent),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '1 ${currency.code} = ${fmtAmount(unit)} $base · ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: fx.muted,
                              fontFeatures: tabularNums),
                        ),
                      ),
                      ChangeText(d),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 반투명 글라스 ＋ 버튼
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Material(
      color: fx.glass,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fx.glassLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: fx.glassLine, shape: BoxShape.circle),
                child: Text('＋',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fx.text,
                        height: 1)),
              ),
              const SizedBox(width: 8),
              Text('국가 추가',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fx.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
