import 'dart:math' as math;

/// Offline sun and moon calculations (no network needed).
///
/// Sunrise/sunset: NOAA Solar Calculator equations (accurate to about a minute
/// below the polar circles). Moon: Meeus' low-precision phase angle
/// (Astronomical Algorithms, ch. 48), good to about an hour for phase times.

const _deg = math.pi / 180;

double _julianDay(DateTime utc) =>
    utc.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

double _sin(double d) => math.sin(d * _deg);
double _cos(double d) => math.cos(d * _deg);
double _norm360(double d) => ((d % 360) + 360) % 360;

class SunTimes {
  const SunTimes({this.sunrise, this.sunset, this.alwaysUp = false});

  final DateTime? sunrise;
  final DateTime? sunset;

  /// Polar day. When both times are null and this is false, it is polar night.
  final bool alwaysUp;

  bool get alwaysDown => sunrise == null && sunset == null && !alwaysUp;
}

/// Sun position terms for Julian century [t]: (declination°, equation of time in minutes).
(double, double) _sunTerms(double t) {
  final l0 = _norm360(280.46646 + t * (36000.76983 + t * 0.0003032));
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  final c = _sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      _sin(2 * m) * (0.019993 - 0.000101 * t) +
      _sin(3 * m) * 0.000289;
  final trueLong = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final appLong = trueLong - 0.00569 - 0.00478 * _sin(omega);
  final obliqMean = 23 +
      (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
  final obliq = obliqMean + 0.00256 * _cos(omega);
  final decl = math.asin(_sin(obliq) * _sin(appLong)) / _deg;
  final y = math.pow(math.tan(obliq / 2 * _deg), 2).toDouble();
  final eqTime = 4 *
      (y * _sin(2 * l0) -
          2 * e * _sin(m) +
          4 * e * y * _sin(m) * _cos(2 * l0) -
          0.5 * y * y * _sin(4 * l0) -
          1.25 * e * e * _sin(2 * m)) /
      _deg;
  return (decl, eqTime);
}

/// Sunrise and sunset for the local calendar date [day] (only its year/month/day
/// are used) at [lat]/[lng]. Results are UTC instants.
SunTimes sunTimes(DateTime day, double lat, double lng) {
  final midnight = DateTime.utc(day.year, day.month, day.day);
  // Solar noon in minutes after 00:00 UTC of that date, refined once.
  double noonMinutes = 720 - 4 * lng;
  for (var i = 0; i < 2; i++) {
    final t = (_julianDay(midnight.add(Duration(seconds: (noonMinutes * 60).round()))) - 2451545) / 36525;
    noonMinutes = 720 - 4 * lng - _sunTerms(t).$2;
  }
  DateTime? event(bool rise) {
    var minutes = noonMinutes;
    for (var i = 0; i < 3; i++) {
      final at = midnight.add(Duration(seconds: (minutes * 60).round()));
      final t = (_julianDay(at) - 2451545) / 36525;
      final (decl, eqTime) = _sunTerms(t);
      final cosH = _cos(90.833) / (_cos(lat) * _cos(decl)) -
          math.tan(lat * _deg) * math.tan(decl * _deg);
      if (cosH.abs() > 1) return null;
      final ha = math.acos(cosH) / _deg;
      final noon = 720 - 4 * lng - eqTime;
      minutes = rise ? noon - 4 * ha : noon + 4 * ha;
    }
    return midnight.add(Duration(seconds: (minutes * 60).round()));
  }

  final rise = event(true);
  final set = event(false);
  if (rise == null || set == null) {
    final t = (_julianDay(midnight.add(Duration(minutes: noonMinutes.round()))) - 2451545) / 36525;
    final decl = _sunTerms(t).$1;
    // Noon altitude decides polar day vs. polar night.
    final noonAlt = 90 - (lat - decl).abs();
    return SunTimes(alwaysUp: noonAlt > 0);
  }
  return SunTimes(sunrise: rise, sunset: set);
}

enum MoonPhase {
  newMoon('New Moon'),
  waxingCrescent('Waxing Crescent'),
  firstQuarter('First Quarter'),
  waxingGibbous('Waxing Gibbous'),
  fullMoon('Full Moon'),
  waningGibbous('Waning Gibbous'),
  lastQuarter('Last Quarter'),
  waningCrescent('Waning Crescent');

  const MoonPhase(this.label);
  final String label;

  bool get isPrincipal =>
      this == newMoon || this == firstQuarter || this == fullMoon || this == lastQuarter;
}

/// Moon age as an angle: 0° new, 90° first quarter, 180° full, 270° last quarter.
double moonAge(DateTime utc) {
  final t = (_julianDay(utc) - 2451545) / 36525;
  final d = _norm360(297.8501921 +
      445267.1114034 * t -
      0.0018819 * t * t +
      t * t * t / 545868);
  final m = _norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t);
  final mp = _norm360(134.9633964 +
      477198.8675055 * t +
      0.0087414 * t * t +
      t * t * t / 69699);
  return _norm360(d +
      6.289 * _sin(mp) -
      2.100 * _sin(m) +
      1.274 * _sin(2 * d - mp) +
      0.658 * _sin(2 * d) +
      0.214 * _sin(2 * mp) +
      0.110 * _sin(d));
}

/// Illuminated fraction 0…1.
double moonIllumination(DateTime utc) => (1 - _cos(moonAge(utc))) / 2;

bool moonWaxing(DateTime utc) => moonAge(utc) < 180;

/// Exact time the moon age crosses [target]° (0/90/180/270) inside [from, to), if any.
DateTime? _crossing(DateTime from, DateTime to, double target) {
  double rel(DateTime t) => _norm360(moonAge(t) - target + 180) - 180; // −180…180
  var a = from, b = to;
  final ra = rel(a), rb = rel(b);
  if (!(ra < 0 && rb >= 0)) return null;
  for (var i = 0; i < 40; i++) {
    final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
    if (rel(mid) < 0) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return a;
}

/// Phase for a station-local day running from [dayStartUtc] to [dayEndUtc].
/// A principal phase (new, quarter, full) is named on the day it happens;
/// other days get the in-between name.
({MoonPhase phase, double illumination, bool waxing}) moonForDay(
    DateTime dayStartUtc, DateTime dayEndUtc) {
  const targets = [
    (0.0, MoonPhase.newMoon),
    (90.0, MoonPhase.firstQuarter),
    (180.0, MoonPhase.fullMoon),
    (270.0, MoonPhase.lastQuarter),
  ];
  final noon = dayStartUtc.add(Duration(
      milliseconds: dayEndUtc.difference(dayStartUtc).inMilliseconds ~/ 2));
  final illum = moonIllumination(noon);
  final waxing = moonWaxing(noon);
  for (final (deg, phase) in targets) {
    if (_crossing(dayStartUtc, dayEndUtc, deg) != null) {
      return (phase: phase, illumination: illum, waxing: waxing);
    }
  }
  final age = moonAge(noon);
  final phase = age < 90
      ? MoonPhase.waxingCrescent
      : age < 180
          ? MoonPhase.waxingGibbous
          : age < 270
              ? MoonPhase.waningGibbous
              : MoonPhase.waningCrescent;
  return (phase: phase, illumination: illum, waxing: waxing);
}

/// Next time the moon reaches [phase] (a principal phase) after [fromUtc].
DateTime nextPrincipalPhase(MoonPhase phase, DateTime fromUtc) {
  final target = switch (phase) {
    MoonPhase.newMoon => 0.0,
    MoonPhase.firstQuarter => 90.0,
    MoonPhase.fullMoon => 180.0,
    MoonPhase.lastQuarter => 270.0,
    _ => throw ArgumentError('not a principal phase: $phase'),
  };
  var a = fromUtc;
  for (var i = 0; i < 40; i++) {
    final b = a.add(const Duration(days: 1));
    final hit = _crossing(a, b, target);
    if (hit != null) return hit;
    a = b;
  }
  throw StateError('phase not found');
}
