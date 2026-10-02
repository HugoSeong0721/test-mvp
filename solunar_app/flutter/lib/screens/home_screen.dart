import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/astro.dart';
import '../core/format.dart';
import '../core/places.dart';
import '../core/solunar.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/zone.dart';
import 'calendar_screen.dart';
import 'places_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// The one main screen: score, what's on now, periods, shooting light, sun & moon.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _tick;

  /// Local date picked in the week strip or the 30-day calendar; null = today.
  DateTime? _picked;

  /// A new list per day/place (keyed below) so it always opens at the top.
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Countdowns move every minute; a 20 s tick keeps them within the minute.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => AppStore.i.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppStore.i.resume();
      if (mounted) setState(() {});
    }
  }

  void _pick(DateTime? wallDay) => setState(() => _picked = wallDay);

  Future<void> _openPlaces() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlacesScreen()));
    if (mounted) setState(() => _picked = null);
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  Future<void> _openCalendar() async {
    final store = AppStore.i;
    if (!store.calendarOpen) {
      final ok = await unlockCalendarFlow(context);
      if (!ok || !mounted) return;
    }
    final picked = await Navigator.of(context)
        .push<DateTime>(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    if (picked != null && mounted) _pick(picked);
  }

  Future<void> _toggleFavorite(Place p) async {
    final store = AppStore.i;
    final messenger = ScaffoldMessenger.of(context);
    if (store.isFavorite(p)) {
      await store.removeFavorite(p);
      messenger.showSnackBar(const SnackBar(content: Text('Removed from saved places')));
      return;
    }
    String? name;
    if (p.isGps) {
      name = await _askName(p);
      if (name == null) return;
    }
    await store.addFavorite(p, name: name);
    messenger.showSnackBar(const SnackBar(content: Text('Saved')));
  }

  Future<String?> _askName(Place p) {
    final near = p.detail?.replaceFirst(RegExp(r'^(near|in) '), '');
    final ctl = TextEditingController(text: near == null ? 'My spot' : 'Spot near ${near.split(',').first}');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this spot'),
        content: TextField(
          key: const Key('fav-name'),
          controller: ctl,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Name, e.g. Deer stand'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            key: const Key('fav-cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('fav-save'),
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final store = AppStore.i;
    final place = store.place!;
    final now = store.clock();
    final days = store.days();
    final today = days.first;
    var picked = _picked;
    if (picked != null && !picked.isAfter(today.wallDay)) picked = null; // midnight passed
    final day = picked == null
        ? today
        : days.firstWhere((d) => d.wallDay == picked, orElse: () => SolunarDay(place, picked!));
    final isToday = identical(day, today);
    final zone = day.zone;
    final fav = store.isFavorite(place);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        // Its own button node: inside the AppBar title it would otherwise be read only as a heading.
        title: Semantics(
          container: true,
          button: true,
          label:
              'Place: ${place.name}${place.detail == null ? '' : ', ${place.detail}'}. '
              'Times in ${zone.abbreviation(now)}. Change place',
          excludeSemantics: true,
          child: InkWell(
            key: const Key('place-button'),
            borderRadius: BorderRadius.circular(10),
            onTap: _openPlaces,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(place.isGps ? Icons.near_me : Icons.place_outlined, size: 20, color: Palette.pine),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          place.name,
                          key: const Key('place-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          [if (place.detail != null) place.detail!, zone.abbreviation(now)].join(' · '),
                          key: const Key('place-detail'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Palette.sub),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more, color: Palette.sub),
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (store.locating)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            key: const Key('fav-toggle'),
            tooltip: fav ? 'Remove from saved' : 'Save place',
            onPressed: () => _toggleFavorite(place),
            icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? Palette.major : Palette.ink),
          ),
          IconButton(
            key: const Key('settings'),
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: _WeekStrip(
                days: days.take(7).toList(),
                selected: day.wallDay,
                onPick: (d) => _pick(d == today.wallDay ? null : d),
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                // Switching day or place starts a fresh list at the top. (Jumping an existing
                // list to the top in the frame that drops the "now" card made it correct its
                // offset from stale positions and stop part-way down — caught by the robot test.)
                key: ValueKey('${place.key}|${place.name}|${day.wallDay}'),
                child: ListView(
                  key: const Key('home-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    _ScoreCard(day: day, todayWall: today.wallDay, onHow: () => showScoreSheet(context, day)),
                    const SizedBox(height: 12),
                    if (isToday) ...[
                      _NowCard(status: NowStatus.at(now, days.take(3).toList()), zone: zone, now: now),
                      const SizedBox(height: 12),
                    ],
                    _PeriodsCard(day: day, now: isToday ? now : null),
                    const SizedBox(height: 12),
                    _LegalCard(
                      day: day,
                      tomorrow: days.length > 1 ? days[1] : null,
                      isToday: isToday,
                      now: now,
                      before: store.beforeSunrise,
                      after: store.afterSunset,
                      onChange: _openSettings,
                    ),
                    const SizedBox(height: 12),
                    _SunMoonCard(day: day),
                    const SizedBox(height: 12),
                    _CalendarButton(open: store.calendarOpen, onTap: _openCalendar),
                    const SizedBox(height: 18),
                    const Text(
                      'Worked out on your phone from the positions of the sun and moon — no signal needed. '
                      'Solunar times are a guide, not a promise: weather, water and pressure matter too.',
                      key: Key('footer'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Palette.faint, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            Ads.i.banner(),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days, required this.selected, required this.onPick});
  final List<SolunarDay> days;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < days.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(child: _dayChip(days[i], i)),
      ],
    ],
  );

  Widget _dayChip(SolunarDay d, int i) {
    final sel = d.wallDay == selected;
    final c = Palette.rating(d.score.rating);
    return Semantics(
      button: true,
      selected: sel,
      label: '${longDay(d.wallDay)} ${monthDay(d.wallDay)}, score ${d.score.total} ${d.score.rating.label}',
      child: InkWell(
        key: Key('day-$i'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPick(d.wallDay),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: sel ? Palette.ink : Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? Palette.ink : Palette.line),
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(
                  i == 0 ? 'Today' : shortDay(d.wallDay),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white70 : Palette.sub,
                  ),
                ),
                Text(
                  '${d.wallDay.day}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: sel ? Colors.white : Palette.ink),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 26,
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
                  child: Text(
                    '${d.score.total}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: d.score.rating == Rating.best || d.score.rating == Rating.good
                          ? Colors.white
                          : Palette.ink,
                    ),
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.day, required this.todayWall, required this.onHow});
  final SolunarDay day;
  final DateTime todayWall;
  final VoidCallback onHow;

  @override
  Widget build(BuildContext context) {
    final rel = relativeDay(day.wallDay, todayWall);
    return Panel(
      child: Row(
        children: [
          Semantics(
            label: 'Solunar score ${day.score.total} out of 100, ${day.score.rating.label}',
            child: ExcludeSemantics(child: ScoreRing(score: day.score, size: 112)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rel == 'Today' || rel == 'Tomorrow' ? '$rel · ${dayLabel(day.wallDay)}' : rel,
                  key: const Key('day-title'),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Palette.sub),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.score.rating.label} day for fishing & hunting',
                  key: const Key('day-headline'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    MoonIcon(illumination: day.phase.illumination, waxing: day.phase.waxing, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${day.phase.phase.label} · ${(day.phase.illumination * 100).round()}%',
                        key: const Key('day-phase'),
                        style: const TextStyle(fontSize: 14, color: Palette.sub),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('how-scored'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onHow,
                  child: const Text('How is this scored?', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.status, required this.zone, required this.now});
  final NowStatus status;
  final PlaceZone zone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cur = status.current, next = status.next;
    if (cur == null && next == null) return const SizedBox.shrink();
    final active = cur != null;
    final p = cur ?? next!;
    final major = p.kind == PeriodKind.major;
    final color = major ? Palette.major : const Color(0xFFC8962E);
    final title = active ? '${p.kind.label.toUpperCase()} PERIOD NOW' : 'NEXT: ${p.kind.label.toUpperCase()} PERIOD';
    final line = active
        ? 'Until ${clock(p.end, zone)} · ${duration(p.end.difference(now))} left'
        : '${span(p.start, p.end, zone)} · starts in ${duration(p.start.difference(now))}';
    return Container(
      key: const Key('now-card'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: active ? color : Palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? color : Palette.line),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.bolt : Icons.schedule, color: active ? Colors.white : color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('now-title'),
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  key: const Key('now-line'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Palette.ink,
                  ),
                ),
                Text(
                  p.event.kind.label + (active ? '' : ' ${clock(p.center, zone)}'),
                  style: TextStyle(fontSize: 12.5, color: active ? Colors.white70 : Palette.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodsCard extends StatelessWidget {
  const _PeriodsCard({required this.day, this.now});
  final SolunarDay day;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final z = day.zone;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Solunar periods'),
          DayTimeline(day: day, now: now),
          const SizedBox(height: 6),
          const TimelineLegend(),
          const SizedBox(height: 10),
          if (day.periods.isEmpty)
            const Text(
              'No moonrise, moonset or moon overhead/underfoot on this day here.',
              style: TextStyle(color: Palette.sub),
            ),
          for (final (i, p) in day.periods.indexed)
            Padding(
              key: Key('period-$i'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: p.kind == PeriodKind.major ? Palette.major : Palette.minor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.kind.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.kind == PeriodKind.major ? Colors.white : Palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          span(p.start, p.end, z),
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${p.event.kind.label} ${clock(p.center, z)}',
                          style: const TextStyle(fontSize: 12.5, color: Palette.sub),
                        ),
                      ],
                    ),
                  ),
                  if (now != null && p.contains(now!))
                    const Text(
                      'NOW',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Palette.major),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.day,
    required this.tomorrow,
    required this.isToday,
    required this.now,
    required this.before,
    required this.after,
    required this.onChange,
  });
  final SolunarDay day;
  final SolunarDay? tomorrow;
  final bool isToday;
  final DateTime now;
  final int before;
  final int after;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final z = day.zone;
    final legal = day.legalLight(before, after);
    String label;
    String big;
    String? sub;
    if (legal == null) {
      label = 'Legal shooting light';
      big = day.sun.alwaysUp ? 'Sun up all day' : 'No sunrise today';
    } else if (!isToday) {
      label = 'Legal shooting light';
      big = span(legal.start, legal.end, z);
    } else if (now.isBefore(legal.start)) {
      label = 'Shooting light starts in';
      big = duration(legal.start.difference(now));
      sub = span(legal.start, legal.end, z);
    } else if (now.isBefore(legal.end)) {
      label = 'Shooting light ends in';
      big = duration(legal.end.difference(now));
      sub = span(legal.start, legal.end, z);
    } else {
      label = 'Shooting light ended ${clock(legal.end, z)}';
      final t = tomorrow?.legalLight(before, after);
      big = t == null ? 'Done for today' : 'Tomorrow ${clock(t.start, z)}';
      sub = t == null ? null : 'Starts in ${duration(t.start.difference(now))}';
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Hunting', trailing: Icon(Icons.wb_twilight, size: 18, color: Palette.sub)),
          Text(
            label,
            key: const Key('legal-label'),
            style: const TextStyle(fontSize: 14.5, color: Palette.sub, fontWeight: FontWeight.w600),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              big,
              key: const Key('legal-big'),
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
            ),
          ),
          if (sub != null)
            Text(
              sub,
              key: const Key('legal-sub'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_offset(before)} before sunrise to ${_offset(after)} after sunset. '
                  'Rules differ by state and species — check your regulations.',
                  key: const Key('legal-rule'),
                  style: const TextStyle(fontSize: 12.5, color: Palette.sub, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('legal-change'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: onChange,
                child: const Text('Change'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _offset(int m) => m == 0 ? '0 min' : '$m min';
}

class _SunMoonCard extends StatelessWidget {
  const _SunMoonCard({required this.day});
  final SolunarDay day;

  @override
  Widget build(BuildContext context) {
    final z = day.zone;
    String t(DateTime? x) => x == null ? '—' : clock(x, z);
    final rise = day.event(MoonEventKind.rise)?.time;
    final set = day.event(MoonEventKind.set)?.time;
    final mid = day.start.add(const Duration(hours: 12));
    final nextFull = z.dayOf(nextPrincipalPhase(MoonPhase.fullMoon, mid));
    final nextNew = z.dayOf(nextPrincipalPhase(MoonPhase.newMoon, mid));
    Widget cell(String k, String label, String value, IconData icon) => Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: Palette.sub),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Palette.sub)),
                Text(
                  value,
                  key: Key(k),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Sun & moon'),
          Row(
            children: [
              cell('sunrise', 'Sunrise', t(day.sun.sunrise), Icons.wb_sunny_outlined),
              cell('sunset', 'Sunset', t(day.sun.sunset), Icons.wb_twilight),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              cell('moonrise', 'Moonrise', t(rise), Icons.arrow_upward),
              cell('moonset', 'Moonset', t(set), Icons.arrow_downward),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              cell('next-full', 'Next full moon', monthDay(nextFull), Icons.circle),
              cell('next-new', 'Next new moon', monthDay(nextNew), Icons.circle_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Palette.pineLight,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const Key('open-calendar'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Palette.pine, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('30-Day Calendar', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  Text(
                    open ? 'Open — plan the best days ahead' : 'Watch a short video to open it for 24 hours',
                    key: const Key('calendar-hint'),
                    style: const TextStyle(fontSize: 13, color: Palette.sub),
                  ),
                ],
              ),
            ),
            Icon(open ? Icons.chevron_right : Icons.play_circle_outline, color: Palette.pine),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet that shows the three parts of the day's score.
Future<void> showScoreSheet(BuildContext context, SolunarDay day) {
  final s = day.score;
  Widget row(String k, String title, String detail, int pts, int max) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 13.5, color: Palette.sub, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$pts / $max',
          key: Key(k),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
  final ageDays = day.phase.age / 360 * 29.53;
  final toNewFull = [ageDays, (ageDays - 14.77).abs(), 29.53 - ageDays].reduce((a, b) => a < b ? a : b);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('How the score works', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    key: const Key('score-close'),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${dayLabel(day.wallDay)}: ${s.total} / 100 (${s.rating.label})',
                style: const TextStyle(fontSize: 15, color: Palette.sub),
              ),
              const Divider(height: 22),
              row(
                'score-phase',
                'Moon phase',
                '${day.phase.phase.label}, ${toNewFull.toStringAsFixed(toNewFull < 1 ? 1 : 0)} days from a new or full moon. '
                    'New and full moon score highest, the quarter moons lowest.',
                s.phasePoints,
                Score.phaseMax,
              ),
              row(
                'score-timing',
                'Sunrise & sunset',
                'How closely a Major or Minor period lines up with sunrise and sunset — dawn and dusk are prime times.',
                s.timingPoints,
                Score.timingMax,
              ),
              row(
                'score-distance',
                'Moon distance',
                '${thousands((day.distanceKm / 1.609344).round())} miles away. '
                    'A closer moon (perigee) pulls harder and scores higher.',
                s.distancePoints,
                Score.distanceMax,
              ),
              const Divider(height: 22),
              const Text(
                'Major periods are when the moon is overhead or underfoot (±1 hour); Minor periods are moonrise and moonset '
                '(±30 minutes). This is the classic solunar theory of John Alden Knight (1926), worked out from the sun and moon '
                'for your spot. It is a guide, not a guarantee — weather, water temperature and air pressure matter too.',
                style: TextStyle(fontSize: 13.5, color: Palette.sub, height: 1.45),
              ),
              const SizedBox(height: 10),
              const Text(
                'Best 70+ · Good 50–69 · Fair 30–49 · Slow under 30',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
