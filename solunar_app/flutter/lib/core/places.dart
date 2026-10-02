import 'dart:math' as math;

import 'package:flutter/services.dart';

/// A spot the solunar times are worked out for.
class Place {
  const Place({
    required this.name,
    required this.lat,
    required this.lng,
    required this.tz,
    this.detail,
    this.isGps = false,
  });

  /// "Austin, TX", a name the user gave ("Deer stand"), or "My Location".
  final String name;

  /// Second line, e.g. "near Austin, TX".
  final String? detail;
  final double lat;
  final double lng;

  /// IANA time zone name.
  final String tz;

  /// Follows the device location.
  final bool isGps;

  /// Same spot (to ~100 m) regardless of name.
  String get key => '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  bool sameSpot(Place o) => key == o.key;

  Place copyWith({String? name, String? detail, bool? isGps}) => Place(
    name: name ?? this.name,
    detail: detail ?? this.detail,
    lat: lat,
    lng: lng,
    tz: tz,
    isGps: isGps ?? this.isGps,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    if (detail != null) 'detail': detail,
    'lat': lat,
    'lng': lng,
    'tz': tz,
    if (isGps) 'gps': true,
  };

  static Place? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['name'], lat = j['lat'], lng = j['lng'], tz = j['tz'];
    if (name is! String || lat is! num || lng is! num || tz is! String) return null;
    return Place(
      name: name,
      detail: j['detail'] as String?,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      tz: tz,
      isGps: j['gps'] == true,
    );
  }

  @override
  String toString() => 'Place($name $key $tz)';
}

class Town {
  const Town(this.name, this.region, this.lat, this.lng, this.tz, this.population);

  final String name;
  final String region; // "TX", "ON"
  final double lat;
  final double lng;
  final String tz;
  final int population;

  String get label => '$name, $region';

  Place toPlace() => Place(name: label, lat: lat, lng: lng, tz: tz);
}

/// Statute miles between two points (haversine).
double milesBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 3958.8;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[àáâãäå]'), 'a')
    .replaceAll(RegExp(r'[èéêë]'), 'e')
    .replaceAll(RegExp(r'[ìíîï]'), 'i')
    .replaceAll(RegExp(r'[òóôõö]'), 'o')
    .replaceAll(RegExp(r'[ùúûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

/// US and Canadian towns of 1,000+ people (GeoNames, CC BY 4.0), bundled so
/// search and "nearest town" work with no signal.
class PlaceDb {
  PlaceDb(this.towns) : _folded = [for (final t in towns) _fold(t.name)];

  final List<Town> towns; // biggest first
  final List<String> _folded;

  static PlaceDb? _loaded;

  /// Parsed once per app run (20k rows).
  static Future<PlaceDb> load() async => _loaded ??= parse(await rootBundle.loadString('assets/places.tsv'));

  static PlaceDb parse(String tsv) {
    final lines = tsv.split('\n');
    final zones = lines.first.split('|');
    final out = <Town>[];
    for (final l in lines.skip(1)) {
      if (l.isEmpty) continue;
      final f = l.split('\t');
      out.add(Town(f[0], f[1], double.parse(f[2]), double.parse(f[3]), zones[int.parse(f[4])], int.parse(f[5])));
    }
    return PlaceDb(out);
  }

  late final Set<String> _regions = {for (final t in towns) t.region};

  /// "austin", "austin tx", "Austin, TX", "st louis". Prefix matches of the town
  /// name come first; bigger towns first within each group.
  List<Town> search(String query, {int limit = 40}) {
    final q = _fold(query);
    if (q.isEmpty) return const [];
    final parts = q.split(' ');
    if (parts.length > 1 && parts.last.length == 2 && _regions.contains(parts.last.toUpperCase())) {
      final hit = _match(parts.sublist(0, parts.length - 1).join(' '), parts.last.toUpperCase(), limit);
      if (hit.isNotEmpty) return hit;
    }
    return _match(q, null, limit);
  }

  List<Town> _match(String name, String? region, int limit) {
    // "St." / "Saint" and "Mt." / "Mount" are written both ways.
    final alts = <String>{
      name,
      if (name.startsWith('st ')) 'saint ${name.substring(3)}',
      if (name.startsWith('saint ')) 'st ${name.substring(6)}',
      if (name.startsWith('mt ')) 'mount ${name.substring(3)}',
      if (name.startsWith('mount ')) 'mt ${name.substring(6)}',
    };
    final exact = <Town>[], prefix = <Town>[], inside = <Town>[];
    for (var i = 0; i < towns.length; i++) {
      final t = towns[i];
      if (region != null && t.region != region) continue;
      final f = _folded[i];
      if (alts.contains(f)) {
        exact.add(t); // "spring" → Spring, TX before Springfield
      } else if (alts.any(f.startsWith)) {
        prefix.add(t);
        if (prefix.length >= limit) break;
      } else if (inside.length < limit && alts.any((a) => f.contains(' $a'))) {
        inside.add(t);
      }
    }
    return [...exact, ...prefix, ...inside].take(limit).toList();
  }

  /// The town to name a GPS spot after: the closest, but a much bigger town a
  /// little farther away wins (1.5 miles per tenfold population), so a spot in
  /// Austin reads "near Austin, TX" rather than a campus or neighborhood entry.
  (Town, double)? landmark(double lat, double lng) {
    final near = nearest(lat, lng, count: 12);
    if (near.isEmpty) return null;
    double eff((Town, double) x) => x.$2 - 1.5 * math.log(math.max(x.$1.population, 1)) / math.ln10;
    return near.reduce((a, b) => eff(b) < eff(a) ? b : a);
  }

  /// Closest towns to a point, nearest first, with their distance in miles.
  List<(Town, double)> nearest(double lat, double lng, {int count = 1}) {
    final best = <(Town, double)>[];
    final cosLat = math.cos(lat * math.pi / 180);
    for (final t in towns) {
      // Cheap flat-earth distance to rank, exact distance for the result.
      final dy = t.lat - lat, dx = (t.lng - lng) * cosLat;
      final d2 = dx * dx + dy * dy;
      if (best.length < count || d2 < best.last.$2) {
        best.add((t, d2));
        best.sort((a, b) => a.$2.compareTo(b.$2));
        if (best.length > count) best.removeLast();
      }
    }
    return [for (final (t, _) in best) (t, milesBetween(lat, lng, t.lat, t.lng))];
  }
}
