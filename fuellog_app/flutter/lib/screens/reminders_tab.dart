import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'log_tab.dart';
import 'reminder_form.dart';
import 'service_form.dart';

/// 정비 알림 목록 — 지난 것·곧인 것이 위. 막대는 주기 중 얼마나 왔는지.
class RemindersTab extends StatelessWidget {
  const RemindersTab({super.key});

  @override
  // 저장소가 바뀔 때마다 다시 그린다 (const 로 만든 탭은 부모가 다시 그려져도 안 그려진다)
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final v = s.vehicle!;
    final states = s.reminderStates(v.id);
    return ListView(
      key: const Key('reminders-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        BigButton(
          key: const Key('add-reminder'),
          label: 'Add reminder',
          icon: Icons.add_alarm_rounded,
          onPressed: () => openReminderForm(context),
        ),
        const SizedBox(height: 12),
        if (states.isEmpty)
          SectionCard(
            key: const Key('reminders-empty'),
            title: 'Never miss an oil change',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set a reminder by distance, time, or both. It resets every time you log that service.',
                  style: TextStyle(fontSize: 14, height: 1.35, color: tk.text2),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in ['Oil change', 'Tire rotation', 'Inspection', 'Registration'])
                      ActionChip(
                        key: Key('quick-$k'),
                        avatar: Icon(kindIcon(k), size: 18, color: tk.accent),
                        label: Text(k),
                        onPressed: () => openReminderForm(context, kind: k),
                      ),
                  ],
                ),
              ],
            ),
          ),
        for (final st in states) _ReminderCard(state: st),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            Notifier.i.supported
                ? 'Distance reminders estimate the date from your recent driving. Keep logging fill-ups and they stay accurate.'
                : 'This is a web preview — notifications work in the iPhone app.',
            style: TextStyle(fontSize: 12, height: 1.35, color: tk.muted),
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.state});
  final ReminderState state;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final f = s.fmt;
    final r = state.reminder;
    final c = switch (state.level) {
      ReminderLevel.overdue => tk.bad,
      ReminderLevel.soon => tk.warn,
      ReminderLevel.ok => tk.good,
      ReminderLevel.unknown => tk.muted,
    };
    final every = [
      if (r.everyMiles != null) f.dist(r.everyMiles!),
      if (r.everyMonths != null) '${r.everyMonths} month${r.everyMonths == 1 ? '' : 's'}',
    ].join(' or ');
    final est = state.estimatedDate != null && (state.dueDate == null || state.estimatedDate!.isBefore(state.dueDate!))
        ? (state.estimatePassed ? ' · likely due now' : ' · about ${fmtDate(state.estimatedDate!)}')
        : '';
    final last = state.baseDate == null ? 'not set' : fmtDate(state.baseDate!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tk.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('rem-${r.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => openReminderForm(context, edit: r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(kindIcon(r.kind), color: c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.kind,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text),
                          ),
                          Text(
                            '${dueText(state)}$est',
                            key: Key('rem-due-${r.id}'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: Key('rem-log-${r.id}'),
                      onPressed: () => openServiceForm(context, kind: r.kind),
                      child: const Text('Log it', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.level == ReminderLevel.unknown ? 0 : state.progress.clamp(0, 1).toDouble(),
                    minHeight: 7,
                    color: c,
                    backgroundColor: tk.surface2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Every $every · last $last${r.notify ? '' : ' · notifications off'}',
                  style: TextStyle(fontSize: 12, color: tk.muted, fontFeatures: tabular),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
