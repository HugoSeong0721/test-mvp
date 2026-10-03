import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'fill_form.dart';
import 'home_shell.dart';
import 'service_form.dart';

/// 기록 탭: 연비 요약 → [주유] [정비] 큰 버튼 → 곧 할 정비 → 달별 기록.
class LogTab extends StatelessWidget {
  const LogTab({super.key});

  @override
  // 저장소가 바뀔 때마다 다시 그린다 (const 로 만든 탭은 부모가 다시 그려져도 안 그려진다)
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = AppStore.i;
    final entries = s.entries;
    final items = <Widget>[
      _Summary(log: s.log),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: BigButton(
                key: const Key('add-fill'),
                label: 'Fill-up',
                icon: Icons.local_gas_station_rounded,
                onPressed: () => openFillForm(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BigButton(
                key: const Key('add-service'),
                label: 'Service',
                icon: Icons.build_rounded,
                filled: false,
                onPressed: () => openServiceForm(context),
              ),
            ),
          ],
        ),
      ),
      for (final r in s.dueReminders.take(3)) _DueRow(state: r),
      if (entries.isEmpty) const _Empty(),
    ];
    // 달마다 머리글 + 그 달 합계
    String? month;
    for (final e in entries) {
      final key = '${e.date.year}-${e.date.month}';
      if (key != month) {
        month = key;
        final from = DateTime(e.date.year, e.date.month), to = DateTime(e.date.year, e.date.month + 1);
        final total = s.log.fuelSpent(since: from, until: to) + s.log.serviceSpent(since: from, until: to);
        items.add(_MonthHeader(title: fmtMonthYear(e.date.year, e.date.month), total: total));
      }
      items.add(_EntryTile(entry: e));
    }
    items.add(const SizedBox(height: 16));
    return ListView.builder(
      key: const Key('log-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.log});

  /// 저장할 때마다 새로 만들어지는 계산 — 바뀌면 다시 그린다
  final VehicleLog log;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final f = s.fmt;
    final avg = log.avgMpg();
    final last = log.lastTank;
    final now = s.now();
    final month =
        log.fuelSpent(since: DateTime(now.year, now.month)) + log.serviceSpent(since: DateTime(now.year, now.month));
    final cpm = log.fuelCostPerMile();
    final hasFull = log.fills.any((e) => e.full);
    Widget stat(String k, String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                maxLines: 1,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text, fontFeatures: tabular),
              ),
            ),
          ],
        ),
      ),
    );
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    avg == null ? '—' : f.econNum(avg),
                    key: const Key('avg-economy'),
                    style: TextStyle(
                      fontSize: 52,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: avg == null ? tk.muted : tk.accent,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.eShort} average',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text2),
                      ),
                      if (avg == null)
                        Text(
                          hasFull ? 'Shows after your next full fill-up' : 'Shows after two full fill-ups',
                          key: const Key('avg-hint'),
                          style: TextStyle(fontSize: 12, color: tk.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('stat-last', 'Last tank', last == null ? '—' : f.econ(last.mpg)),
              const SizedBox(width: 8),
              stat('stat-cpm', 'Fuel cost', cpm == null ? '—' : f.perDist(cpm)),
              const SizedBox(width: 8),
              stat('stat-month', 'This month', money(month)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.state});
  final ReminderState state;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final over = state.level == ReminderLevel.overdue;
    final c = over ? tk.bad : tk.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('due-${state.reminder.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => HomeShell.goTo(context, 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(over ? Icons.error_rounded : Icons.schedule_rounded, color: c),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${state.reminder.kind} · ${dueText(state)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tk.text),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tk.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Overdue by 1,906 mi · 61 days", "In 203 mi or 38 days", "In 2,000 mi or by Apr 2, 2027" …
String dueText(ReminderState st) {
  final f = AppStore.i.fmt;
  final late = <String>[], ahead = <String>[];
  final mi = st.milesLeft, d = st.daysLeft;
  if (mi != null) (mi <= 0 ? late : ahead).add(f.dist(mi.abs()));
  if (d != null) {
    if (d < 0) {
      late.add('${-d} day${d == -1 ? '' : 's'}');
    } else {
      ahead.add(d == 0 ? 'today' : (d < 60 ? '$d day${d == 1 ? '' : 's'}' : 'by ${fmtDate(st.dueDate!)}'));
    }
  }
  if (late.isNotEmpty) return 'Overdue by ${late.join(' · ')}';
  if (ahead.isEmpty) return 'Set when it was last done';
  if (ahead.length == 1 && ahead.first == 'today') return 'Due today';
  final t = ahead.join(' or ');
  return t.startsWith('by ') ? 'Due $t' : 'In $t';
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    Widget tip(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 20, color: tk.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t, style: TextStyle(fontSize: 14, height: 1.35, color: tk.text2)),
          ),
        ],
      ),
    );
    return SectionCard(
      key: const Key('log-empty'),
      title: 'How it works',
      child: Column(
        children: [
          tip(
            Icons.local_gas_station_rounded,
            'Log each fill-up: odometer, gallons and price. Takes 10 seconds at the pump.',
          ),
          tip(
            Icons.speed_rounded,
            'MPG is measured from one full tank to the next. Partial fill-ups are fine — they count toward the next full tank.',
          ),
          tip(
            Icons.notifications_active_rounded,
            'Add oil changes and other service, and get a reminder when the next one is due.',
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title, required this.total});
  final String title;
  final double total;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tk.text),
            ),
          ),
          Text(
            money(total),
            style: TextStyle(fontSize: 14, color: tk.text2, fontFeatures: tabular),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final f = s.fmt;
    final fill = entry.fill;
    final svc = entry.service;
    late final String title, sub, amount;
    late final IconData icon;
    late final Color color;
    String? badge;
    Color? badgeColor;
    if (fill != null) {
      icon = Icons.local_gas_station_rounded;
      color = tk.fuel;
      title = '${f.vol(fill.volume)} · ${f.price(fill.pricePerGallon)}';
      sub = '${fmtDayMonth(fill.date)} · ${f.dist(fill.odometer)}${fill.note.isEmpty ? '' : ' · ${fill.note}'}';
      amount = money(fill.cost);
      final info = s.log.info[fill.id];
      switch (info?.role) {
        case FillRole.tank:
          badge = f.econ(info!.tank!.mpg);
          badgeColor = tk.accent;
        case FillRole.partial:
          badge = 'Partial';
          badgeColor = tk.muted;
        case FillRole.first:
          badge = 'First fill';
          badgeColor = tk.muted;
        case FillRole.skipped:
          badge = 'Skipped';
          badgeColor = tk.warn;
        case FillRole.beforeFirst:
          badge = 'Partial';
          badgeColor = tk.muted;
        case null:
          break;
      }
    } else {
      icon = kindIcon(svc!.kind);
      color = tk.service;
      title = svc.kind;
      final odo = svc.odometer == null ? '' : ' · ${f.dist(svc.odometer!)}';
      sub = '${fmtDayMonth(svc.date)}$odo${svc.note.isEmpty ? '' : ' · ${svc.note}'}';
      amount = money(svc.cost);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: tk.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('entry-${entry.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => fill != null ? openFillForm(context, edit: fill) : openServiceForm(context, edit: svc),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tk.text,
                          fontFeatures: tabular,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: tk.muted, fontFeatures: tabular),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tk.text,
                        fontFeatures: tabular,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
