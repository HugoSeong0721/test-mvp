import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'location.dart';
import 'station.dart';
import 'tides.dart';

/// App state: chosen station, its predictions (cached on the device so they
/// still show near the water with no signal), favorites and units.
/// Screens listen to this instead of passing results back through Navigator.
class AppStore extends ChangeNotifier {
  static AppStore i = AppStore();

  /// UTC "now". Tests pin it.
  DateTime Function() clock = () => DateTime.now().toUtc();

  http.Client httpClient = http.Client();

  late SharedPreferences _prefs;
  late StationDb db;

  Units units = Units.feet;
  List<String> favorites = [];
  Station? station;

  /// Picked from the device location (re-checked on every launch) rather than by hand.
  bool followLocation = false;

  /// Last known device location, this session only.
  (double, double)? here;

  TideData? data;
  bool loading = false;
  String? error;

  /// Last fetch failed but saved predictions are shown.
  bool get offline => error != null && data != null;

  static const _maxCached = 12;

  /// Fetch again after this long even if the saved data still covers the week.
  static const refreshAfter = Duration(hours: 12);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    db = await StationDb.load();
    units = _prefs.getString('units') == 'm' ? Units.meters : Units.feet;
    favorites = _prefs.getStringList('favorites') ?? [];
    followLocation = _prefs.getBool('followLocation') ?? false;
    final id = _prefs.getString('station');
    station = id == null ? null : db.byId(id);
    data = station == null ? null : _cached(station!.id);
    loading = false;
    error = null;
    here = null;
  }

  /// On launch / when the app comes back: follow the device if the user chose
  /// "near me" before (no prompt unless permission is already granted), then refresh.
  Future<void> resume() async {
    if (followLocation && await LocationService.i.hasPermission()) {
      final r = await LocationService.i.current();
      if (r.ok) {
        here = (r.lat!, r.lng!);
        final near = db.nearest(r.lat!, r.lng!, count: 1).first.$1;
        if (near != station) {
          await selectStation(near, viaLocation: true);
          return;
        }
      }
    }
    await refresh();
  }

  /// Ask for the location (may show the system prompt) and switch to the nearest station.
  Future<LocationResult> useMyLocation() async {
    final r = await LocationService.i.current();
    if (r.ok) {
      here = (r.lat!, r.lng!);
      await selectStation(db.nearest(r.lat!, r.lng!, count: 1).first.$1, viaLocation: true);
    } else {
      notifyListeners();
    }
    return r;
  }

  Future<void> selectStation(Station s, {bool viaLocation = false}) async {
    station = s;
    followLocation = viaLocation;
    data = _cached(s.id);
    error = null;
    loading = false;
    await _prefs.setString('station', s.id);
    await _prefs.setBool('followLocation', viaLocation);
    notifyListeners();
    await refresh();
  }

  bool _needsFetch(TideData? d, DateTime now) =>
      d == null ||
      now.difference(d.fetchedAt) > refreshAfter ||
      d.fetchedAt.isAfter(now.add(const Duration(minutes: 5))) ||
      d.coversUntil!.isBefore(now.add(const Duration(days: 6, hours: 12)));

  Station? _inFlight;

  Future<void> refresh({bool force = false}) async {
    final s = station;
    if (s == null || _inFlight == s) return;
    final now = clock();
    if (!force && !_needsFetch(data, now)) return;
    _inFlight = s;
    loading = true;
    notifyListeners();
    try {
      final d = await NoaaApi(httpClient).fetch(s, now);
      await _save(d);
      if (station == s) {
        data = d;
        error = null;
      }
    } on NoaaException catch (e) {
      if (station == s) error = e.message;
    } finally {
      if (_inFlight == s) _inFlight = null;
      if (station == s) {
        loading = false;
        notifyListeners();
      }
    }
  }

  TideData? _cached(String id) => TideData.decode(_prefs.getString('cache.$id'));

  Future<void> _save(TideData d) async {
    final ids = (_prefs.getStringList('cache.ids') ?? [])..remove(d.stationId);
    ids.insert(0, d.stationId);
    while (ids.length > _maxCached) {
      await _prefs.remove('cache.${ids.removeLast()}');
    }
    await _prefs.setStringList('cache.ids', ids);
    await _prefs.setString('cache.${d.stationId}', d.encode());
  }

  bool isFavorite(Station s) => favorites.contains(s.id);

  Future<void> toggleFavorite(Station s) async {
    if (!favorites.remove(s.id)) favorites.add(s.id);
    await _prefs.setStringList('favorites', favorites);
    notifyListeners();
  }

  Future<void> setUnits(Units u) async {
    units = u;
    await _prefs.setString('units', u == Units.meters ? 'm' : 'ft');
    notifyListeners();
  }

  List<Station> get favoriteStations =>
      [for (final id in favorites) if (db.byId(id) != null) db.byId(id)!];
}

/// One-tap starting points when the search box is empty. All NOAA reference stations.
const popularStationIds = [
  '9410230', // La Jolla
  '9410840', // Santa Monica
  '9414290', // San Francisco
  '9447130', // Seattle
  '1612340', // Honolulu
  '8723170', // Miami
  '8724580', // Key West
  '8771450', // Galveston
  '8661070', // Myrtle Beach
  '8570283', // Ocean City
  '8534720', // Atlantic City
  '8518750', // New York
  '8443970', // Boston
];
