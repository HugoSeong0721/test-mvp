import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

/// A place's clock, from the IANA time zone database (bundled, works offline).
///
/// Instants are kept in UTC. "Wall" times are local clock readings stored in a
/// UTC [DateTime] so their fields (day, hour) never get shifted by the device's
/// own time zone.
class PlaceZone {
  PlaceZone._(this.name, this._loc);

  static bool _ready = false;

  /// IANA database 2025c ("all", with old alias names), copied from the
  /// `timezone` package. Loaded as an asset rather than the package's embedded
  /// Dart string, which added 1.8 MB to the web preview's script.
  static Future<void> load() async {
    if (_ready) return;
    final data = await rootBundle.load('assets/tz/latest_all.tzf');
    tz.initializeDatabase(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    _ready = true;
  }

  static void ensureLoaded() {
    if (!_ready) throw StateError('PlaceZone.load() must run first');
  }

  static bool isKnown(String name) {
    ensureLoaded();
    return tz.timeZoneDatabase.locations.containsKey(name);
  }

  static final Map<String, PlaceZone> _cache = {};

  /// Unknown names fall back to UTC rather than throwing.
  factory PlaceZone(String name) {
    ensureLoaded();
    return _cache.putIfAbsent(name, () {
      final loc = tz.timeZoneDatabase.locations[name];
      return loc == null ? PlaceZone._('UTC', tz.UTC) : PlaceZone._(name, loc);
    });
  }

  final String name;
  final tz.Location _loc;

  Duration offsetAt(DateTime utc) => _loc.timeZone(utc.toUtc().millisecondsSinceEpoch).offset;

  DateTime toWall(DateTime utc) {
    final u = utc.toUtc();
    return u.add(offsetAt(u));
  }

  /// Local clock reading (fields of [wall]) → UTC instant.
  DateTime fromWall(DateTime wall) => DateTime.fromMillisecondsSinceEpoch(
    tz.TZDateTime(_loc, wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).millisecondsSinceEpoch,
    isUtc: true,
  );

  /// UTC instant of the local midnight that starts [wallDay]'s date.
  DateTime startOfDay(DateTime wallDay) => fromWall(DateTime.utc(wallDay.year, wallDay.month, wallDay.day));

  /// Local date (midnight, UTC fields) for [utc].
  DateTime dayOf(DateTime utc) {
    final w = toWall(utc);
    return DateTime.utc(w.year, w.month, w.day);
  }

  /// "CDT", "PST"; "UTC+10" style where the database has only a number.
  String abbreviation(DateTime utc) {
    final a = _loc.timeZone(utc.toUtc().millisecondsSinceEpoch).abbreviation;
    if (RegExp(r'^[A-Z]{2,5}$').hasMatch(a)) return a;
    final m = offsetAt(utc).inMinutes;
    final h = m ~/ 60, mm = (m.abs() % 60);
    return 'UTC${m >= 0 ? '+' : '−'}${h.abs()}${mm == 0 ? '' : ':${mm.toString().padLeft(2, '0')}'}';
  }
}
