import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/controller.dart';
import '../core/levels.dart';
import '../core/meter.dart';
import '../core/share.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'guide_screen.dart';
import 'history_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// 첫 화면: 큰 게이지 + 쉬운 비유 + 평균·최대·시간 + 최근 1분 그래프.
class MeterScreen extends StatefulWidget {
  const MeterScreen({super.key, this.autoStart = false});

  /// 안내 화면에서 넘어오면 바로 측정을 시작한다.
  final bool autoStart;

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> with WidgetsBindingObserver {
  final ctl = MeterController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ctl.addListener(_onCtl);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ctl.start());
    }
  }

  String? _lastError;
  void _onCtl() {
    final e = ctl.error;
    if (e != null && e != _lastError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    }
    _lastError = e;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // 화면을 떠나면 마이크도 멈춘다 (백그라운드 녹음 없음). 돌아오면 사용자가 이어서 누른다.
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      ctl.pause(reason: PauseReason.leftApp);
    } else if (s == AppLifecycleState.resumed) {
      ctl.recheckPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctl.removeListener(_onCtl);
    ctl.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _report() async {
    final r = ctl.snapshot();
    if (r == null) return;
    await AppStore.i.saveRecord(r);
    if (!mounted) return;
    await _open(ReportScreen(recordId: r.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([ctl, AppStore.i]),
          builder: (context, _) => _body(context),
        ),
      ),
      bottomNavigationBar: SafeArea(top: false, child: Ads.i.banner()),
    );
  }

  Widget _body(BuildContext context) {
    final e = ctl.engine;
    final has = ctl.hasData;
    final unit = (e?.weighting ?? AppStore.i.weighting).unit;
    final cur = has ? e!.current : null;
    final short = MediaQuery.sizeOf(context).height < 700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _topBar(unit),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Gauge(
                value: cur,
                max: has ? e!.max : null,
                unit: unit,
                active: ctl.running,
              ),
            ),
          ),
          _likeChip(cur),
          SizedBox(height: short ? 6 : 10),
          _notice(),
          Row(
            children: [
              StatTile(
                label: 'AVG',
                value: has ? fmtDb(e!.average) : '--',
                unit: unit,
              ),
              const SizedBox(width: 8),
              StatTile(
                label: 'MAX',
                value: has ? fmtDb(e!.max) : '--',
                unit: unit,
              ),
              const SizedBox(width: 8),
              StatTile(
                label: 'TIME',
                value: e == null ? '0:00' : fmtDuration(e.measured),
              ),
            ],
          ),
          SizedBox(height: short ? 6 : 10),
          Container(
            height: short ? 70 : 100,
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 6),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAST MINUTE',
                  style: TextStyle(
                    color: C.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(child: LiveChart(points: e?.recent ?? const [])),
              ],
            ),
          ),
          SizedBox(height: short ? 8 : 14),
          _controls(),
          SizedBox(height: short ? 6 : 10),
        ],
      ),
    );
  }

  Widget _topBar(String unit) => SizedBox(
    height: 48,
    child: Row(
      children: [
        IconButton(
          key: const Key('history'),
          tooltip: 'History',
          icon: const Icon(Icons.history, color: C.ink),
          onPressed: () => _open(const HistoryScreen()),
        ),
        Expanded(
          child: Text(
            kAppName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: C.ink,
            ),
          ),
        ),
        IconButton(
          key: const Key('settings'),
          tooltip: 'Settings',
          icon: const Icon(Icons.tune, color: C.ink),
          onPressed: () => _open(const SettingsScreen()),
        ),
      ],
    ),
  );

  Widget _likeChip(double? cur) {
    final band = cur == null ? null : bandOf(cur);
    final text = switch (ctl.state) {
      _ when cur != null => likeText(cur),
      MeterState.starting => 'Listening…',
      MeterState.denied => 'Microphone is off',
      _ => 'Tap Start to measure',
    };
    return Semantics(
      button: true,
      label: 'Sound level guide. $text',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('guide'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(
          GuideScreen(
            current: cur,
            unit: (ctl.engine?.weighting ?? AppStore.i.weighting).unit,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: band?.color.withValues(alpha: 0.6) ?? C.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (band != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: band.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    band.name,
                    style: const TextStyle(
                      color: Color(0xFF10151D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  key: const Key('like'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: C.sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 상황 안내 한 줄 (권한 꺼짐·멈춘 이유·청력 주의).
  Widget _notice() {
    final e = ctl.engine;
    Widget line(
      IconData icon,
      String text, {
      Color color = C.sub,
      Widget? action,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                key: const Key('notice'),
                style: TextStyle(color: color, fontSize: 13, height: 1.3),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );

    if (ctl.state == MeterState.denied) {
      // 웹 미리보기는 브라우저가 권한을 쥐고 있다 → 설정 앱 대신 "다시 시도".
      return line(
        Icons.mic_off,
        kIsWeb
            ? 'Microphone is blocked. Allow it for this site in your browser, then try again.'
            : 'Microphone access is off. Turn it on in Settings to measure.',
        color: C.red,
        action: kIsWeb
            ? TextButton(
                key: const Key('open-settings'),
                onPressed: ctl.start,
                child: const Text('Try again'),
              )
            : TextButton(
                key: const Key('open-settings'),
                onPressed: () => Outside.i.openAppSettings(),
                child: const Text('Open Settings'),
              ),
      );
    }
    if (ctl.state == MeterState.paused) {
      final why = switch (ctl.pauseReason) {
        PauseReason.leftApp =>
          'Paused — measuring stops when you leave the app.',
        PauseReason.interrupted =>
          'Paused — the microphone was interrupted (a call or another app).',
        _ => 'Paused. Your measurement is saved in History.',
      };
      return line(Icons.pause_circle_outline, why);
    }
    if (e != null && ctl.hasData && e.weighting == Weighting.a) {
      final limit = nioshDailyLimit(e.average);
      if (limit != null) {
        return line(
          Icons.hearing_disabled,
          'Average over 85 dBA. NIOSH suggests no more than ${fmtLimit(limit)} a day at this level.',
          color: bandOf(e.average).color,
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _controls() {
    final st = ctl.state;
    final running = st == MeterState.running;
    final (IconData icon, String label) = switch (st) {
      MeterState.running => (Icons.pause, 'Pause'),
      MeterState.paused => (Icons.play_arrow, 'Resume'),
      MeterState.starting => (Icons.more_horiz, 'Starting'),
      _ => (Icons.mic, 'Start'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RoundButton(
          key: const Key('reset'),
          icon: Icons.restart_alt,
          label: 'Reset',
          onTap: ctl.engine == null ? null : ctl.reset,
        ),
        RoundButton(
          key: const Key('main'),
          icon: icon,
          label: label,
          size: 76,
          color: running ? C.card2 : C.accent,
          iconColor: running ? C.ink : const Color(0xFF06202C),
          onTap: st == MeterState.starting
              ? null
              : (running ? ctl.pause : ctl.start),
        ),
        RoundButton(
          key: const Key('report'),
          icon: Icons.description_outlined,
          label: 'Report',
          onTap: ctl.canReport ? _report : null,
        ),
      ],
    );
  }
}
