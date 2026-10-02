import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/day.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 30 days of NOAA highs/lows with sunrise/sunset and moon — opened by a rewarded video.
class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  final store = AppStore.i;

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => store.loadMonth());
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = store.station!;
    final now = store.clock();
    final m = store.month?.stationId == s.id ? store.month : null;
    final until = store.monthOpenUntil;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '30-day tides',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Palette.sub),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body(m, now)),
          if (until != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Open until ${deviceStamp(until)} · ${units(store.units)} above MLLW · '
                'times in ${s.zone.abbreviation(now)} · Not for navigation',
                key: const Key('month-footer'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Palette.faint),
              ),
            ),
          Ads.i.banner(),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  static String units(Units u) => u == Units.feet ? 'Feet' : 'Meters';

  Widget _body(dynamic m, DateTime now) {
    if (m == null) {
      if (store.monthLoading || store.monthError == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No data',
                key: Key('month-no-data'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                store.monthError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.sub),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('month-retry'),
                onPressed: () => store.loadMonth(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final days = buildDays(store.station!, m, now, count: 30);
    return ListView(
      key: const Key('month-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        if (store.monthError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Notice(
              text:
                  'Offline — showing the 30-day table saved ${deviceStamp(m.fetchedAt)}.',
            ),
          ),
        for (var i = 0; i < days.length; i++)
          DayRow(
            key: Key('month-day-$i'),
            day: days[i],
            index: i,
            selected: false,
            units: store.units,
            showSun: true,
          ),
      ],
    );
  }
}
