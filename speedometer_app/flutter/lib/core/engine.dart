import 'dart:math' as math;

import 'units.dart';

/// GPS 한 번의 측정값. 위치 소스(아이폰·웹·가짜)가 이 모양으로 넘긴다.
class Fix {
  const Fix({
    required this.lat,
    required this.lon,
    required this.accuracy,
    required this.time,
    this.speed,
    this.speedAccuracy,
  });

  final double lat, lon;

  /// 수평 오차 반경 (m). 모르면 음수.
  final double accuracy;

  /// GPS 가 잰 속도 (m/s, 도플러). 없으면 null, 아이폰은 못 재면 -1 을 준다.
  final double? speed;
  final double? speedAccuracy;
  final DateTime time;

  bool get hasSpeed => speed != null && speed!.isFinite && speed! >= 0;
  bool get accurate => accuracy > 0 && accuracy <= SpeedEngine.weakAccuracy;
}

/// 화면 위 GPS 표시. 가짜 숫자를 만들지 않으려고 "모름"을 그대로 드러낸다.
enum GpsState {
  /// 켜고 아직 첫 측정이 없다.
  searching,

  /// 측정이 끊겼다 (터널·실내). 속도는 '--'.
  lost,

  /// 오차가 크다 — 숫자는 보여 주되 "Weak GPS" 라고 밝힌다.
  weak,
  good,
  strong,
}

/// 이번 이동 기록. 미터·초로 저장하고 화면에서 단위를 바꾼다.
class Trip {
  double distance = 0;
  Duration moving = Duration.zero;
  Duration elapsed = Duration.zero;
  double maxMs = 0;

  /// 움직이기 시작해야 시계가 돈다 — 앱을 켜 두고 서 있기만 해도 시간이 늘지 않게.
  bool get started => distance > 0;

  /// 움직인 동안의 평균 (자전거 속도계와 같은 방식).
  double? get avgMs => moving.inMilliseconds < 1000
      ? null
      : distance / (moving.inMilliseconds / 1000);

  Map<String, Object> toJson() => {
    'd': distance,
    'mv': moving.inMilliseconds,
    'el': elapsed.inMilliseconds,
    'mx': maxMs,
  };

  static Trip fromJson(Map<String, dynamic> j) => Trip()
    ..distance = (j['d'] as num?)?.toDouble() ?? 0
    ..moving = Duration(milliseconds: (j['mv'] as num?)?.toInt() ?? 0)
    ..elapsed = Duration(milliseconds: (j['el'] as num?)?.toInt() ?? 0)
    ..maxMs = (j['mx'] as num?)?.toDouble() ?? 0;
}

/// 측정 엔진 — 순수 Dart. 시각은 밖에서 넣어 준다(테스트에서 시간을 마음대로 돌리게).
class SpeedEngine {
  /// 이 시간 동안 측정이 없으면 "No GPS signal".
  static const lostAfter = Duration(seconds: 5);

  /// 아이폰은 켜자마자 예전에 받아 둔 위치를 먼저 줄 때가 있다 — 이만큼 오래된 건 버린다.
  static const staleFix = Duration(seconds: 10);
  static const weakAccuracy = 25.0;
  static const strongAccuracy = 10.0;

  /// 약 200 mph. 이보다 빠르면 GPS 튐으로 본다.
  static const maxPlausibleMs = 90.0;

  Trip trip = Trip();

  /// 화면에 보여 줄 속도 (m/s). 모르면 null → '--'.
  double? speed;
  double? accuracy;
  GpsState state = GpsState.searching;

  /// GPS 가 속도를 안 줘서 위치 변화로 계산한 값인가.
  bool speedDerived = false;

  _Sample? _prev;
  DateTime? _lastFixAt;
  DateTime? _lastTick;

  void addFix(Fix f, DateTime now) {
    if (now.difference(f.time) > staleFix) return;
    final prev = _prev;
    if (prev != null && !f.time.isAfter(prev.fix.time)) return;
    _lastFixAt = now;
    accuracy = f.accuracy;
    state = !f.accurate
        ? GpsState.weak
        : f.accuracy <= strongAccuracy
        ? GpsState.strong
        : GpsState.good;

    double? s;
    speedDerived = false;
    if (f.hasSpeed) {
      s = f.speed! <= maxPlausibleMs ? f.speed : null;
    } else if (prev != null && f.accurate && prev.fix.accurate) {
      final dt = _secs(f.time.difference(prev.fix.time));
      if (dt >= 0.5 && dt <= 10) {
        final d = distanceBetween(prev.fix, f);
        final noise = (f.accuracy + prev.fix.accuracy) / 4;
        s = d <= noise ? 0 : d / dt;
        if (s > maxPlausibleMs) s = null;
        speedDerived = true;
      }
    }
    if (s != null && s < SpeedEngineConst.stopMs) s = 0;

    if (prev != null) {
      final dt = _secs(f.time.difference(prev.fix.time));
      var seg = 0.0;
      if (dt <= 5 && s != null && prev.speed != null) {
        // 속도를 시간으로 적분 — 천천히 걸을 때 위치 흔들림이 거리로 쌓이지 않는다.
        final avg = (s + prev.speed!) / 2;
        if (avg >= SpeedEngineConst.stopMs) seg = avg * dt;
      } else if (f.accurate && prev.fix.accurate) {
        // 신호가 잠깐 끊겼다 돌아온 경우(터널) — 두 위치 사이 직선거리.
        final d = distanceBetween(prev.fix, f);
        final implied = d / dt;
        if (d > f.accuracy + prev.fix.accuracy &&
            implied >= SpeedEngineConst.stopMs &&
            implied <= maxPlausibleMs) {
          seg = d;
        }
      }
      if (seg > 0) {
        // 처음 움직인 구간도 시간에 넣는다 (시계는 움직이기 시작해야 돈다).
        if (!trip.started) {
          trip.elapsed += Duration(milliseconds: (dt * 1000).round());
          _lastTick = now;
        }
        trip.distance += seg;
        trip.moving += Duration(milliseconds: (dt * 1000).round());
      }
      // 최고 속도: 연속 두 번 이상 나온 값만 — 한 번 튄 값(200 mph 같은)이 기록으로 남지 않게.
      if (s != null && prev.speed != null && f.accurate && prev.fix.accurate) {
        final confirmed = math.min(s, prev.speed!);
        if (confirmed > trip.maxMs) trip.maxMs = confirmed;
      }
    }
    speed = s;
    _prev = _Sample(f, s);
  }

  /// 1초마다 부른다 — 끊김 감지와 이동 시간.
  void tick(DateTime now) {
    final last = _lastTick;
    if (last != null && trip.started) {
      final d = now.difference(last);
      if (d > Duration.zero && d < const Duration(seconds: 5)) {
        trip.elapsed += d;
      }
    }
    _lastTick = now;
    final f = _lastFixAt;
    if (f != null && now.difference(f) > lostAfter) {
      state = GpsState.lost;
      speed = null;
      accuracy = null;
    }
  }

  /// 앱이 뒤로 갔을 때. 다시 켰을 때 그 사이를 이동으로 세지 않는다.
  void pause() {
    _prev = null;
    _lastTick = null;
    _lastFixAt = null;
    speed = null;
    accuracy = null;
    state = GpsState.searching;
  }

  void resetTrip() => trip = Trip();

  static double _secs(Duration d) => d.inMicroseconds / 1e6;
}

class _Sample {
  _Sample(this.fix, this.speed);
  final Fix fix;
  final double? speed;
}

/// 두 위치 사이 거리 (m, 하버사인).
double distanceBetween(Fix a, Fix b) {
  const r = 6371008.8;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLon = rad(b.lon - a.lon);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// 속도 경고. 화면에 보이는 숫자가 정한 값을 넘으면 켜지고, 1 단위 아래로 내려와야 꺼진다
/// (경계에서 깜빡이지 않게). GPS 가 한 번 튄 걸로 울리지 않게 연속 두 번 넘어야 켜진다.
class SpeedAlert {
  bool enabled = false;

  /// 단위 기준 정수 (예: 65 mph).
  int limit = 65;
  SpeedUnit unit = SpeedUnit.mph;
  int decimals = 0;
  bool over = false;
  int _streak = 0;

  /// 새로 넘어선 순간 true (소리를 낼 때).
  bool update(double? ms) {
    if (!enabled || ms == null) {
      over = false;
      _streak = 0;
      return false;
    }
    final shown = double.parse(unit.fromMs(ms).toStringAsFixed(decimals));
    if (shown > limit) {
      _streak++;
      if (!over && _streak >= 2) {
        over = true;
        return true;
      }
    } else {
      _streak = 0;
      if (over && shown <= limit - 1) over = false;
    }
    return false;
  }
}
