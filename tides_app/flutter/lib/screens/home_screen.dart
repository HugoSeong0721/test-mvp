import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/day.dart';
import '../core/format.dart';
import '../core/station.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/tides.dart';
import '../core/zone.dart';
import 'about_sheet.dart';
import 'stations_screen.dart';
import 'widgets.dart';

/// The one screen: today's curve, what the tide is doing now, and the week.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final store = AppStore.i;
  int selected = 0; // day index in the week list
  String? _stationId;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_changed);
    _stationId = store.station?.id;
    // Keep "now", the countdown and the day list current while open (crossing midnight too).
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
      store.refresh();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => store.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      setState(() {});
      store.resume();
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (store.station?.id != _stationId) {
        _stationId = store.station?.id;
        selected = 0;
      }
    });
  }

  Future<void> _openStations() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const StationsScreen()));

  @override
  Widget build(BuildContext context) {
    final s = store.station!;
    final now = store.clock();
    final days = buildDays(s, store.data, now);
    if (selected >= days.length) selected = 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(station: s, onOpen: _openStations),
          Expanded(child: _body(s, days, now)),
          Ads.i.banner(),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ]),
      ),
    );
  }

  Widget _body(Station s, List<DayInfo> days, DateTime now) {
    final d = store.data;
    if (d == null || !days.first.hasData && !_partly(days.first)) {
      if (store.loading) {
        return const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Getting NOAA predictions…', style: TextStyle(color: Palette.sub)),
          ]),
        );
      }
      return _NoData(
        message: store.error ??
            (d == null ? 'No predictions saved for this station yet.' : 'Saved predictions don’t reach today.'),
        stamp: d == null ? null : 'Last updated ${deviceStamp(d.fetchedAt)}',
        onRetry: () => store.refresh(force: true),
        onSearch: _openStations,
      );
    }
    final day = days[selected];
    return Column(children: [
      if (store.offline)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Notice(
            key: const Key('offline-notice'),
            text: 'Offline — showing predictions saved ${deviceStamp(d.fetchedAt)}.',
          ),
        ),
      _NowCard(data: d, station: s, now: now, units: store.units),
      const SizedBox(height: 10),
      _DayCard(day: day, now: selected == 0 ? now : null, units: store.units),
      const SizedBox(height: 8),
      Expanded(
        child: ListView(
          key: const Key('week-list'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (var i = 0; i < days.length; i++)
              _DayRow(
                key: Key('day-$i'),
                day: days[i],
                index: i,
                selected: i == selected,
                units: store.units,
                onTap: () => setState(() => selected = i),
              ),
            const SizedBox(height: 10),
            _Footer(station: s, data: d, now: now, loading: store.loading),
          ],
        ),
      ),
    ]);
  }

  bool _partly(DayInfo day) => day.events.isNotEmpty;
}

class _Header extends StatelessWidget {
  const _Header({required this.station, required this.onOpen});
  final Station station;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.i;
    final fav = store.isFavorite(station);
    final where = [if (station.stateName.isNotEmpty) station.stateName, 'NOAA ${station.id}'].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 6),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Change station',
            child: InkWell(
              key: const Key('station-button'),
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (store.followLocation)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.near_me, size: 16, color: Palette.sea),
                      ),
                    Flexible(
                      child: Text(station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.expand_more, size: 22, color: Palette.sub),
                  ]),
                  Text(where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Palette.sub)),
                ]),
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('favorite-button'),
          tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => store.toggleFavorite(station),
          icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: fav ? const Color(0xFFF2A900) : Palette.sub, size: 28),
        ),
        IconButton(
          key: const Key('settings-button'),
          tooltip: 'Settings',
          onPressed: () => showAboutSheet(context),
          icon: const Icon(Icons.tune_rounded, color: Palette.sub),
        ),
      ]),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.data, required this.station, required this.now, required this.units});
  final TideData data;
  final Station station;
  final DateTime now;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final next = data.nextEvent(now);
    final h = data.heightAt(now);
    final rising = next?.isHigh ?? false;
    final color = rising ? Palette.rising : Palette.falling;
    final after = next == null ? null : data.nextEvent(next.time);
    return Container(
      key: const Key('now-card'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(rising ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(rising ? 'Rising' : 'Falling',
                  key: const Key('trend'),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 8),
              if (h != null)
                Flexible(
                  child: Text('${height(h, units)} now',
                      key: const Key('height-now'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.ink)),
                ),
            ]),
            const SizedBox(height: 2),
            if (next != null) _line(next, true),
            if (after != null) _line(after, false),
          ]),
        ),
      ]),
    );
  }

  Widget _line(TideEvent e, bool first) {
    final what = e.isHigh ? 'High' : 'Low';
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '$what ${height(e.feet, units)} at ${clock(e.time, station.zone)}',
            style: TextStyle(fontWeight: first ? FontWeight.w700 : FontWeight.w500)),
        TextSpan(text: '  ${until(e.time.difference(now))}', style: const TextStyle(color: Palette.sub)),
      ]),
      key: Key(first ? 'next-event' : 'after-event'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14.5, color: Palette.ink),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.now, required this.units});
  final DayInfo day;
  final DateTime? now;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final z = day.station.zone;
    final sun = day.sun;
    final sunText = sun.alwaysUp
        ? 'Sun up all day'
        : sun.alwaysDown
            ? 'No sunrise'
            : '${clock(sun.sunrise!, z)} – ${clock(sun.sunset!, z)}';
    final title = now != null ? 'Today · ${dayLabel(day.wallDay)}' : '${longDay(day.wallDay)} · ${monthDay(day.wallDay)}';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Expanded(
              child: Text(title,
                  key: const Key('chart-title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Text(units == Units.feet ? 'feet' : 'meters', style: const TextStyle(fontSize: 12, color: Palette.faint)),
          ]),
        ),
        SizedBox(height: 190, child: TideChart(day: day, units: units, now: now)),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
          // Scales down a little on narrow phones instead of cutting the moon phase off.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wb_sunny_outlined, size: 17, color: Color(0xFFE0A100)),
              const SizedBox(width: 5),
              Text(sunText, key: const Key('sun-times'), style: const TextStyle(fontSize: 13, color: Palette.sub)),
              const SizedBox(width: 12),
              MoonIcon(illumination: day.moon.illumination, waxing: day.moon.waxing),
              const SizedBox(width: 5),
              Text('${day.moon.phase.label} · ${(day.moon.illumination * 100).round()}%',
                  key: const Key('moon-phase'), style: const TextStyle(fontSize: 13, color: Palette.sub)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.day,
    required this.index,
    required this.selected,
    required this.units,
    required this.onTap,
  });
  final DayInfo day;
  final int index;
  final bool selected;
  final Units units;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = day.station.zone;
    final name = index == 0 ? 'Today' : shortDay(day.wallDay);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Palette.seaLight : Palette.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(children: [
              SizedBox(
                width: 60,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    MoonIcon(illumination: day.moon.illumination, waxing: day.moon.waxing, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(monthDay(day.wallDay),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(fontSize: 11.5, color: Palette.sub)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(width: 6),
              if (day.events.isEmpty)
                const Expanded(child: Text('No data', style: TextStyle(color: Palette.sub)))
              else
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: i < day.events.length ? _ev(day.events[i], z) : const SizedBox.shrink(),
                  ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ev(TideEvent e, StationZone z) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(e.isHigh ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              size: 18, color: e.isHigh ? Palette.sea : Palette.falling),
          Flexible(
            child: Text(clock(e.time, z, compact: true),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(height(e.feet, units),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(fontSize: 12, color: Palette.sub)),
        ),
      ]);
}

class _Footer extends StatelessWidget {
  const _Footer({required this.station, required this.data, required this.now, required this.loading});
  final Station station;
  final TideData data;
  final DateTime now;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final zone = station.zone.abbreviation(now);
    final curve = data.hasOfficialCurve
        ? 'Curve: NOAA 6-minute predictions.'
        : 'NOAA publishes only high/low times here; the curve between them is estimated.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'NOAA tide predictions · heights above MLLW · times in $zone. $curve\n'
        '${loading ? 'Updating…' : 'Updated ${deviceStamp(data.fetchedAt)}'} · Not for navigation.',
        key: const Key('footer'),
        style: const TextStyle(fontSize: 11.5, color: Palette.faint, height: 1.4),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.message, required this.onRetry, required this.onSearch, this.stamp});
  final String message;
  final String? stamp;
  final VoidCallback onRetry;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: Palette.faint),
            const SizedBox(height: 10),
            const Text('No data', key: Key('no-data'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Palette.sub)),
            if (stamp != null) ...[
              const SizedBox(height: 4),
              Text(stamp!, style: const TextStyle(color: Palette.faint, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            TextButton(onPressed: onSearch, child: const Text('Choose another station')),
          ]),
        ),
      );
}
