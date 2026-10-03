import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/format.dart';
import '../core/loan.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// 상환표 — 연 단위/월 단위, 해마다 원금·이자 막대.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.result, this.base});

  /// 화면에 보여 줄 상환 (추가 상환 포함).
  final LoanResult result;

  /// 추가 상환이 있으면 비교용 원래 상환.
  final LoanResult? base;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool yearly = true;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final r = widget.result;
    final years = r.yearly;
    final hasExtra = r.input.hasExtras;
    final payoff = r.payoff!;
    final colStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: tk.muted,
    );

    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(
        backgroundColor: tk.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Amortization schedule',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          key: const Key('back'),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: CustomScrollView(
        key: const Key('schedule-list'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _stat(tk, 'Loan', money(r.loanAmount)),
                        _stat(tk, 'Interest', money(r.totalInterest)),
                        _stat(
                          tk,
                          'Paid off',
                          monthYear(payoff.$1, payoff.$2),
                          key: const Key('sched-payoff'),
                        ),
                      ],
                    ),
                    if (hasExtra && widget.base != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Includes your extra payments — '
                          '${r.months} payments instead of ${widget.base!.months}.',
                          style: TextStyle(fontSize: 12, color: tk.accent),
                        ),
                      ),
                    const SizedBox(height: 14),
                    YearlyBars(key: const Key('yearly-bars'), rows: years),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _legend(tk, tk.principal, 'Principal'),
                        const SizedBox(width: 16),
                        _legend(tk, tk.interest, 'Interest'),
                        const Spacer(),
                        Text(
                          'paid each year',
                          style: TextStyle(fontSize: 12, color: tk.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Segmented<bool>(
                keyPrefix: 'view',
                items: const [(true, 'Yearly'), (false, 'Monthly')],
                value: yearly,
                onChanged: (v) => setState(() => yearly = v),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              color: tk.bg,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(yearly ? 'Year' : 'Month', style: colStyle),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Principal',
                        textAlign: TextAlign.right,
                        style: colStyle,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Interest',
                        textAlign: TextAlign.right,
                        style: colStyle,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Balance',
                        textAlign: TextAlign.right,
                        style: colStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: yearly ? years.length : r.schedule.length,
              itemBuilder: (c, k) {
                if (yearly) {
                  final y = years[k];
                  return _row(
                    tk,
                    k,
                    '${y.year}',
                    money(y.totalPrincipal),
                    money(y.interest),
                    money(y.balance),
                    key: Key('row-y$k'),
                  );
                }
                final p = r.schedule[k];
                return _row(
                  tk,
                  // 해마다 줄무늬를 바꿔 연도 경계가 보이게
                  p.year - r.schedule.first.year,
                  monthYear(p.year, p.month),
                  money2(p.totalPrincipal),
                  money2(p.interest),
                  money2(p.balance),
                  key: Key('row-m$k'),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(top: false, child: Ads.i.banner()),
    );
  }

  Widget _stat(Tk tk, String k, String v, {Key? key}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 12, color: tk.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v,
            key: key,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tk.text,
              fontFeatures: tabular,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _legend(Tk tk, Color c, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: tk.text2)),
    ],
  );

  Widget _row(
    Tk tk,
    int stripe,
    String when,
    String principal,
    String interest,
    String balance, {
    Key? key,
  }) {
    final st = TextStyle(fontSize: 13, color: tk.text, fontFeatures: tabular);
    Widget cell(String s, int flex) => Expanded(
      flex: flex,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(s, style: st),
      ),
    );
    return Container(
      key: key,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: stripe.isEven ? tk.surface : tk.surface2,
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(when, style: st.copyWith(fontWeight: FontWeight.w600)),
          ),
          cell(principal, 4),
          cell(interest, 4),
          cell(balance, 5),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  double get minExtent => 32;
  @override
  double get maxExtent => 32;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: color,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}
