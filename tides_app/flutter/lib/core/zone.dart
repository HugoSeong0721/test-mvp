/// A station's clock. NOAA gives each station a standard UTC offset; whether it
/// observes daylight saving time is decided by region when the station list is
/// built (tools/tides/make_asset.py). Stations that observe DST follow US rules,
/// like NOAA's own "LST/LDT" tables.
///
/// Instants are kept in UTC. "Wall" times are station-local clock readings
/// stored in a UTC [DateTime] so their fields (day, hour) never get shifted by
/// the device's own time zone.
class StationZone {
  const StationZone(this.stdOffsetHours, {required this.observesDst});

  final int stdOffsetHours;
  final bool observesDst;

  Duration get _std => Duration(hours: stdOffsetHours);

  /// DST starts 2:00 local standard time on the second Sunday of March and ends
  /// 2:00 local daylight time on the first Sunday of November.
  bool isDst(DateTime utc) {
    if (!observesDst) return false;
    final y = utc.toUtc().year;
    final start = DateTime.utc(y, 3, _nthSunday(y, 3, 2), 2).subtract(_std);
    final end = DateTime.utc(y, 11, _nthSunday(y, 11, 1), 1).subtract(_std);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  Duration offsetAt(DateTime utc) =>
      isDst(utc) ? _std + const Duration(hours: 1) : _std;

  DateTime toWall(DateTime utc) {
    final u = utc.toUtc();
    return u.add(offsetAt(u));
  }

  /// Station-local clock reading (fields of [wall]) → UTC instant.
  DateTime fromWall(DateTime wall) {
    final w = DateTime.utc(wall.year, wall.month, wall.day, wall.hour,
        wall.minute, wall.second);
    final guess = w.subtract(_std);
    return w.subtract(offsetAt(guess));
  }

  /// UTC instant of the station-local midnight that starts [wallDay]'s date.
  DateTime startOfDay(DateTime wallDay) =>
      fromWall(DateTime.utc(wallDay.year, wallDay.month, wallDay.day));

  /// Station-local date (midnight, UTC fields) for [utc].
  DateTime dayOf(DateTime utc) {
    final w = toWall(utc);
    return DateTime.utc(w.year, w.month, w.day);
  }

  /// Short US-style zone name ("PDT"); "UTC+10" style elsewhere.
  String abbreviation(DateTime utc) {
    final dst = isDst(utc);
    final names = switch (stdOffsetHours) {
      -4 => ('AST', 'ADT'),
      -5 => ('EST', 'EDT'),
      -6 => ('CST', 'CDT'),
      -7 => ('MST', 'MDT'),
      -8 => ('PST', 'PDT'),
      -9 => ('AKST', 'AKDT'),
      -10 => ('HST', 'HDT'),
      -11 => ('SST', 'SST'),
      10 => ('ChST', 'ChST'),
      _ => (null, null),
    };
    if (names.$1 != null) return dst ? names.$2! : names.$1!;
    final h = offsetAt(utc).inHours;
    return 'UTC${h >= 0 ? '+' : '−'}${h.abs()}';
  }

  static int _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1).weekday; // Mon=1 … Sun=7
    final firstSunday = 1 + (7 - first) % 7;
    return firstSunday + 7 * (n - 1);
  }
}
