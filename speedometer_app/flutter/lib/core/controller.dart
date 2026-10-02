import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import 'device.dart';
import 'engine.dart';
import 'location.dart';
import 'prefs.dart';
import 'units.dart';

/// 화면과 측정 엔진을 잇는다: 위치 받기, 1초 시계, 속도 경고 소리, 화면 꺼짐 방지, 기록 저장.
class SpeedController extends ChangeNotifier with WidgetsBindingObserver {
  SpeedController({
    required this.source,
    required this.prefs,
    required this.io,
  }) {
    engine.trip = prefs.trip;
    _syncAlert();
  }

  final LocationSource source;
  final Prefs prefs;
  final DeviceIO io;

  final engine = SpeedEngine();
  final alert = SpeedAlert();

  Access access = Access.checking;
  bool preciseOff = false;
  bool running = false;
  bool _starting = false;
  bool _disposed = false;

  StreamSubscription<Fix>? _sub;
  Timer? _tick;
  Timer? _repeat;
  int _ticks = 0;

  /// 경고를 넘은 채로 있으면 이 간격으로 다시 알린다.
  static const repeatEvery = Duration(seconds: 15);

  Mode get mode => prefs.mode;
  SpeedUnit get unit => prefs.unitFor(mode);
  Display get display => prefs.display;

  // ── 시작·정지 ──

  /// 권한을 확인하고 위치를 받기 시작한다. [prompt] 면 시스템 권한 창을 띄운다.
  Future<void> start({bool prompt = false}) async {
    if (_starting) return;
    _starting = true;
    try {
      var a = await source.check();
      if (prompt && (a == Access.unknown || a == Access.denied)) {
        a = await source.request();
      }
      if (_disposed) return;
      access = a;
      preciseOff = a == Access.granted && await source.preciseOff();
      if (_disposed) return;
      if (access == Access.granted) {
        _listen();
      } else {
        _stopListening();
      }
      notifyListeners();
    } finally {
      _starting = false;
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = source.watch(mode).listen(_onFix, onError: _onError);
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    if (!running) io.keepAwake(true);
    running = true;
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
    _repeat?.cancel();
    _repeat = null;
    if (running) io.keepAwake(false);
    running = false;
    engine.pause();
    alert.update(null);
    _save();
  }

  void _onFix(Fix f) {
    engine.addFix(f, clock.now());
    _evalAlert(engine.speed);
    notifyListeners();
  }

  void _onError(Object e) {
    // 권한이 도중에 꺼졌을 수 있다 → 다시 확인.
    debugPrint('location error: $e');
    start();
  }

  void _onTick() {
    engine.tick(clock.now());
    if (engine.speed == null) _evalAlert(null);
    if (++_ticks % 10 == 0) _save();
    notifyListeners();
  }

  void _save() => prefs.trip = engine.trip;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        start();
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        // 화면이 꺼지면 위치도 끈다 (배터리, 백그라운드 위치 없음).
        if (running) {
          _stopListening();
          notifyListeners();
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ── 속도 경고 ──

  void _evalAlert(double? ms) {
    final fired = alert.update(ms);
    if (fired) {
      _ring();
      _repeat?.cancel();
      _repeat = Timer.periodic(repeatEvery, (_) {
        if (alert.over) _ring();
      });
    }
    if (!alert.over) {
      _repeat?.cancel();
      _repeat = null;
    }
  }

  void _ring() {
    io.buzz();
    if (prefs.sound) io.beep();
  }

  void _syncAlert() {
    alert
      ..enabled = prefs.alertOn(mode)
      ..unit = unit
      ..decimals = mode.decimals
      ..limit = unit.fromMs(prefs.alertMs(mode)).round();
    alert.update(alert.enabled ? engine.speed : null);
  }

  int get alertLimit => alert.limit;
  bool get alertOn => alert.enabled;

  void setAlertOn(bool v) {
    prefs.setAlertOn(mode, v);
    _syncAlert();
    // 켜는 순간 소리를 한 번 들려준다 — 소리 확인 겸, 웹 사파리는 탭이 있어야 소리가 풀린다.
    if (v && prefs.sound) io.beep();
    notifyListeners();
  }

  void changeAlertLimit(int delta) {
    final v = (alert.limit + delta).clamp(minAlert, maxAlert);
    prefs.setAlertMs(mode, unit.toMs(v.toDouble()));
    _syncAlert();
    notifyListeners();
  }

  int get minAlert => 3;
  int get maxAlert => mode.gaugeMax(unit).round() + 60;

  void setSound(bool v) {
    prefs.sound = v;
    if (v) io.beep();
    notifyListeners();
  }

  // ── 모드·단위·표시 ──

  void setMode(Mode m) {
    if (m == mode) return;
    prefs.mode = m;
    _syncAlert();
    // 모드마다 iOS 에 알려 주는 이동 종류(차·운동·항해)가 달라 위치 받기를 다시 시작.
    if (running) _sub?.cancel();
    if (running) _sub = source.watch(mode).listen(_onFix, onError: _onError);
    notifyListeners();
  }

  void setUnit(SpeedUnit u) {
    prefs.setUnit(mode, u);
    _syncAlert();
    notifyListeners();
  }

  /// 단위 글자를 탭하면 다음 단위로.
  void cycleUnit() {
    final us = mode.units;
    setUnit(us[(us.indexOf(unit) + 1) % us.length]);
  }

  void setDisplay(Display d) {
    prefs.display = d;
    notifyListeners();
  }

  bool get hudMirror => prefs.hudMirror;
  void setHudMirror(bool v) {
    prefs.hudMirror = v;
    notifyListeners();
  }

  void acceptSafety() {
    prefs.seenSafety = true;
    notifyListeners();
  }

  void resetTrip() {
    engine.resetTrip();
    _save();
    notifyListeners();
  }

  Future<void> openSettings() => source.openSettings();

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _tick?.cancel();
    _repeat?.cancel();
    if (running) io.keepAwake(false);
    _save();
    super.dispose();
  }
}
