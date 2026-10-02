import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/format.dart';
import '../core/solunar.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// Asks to watch a rewarded video, then opens the 30-day calendar for 24 hours.
/// Returns true when the calendar is open.
Future<bool> unlockCalendarFlow(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.calendar_month, color: Palette.pine, size: 36),
      title: const Text('30-Day Calendar'),
      content: const Text(
        'Watch a short video to open the 30-day calendar for 24 hours. '
        'Today and the next 7 days are always free.',
      ),
      actions: [
        TextButton(
          key: const Key('unlock-cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          key: const Key('unlock-watch'),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Watch Video'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;

  // While the video loads (up to Ads.waitForVideo) show a small "Loading video…".
  final nav = Navigator.of(context, rootNavigator: true);
  var loadingShown = false;
  if (!Ads.i.isReady(RewardPlacement.calendar)) {
    loadingShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          key: Key('video-loading'),
          content: Row(
            children: [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: 16),
              Text('Loading video…'),
            ],
          ),
        ),
      ),
    );
  }
  final result = await Ads.i.showRewarded(RewardPlacement.calendar);
  if (loadingShown) nav.pop();
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case RewardResult.rewarded:
      await AppStore.i.unlockCalendar();
      messenger.showSnackBar(const SnackBar(content: Text('30-day calendar open for 24 hours')));
      return true;
    case RewardResult.closedEarly:
      messenger.showSnackBar(
        const SnackBar(content: Text('The video was closed early, so the calendar stays locked.')),
      );
      return false;
    case RewardResult.unavailable:
      // No video to show (no signal, no ad to fill): don't make people pay for our ad gap.
      await AppStore.i.unlockCalendar();
      messenger.showSnackBar(
        const SnackBar(content: Text('No video right now — the calendar is open for you anyway.')),
      );
      return true;
  }
}

/// 30 days from today, laid out by week. Tap a day to see it on the main screen.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final List<SolunarDay> _days = SolunarDay.week(AppStore.i.place!, AppStore.i.clock(), count: 30);

  @override
  Widget build(BuildContext context) {
    final first = _days.first.wallDay;
    final lead = first.weekday % 7; // Sunday-first weeks
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final (i, d) in _days.indexed) _cell(d, i),
    ];
    final best = [..._days]..sort((a, b) => b.score.total.compareTo(a.score.total));
    return Scaffold(
      appBar: AppBar(title: const Text('30-Day Calendar')),
      body: SafeArea(
        child: ListView(
          key: const Key('calendar-list'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            Text(
              AppStore.i.place!.name,
              style: const TextStyle(fontSize: 15, color: Palette.sub, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final w in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
                  Expanded(
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.sub),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.72,
              children: cells,
            ),
            const SizedBox(height: 18),
            const SectionTitle('Best days ahead'),
            for (final d in best.take(5))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: MoonIcon(illumination: d.phase.illumination, waxing: d.phase.waxing, size: 26),
                title: Text(dayLabel(d.wallDay), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(d.phase.phase.label),
                trailing: ScoreChip(score: d.score),
                onTap: () => Navigator.of(context).pop(d.wallDay),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(SolunarDay d, int i) {
    final c = Palette.rating(d.score.rating);
    final strong = d.score.rating == Rating.best || d.score.rating == Rating.good;
    return Semantics(
      button: true,
      label: '${dayLabel(d.wallDay)}, score ${d.score.total} ${d.score.rating.label}',
      child: InkWell(
        key: Key('cal-$i'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).pop(d.wallDay),
        child: Container(
          decoration: BoxDecoration(
            color: c.withValues(alpha: strong ? 1 : 0.55),
            borderRadius: BorderRadius.circular(10),
            border: i == 0 ? Border.all(color: Palette.ink, width: 2) : null,
          ),
          padding: const EdgeInsets.all(3),
          child: ExcludeSemantics(
            // Big text settings shrink to fit the cell instead of spilling out.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.wallDay.day == 1 || i == 0 ? '${monthName(d.wallDay)} ${d.wallDay.day}' : '${d.wallDay.day}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: strong ? Colors.white : Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MoonIcon(illumination: d.phase.illumination, waxing: d.phase.waxing, size: 14),
                  const SizedBox(height: 2),
                  Text(
                    '${d.score.total}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: strong ? Colors.white : Palette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
