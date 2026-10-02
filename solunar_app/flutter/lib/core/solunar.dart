import 'dart:math' as math;

import 'astro.dart';
import 'places.dart';
import 'zone.dart';

/// Solunar periods (John Alden Knight, 1926): fish and game tend to move more
/// around the moon's meridian passages (Major) and its rise and set (Minor).
enum PeriodKind {
  major('Major', Duration(hours: 1)),
  minor('Minor', Duration(minutes: 30));

  const PeriodKind(this.label, this.halfLength);
  final String label;

  /// Major = moon overhead/underfoot ± 1 h. Minor = moonrise/moonset ± 30 min.
  final Duration halfLength;
}

class Period {
  Period(this.event)
    : kind = event.kind == MoonEventKind.overhead || event.kind == MoonEventKind.underfoot
          ? PeriodKind.major
          : PeriodKind.minor;

  final MoonEvent event;
  final PeriodKind kind;

  DateTime get center => event.time;
  DateTime get start => center.subtract(kind.halfLength);
  DateTime get end => center.add(kind.halfLength);

  bool contains(DateTime utc) => !utc.isBefore(start) && utc.isBefore(end);
}

/// The day score and the three parts it's made of. Each part is a plain sun/moon
/// fact; nothing here is a prediction about any particular water or animal.
class Score {
  const Score({required this.phase, required this.timing, required this.distance});

  /// 1 at new and full moon, 0 at the quarters: cos²(moon age).
  final double phase;

  /// How closely a Major/Minor period lines up with sunrise and with sunset (0…1).
  final double timing;

  /// 1 when the moon is at its closest (perigee), 0 at its farthest (apogee).
  final double distance;

  static const phaseMax = 60, timingMax = 25, distanceMax = 15;

  int get phasePoints => (phase * phaseMax).round();
  int get timingPoints => (timing * timingMax).round();
  int get distancePoints => (distance * distanceMax).round();
  int get total => (phasePoints + timingPoints + distancePoints).clamp(0, 100);

  Rating get rating => Rating.of(total);
}

enum Rating {
  best('Best'),
  good('Good'),
  fair('Fair'),
  slow('Slow');

  const Rating(this.label);
  final String label;

  static Rating of(int score) => score >= 70
      ? best
      : score >= 50
      ? good
      : score >= 30
      ? fair
      : slow;
}

/// Legal shooting light: [beforeSunrise] minutes before sunrise to
/// [afterSunset] minutes after sunset (the user sets both; states differ).
class LegalLight {
  const LegalLight(this.start, this.end);
  final DateTime start; // UTC
  final DateTime end; // UTC
}

const _alignWindow = Duration(minutes: 90);

/// One local calendar day at a place: sun, moon, periods, score.
class SolunarDay {
  SolunarDay(this.place, this.wallDay)
    : zone = PlaceZone(place.tz),
      start = PlaceZone(place.tz).startOfDay(wallDay),
      end = PlaceZone(place.tz).startOfDay(DateTime.utc(wallDay.year, wallDay.month, wallDay.day + 1)) {
    sun = sunTimes(wallDay, place.lat, place.lng);
    // A little either side so a period just across midnight still counts for sunrise/sunset timing.
    final around = moonEvents(
      start.subtract(const Duration(hours: 3)),
      end.add(const Duration(hours: 3)),
      place.lat,
      place.lng,
    );
    moon = [
      for (final e in around)
        if (!e.time.isBefore(start) && e.time.isBefore(end)) e,
    ];
    periods = [for (final e in moon) Period(e)];
    final mid = start.add(Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2));
    phase = moonForDay(start, end);
    distanceKm = moonPosition(mid).distanceKm;
    score = Score(
      phase: math.pow(math.cos(phase.age * math.pi / 180), 2).toDouble(),
      timing: _timing([for (final e in around) Period(e)]),
      distance: ((_apogeeKm - distanceKm) / (_apogeeKm - _perigeeKm)).clamp(0.0, 1.0),
    );
  }

  /// Typical extremes of the moon's distance (km); the closest perigees and
  /// farthest apogees of a year land near these.
  static const _perigeeKm = 356500.0, _apogeeKm = 406700.0;

  final Place place;
  final PlaceZone zone;
  final DateTime wallDay; // local date, UTC fields
  final DateTime start; // UTC
  final DateTime end; // UTC
  late final SunTimes sun;
  late final List<MoonEvent> moon;
  late final List<Period> periods;
  late final MoonDay phase;
  late final double distanceKm;
  late final Score score;

  bool contains(DateTime utc) => !utc.isBefore(start) && utc.isBefore(end);

  MoonEvent? event(MoonEventKind k) {
    for (final e in moon) {
      if (e.kind == k) return e;
    }
    return null;
  }

  List<Period> get majors => [
    for (final p in periods)
      if (p.kind == PeriodKind.major) p,
  ];
  List<Period> get minors => [
    for (final p in periods)
      if (p.kind == PeriodKind.minor) p,
  ];

  /// Sunrise and sunset each get the best of: a Major centred right on it (1.0)
  /// or a Minor (0.75), fading to nothing 90 minutes away. Average of the two.
  double _timing(List<Period> candidates) {
    double at(DateTime? sunEvent) {
      if (sunEvent == null) return 0;
      var best = 0.0;
      for (final p in candidates) {
        final gap = p.center.difference(sunEvent).inSeconds.abs() / _alignWindow.inSeconds;
        final v = (1 - gap).clamp(0.0, 1.0) * (p.kind == PeriodKind.major ? 1.0 : 0.75);
        if (v > best) best = v;
      }
      return best;
    }

    return (at(sun.sunrise) + at(sun.sunset)) / 2;
  }

  LegalLight? legalLight(int beforeSunrise, int afterSunset) {
    final r = sun.sunrise, s = sun.sunset;
    if (r == null || s == null) return null;
    return LegalLight(r.subtract(Duration(minutes: beforeSunrise)), s.add(Duration(minutes: afterSunset)));
  }

  /// Days starting with the local date that contains [nowUtc].
  static List<SolunarDay> week(Place place, DateTime nowUtc, {int count = 7}) {
    final today = PlaceZone(place.tz).dayOf(nowUtc);
    return [for (var i = 0; i < count; i++) SolunarDay(place, DateTime.utc(today.year, today.month, today.day + i))];
  }
}

/// What's happening right now, from today's and tomorrow's periods.
class NowStatus {
  NowStatus._(this.current, this.next);

  /// The period we're in, if any.
  final Period? current;

  /// The next period to start.
  final Period? next;

  static NowStatus at(DateTime nowUtc, List<SolunarDay> days) {
    final all = [for (final d in days) ...d.periods]..sort((a, b) => a.start.compareTo(b.start));
    Period? cur, nxt;
    for (final p in all) {
      if (p.contains(nowUtc)) {
        // Overlapping periods: the Major wins, then whichever ends later.
        if (cur == null ||
            (p.kind == PeriodKind.major && cur.kind == PeriodKind.minor) ||
            (p.kind == cur.kind && p.end.isAfter(cur.end))) {
          cur = p;
        }
      } else if (p.start.isAfter(nowUtc) && nxt == null) {
        nxt = p;
      }
    }
    return NowStatus._(cur, nxt);
  }
}
