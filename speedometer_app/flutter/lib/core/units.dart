/// 모드(차·자전거·달리기·보트)와 단위. 모드마다 단위·표시만 다르고 측정은 같다.
enum Mode { car, bike, run, boat }

enum SpeedUnit { mph, kmh, knots }

extension ModeInfo on Mode {
  String get label => switch (this) {
    Mode.car => 'Car',
    Mode.bike => 'Bike',
    Mode.run => 'Run',
    Mode.boat => 'Boat',
  };

  /// 이 모드에서 고를 수 있는 단위 (첫 번째가 기본값 — 미국 사용자 기준).
  List<SpeedUnit> get units => this == Mode.boat
      ? const [SpeedUnit.knots, SpeedUnit.mph, SpeedUnit.kmh]
      : const [SpeedUnit.mph, SpeedUnit.kmh];

  /// 큰 숫자 소수점 자리. 자전거·달리기는 속도가 낮아 소수 한 자리가 의미 있다.
  int get decimals => (this == Mode.bike || this == Mode.run) ? 1 : 0;

  /// 달리기는 큰 숫자를 페이스(분/마일)로 보여 준다.
  bool get showsPace => this == Mode.run;

  /// 게이지 눈금 끝 값 (단위 기준).
  double gaugeMax(SpeedUnit u) => switch ((this, u)) {
    (Mode.car, SpeedUnit.kmh) => 220,
    (Mode.car, _) => 140,
    (Mode.bike, SpeedUnit.kmh) => 60,
    (Mode.bike, _) => 40,
    (Mode.run, SpeedUnit.kmh) => 25,
    (Mode.run, _) => 15,
    (Mode.boat, SpeedUnit.kmh) => 100,
    (Mode.boat, SpeedUnit.mph) => 60,
    (Mode.boat, _) => 50,
  };

  /// 속도 경고 기본값 (m/s). 처음엔 꺼져 있고, 켜면 이 값부터 시작한다.
  double get defaultAlertMs => switch (this) {
    Mode.car => 65 / SpeedUnit.mph.perMs,
    Mode.bike => 25 / SpeedUnit.mph.perMs,
    Mode.run => 8 / SpeedUnit.mph.perMs,
    Mode.boat => 30 / SpeedUnit.knots.perMs,
  };
}

extension UnitInfo on SpeedUnit {
  /// 1 m/s 가 이 단위로 얼마인가.
  double get perMs => switch (this) {
    SpeedUnit.mph => 2.2369362920544,
    SpeedUnit.kmh => 3.6,
    SpeedUnit.knots => 1.9438444924406,
  };

  String get label => switch (this) {
    SpeedUnit.mph => 'MPH',
    SpeedUnit.kmh => 'KM/H',
    SpeedUnit.knots => 'KNOTS',
  };

  /// 거리 단위 1 이 몇 미터인가 (mph→마일, km/h→km, 노트→해리).
  double get distMeters => switch (this) {
    SpeedUnit.mph => 1609.344,
    SpeedUnit.kmh => 1000,
    SpeedUnit.knots => 1852,
  };

  String get distLabel => switch (this) {
    SpeedUnit.mph => 'mi',
    SpeedUnit.kmh => 'km',
    SpeedUnit.knots => 'nm',
  };

  String get paceLabel => this == SpeedUnit.kmh ? 'MIN/KM' : 'MIN/MI';

  double fromMs(double ms) => ms * perMs;
  double toMs(double v) => v / perMs;
}

/// 속도 숫자 (단위 변환 + 반올림). 없으면 '--'.
String formatSpeed(double? ms, SpeedUnit u, int decimals) {
  if (ms == null) return '--';
  return u.fromMs(ms).toStringAsFixed(decimals);
}

/// 페이스 "8:32" (거리 단위 1 을 가는 데 걸리는 분:초). 서 있거나 너무 느리면 '--:--'.
String formatPace(double? ms, SpeedUnit u) {
  if (ms == null || ms < SpeedEngineConst.stopMs) return '--:--';
  final secs = (u.distMeters / ms).round();
  if (secs >= 60 * 60) return '--:--';
  return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
}

String formatDistance(double meters, SpeedUnit u) {
  final v = meters / u.distMeters;
  return v < 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);
}

/// 시간 "0:24:10" / 1시간 미만은 "24:10".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '${d.inMinutes}:$ss';
}

class SpeedEngineConst {
  /// 이보다 느리면 0 으로 본다 (약 1 mph). 서 있을 때 GPS 속도가 0~2 mph 로 흔들리는 걸 막는다.
  static const stopMs = 0.45;
}
