import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/controller.dart';
import '../core/engine.dart';
import '../core/location.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../core/units.dart';
import 'alert_sheet.dart';
import 'hud_screen.dart';
import 'settings_sheet.dart';
import 'speed_display.dart';
import 'widgets.dart';

/// 메인 속도계. 켜 두기만 하면 탭 없이 계속 보인다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final over = c.alert.over;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: over ? C.alertBg : C.bg,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(c: c),
                _GpsLine(c: c),
                if (c.preciseOff && c.access == Access.granted)
                  _PreciseOff(c: c),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        c.access == Access.granted ||
                            c.access == Access.checking
                        ? Column(
                            children: [
                              Expanded(child: speedView(c)),
                              SizedBox(
                                height: 30,
                                child: over
                                    ? Text(
                                        'Over your ${c.alert.limit} ${c.unit.label} alert',
                                        key: const Key('over-label'),
                                        style: const TextStyle(
                                          color: C.ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          )
                        : _AccessPanel(c: c),
                  ),
                ),
                _Actions(c: c),
                const SizedBox(height: 10),
                _TripCard(c: c),
                const SizedBox(height: 6),
                Ads.i.banner(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.c});
  final SpeedController c;

  static IconData icon(Mode m) => switch (m) {
    Mode.car => Icons.directions_car_filled,
    Mode.bike => Icons.directions_bike,
    Mode.run => Icons.directions_run,
    Mode.boat => Icons.directions_boat_filled,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.alert.over ? const Color(0x33000000) : C.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final m in Mode.values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: m == c.mode,
                      label: '${m.label} mode',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: Key('mode-${m.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => c.setMode(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: m == c.mode ? C.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon(m),
                                size: 18,
                                color: m == c.mode ? C.bg : C.sub,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  m.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    color: m == c.mode ? C.bg : C.sub,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('settings'),
          tooltip: 'Settings',
          onPressed: () => showSettingsSheet(context, c),
          icon: const Icon(Icons.settings, color: C.sub),
        ),
      ],
    ),
  );
}

class _GpsLine extends StatelessWidget {
  const _GpsLine({required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final e = c.engine;
    final acc = e.accuracy == null ? '' : ' · ±${e.accuracy!.round()} m';
    final (text, color) = !c.running
        ? (c.access == Access.checking ? 'Starting GPS…' : 'GPS off', C.muted)
        : switch (e.state) {
            GpsState.searching => ('Searching for GPS…', C.sub),
            GpsState.lost => ('No GPS signal', C.red),
            GpsState.weak => ('Weak GPS$acc', C.amber),
            GpsState.good || GpsState.strong => ('GPS$acc', C.accent),
          };
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GpsBars(c.running ? e.state : GpsState.searching),
          const SizedBox(width: 8),
          Text(
            text,
            key: const Key('gps'),
            style: TextStyle(
              color: c.alert.over ? C.ink : color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
            ),
          ),
          if (c.source.isDemo) ...[
            const SizedBox(width: 8),
            Container(
              key: const Key('demo'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEMO — simulated drive',
                style: TextStyle(
                  color: C.bg,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreciseOff extends StatelessWidget {
  const _PreciseOff({required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(
      color: C.amber.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_searching, color: C.amber, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Precise Location is off — speed can’t be measured.',
            style: TextStyle(color: C.amber, fontSize: 13),
          ),
        ),
        TextButton(
          key: const Key('fix-precise'),
          onPressed: c.openSettings,
          child: const Text('Fix'),
        ),
      ],
    ),
  );
}

/// 위치 권한이 없을 때 속도 자리에 보이는 안내. 막힌 길이 없게 항상 누를 버튼이 있다.
class _AccessPanel extends StatelessWidget {
  const _AccessPanel({required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final web = !c.source.canOpenSettings;
    final (title, body, button, key, action) = switch (c.access) {
      Access.blocked => (
        'Location is off for this app',
        web
            ? 'Allow location for this site in your browser settings, then tap Try Again.'
            : 'Open Settings → Location → choose “While Using the App”.',
        web ? 'Try Again' : 'Open Settings',
        web ? 'retry' : 'open-settings',
        web ? () => c.start(prompt: true) : c.openSettings,
      ),
      Access.servicesOff => (
        'Location Services are off',
        'Turn on Location Services in Settings → Privacy & Security, then come back.',
        web ? 'Try Again' : 'Open Settings',
        web ? 'retry' : 'open-settings',
        web ? () => c.start(prompt: true) : c.openSettings,
      ),
      _ => (
        'Location needed',
        'Speed is measured from your phone’s GPS. Your location stays on this device.',
        'Allow Location',
        'allow',
        () => c.start(prompt: true),
      ),
    };
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 56, color: C.sub),
            const SizedBox(height: 14),
            Text(
              title,
              key: const Key('access-title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: C.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.sub, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: Key(key),
              onPressed: action,
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              child: Text(
                button,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final gauge = c.display == Display.gauge;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: BigButton(
              key: const Key('alert'),
              icon: c.alertOn
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              label: c.alertOn
                  ? 'Alert ${c.alertLimit} ${c.unit.label}'
                  : 'Alert off',
              active: c.alertOn,
              semantic: c.alertOn
                  ? 'Speed alert ${c.alertLimit} ${c.unit.label}'
                  : 'Speed alert off',
              onTap: () => showAlertSheet(context, c),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BigButton(
              key: const Key('display'),
              icon: gauge ? Icons.pin_outlined : Icons.speed,
              label: gauge ? 'Digits' : 'Gauge',
              semantic: gauge ? 'Show digits' : 'Show gauge',
              onTap: () =>
                  c.setDisplay(gauge ? Display.digital : Display.gauge),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BigButton(
              key: const Key('hud'),
              icon: Icons.flip,
              label: 'HUD',
              semantic: 'HUD mode',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HudScreen(c: c),
                  fullscreenDialog: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.c});
  final SpeedController c;

  @override
  Widget build(BuildContext context) {
    final t = c.engine.trip;
    final u = c.unit;
    final m = c.mode;
    final pace = m.showsPace;
    String sp(double? ms) =>
        pace ? formatPace(ms, u) : formatSpeed(ms, u, m.decimals);
    final best = t.maxMs > 0 ? t.maxMs : null;
    return Container(
      key: const Key('trip'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: c.alert.over ? const Color(0x33000000) : C.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              onRed: c.alert.over,
              label: pace ? 'BEST' : 'MAX',
              value: best == null ? (pace ? '--:--' : '0') : sp(best),
              unit: pace ? '' : u.label.toLowerCase(),
            ),
          ),
          Expanded(
            child: StatTile(
              onRed: c.alert.over,
              label: pace ? 'AVG PACE' : 'AVG',
              value: sp(t.avgMs),
              unit: pace ? '' : u.label.toLowerCase(),
            ),
          ),
          Expanded(
            child: StatTile(
              onRed: c.alert.over,
              label: 'DIST',
              value: formatDistance(t.distance, u),
              unit: u.distLabel,
            ),
          ),
          Expanded(
            child: StatTile(
              onRed: c.alert.over,
              label: 'TIME',
              value: formatDuration(t.elapsed),
            ),
          ),
          IconButton(
            key: const Key('reset'),
            tooltip: 'Reset trip',
            onPressed: () => confirmReset(context, c),
            icon: const Icon(Icons.restart_alt, color: C.sub),
          ),
        ],
      ),
    );
  }
}

Future<void> confirmReset(BuildContext context, SpeedController c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset trip?'),
      content: const Text('Max, average, distance and time will be cleared.'),
      actions: [
        TextButton(
          key: const Key('reset-cancel'),
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('reset-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  if (ok == true) c.resetTrip();
}
