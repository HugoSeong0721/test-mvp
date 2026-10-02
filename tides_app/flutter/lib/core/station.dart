import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'zone.dart';

/// A NOAA tide-prediction station (bundled list, tools/tides/make_asset.py).
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.state,
    required this.lat,
    required this.lng,
    required this.isReference,
    required this.zone,
  });

  final String id;
  final String name;
  final String state;
  final double lat;
  final double lng;

  /// Harmonic (reference) stations have full 6-minute predictions; subordinate
  /// stations only publish high/low times.
  final bool isReference;
  final StationZone zone;

  factory Station.fromRow(List<dynamic> r) => Station(
        id: r[0] as String,
        name: r[1] as String,
        state: r[2] as String,
        lat: (r[3] as num).toDouble(),
        lng: (r[4] as num).toDouble(),
        isReference: r[5] == 1,
        zone: StationZone((r[6] as num).toInt(), observesDst: r[7] == 1),
      );

  String get stateName => usStates[state] ?? '';

  /// "CA" or "" for stations outside US states/territories.
  String get place => state;

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const usStates = {
  'AL': 'Alabama', 'AK': 'Alaska', 'CA': 'California', 'CT': 'Connecticut',
  'DE': 'Delaware', 'DC': 'District of Columbia', 'FL': 'Florida',
  'GA': 'Georgia', 'HI': 'Hawaii', 'LA': 'Louisiana', 'ME': 'Maine',
  'MD': 'Maryland', 'MA': 'Massachusetts', 'MS': 'Mississippi',
  'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NY': 'New York',
  'NC': 'North Carolina', 'OR': 'Oregon', 'PA': 'Pennsylvania',
  'RI': 'Rhode Island', 'SC': 'South Carolina', 'TX': 'Texas',
  'VA': 'Virginia', 'WA': 'Washington', 'PR': 'Puerto Rico',
  'VI': 'U.S. Virgin Islands', 'GU': 'Guam', 'AS': 'American Samoa',
  'FM': 'Micronesia', 'MP': 'Northern Mariana Islands',
};

/// Great-circle distance in miles.
double milesBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 3958.8;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

class StationDb {
  StationDb(this.all) : _byId = {for (final s in all) s.id: s};

  final List<Station> all;
  final Map<String, Station> _byId;

  static StationDb? _cached;

  static Future<StationDb> load([AssetBundle? bundle]) async {
    if (_cached != null) return _cached!;
    final text = await (bundle ?? rootBundle).loadString('assets/stations.json');
    final rows = jsonDecode(text) as List<dynamic>;
    return _cached = StationDb([for (final r in rows) Station.fromRow(r as List<dynamic>)]);
  }

  Station? byId(String id) => _byId[id];

  List<(Station, double)> nearest(double lat, double lng, {int count = 10}) {
    final list = [for (final s in all) (s, milesBetween(lat, lng, s.lat, s.lng))]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return list.take(count).toList();
  }

  /// Search by station name, city, state ("CA" or "California") or station ID.
  /// Every word of the query must match; names starting with the query come first.
  List<Station> search(String query, {double? lat, double? lng, int limit = 60}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final words = q.split(RegExp(r'[\s,]+')).where((w) => w.isNotEmpty).toList();
    final hits = <(Station, int, double)>[];
    for (final s in all) {
      final name = s.name.toLowerCase();
      final hay = '$name ${s.state.toLowerCase()} ${s.stateName.toLowerCase()} ${s.id}';
      if (!words.every(hay.contains)) continue;
      final rank = s.id == q
          ? 0
          : name.startsWith(q)
              ? 1
              : RegExp('\\b${RegExp.escape(words.first)}').hasMatch(name)
                  ? 2
                  : 3;
      final d = (lat != null && lng != null) ? milesBetween(lat, lng, s.lat, s.lng) : 0.0;
      hits.add((s, rank, d));
    }
    hits.sort((a, b) {
      final r = a.$2.compareTo(b.$2);
      if (r != 0) return r;
      if (lat != null) return a.$3.compareTo(b.$3);
      return a.$1.name.compareTo(b.$1.name);
    });
    return [for (final h in hits.take(limit)) h.$1];
  }
}
