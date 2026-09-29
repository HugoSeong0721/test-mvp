import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/format.dart';
import '../../core/rate_service.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

enum PickMode { base, add, replace }

/// 시트에서 "목록에서 제거"를 눌렀을 때 돌아오는 값
const kRemoveResult = '__remove__';

/// 통화 선택 바텀시트. 고른 통화 코드(또는 [kRemoveResult])를 돌려준다.
class CurrencyPickerSheet extends StatefulWidget {
  const CurrencyPickerSheet({super.key, required this.mode, this.replaceIndex});

  final PickMode mode;
  final int? replaceIndex;

  static Future<String?> show(
    BuildContext context, {
    required PickMode mode,
    int? replaceIndex,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Fx.of(context).appBg.withValues(alpha: .6),
      builder: (_) =>
          CurrencyPickerSheet(mode: mode, replaceIndex: replaceIndex),
    );
  }

  @override
  State<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<CurrencyPickerSheet> {
  String _q = '';

  String get _title {
    final s = AppStore.i;
    return switch (widget.mode) {
      PickMode.base => '기준 통화 변경',
      PickMode.add => '변환 국가 추가',
      PickMode.replace => '${s.targets[widget.replaceIndex!]} → 다른 통화로 교체',
    };
  }

  bool _taken(String code) {
    final s = AppStore.i;
    if (widget.mode == PickMode.base) return code == s.base;
    return code == s.base || s.targets.contains(code);
  }

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final s = AppStore.i;
    final canRemove =
        widget.mode == PickMode.replace && s.targets.length > 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      decoration: BoxDecoration(
        color: fx.appBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: fx.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color: fx.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(_title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: fx.text)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('닫기',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fx.muted)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: CurrencySearchField(onChanged: (v) => setState(() => _q = v)),
          ),
          if (canRemove)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, kRemoveResult),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fx.neg,
                    backgroundColor: fx.surface,
                    side: BorderSide(color: fx.line),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '− ${s.targets[widget.replaceIndex!]} 목록에서 제거',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          Flexible(
            child: CurrencyList(
              query: _q,
              showRecents: true,
              isTaken: _taken,
              onPick: (code) => Navigator.pop(context, code),
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색창 — 시트와 온보딩에서 같이 쓴다.
class CurrencySearchField extends StatelessWidget {
  const CurrencySearchField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return TextField(
      onChanged: onChanged,
      autocorrect: false,
      style: TextStyle(fontSize: 14, color: fx.text),
      decoration: InputDecoration(
        hintText: '통화명 또는 코드 검색',
        hintStyle: TextStyle(color: fx.muted),
        prefixIcon: Icon(Icons.search, size: 18, color: fx.muted),
        filled: true,
        fillColor: fx.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: fx.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: fx.accent, width: 2),
        ),
      ),
    );
  }
}

/// 최근 사용 → 법정통화 → 암호화폐 → 귀금속 순으로 묶인 통화 목록.
class CurrencyList extends StatelessWidget {
  const CurrencyList({
    super.key,
    required this.query,
    required this.onPick,
    this.isTaken,
    this.showRecents = false,
  });

  final String query;
  final ValueChanged<String> onPick;
  final bool Function(String code)? isTaken;
  final bool showRecents;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final q = query.trim();
    final children = <Widget>[];

    if (showRecents && q.isEmpty) {
      final rec = AppStore.i.recents
          .map((c) => currencyByCode[c])
          .whereType<Currency>()
          .toList();
      if (rec.isNotEmpty) {
        children.add(_group('최근 사용'));
        children.addAll(rec.map(_row));
      }
    }

    var any = false;
    for (final g in CurrencyGroup.values) {
      final items =
          currencies.where((c) => c.group == g && c.matches(q)).toList();
      if (items.isEmpty) continue;
      any = true;
      children.add(_group(groupLabels[g]!));
      children.addAll(items.map(_row));
    }

    if (!any) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text('검색 결과가 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: fx.muted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      shrinkWrap: true,
      children: children,
    );
  }

  Widget _group(String label) => Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 7),
          child: Eyebrow(label),
        ),
      );

  Widget _row(Currency c) => CurrencyRow(
        currency: c,
        taken: isTaken?.call(c.code) ?? false,
        onTap: () => onPick(c.code),
      );
}

class CurrencyRow extends StatelessWidget {
  const CurrencyRow({
    super.key,
    required this.currency,
    required this.onTap,
    this.taken = false,
  });

  final Currency currency;
  final VoidCallback onTap;
  final bool taken;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final rate = RateService.i.rate[currency.code] ?? currency.snapshotRate;
    return Opacity(
      opacity: taken ? .45 : 1,
      child: InkWell(
        onTap: taken ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              FlagDot(currency),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currency.code,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                            fontFamily: 'monospace',
                            color: fx.text)),
                    Text(currency.name,
                        style: TextStyle(fontSize: 11.5, color: fx.muted)),
                  ],
                ),
              ),
              if (taken)
                Text('✓',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fx.pos))
              else
                Text('1 USD = ${fmtAmount(rate)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: fx.text2,
                        fontFeatures: tabularNums)),
            ],
          ),
        ),
      ),
    );
  }
}
