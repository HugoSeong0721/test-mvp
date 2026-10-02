import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

enum Range { m3, m6, y1, all }

/// 차트 탭: 연비 추이 · 달마다 비용 · 단가 추이 · 숫자 요약. 전부 사용자가 적은 기록에서만 나온다.
class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  Range _range = Range.y1;

  DateTime? _since(DateTime now) => switch (_range) {
    Range.m3 => DateTime(now.year, now.month - 2),
    Range.m6 => DateTime(now.year, now.month - 5),
    Range.y1 => DateTime(now.year, now.month - 11),
    Range.all => null,
  };

  @override
  // 저장소가 바뀔 때마다 다시 그린다 (const 로 만든 탭은 부모가 다시 그려져도 안 그려진다)
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final f = s.fmt;
    final log = s.log;
    final now = s.now();
    final since = _since(now);
    final tanks = log.tanks.where((t) => since == null || !t.date.isBefore(since)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final months = log.monthly(now).where((m) => since == null || !DateTime(m.year, m.month).isBefore(since)).toList();
    final fills = log.fills.where((e) => since == null || !e.date.isBefore(since)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final avg = log.avgMpg(since: since);
    final hib = s.units.economy.higherIsBetter;
    double? best, worst;
    for (final t in tanks) {
      final e = f.economy(t.mpg);
      best = best == null ? e : (hib ? math.max(best, e) : math.min(best, e));
      worst = worst == null ? e : (hib ? math.min(worst, e) : math.max(worst, e));
    }
    final fuel = log.fuelSpent(since: since);
    final service = log.serviceSpent(since: since);
    final cpm = log.fuelCostPerMile(since: since);
    final price = log.avgPricePerGallon(since: since);

    Widget stat(String k, String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: tk.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 1, style: TextStyle(fontSize: 12, color: tk.muted)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: Key(k),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tk.text, fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );

    String dash(double? v, String Function(double) g) => v == null ? '—' : g(v);

    return ListView(
      key: const Key('charts-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Segmented<Range>(
            keyPrefix: 'range',
            items: const [(Range.m3, '3M'), (Range.m6, '6M'), (Range.y1, '1Y'), (Range.all, 'All')],
            value: _range,
            onChanged: (r) => setState(() => _range = r),
          ),
        ),
        SectionCard(
          title: 'Fuel economy',
          trailing: avg == null
              ? null
              : Text(
                  'avg ${f.econ(avg)}',
                  style: TextStyle(fontSize: 13, color: tk.muted, fontFeatures: tabular),
                ),
          child: tanks.length < 2
              ? _NotYet(
                  key: const Key('econ-empty'),
                  text: tanks.isEmpty
                      ? 'Log two full fill-ups to see your ${f.eShort} trend.'
                      : 'One tank so far: ${f.econ(tanks.first.mpg)}. The trend line starts with the next full fill-up.',
                )
              : TrendChart(
                  key: const Key('econ-chart'),
                  points: [for (final t in tanks) (t.date, f.economy(t.mpg))],
                  average: avg == null ? null : f.economy(avg),
                  color: tk.accent,
                  label: (v) => v.toStringAsFixed(1),
                  semantics: '${f.eShort} chart, ${tanks.length} tanks, average ${avg == null ? '' : f.econ(avg)}',
                ),
        ),
        SectionCard(
          title: 'Spending by month',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Legend(color: tk.fuel, label: 'Fuel'),
              const SizedBox(width: 10),
              _Legend(color: tk.service, label: 'Service'),
            ],
          ),
          child: months.every((m) => m.total == 0)
              ? const _NotYet(
                  key: Key('cost-empty'),
                  text: 'Your monthly spending shows here once you log fill-ups or service.',
                )
              : MonthBars(
                  key: const Key('cost-chart'),
                  months: months,
                  semantics: 'Spending chart, ${months.length} months, total ${money(fuel + service)}',
                ),
        ),
        SectionCard(
          title: 'Gas price you paid',
          child: fills.length < 2
              ? const _NotYet(key: Key('price-empty'), text: 'Shows the price per gallon of each fill-up.')
              : TrendChart(
                  key: const Key('price-chart'),
                  points: [for (final e in fills) (e.date, f.pricePerUnit(e.pricePerGallon))],
                  color: tk.service,
                  label: (v) => '\$${v.toStringAsFixed(2)}',
                  semantics: 'Gas price chart, ${fills.length} fill-ups',
                  height: 150,
                ),
        ),
        SectionCard(
          title: 'Numbers',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              stat('n-avg', 'Average', dash(avg, f.econ)),
              stat('n-best', 'Best tank', best == null ? '—' : '${best.toStringAsFixed(1)} ${f.eShort}'),
              stat('n-worst', 'Worst tank', worst == null ? '—' : '${worst.toStringAsFixed(1)} ${f.eShort}'),
              stat('n-dist', 'Distance measured', f.dist(log.trackedMiles(since: since))),
              stat('n-fuel', 'Fuel spent', money(fuel)),
              stat('n-service', 'Service & other', money(service)),
              stat('n-price', 'Avg price', dash(price, f.price)),
              stat('n-cpm', 'Fuel cost', dash(cpm, f.perDist)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Container(
      height: 110,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: tk.surface2, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.35, color: tk.text2),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Tk.of(context).muted)),
    ],
  );
}
