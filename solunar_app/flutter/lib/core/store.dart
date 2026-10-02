import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_zone.dart';
import 'location.dart';
import 'places.dart';
import 'solunar.dart';
import 'zone.dart';

/// App state: the place, saved spots, shooting-light offsets and the 30-day
/// calendar unlock. Everything is worked out on the device — nothing to fetch.
/// Screens listen to this instead of passing results back through Navigator.
class AppStore extends ChangeNotifier {
  static AppStore i = AppStore();

  /// UTC "now". Tests pin it.
  DateTime Function() clock = () => DateTime.now().toUtc();

  late SharedPreferences _prefs;
  late PlaceDb db;

  /// The place on screen. Null until the user picks one (welcome screen).
  Place? place;

  /// Follow the device location on every launch.
  bool followLocation = false;

  /// Device location is being looked up.
  bool locating = false;

  List<Place> favorites = [];

  /// Legal shooting light: minutes before sunrise / after sunset.
  int beforeSunrise = 30;
  int afterSunset = 30;

  /// The 30-day calendar is open until this time (after a rewarded video).
  DateTime? calendarUntil;

  static const maxFavorites = 20;
  static const unlockFor = Duration(hours: 24);

  Future<void> load() async {
    await PlaceZone.load();
    _prefs = await SharedPreferences.getInstance();
    db = await PlaceDb.load();
    place = _readPlace('place');
    followLocation = _prefs.getBool('followLocation') ?? false;
    favorites = [for (final j in _readList('favorites')) ?Place.fromJson(j)];
    beforeSunrise = _prefs.getInt('beforeSunrise') ?? 30;
    afterSunset = _prefs.getInt('afterSunset') ?? 30;
    final until = _prefs.getString('calendarUntil');
    calendarUntil = until == null ? null : DateTime.tryParse(until);
    locating = false;
    _weekCache = null;
  }

  Place? _readPlace(String key) {
    final s = _prefs.getString(key);
    if (s == null) return null;
    try {
      return Place.fromJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }

  List<Object?> _readList(String key) {
    final s = _prefs.getString(key);
    if (s == null) return const [];
    try {
      final v = jsonDecode(s);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  // ───────────── place ─────────────

  Future<void> selectPlace(Place p, {bool viaLocation = false}) async {
    place = p;
    followLocation = viaLocation;
    _weekCache = null;
    await _prefs.setString('place', jsonEncode(p.toJson()));
    await _prefs.setBool('followLocation', viaLocation);
    notifyListeners();
  }

  /// "near Austin, TX" for a GPS fix, with the town's zone as a fallback when the
  /// phone's zone is unknown.
  Future<Place> placeFromFix(double lat, double lng) async {
    var zone = await DeviceZone.i.name();
    String? detail;
    if (db.landmark(lat, lng) case (final town, final mi) when mi < 60) {
      detail = mi < 1 ? 'in ${town.label}' : 'near ${town.label}';
    }
    final near = db.nearest(lat, lng, count: 1);
    if (zone == 'UTC' && near.isNotEmpty && near.first.$2 < 150) zone = near.first.$1.tz;
    return Place(name: 'My Location', detail: detail, lat: lat, lng: lng, tz: zone, isGps: true);
  }

  /// Ask for the location (may show the system prompt) and show times for it.
  Future<LocationResult> useMyLocation() async {
    locating = true;
    notifyListeners();
    final r = await LocationService.i.current();
    locating = false;
    if (r.ok) {
      await selectPlace(await placeFromFix(r.lat!, r.lng!), viaLocation: true);
    } else {
      notifyListeners();
    }
    return r;
  }

  /// On launch / when the app comes back: if the user follows their location
  /// (and permission is already there — no prompt), refresh the spot quietly.
  /// No fix (no signal, indoors) keeps the last known spot.
  Future<void> resume() async {
    if (!followLocation || locating) return;
    if (!await LocationService.i.hasPermission()) return;
    locating = true;
    notifyListeners();
    final r = await LocationService.i.current();
    locating = false;
    if (r.ok && followLocation) {
      final p = await placeFromFix(r.lat!, r.lng!);
      final old = place;
      // Ignore GPS jitter: only move for ~half a mile or a new name/zone.
      if (old == null ||
          milesBetween(old.lat, old.lng, p.lat, p.lng) > 0.5 ||
          old.detail != p.detail ||
          old.tz != p.tz) {
        await selectPlace(p, viaLocation: true);
        return;
      }
    }
    notifyListeners();
  }

  // ───────────── saved spots ─────────────

  bool isFavorite(Place p) => favorites.any((f) => f.sameSpot(p));

  Future<void> addFavorite(Place p, {String? name}) async {
    if (isFavorite(p)) return;
    final saved = p.copyWith(name: name?.trim().isNotEmpty == true ? name!.trim() : null, isGps: false);
    favorites = [saved, ...favorites].take(maxFavorites).toList();
    await _saveFavorites();
  }

  Future<void> removeFavorite(Place p) async {
    favorites = [
      for (final f in favorites)
        if (!f.sameSpot(p)) f,
    ];
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    await _prefs.setString('favorites', jsonEncode([for (final f in favorites) f.toJson()]));
    notifyListeners();
  }

  // ───────────── shooting light ─────────────

  Future<void> setLegalOffsets({int? before, int? after}) async {
    beforeSunrise = (before ?? beforeSunrise).clamp(0, 90);
    afterSunset = (after ?? afterSunset).clamp(0, 90);
    await _prefs.setInt('beforeSunrise', beforeSunrise);
    await _prefs.setInt('afterSunset', afterSunset);
    notifyListeners();
  }

  // ───────────── 30-day calendar ─────────────

  bool get calendarOpen {
    final u = calendarUntil;
    final now = clock();
    // A clock moved backwards past the unlock doesn't keep it open for days.
    return u != null && now.isBefore(u) && u.difference(now) <= unlockFor;
  }

  Future<void> unlockCalendar() async {
    calendarUntil = clock().add(unlockFor);
    await _prefs.setString('calendarUntil', calendarUntil!.toIso8601String());
    notifyListeners();
  }

  // ───────────── days ─────────────

  (String, DateTime, int)? _weekKey;
  List<SolunarDay>? _weekCache;

  /// [count] local days from today at the current place. Cached per place/day.
  List<SolunarDay> days({int count = 8}) {
    final p = place;
    if (p == null) return const [];
    final today = PlaceZone(p.tz).dayOf(clock());
    final key = ('${p.key}|${p.tz}', today, count);
    if (_weekCache != null && _weekKey == key) return _weekCache!;
    _weekKey = key;
    return _weekCache = SolunarDay.week(p, clock(), count: count);
  }
}
