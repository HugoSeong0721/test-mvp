import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'station.dart';

/// A predicted high or low tide. Heights are feet above MLLW (NOAA's chart datum).
class TideEvent {
  const TideEvent(this.time, this.feet, {required this.isHigh});

  final DateTime time; // UTC
  final double feet;
  final bool isHigh;

  Map<String, Object> toJson() =>
      {'t': time.millisecondsSinceEpoch, 'v': feet, 'h': isHigh};

  factory TideEvent.fromJson(Map<String, dynamic> j) => TideEvent(
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int, isUtc: true),
        (j['v'] as num).toDouble(),
        isHigh: j['h'] as bool,
      );
}

/// Evenly spaced NOAA predictions (6-minute series, reference stations only).
class TideCurve {
  const TideCurve(this.start, this.stepMinutes, this.feet);

  final DateTime start; // UTC
  final int stepMinutes;
  final List<double> feet;

  DateTime get end => start.add(Duration(minutes: stepMinutes * (feet.length - 1)));

  double? at(DateTime utc) {
    final m = utc.difference(start).inSeconds / 60 / stepMinutes;
    if (m < 0 || m > feet.length - 1) return null;
    final i = m.floor();
    if (i >= feet.length - 1) return feet.last;
    final f = m - i;
    return feet[i] * (1 - f) + feet[i + 1] * f;
  }

  Map<String, Object> toJson() => {
        's': start.millisecondsSinceEpoch,
        'm': stepMinutes,
        'v': [for (final v in feet) (v * 1000).round()],
      };

  factory TideCurve.fromJson(Map<String, dynamic> j) => TideCurve(
        DateTime.fromMillisecondsSinceEpoch(j['s'] as int, isUtc: true),
        j['m'] as int,
        [for (final v in j['v'] as List<dynamic>) (v as num) / 1000],
      );
}

/// Everything NOAA returned for one station, as cached on the device.
class TideData {
  const TideData({
    required this.stationId,
    required this.fetchedAt,
    required this.events,
    this.curve,
  });

  final String stationId;
  final DateTime fetchedAt; // UTC
  final List<TideEvent> events; // sorted by time
  final TideCurve? curve;

  DateTime? get coversUntil => events.isEmpty ? null : events.last.time;

  /// Whether the curve between high and low is NOAA's own 6-minute series
  /// (reference stations) or estimated from the high/low predictions.
  bool get hasOfficialCurve => curve != null;

  /// Height at [utc]: NOAA's 6-minute series when available, otherwise cosine
  /// interpolation between the surrounding NOAA high/low predictions (the
  /// method in NOAA's Tide Tables, Table 3). Null outside the predicted range.
  double? heightAt(DateTime utc) {
    final c = curve?.at(utc);
    if (c != null) return c;
    final i = events.indexWhere((e) => e.time.isAfter(utc));
    if (i <= 0) {
      if (i == -1 && events.isNotEmpty && events.last.time == utc) return events.last.feet;
      return null;
    }
    final a = events[i - 1], b = events[i];
    final f = utc.difference(a.time).inSeconds / b.time.difference(a.time).inSeconds;
    return (a.feet + b.feet) / 2 + (a.feet - b.feet) / 2 * math.cos(math.pi * f);
  }

  TideEvent? nextEvent(DateTime utc, {bool? high}) {
    for (final e in events) {
      if (e.time.isAfter(utc) && (high == null || e.isHigh == high)) return e;
    }
    return null;
  }

  TideEvent? previousEvent(DateTime utc) {
    TideEvent? last;
    for (final e in events) {
      if (e.time.isAfter(utc)) break;
      last = e;
    }
    return last;
  }

  List<TideEvent> eventsBetween(DateTime from, DateTime to) =>
      [for (final e in events) if (!e.time.isBefore(from) && e.time.isBefore(to)) e];

  String encode() => jsonEncode({
        'id': stationId,
        'f': fetchedAt.millisecondsSinceEpoch,
        'e': [for (final e in events) e.toJson()],
        if (curve != null) 'c': curve!.toJson(),
      });

  static TideData? decode(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return TideData(
        stationId: j['id'] as String,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['f'] as int, isUtc: true),
        events: [
          for (final e in j['e'] as List<dynamic>) TideEvent.fromJson(e as Map<String, dynamic>)
        ],
        curve: j['c'] == null ? null : TideCurve.fromJson(j['c'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}

class NoaaException implements Exception {
  NoaaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// NOAA CO-OPS data API — free, no key. Times are requested in GMT and shown in
/// the station's own clock ([Station.zone]).
class NoaaApi {
  NoaaApi(this.client);

  final http.Client client;
  static const host = 'api.tidesandcurrents.noaa.gov';
  static const timeout = Duration(seconds: 15);

  static String _d(DateTime u) =>
      '${u.year}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}';

  static Uri predictionsUri(String station, DateTime beginUtc, DateTime endUtc, String interval) =>
      Uri.https(host, '/api/prod/datagetter', {
        'product': 'predictions',
        'application': 'soulfulfill_tides',
        'begin_date': _d(beginUtc),
        'end_date': _d(endUtc),
        'datum': 'MLLW',
        'station': station,
        'time_zone': 'gmt',
        'units': 'english',
        'interval': interval,
        'format': 'json',
      });

  static DateTime _parseTime(String t) {
    // "2026-10-01 04:00" in GMT
    final p = t.split(RegExp(r'[- :]'));
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]),
        int.parse(p[3]), int.parse(p[4]));
  }

  Future<List<dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw NoaaException('NOAA took too long to answer.');
    } catch (_) {
      throw NoaaException("Couldn't reach NOAA. Check your connection.");
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw NoaaException('NOAA sent an unexpected answer (HTTP ${res.statusCode}).');
    }
    final err = j['error'];
    if (err is Map) throw NoaaException('NOAA: ${(err['message'] ?? 'error').toString().trim()}');
    final p = j['predictions'];
    if (p is! List) throw NoaaException('NOAA sent no predictions.');
    return p;
  }

  /// High/low predictions plus, for reference stations, the 6-minute series.
  /// Covers from 2 days ago to 8 days ahead (UTC dates) so "today" in any US
  /// time zone and the 7-day table are always inside.
  Future<TideData> fetch(Station s, DateTime nowUtc) async {
    final begin = nowUtc.subtract(const Duration(days: 2));
    final end = nowUtc.add(const Duration(days: 8));
    final hiloF = _get(predictionsUri(s.id, begin, end, 'hilo'));
    // The 6-minute series is a bonus: if it fails, the chart falls back to
    // interpolating NOAA's highs/lows. Errors are caught here so they never go unhandled.
    final Future<List<dynamic>?> curveF = s.isReference
        ? _get(predictionsUri(s.id, begin, end, '6')).then<List<dynamic>?>((v) => v, onError: (Object _) => null)
        : Future.value(null);
    final hilo = await hiloF;
    final events = <TideEvent>[
      for (final p in hilo)
        TideEvent(_parseTime(p['t'] as String), double.parse(p['v'] as String),
            isHigh: p['type'] == 'H')
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (events.isEmpty) throw NoaaException('NOAA has no predictions for this station.');
    TideCurve? curve;
    final pts = await curveF;
    if (pts != null && pts.length > 2) {
      final first = _parseTime(pts.first['t'] as String);
      final last = _parseTime(pts.last['t'] as String);
      // Only trust an unbroken 6-minute series; otherwise interpolate.
      if (last.difference(first).inMinutes == 6 * (pts.length - 1)) {
        curve = TideCurve(first, 6, [for (final p in pts) double.parse(p['v'] as String)]);
      }
    }
    return TideData(stationId: s.id, fetchedAt: nowUtc, events: events, curve: curve);
  }
}
