import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'history.dart';
import 'meter.dart';
import 'mic.dart';
import 'store.dart';

enum MeterState { idle, starting, running, paused, denied }

/// 왜 멈췄나 — 화면에 정직하게 알려 준다.
enum PauseReason { user, leftApp, interrupted }

/// 측정 한 번(시작 → 멈춤/이어서 → 초기화)을 관리한다.
/// 기록은 10초마다, 멈출 때마다 자동 저장 — 사용자가 "저장"을 잊어도 남는다.
class MeterController extends ChangeNotifier {
  MeterController({SoundSource? source}) : source = source ?? SoundSource.i {
    AppStore.i.addListener(_onSettings);
  }

  final SoundSource source;
  MeterEngine? _engine;
  MeterState state = MeterState.idle;
  PauseReason? pauseReason;
  String? error;
  DateTime? startedAt;
  final List<(int, DateTime)> _segments = [];
  Timer? _ui;
  int _savedAt = 0;
  Weighting? _weighting;

  /// 이보다 짧은 측정은 기록에 남기지 않는다.
  static const minSecondsToSave = 3;
  static const autosaveEvery = 10;

  MeterEngine? get engine => _engine;
  bool get running => state == MeterState.running;
  bool get hasData => _engine?.hasData ?? false;
  bool get canReport => (_engine?.secondCount ?? 0) >= minSecondsToSave;

  Future<void> start() async {
    if (state == MeterState.starting || state == MeterState.running) return;
    state = MeterState.starting;
    error = null;
    notifyListeners();
    final ok = await source.hasPermission(request: true);
    if (!ok) {
      state = MeterState.denied;
      notifyListeners();
      return;
    }
    final store = AppStore.i;
    if (_engine == null) {
      _engine = MeterEngine(
        sampleRate: source.sampleRate,
        weighting: store.weighting,
        offset: store.offset,
      );
      _weighting = store.weighting;
      startedAt = store.clock();
      _segments.clear();
      _savedAt = 0;
    } else {
      _engine!.resume();
      _segments.add((_engine!.secondCount, store.clock()));
    }
    try {
      await source.start(
        onData: (b) => _engine?.addPcm16(b),
        onStopped: () => pause(reason: PauseReason.interrupted),
      );
    } catch (e) {
      debugPrint('mic start failed: $e');
      error = 'Could not start the microphone. Close other apps using it and try again.';
      state = _engine!.secondCount > 0 ? MeterState.paused : MeterState.idle;
      if (state == MeterState.idle) _engine = null;
      notifyListeners();
      return;
    }
    state = MeterState.running;
    pauseReason = null;
    _ui?.cancel();
    _ui = Timer.periodic(MeterEngine.tick, (_) => _onTick());
    if (store.keepAwake) _awake(true);
    notifyListeners();
  }

  void _onTick() {
    final e = _engine;
    if (e != null && e.secondCount - _savedAt >= autosaveEvery) {
      _save();
    }
    notifyListeners();
  }

  Future<void> pause({PauseReason reason = PauseReason.user}) async {
    if (state != MeterState.running && state != MeterState.starting) return;
    _ui?.cancel();
    _ui = null;
    await source.stop();
    state = MeterState.paused;
    pauseReason = reason;
    _awake(false);
    notifyListeners();
    await _save();
  }

  /// 지금 측정을 끝내고 처음으로 (기록은 저장해 둔다).
  Future<void> reset() async {
    _ui?.cancel();
    _ui = null;
    await source.stop();
    await _save();
    _awake(false);
    _engine = null;
    startedAt = null;
    _segments.clear();
    state = MeterState.idle;
    pauseReason = null;
    error = null;
    notifyListeners();
  }

  /// 설정 앱에서 마이크를 켜고 돌아왔을 때.
  Future<void> recheckPermission() async {
    if (state != MeterState.denied) return;
    if (await source.hasPermission(request: false)) {
      state = _engine == null ? MeterState.idle : MeterState.paused;
      notifyListeners();
    }
  }

  /// 지금 측정을 기록(리포트용)으로 만든다. 짧으면 null.
  NoiseRecord? snapshot() {
    final e = _engine, t = startedAt;
    if (e == null || t == null || e.secondCount < minSecondsToSave) return null;
    final secs = e.seconds;
    return NoiseRecord(
      id: t.millisecondsSinceEpoch,
      startedAt: t,
      weighting: e.weighting,
      offset: e.offset,
      average: e.average,
      max: e.max,
      min: e.min,
      leq: [for (final s in secs) s.leq],
      peaks: [for (final s in secs) s.max],
      segments: List.of(_segments),
    );
  }

  Future<void> _save() async {
    final r = snapshot();
    if (r == null) return;
    _savedAt = _engine!.secondCount;
    await AppStore.i.saveRecord(r);
  }

  void _onSettings() {
    final e = _engine;
    if (e == null) return;
    final s = AppStore.i;
    if (e.offset != s.offset) {
      e.offset = s.offset;
      notifyListeners();
    }
    // 가중을 바꾸면 숫자 뜻이 달라지므로 새 측정으로 시작한다 (지금까지는 저장).
    if (_weighting != null && s.weighting != _weighting) {
      _weighting = s.weighting;
      final wasRunning = running;
      reset().then((_) {
        if (wasRunning) start();
      });
    }
  }

  /// 화면 꺼짐 막기. 기다리지 않는다 — 응답이 안 와도(테스트·일부 브라우저) 측정·저장이 막히면 안 된다.
  void _awake(bool on) {
    (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError(
      (Object _) {},
    );
  }

  @override
  void dispose() {
    AppStore.i.removeListener(_onSettings);
    _ui?.cancel();
    source.stop();
    super.dispose();
  }
}
