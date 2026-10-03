import 'dart:math' as math;

/// Offline sun and moon calculations (no network needed).
///
/// Sun: NOAA Solar Calculator equations (same code as the tides app, checked
/// against PyEphem to ±90 s). Moon: Meeus, Astronomical Algorithms ch. 47
/// (ELP-2000/82 main terms, about 10″ in longitude) for position and distance,
/// ch. 48 for the phase. Rise/set follow the USNO definition: the upper limb
/// touches the horizon with 34′ of refraction, seen from the observer.

const _deg = math.pi / 180;

/// TT − UT. About 69 s through the late 2020s; it moves the moon 0.6″ — far below
/// what a minute-level timetable can show, kept so positions match ephemerides.
const _deltaT = Duration(seconds: 69);

double _julianDay(DateTime utc) => utc.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

double _sin(double d) => math.sin(d * _deg);
double _cos(double d) => math.cos(d * _deg);
double _norm360(double d) => ((d % 360) + 360) % 360;

/// −180…180
double _norm180(double d) => _norm360(d + 180) - 180;

// ───────────────────────────── Sun ─────────────────────────────

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
  final c =
      _sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      _sin(2 * m) * (0.019993 - 0.000101 * t) +
      _sin(3 * m) * 0.000289;
  final trueLong = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final appLong = trueLong - 0.00569 - 0.00478 * _sin(omega);
  final obliqMean = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
  final obliq = obliqMean + 0.00256 * _cos(omega);
  final decl = math.asin(_sin(obliq) * _sin(appLong)) / _deg;
  final y = math.pow(math.tan(obliq / 2 * _deg), 2).toDouble();
  final eqTime =
      4 *
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
      final cosH = _cos(90.833) / (_cos(lat) * _cos(decl)) - math.tan(lat * _deg) * math.tan(decl * _deg);
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

// ───────────────────────────── Moon position ─────────────────────────────

/// Meeus table 47.A: multiples of D, M, M′, F; longitude (1e-6°); distance (1e-3 km).
const _lr = <List<int>>[
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
  [0, 1, 2, 0, -2120, 5751],
  [0, 2, 0, 0, -2069, 0],
  [2, -2, -1, 0, 2048, -4950],
  [2, 0, 1, -2, -1773, 4130],
  [2, 0, 0, 2, -1595, 0],
  [4, -1, -1, 0, 1215, -3958],
  [0, 0, 2, 2, -1110, 0],
  [3, 0, -1, 0, -892, 3258],
  [2, 1, 1, 0, -810, 2616],
  [4, -1, -2, 0, 759, -1897],
  [0, 2, -1, 0, -713, -2117],
  [2, 2, -1, 0, -700, 2354],
  [2, 1, -2, 0, 691, 0],
  [2, -1, 0, -2, 596, 0],
  [4, 0, 1, 0, 549, -1423],
  [0, 0, 4, 0, 537, -1117],
  [4, -1, 0, 0, 520, -1571],
  [1, 0, -2, 0, -487, -1739],
  [2, 1, 0, -2, -399, 0],
  [0, 0, 2, -2, -381, -4421],
  [1, 1, 1, 0, 351, 0],
  [3, 0, -2, 0, -340, 0],
  [4, 0, -3, 0, 330, 0],
  [2, -1, 2, 0, 327, 0],
  [0, 2, 1, 0, -323, 1165],
  [1, 1, -1, 0, 299, 0],
  [2, 0, 3, 0, 294, 0],
  [2, 0, -1, -2, 0, 8752],
];

/// Meeus table 47.B: multiples of D, M, M′, F; latitude (1e-6°).
const _b = <List<int>>[
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
  [4, 0, 0, -1, 1021],
  [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777],
  [4, 0, -2, 1, 671],
  [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596],
  [2, -1, 1, -1, 491],
  [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439],
  [2, 0, 2, 1, 422],
  [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366],
  [2, 1, 0, 1, -351],
  [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315],
  [2, -2, 0, -1, 302],
  [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229],
  [1, 1, 0, -1, 223],
  [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220],
  [2, 1, -1, -1, -220],
  [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181],
  [0, 1, 2, 1, -177],
  [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166],
  [1, 0, 1, -1, -164],
  [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119],
  [4, -1, 0, -1, 115],
  [2, -2, 0, 1, 107],
];

/// Geocentric apparent moon position.
class MoonPosition {
  const MoonPosition({
    required this.ra,
    required this.dec,
    required this.distanceKm,
    required this.longitude,
    required this.latitude,
  });

  /// Right ascension and declination of date, degrees.
  final double ra;
  final double dec;
  final double distanceKm;

  /// Apparent ecliptic longitude / latitude of date, degrees.
  final double longitude;
  final double latitude;

  /// Equatorial horizontal parallax, degrees.
  double get parallax => math.asin(6378.14 / distanceKm) / _deg;
}

MoonPosition moonPosition(DateTime utc) {
  final t = (_julianDay(utc.toUtc().add(_deltaT)) - 2451545) / 36525;
  final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
  final lp = _norm360(218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000);
  final d = _norm360(297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000);
  final m = _norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000);
  final mp = _norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000);
  final f = _norm360(93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000);
  final a1 = _norm360(119.75 + 131.849 * t);
  final a2 = _norm360(53.09 + 479264.290 * t);
  final a3 = _norm360(313.45 + 481266.484 * t);
  final e = 1 - 0.002516 * t - 0.0000074 * t2;

  double ecc(int mm) => mm == 0 ? 1 : (mm.abs() == 1 ? e : e * e);

  var sl = 0.0, sr = 0.0, sb = 0.0;
  for (final r in _lr) {
    final arg = r[0] * d + r[1] * m + r[2] * mp + r[3] * f;
    final k = ecc(r[1]);
    sl += r[4] * k * _sin(arg);
    sr += r[5] * k * _cos(arg);
  }
  for (final r in _b) {
    final arg = r[0] * d + r[1] * m + r[2] * mp + r[3] * f;
    sb += r[4] * ecc(r[1]) * _sin(arg);
  }
  sl += 3958 * _sin(a1) + 1962 * _sin(lp - f) + 318 * _sin(a2);
  sb +=
      -2235 * _sin(lp) +
      382 * _sin(a3) +
      175 * _sin(a1 - f) +
      175 * _sin(a1 + f) +
      127 * _sin(lp - mp) -
      115 * _sin(lp + mp);

  // Nutation (Meeus ch. 22, low precision) and true obliquity.
  final omega = 125.04452 - 1934.136261 * t;
  final ls = 280.4665 + 36000.7698 * t;
  final dPsi = (-17.20 * _sin(omega) - 1.32 * _sin(2 * ls) - 0.23 * _sin(2 * lp) + 0.21 * _sin(2 * omega)) / 3600;
  final dEps = (9.20 * _cos(omega) + 0.57 * _cos(2 * ls) + 0.10 * _cos(2 * lp) - 0.09 * _cos(2 * omega)) / 3600;
  final eps0 = 23.4392911111 - 0.0130041667 * t - 1.638889e-7 * t2 + 5.036111e-7 * t3;
  final eps = eps0 + dEps;

  final lambda = _norm360(lp + sl / 1e6 + dPsi);
  final beta = sb / 1e6;
  final dist = 385000.56 + sr / 1000;

  final ra = _norm360(math.atan2(_sin(lambda) * _cos(eps) - math.tan(beta * _deg) * _sin(eps), _cos(lambda)) / _deg);
  final dec = math.asin(_sin(beta) * _cos(eps) + _cos(beta) * _sin(eps) * _sin(lambda)) / _deg;
  return MoonPosition(ra: ra, dec: dec, distanceKm: dist, longitude: lambda, latitude: beta);
}

/// Greenwich mean sidereal time, degrees (Meeus 12.4).
double _gmst(DateTime utc) {
  final jd = _julianDay(utc);
  final t = (jd - 2451545) / 36525;
  return _norm360(280.46061837 + 360.98564736629 * (jd - 2451545) + 0.000387933 * t * t - t * t * t / 38710000);
}

/// Local hour angle of the moon, −180…180 (0 = on the meridian, overhead side).
double moonHourAngle(DateTime utc, double lng, [MoonPosition? p]) {
  final pos = p ?? moonPosition(utc);
  return _norm180(_gmst(utc) + lng - pos.ra);
}

/// Geocentric altitude of the moon's centre, degrees.
double _moonAltitude(DateTime utc, double lat, double lng, MoonPosition p) {
  final h = moonHourAngle(utc, lng, p);
  return math.asin(_sin(lat) * _sin(p.dec) + _cos(lat) * _cos(p.dec) * _cos(h)) / _deg;
}

/// How far the moon is above its rise/set altitude (Meeus 15: h0 = 0.7275π − 34′).
/// Positive = up.
double moonAboveHorizon(DateTime utc, double lat, double lng) {
  final p = moonPosition(utc);
  return _moonAltitude(utc, lat, lng, p) - (0.7275 * p.parallax - 34 / 60);
}

// ───────────────────────────── Moon events ─────────────────────────────

enum MoonEventKind {
  rise('Moonrise'),
  set('Moonset'),
  overhead('Moon overhead'),
  underfoot('Moon underfoot');

  const MoonEventKind(this.label);
  final String label;
}

class MoonEvent {
  const MoonEvent(this.kind, this.time);
  final MoonEventKind kind;
  final DateTime time; // UTC

  @override
  String toString() => '${kind.name} $time';
}

const _step = Duration(minutes: 20);

/// Root of [f] between [a] (f<0 side or f>0 side) and [b], to the second.
DateTime _bisect(DateTime a, DateTime b, double Function(DateTime) f) {
  final fa = f(a);
  while (b.difference(a).inMilliseconds > 1000) {
    final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
    final fm = f(mid);
    if ((fm < 0) == (fa < 0)) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
}

/// Moonrise, moonset and the two meridian passages inside [start, end), sorted.
/// A day can lack any of them (the moon runs ~50 minutes later each day), and
/// near the poles the moon can stay up or down all day.
List<MoonEvent> moonEvents(DateTime start, DateTime end, double lat, double lng) {
  final out = <MoonEvent>[];
  double above(DateTime t) => moonAboveHorizon(t, lat, lng);
  double ha(DateTime t) => moonHourAngle(t, lng);
  // Hour angle measured from the lower meridian: crosses 0 at "underfoot".
  double haLower(DateTime t) => _norm180(moonHourAngle(t, lng) + 180);

  var a = start;
  var upA = above(a), haA = ha(a), loA = haLower(a);
  while (a.isBefore(end)) {
    var b = a.add(_step);
    if (b.isAfter(end)) b = end;
    final upB = above(b), haB = ha(b), loB = haLower(b);
    if ((upA < 0) != (upB < 0)) {
      final t = _bisect(a, b, above);
      if (!t.isBefore(start) && t.isBefore(end)) {
        out.add(MoonEvent(upA < 0 ? MoonEventKind.rise : MoonEventKind.set, t));
      }
    }
    // The hour angle grows ~14.5°/h; a sign change from − to + (not the ±180 wrap) is a passage.
    if (haA < 0 && haB >= 0 && haB - haA < 90) {
      out.add(MoonEvent(MoonEventKind.overhead, _bisect(a, b, ha)));
    }
    if (loA < 0 && loB >= 0 && loB - loA < 90) {
      out.add(MoonEvent(MoonEventKind.underfoot, _bisect(a, b, haLower)));
    }
    a = b;
    upA = upB;
    haA = haB;
    loA = loB;
  }
  out.sort((x, y) => x.time.compareTo(y.time));
  return out;
}

// ───────────────────────────── Moon phase ─────────────────────────────

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

  bool get isPrincipal => this == newMoon || this == firstQuarter || this == fullMoon || this == lastQuarter;
}

/// Moon age as an angle: 0° new, 90° first quarter, 180° full, 270° last quarter.
double moonAge(DateTime utc) {
  final t = (_julianDay(utc) - 2451545) / 36525;
  final d = _norm360(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t + t * t * t / 545868);
  final m = _norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t);
  final mp = _norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t + t * t * t / 69699);
  return _norm360(
    d +
        6.289 * _sin(mp) -
        2.100 * _sin(m) +
        1.274 * _sin(2 * d - mp) +
        0.658 * _sin(2 * d) +
        0.214 * _sin(2 * mp) +
        0.110 * _sin(d),
  );
}

/// Illuminated fraction 0…1.
double moonIllumination(DateTime utc) => (1 - _cos(moonAge(utc))) / 2;

bool moonWaxing(DateTime utc) => moonAge(utc) < 180;

/// Exact time the moon age crosses [target]° (0/90/180/270) inside [from, to), if any.
DateTime? _crossing(DateTime from, DateTime to, double target) {
  double rel(DateTime t) => _norm180(moonAge(t) - target);
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

typedef MoonDay = ({MoonPhase phase, double illumination, bool waxing, double age});

/// Phase for a local day running from [dayStartUtc] to [dayEndUtc].
/// A principal phase (new, quarter, full) is named on the day it happens;
/// other days get the in-between name.
MoonDay moonForDay(DateTime dayStartUtc, DateTime dayEndUtc) {
  const targets = [
    (0.0, MoonPhase.newMoon),
    (90.0, MoonPhase.firstQuarter),
    (180.0, MoonPhase.fullMoon),
    (270.0, MoonPhase.lastQuarter),
  ];
  final noon = dayStartUtc.add(Duration(milliseconds: dayEndUtc.difference(dayStartUtc).inMilliseconds ~/ 2));
  final illum = moonIllumination(noon);
  final age = moonAge(noon);
  final waxing = age < 180;
  for (final (deg, phase) in targets) {
    if (_crossing(dayStartUtc, dayEndUtc, deg) != null) {
      return (phase: phase, illumination: illum, waxing: waxing, age: age);
    }
  }
  final phase = age < 90
      ? MoonPhase.waxingCrescent
      : age < 180
      ? MoonPhase.waxingGibbous
      : age < 270
      ? MoonPhase.waningGibbous
      : MoonPhase.waningCrescent;
  return (phase: phase, illumination: illum, waxing: waxing, age: age);
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
