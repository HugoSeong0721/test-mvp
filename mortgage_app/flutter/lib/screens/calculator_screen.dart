import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/format.dart';
import '../core/loan.dart';
import '../core/states.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';
import 'about_sheet.dart';
import 'schedule_screen.dart';

/// 한 화면에서 끝나는 계산기: 위에 월 납입액, 아래로 입력 → 내역 → 추가 상환 → 상환표.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final store = AppStore.i;
  late LoanKind kind = store.kind;
  bool feesOpen = false;
  final _scroll = ScrollController();

  /// 아래로 내리면 위 카드를 한 줄로 접는다 (작은 화면에서 입력 칸이 더 보이게).
  bool collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final off = _scroll.offset;
      // 출렁이지 않게 접는 기준과 펴는 기준을 다르게 둔다
      final next = collapsed ? off > 8 : off > 48;
      if (next != collapsed) setState(() => collapsed = next);
    });
  }

  Scenario get s => store.scenario(kind);

  void update(void Function(Scenario s) f) {
    setState(() => f(s));
    store.save(s);
  }

  void unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final input = s.toInput();
    final valid = s.loanAmount > 0 && s.termMonths > 0;
    final res = calculate(valid ? input : input.withoutExtras());
    final effect = valid && input.hasExtras ? extraEffect(input) : null;

    return Scaffold(
      backgroundColor: tk.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Segmented<LoanKind>(
                      keyPrefix: 'kind',
                      items: const [
                        (LoanKind.mortgage, 'Mortgage'),
                        (LoanKind.auto, 'Auto'),
                        (LoanKind.personal, 'Personal'),
                      ],
                      value: kind,
                      onChanged: (k) {
                        unfocus();
                        setState(() {
                          kind = k;
                          collapsed = false;
                        });
                        store.setKind(k);
                        // 새 목록이 그려진 뒤 맨 위로 (먼저 올리면 바뀐 목록 길이에 밀려 중간에 멈춘다)
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    key: const Key('about'),
                    tooltip: 'About',
                    onPressed: () {
                      unfocus();
                      showAbout(context);
                    },
                    icon: Icon(Icons.info_outline_rounded, color: tk.text2),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ResultCard(
                s: s,
                res: res,
                valid: valid,
                compact: keyboard || collapsed,
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: unfocus,
                child: KeyedSubtree(
                  key: const Key('form'),
                  // 종류마다 새 목록 — 같은 키 카드(내역·추가 상환)를 옛 위치째 재사용하면
                  // 맨 위로 올려도 스크롤이 중간에 멈춘다 (로봇이 380px 에서 멈추는 걸 잡음)
                  child: ListView(
                    key: ValueKey(kind),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _loanCard(tk),
                      if (s.hasFees) _feesCard(tk, res),
                      if (valid) _breakdownCard(tk, res, effect),
                      if (valid) _extraCard(tk, res, effect),
                      if (valid) _scheduleButton(tk, res, effect),
                      _footer(tk),
                    ],
                  ),
                ),
              ),
            ),
            if (keyboard)
              const KeyboardBar()
            else
              SafeArea(top: false, child: Ads.i.banner()),
          ],
        ),
      ),
    );
  }

  // ── 입력 ──

  Widget _loanCard(Tk tk) {
    final title = switch (kind) {
      LoanKind.mortgage => 'Home loan',
      LoanKind.auto => 'Car loan',
      LoanKind.personal => 'Personal loan',
    };
    final priceLabel = switch (kind) {
      LoanKind.mortgage => 'Home price',
      LoanKind.auto => 'Vehicle price',
      LoanKind.personal => 'Loan amount',
    };
    final years = kind == LoanKind.mortgage;
    final termChips = switch (kind) {
      LoanKind.mortgage => const [
        (180, '15 yr'),
        (240, '20 yr'),
        (360, '30 yr'),
      ],
      LoanKind.auto => const [
        (36, '36'),
        (48, '48'),
        (60, '60'),
        (72, '72'),
        (84, '84 mo'),
      ],
      LoanKind.personal => const [
        (12, '12'),
        (24, '24'),
        (36, '36'),
        (48, '48'),
        (60, '60 mo'),
      ],
    };
    return SectionCard(
      key: Key('card-loan-${kind.name}'),
      title: title,
      child: Column(
        children: [
          FieldRow(
            label: priceLabel,
            child: NumField(
              key: const Key('f-price'),
              semanticLabel: priceLabel,
              prefix: '\$',
              max: 99999999,
              value: s.price,
              onChanged: (v) => update((s) => s.price = v),
            ),
          ),
          if (s.hasDown)
            FieldRow(
              label: 'Down payment',
              hint: s.pmiApplies ? 'Under 20% — PMI applies' : null,
              fieldWidth: 206,
              child: Row(
                children: [
                  Expanded(
                    child: NumField(
                      key: const Key('f-down'),
                      semanticLabel: 'Down payment dollars',
                      prefix: '\$',
                      max: 99999999,
                      dim: s.downIsPercent,
                      value: s.downDollars,
                      onChanged: (v) => update((s) {
                        s.down = v;
                        s.downIsPercent = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 94,
                    child: NumField(
                      key: const Key('f-down-pct'),
                      semanticLabel: 'Down payment percent',
                      suffix: '%',
                      decimals: 2,
                      max: 100,
                      dim: !s.downIsPercent,
                      value: s.downPercent,
                      onChanged: (v) => update((s) {
                        s.down = v;
                        s.downIsPercent = true;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          if (s.isAuto) ...[
            FieldRow(
              label: 'Trade-in value',
              child: NumField(
                key: const Key('f-trade'),
                semanticLabel: 'Trade-in value',
                prefix: '\$',
                max: 9999999,
                value: s.tradeIn,
                onChanged: (v) => update((s) => s.tradeIn = v),
              ),
            ),
            _stateRow(tk, forSales: true),
            FieldRow(
              label: 'Sales tax',
              hint: _salesHint(),
              child: NumField(
                key: const Key('f-salestax'),
                semanticLabel: 'Sales tax percent',
                suffix: '%',
                decimals: 3,
                max: 30,
                value: s.salesTax,
                onChanged: (v) => update((s) => s.salesTax = v),
              ),
            ),
          ],
          FieldRow(
            label: kind == LoanKind.mortgage
                ? 'Interest rate'
                : 'Interest rate (APR)',
            hint: 'Example — enter your rate',
            child: NumField(
              key: const Key('f-rate'),
              semanticLabel: 'Interest rate percent',
              suffix: '%',
              decimals: 3,
              max: 99,
              value: s.rate,
              onChanged: (v) => update((s) => s.rate = v),
            ),
          ),
          FieldRow(
            label: 'Loan term',
            child: NumField(
              key: const Key('f-term'),
              semanticLabel: years ? 'Loan term years' : 'Loan term months',
              suffix: years ? 'years' : 'months',
              max: years ? 50 : 600,
              value: years ? s.termMonths / 12 : s.termMonths.toDouble(),
              onChanged: (v) => update(
                (s) => s.termMonths = years ? v.round() * 12 : v.round(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: ChipRow<int>(
                keyPrefix: 'term',
                items: termChips,
                selected: s.termMonths,
                onTap: (m) {
                  unfocus();
                  update((s) => s.termMonths = m);
                },
              ),
            ),
          ),
          FieldRow(
            label: 'First payment',
            child: _PickerButton(
              key: const Key('f-start'),
              text: monthYear(s.startYear, s.startMonth),
              onTap: () async {
                unfocus();
                final picked = await pickMonth(
                  context,
                  s.startYear,
                  s.startMonth,
                  store.clock().year,
                );
                if (picked != null) {
                  update((s) {
                    s.startYear = picked.$1;
                    s.startMonth = picked.$2;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _feesCard(Tk tk, LoanResult res) {
    final monthly =
        res.monthlyTax + res.monthlyInsurance + res.monthlyHoa + res.monthlyPmi;
    final pmiEnd = res.pmiMonths > 0 ? res.schedule[res.pmiMonths - 1] : null;
    return SectionCard(
      key: const Key('card-fees'),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('fees-toggle'),
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              unfocus();
              setState(() => feesOpen = !feesOpen);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taxes, insurance & fees',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tk.text,
                          ),
                        ),
                        Text(
                          'Property tax, home insurance, HOA, PMI',
                          style: TextStyle(fontSize: 12, color: tk.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${money(monthly)}/mo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tk.text2,
                      fontFeatures: tabular,
                    ),
                  ),
                  AnimatedRotation(
                    turns: feesOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: tk.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !feesOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 12),
                    child: Column(
                      children: [
                        _stateRow(tk, forSales: false),
                        FieldRow(
                          label: 'Property tax',
                          hint: _taxHint(),
                          fieldWidth: 206,
                          child: Row(
                            children: [
                              Expanded(
                                child: NumField(
                                  key: const Key('f-tax'),
                                  semanticLabel:
                                      'Property tax dollars per year',
                                  prefix: '\$',
                                  max: 9999999,
                                  dim: s.taxIsPercent,
                                  value: s.taxYearly,
                                  onChanged: (v) => update((s) {
                                    s.tax = v;
                                    s.taxIsPercent = false;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 94,
                                child: NumField(
                                  key: const Key('f-tax-pct'),
                                  semanticLabel: 'Property tax percent',
                                  suffix: '%',
                                  decimals: 3,
                                  max: 20,
                                  dim: !s.taxIsPercent,
                                  value: s.taxPercent,
                                  onChanged: (v) => update((s) {
                                    s.tax = v;
                                    s.taxIsPercent = true;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FieldRow(
                          label: 'Home insurance',
                          hint: 'Per year',
                          child: NumField(
                            key: const Key('f-ins'),
                            semanticLabel: 'Home insurance per year',
                            prefix: '\$',
                            max: 999999,
                            value: s.insurance,
                            onChanged: (v) => update((s) => s.insurance = v),
                          ),
                        ),
                        FieldRow(
                          label: 'HOA dues',
                          hint: 'Per month',
                          child: NumField(
                            key: const Key('f-hoa'),
                            semanticLabel: 'HOA dues per month',
                            prefix: '\$',
                            max: 99999,
                            value: s.hoa,
                            onChanged: (v) => update((s) => s.hoa = v),
                          ),
                        ),
                        FieldRow(
                          label: 'PMI',
                          hint: !s.pmiApplies
                              ? 'Only if down payment is under 20%'
                              : pmiEnd != null
                              ? 'Ends ${monthYear(pmiEnd.year, pmiEnd.month)} (78% LTV)'
                              : 'Per year, % of loan',
                          child: NumField(
                            key: const Key('f-pmi'),
                            semanticLabel: 'PMI percent per year',
                            suffix: '% / yr',
                            decimals: 3,
                            max: 5,
                            dim: !s.pmiApplies,
                            value: s.pmiRate,
                            onChanged: (v) => update((s) => s.pmiRate = v),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 결과 ──

  Widget _breakdownCard(Tk tk, LoanResult res, ExtraEffect? e) {
    // iPhone SE 처럼 좁으면 도넛을 줄여 범례 이름이 잘리지 않게
    final donutSize = MediaQuery.sizeOf(context).width < 380 ? 96.0 : 120.0;
    if (kind == LoanKind.mortgage) {
      final slices = [
        Slice('Principal & interest', res.monthlyPI, tk.principal),
        Slice('Property tax', res.monthlyTax, tk.tax),
        Slice('Home insurance', res.monthlyInsurance, tk.insurance),
        Slice('HOA dues', res.monthlyHoa, tk.hoa),
        Slice('PMI', res.monthlyPmi, tk.pmi),
      ];
      return SectionCard(
        key: const Key('card-breakdown'),
        title: 'Monthly breakdown',
        child: Column(
          children: [
            Row(
              children: [
                Donut(
                  slices: slices,
                  center: money(res.monthlyTotal),
                  caption: 'per month',
                  size: donutSize,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final sl in slices)
                        if (sl.value > 0 || sl.label == 'Principal & interest')
                          LegendRow(slice: sl),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _summary(tk, res, e),
          ],
        ),
      );
    }
    final slices = [
      Slice('Principal', res.loanAmount, tk.principal),
      Slice('Interest', res.totalInterest, tk.interest),
    ];
    return SectionCard(
      key: const Key('card-breakdown'),
      title: 'Loan summary',
      child: Column(
        children: [
          Row(
            children: [
              Donut(
                slices: slices,
                center: money(res.totalOfPayments),
                caption: 'total paid',
                size: donutSize,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [for (final sl in slices) LegendRow(slice: sl)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summary(tk, res, e),
        ],
      ),
    );
  }

  /// 합계는 추가 상환 없이 기준 — 추가 상환 효과는 아래 'Pay extra' 카드가 따로 보여 준다.
  Widget _summary(Tk tk, LoanResult res, ExtraEffect? e) {
    final payoff = res.payoff!;
    final base = e?.base ?? res;
    Widget line(String k, String v, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: TextStyle(fontSize: 14, color: tk.text2)),
          ),
          Text(
            v,
            key: key,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tk.text,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tk.line)),
      ),
      child: Column(
        children: [
          if (s.hasDown) line('Down payment', money(s.downDollars)),
          if (s.isAuto && s.salesTaxDollars > 0)
            line('Sales tax', money(s.salesTaxDollars)),
          line(
            'Loan amount',
            money(res.loanAmount),
            key: const Key('loan-amount'),
          ),
          line(
            'Total interest',
            money(base.totalInterest),
            key: const Key('total-interest'),
          ),
          if (base.totalPmi > 0) line('Total PMI', money(base.totalPmi)),
          line(
            'Total of ${base.months} payments',
            money(base.totalOfPayments + base.totalPmi),
          ),
          line(
            'Payoff date',
            monthYear(base.payoff!.$1, base.payoff!.$2),
            key: const Key('payoff'),
          ),
          if (e != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Without extra payments. With your extra payments: '
                '${monthYear(payoff.$1, payoff.$2)}.',
                style: TextStyle(fontSize: 12, color: tk.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _extraCard(Tk tk, LoanResult res, ExtraEffect? e) {
    const quick = [
      (50.0, '+\$50'),
      (100.0, '+\$100'),
      (200.0, '+\$200'),
      (500.0, '+\$500'),
    ];
    final saved = e != null && e.monthsSaved > 0;
    return SectionCard(
      key: const Key('card-extra'),
      title: 'Pay extra',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldRow(
            label: 'Extra each month',
            hint: 'Goes straight to principal',
            child: NumField(
              key: const Key('f-extra'),
              semanticLabel: 'Extra payment per month',
              prefix: '\$',
              max: 9999999,
              value: s.extra,
              onChanged: (v) => update((s) => s.extra = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: ChipRow<double>(
                keyPrefix: 'extra',
                items: quick,
                selected: s.extra,
                onTap: (v) {
                  unfocus();
                  // 같은 칩을 다시 누르면 끈다
                  update((s) => s.extra = s.extra == v ? 0 : v);
                },
              ),
            ),
          ),
          if (s.extra > 0)
            FieldRow(
              label: 'Starting',
              hint: 'Month the extra begins',
              child: _PickerButton(
                key: const Key('f-extra-from'),
                text: s.extraFromYear == 0
                    ? monthYear(s.startYear, s.startMonth)
                    : monthYear(s.extraFromYear, s.extraFromMonth),
                onTap: () => _pickLoanMonth(
                  'Extra payments start',
                  s.extraFromYear == 0 ? s.startYear : s.extraFromYear,
                  s.extraFromYear == 0 ? s.startMonth : s.extraFromMonth,
                  (y, m) => update((s) {
                    s.extraFromYear = y;
                    s.extraFromMonth = m;
                  }),
                ),
              ),
            ),
          FieldRow(
            label: 'One-time payment',
            hint: 'Bonus, tax refund…',
            child: NumField(
              key: const Key('f-lump'),
              semanticLabel: 'One-time extra payment',
              prefix: '\$',
              max: 99999999,
              value: s.lump,
              onChanged: (v) => update((s) {
                s.lump = v;
                if (s.lumpYear == 0) {
                  // 기본은 1년 뒤 같은 달
                  s.lumpYear = s.startYear + 1;
                  s.lumpMonth = s.startMonth;
                }
              }),
            ),
          ),
          if (s.lump > 0)
            FieldRow(
              label: 'Paid in',
              child: _PickerButton(
                key: const Key('f-lump-when'),
                text: monthYear(s.lumpYear, s.lumpMonth),
                onTap: () => _pickLoanMonth(
                  'One-time payment',
                  s.lumpYear,
                  s.lumpMonth,
                  (y, m) => update((s) {
                    s.lumpYear = y;
                    s.lumpMonth = m;
                  }),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay every 2 weeks',
                        style: TextStyle(fontSize: 15, color: tk.text),
                      ),
                      Text(
                        'Half a payment every 2 weeks = 13 payments a year',
                        style: TextStyle(fontSize: 12, color: tk.muted),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  key: const Key('f-biweekly'),
                  value: s.biweekly,
                  activeTrackColor: tk.accent,
                  onChanged: (v) {
                    unfocus();
                    update((s) => s.biweekly = v);
                  },
                ),
              ],
            ),
          ),
          if (saved) ...[
            Container(
              key: const Key('extra-result'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tk.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debt-free ${duration(e.monthsSaved)} sooner',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tk.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: tk.text,
                        fontFeatures: tabular,
                      ),
                      children: [
                        const TextSpan(text: 'Save '),
                        TextSpan(
                          text: money(e.interestSaved),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' in interest'),
                        if (e.pmiSaved > 0) ...[
                          const TextSpan(text: ' + '),
                          TextSpan(
                            text: money(e.pmiSaved),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' PMI'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Paid off ${monthYear(e.withExtra.payoff!.$1, e.withExtra.payoff!.$2)}'
                    ' instead of ${monthYear(e.base.payoff!.$1, e.base.payoff!.$2)}',
                    style: TextStyle(fontSize: 13, color: tk.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Add a little each month and see how much sooner you’re debt-free.',
                style: TextStyle(fontSize: 13, color: tk.muted),
              ),
            ),
          Text(
            'Remaining balance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tk.text2,
            ),
          ),
          const SizedBox(height: 8),
          BalanceChart(
            key: const Key('balance-chart'),
            base: e?.base ?? res,
            withExtra: e?.withExtra,
          ),
          if (saved)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _key(tk.accent, 'With extra', solid: true),
                  const SizedBox(width: 16),
                  _key(tk.muted, 'Without', solid: false),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(Color c, String label, {required bool solid}) => Row(
    children: [
      Container(
        width: 16,
        height: 3,
        decoration: BoxDecoration(
          color: solid ? c : null,
          border: solid ? null : Border(top: BorderSide(color: c, width: 2)),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: Tk.of(context).text2)),
    ],
  );

  Widget _scheduleButton(Tk tk, LoanResult res, ExtraEffect? e) => SectionCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      key: const Key('open-schedule'),
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        unfocus();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ScheduleScreen(result: res, base: e?.base),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.table_rows_rounded, color: tk.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amortization schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tk.text,
                    ),
                  ),
                  Text(
                    'Every payment, by year or month',
                    style: TextStyle(fontSize: 12, color: tk.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tk.muted),
          ],
        ),
      ),
    ),
  );

  String _taxHint() {
    final st = stateByCode(s.stateCode);
    if (st != null && s.taxIsPercent && s.tax == st.propertyTax) {
      return '${st.name} average · per year';
    }
    return 'Per year';
  }

  String _salesHint() {
    final st = stateByCode(s.stateCode);
    if (st != null && s.salesTax == st.combinedSalesTax) {
      return '${st.name} state + avg. local';
    }
    return 'On price minus trade-in';
  }

  /// 주 고르기 — 집이면 재산세율, 자동차면 판매세율을 채운다.
  Widget _stateRow(Tk tk, {required bool forSales}) {
    final st = stateByCode(s.stateCode);
    return FieldRow(
      label: 'State',
      hint: forSales ? 'Fills in sales tax' : 'Fills in property tax',
      child: _PickerButton(
        key: const Key('f-state'),
        text: st?.name ?? 'Choose',
        onTap: () async {
          unfocus();
          final picked = await pickState(context, s.stateCode);
          if (picked == null) return;
          update((s) {
            s.stateCode = picked.code;
            if (forSales) {
              s.salesTax = picked.combinedSalesTax;
            } else {
              s.tax = picked.propertyTax;
              s.taxIsPercent = true;
            }
          });
        },
      ),
    );
  }

  Future<void> _pickLoanMonth(
    String title,
    int year,
    int month,
    void Function(int y, int m) onPicked,
  ) async {
    unfocus();
    final endYear = s.startYear + (s.termMonths / 12).ceil();
    final picked = await pickMonth(
      context,
      year,
      month,
      store.clock().year,
      title: title,
      first: s.startYear,
      last: endYear,
    );
    if (picked != null) onPicked(picked.$1, picked.$2);
  }

  Widget _footer(Tk tk) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      children: [
        Text(
          'Estimates only, not financial advice. Interest rates shown are '
          'examples — enter the rate from your lender.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: tk.muted, height: 1.4),
        ),
        TextButton(
          key: const Key('reset'),
          onPressed: () async {
            unfocus();
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Reset this calculator?'),
                content: const Text(
                  'All values go back to the starting examples.',
                ),
                actions: [
                  TextButton(
                    key: const Key('reset-cancel'),
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    key: const Key('reset-ok'),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await store.reset(kind);
              setState(() => feesOpen = false);
            }
          },
          child: Text('Reset to examples', style: TextStyle(color: tk.text2)),
        ),
      ],
    ),
  );
}

/// 맨 위 고정 카드 — 무엇을 고치든 바로 바뀌는 월 납입액.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.s,
    required this.res,
    required this.valid,
    required this.compact,
  });
  final Scenario s;
  final LoanResult res;
  final bool valid;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final total = valid ? res.monthlyTotal : 0.0;
    final cents = (total * 100).round();
    final big = Text.rich(
      key: const Key('monthly'),
      TextSpan(
        children: [
          TextSpan(text: '\$${group((cents ~/ 100).toString())}'),
          TextSpan(
            text: '.${(cents % 100).toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: compact ? 18 : 22, color: tk.text2),
          ),
        ],
      ),
      maxLines: 1,
      style: TextStyle(
        fontSize: compact ? 30 : 42,
        fontWeight: FontWeight.w800,
        color: tk.text,
        letterSpacing: -0.5,
        fontFeatures: tabular,
      ),
    );
    final label = Text(
      'Monthly payment',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: tk.text2,
      ),
    );
    final slices = s.hasFees
        ? [
            Slice('P&I', res.monthlyPI, tk.principal),
            Slice('Tax', res.monthlyTax, tk.tax),
            Slice('Insurance', res.monthlyInsurance, tk.insurance),
            Slice('HOA', res.monthlyHoa, tk.hoa),
            Slice('PMI', res.monthlyPmi, tk.pmi),
          ]
        : [
            Slice('Principal', res.loanAmount, tk.principal),
            Slice('Interest', res.totalInterest, tk.interest),
          ];
    return AnimatedContainer(
      key: const Key('result-card'),
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        compact ? 10 : 14,
        18,
        compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: tk.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: compact
            ? Row(
                children: [
                  Expanded(child: label),
                  FittedBox(child: big),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: big,
                  ),
                  if (s.toInput().hasExtras && valid)
                    Text(
                      _extraLine(s, res),
                      style: TextStyle(
                        fontSize: 13,
                        color: tk.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 10),
                  StackBar(slices: valid ? slices : const []),
                  const SizedBox(height: 8),
                  if (valid)
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        for (final sl in slices.where((x) => x.value > 0))
                          _dot(tk, sl.color, sl.label),
                        Text(
                          'Paid off ${monthYear(res.payoff!.$1, res.payoff!.$2)}',
                          style: TextStyle(fontSize: 12, color: tk.text2),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Enter a price and loan term to see your payment.',
                      style: TextStyle(fontSize: 13, color: tk.muted),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _dot(Tk tk, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: tk.text2)),
    ],
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({super.key, required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: tk.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: tk.text,
                  ),
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: 20, color: tk.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 첫 납입 달 고르기 — 이미 갚고 있는 대출도 넣을 수 있게 40년 전부터.
Future<(int, int)?> pickMonth(
  BuildContext context,
  int year,
  int month,
  int thisYear, {
  String title = 'First payment',
  int? first,
  int? last,
}) {
  final lo = first ?? thisYear - 40, hi = last ?? thisYear + 10;
  var y = year.clamp(lo, hi), m = month;
  return showModalBottomSheet<(int, int)>(
    context: context,
    backgroundColor: Tk.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) {
      final tk = Tk.of(c);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tk.text,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('month-done'),
                    onPressed: () => Navigator.pop(c, (y, m)),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      key: const Key('month-wheel'),
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(
                        initialItem: m - 1,
                      ),
                      onSelectedItemChanged: (i) => m = i + 1,
                      children: [
                        for (final n in monthsLong)
                          Center(
                            child: Text(n, style: TextStyle(color: tk.text)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      key: const Key('year-wheel'),
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(
                        initialItem: y - lo,
                      ),
                      onSelectedItemChanged: (i) => y = lo + i,
                      children: [
                        for (var k = lo; k <= hi; k++)
                          Center(
                            child: Text('$k', style: TextStyle(color: tk.text)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 위 카드의 추가 상환 한 줄.
String _extraLine(Scenario s, LoanResult res) {
  final parts = <String>[
    if (s.extra > 0) '${money(s.extra)}/mo',
    if (s.biweekly) 'bi-weekly',
    if (s.lump > 0) '${money(s.lump)} once',
  ];
  return '+ ${parts.join(' · ')} extra toward principal';
}

/// 주 고르기 시트 — 이름과 재산세·판매세 추정치를 같이 보여 준다.
Future<UsState?> pickState(BuildContext context, String? current) {
  return showModalBottomSheet<UsState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tk.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) {
      final tk = Tk.of(c);
      final cur = usStates.indexWhere((x) => x.code == current);
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose your state',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: tk.text,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('state-close'),
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'State averages (Tax Foundation 2026). Your county may differ — you can edit the rate.',
                  style: TextStyle(fontSize: 12, color: tk.muted),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const Key('state-list'),
                  controller: ScrollController(
                    initialScrollOffset: cur > 3 ? (cur - 3) * 56.0 : 0,
                  ),
                  itemCount: usStates.length,
                  itemExtent: 56,
                  itemBuilder: (c, k) {
                    final st = usStates[k];
                    final sel = st.code == current;
                    return ListTile(
                      key: Key('state-${st.code}'),
                      selected: sel,
                      selectedColor: tk.accent,
                      title: Text(
                        st.name,
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Property tax ${trimNum(st.propertyTax, 3)}% · Sales tax ${trimNum(st.combinedSalesTax, 3)}%',
                        style: TextStyle(fontSize: 12, color: tk.muted),
                      ),
                      trailing: sel
                          ? Icon(Icons.check_rounded, color: tk.accent)
                          : null,
                      onTap: () => Navigator.pop(c, st),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
