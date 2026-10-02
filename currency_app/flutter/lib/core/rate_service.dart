import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currencies.dart';

enum RateStatus { loading, live, cache, offline }

/// 실시간 환율.
///
/// 기본값은 내장 스냅샷이고, 앱이 열릴 때 무료 환율 API에서 최신 환율을 받아
/// 덮어쓴다. 어제 값도 같이 받아 전일 대비 ▲▼ 를 실제로 계산한다.
/// 못 받아오면 마지막으로 받은 값(캐시) → 내장 스냅샷 순으로 물러난다.
class RateService extends ChangeNotifier {
  RateService._() {
    for (final c in currencies) {
      rate[c.code] = c.snapshotRate;
      change[c.code] = c.snapshotChange;
    }
  }

  static final RateService i = RateService._();

  static const _cacheKey = 'fx-rates-v1';
  static const _timeout = Duration(seconds: 7);

  /// 1 USD당 통화 수량
  final Map<String, double> rate = {};

  /// 전일 대비 USD→통화 변동(%)
  final Map<String, double> change = {};

  RateStatus status = RateStatus.loading;
  String date = snapshotDate;

  static String _url(int source, String day) => source == 0
      ? 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$day/v1/currencies/usd.min.json'
      : 'https://$day.currency-api.pages.dev/v1/currencies/usd.min.json';

  double convert(double v, String from, String to) =>
      v / (rate[from] ?? 1) * (rate[to] ?? 1);

  /// from→to 환율의 전일 대비 변동(%)
  double pairChange(String from, String to) =>
      (change[to] ?? 0) - (change[from] ?? 0);

  String get statusLabel => switch (status) {
        RateStatus.live => 'Live',
        RateStatus.cache => 'Saved',
        RateStatus.offline => 'Offline',
        RateStatus.loading => '',
      };

  /// 헤더 배지 글자: "Oct 2 · Live"
  String get stampText {
    if (status == RateStatus.loading) return 'Loading rates…';
    final d = DateTime.tryParse(date);
    final md = d == null ? date : DateFormat('MMM d', 'en_US').format(d);
    return '$md · $statusLabel';
  }

  String get statusHelp => switch (status) {
        RateStatus.live => 'Live rates, just updated',
        RateStatus.cache => 'Last saved rates — refreshes when you are back online',
        _ => 'Built-in offline rates — refreshes once you are online',
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) 지난번에 받아둔 값이 있으면 먼저 그려서 빈 화면을 안 보여준다
    final cached = _readCache(prefs);
    if (cached != null) {
      _apply(cached.rates, cached.prev);
      status = RateStatus.cache;
      date = cached.date;
      notifyListeners();
    }

    // 2) 최신 환율 + 어제 환율
    try {
      final today = await _fetchDay('latest');
      Map<String, double>? prev;
      try {
        prev = (await _fetchDay(_prevDay(today.date))).rates;
      } catch (_) {}
      _apply(today.rates, prev);
      status = RateStatus.live;
      date = today.date;
      notifyListeners();
      await prefs.setString(
        _cacheKey,
        jsonEncode({'date': today.date, 'rates': today.rates, 'prev': prev}),
      );
    } catch (_) {
      if (status != RateStatus.cache) {
        status = RateStatus.offline;
        date = snapshotDate;
        notifyListeners();
      }
    }
  }

  // ---- 과거 환율 (차트) ----
  // 날짜별 파일은 바뀌지 않으므로 받은 날은 기기에 저장해 두고 다시 받지 않는다.
  static const _histKey = 'fx-hist-v1';
  final Map<String, Map<String, double>> _hist = {};
  bool _histLoaded = false;

  /// 기간별 (날짜 수, 간격일). 일 단위 데이터만 있어 1일 차트는 없다.
  static const historyPlan = {
    '1W': (8, 1),
    '1M': (31, 1),
    '3M': (31, 3),
    '1Y': (27, 14),
  };

  /// from→to 의 실제 과거 환율 [(날짜, 값)]. 못 받은 날은 건너뛴다.
  Future<List<(DateTime, double)>> history(
      String from, String to, String period) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_histLoaded) {
      _histLoaded = true;
      try {
        final raw = prefs.getString(_histKey);
        if (raw != null) {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          for (final e in j.entries) {
            if (e.value is Map) _hist[e.key] = _toDoubles(e.value as Map);
          }
        }
      } catch (_) {}
    }

    final (n, step) = historyPlan[period]!;
    final end = DateTime.tryParse(date) ?? DateTime.now().toUtc();
    final days = [
      for (var i = n - 1; i >= 0; i--)
        DateTime.utc(end.year, end.month, end.day - i * step)
            .toIso8601String()
            .substring(0, 10),
    ];

    final missing = days.where((d) => !_hist.containsKey(d)).toList();
    var added = false;
    for (var i = 0; i < missing.length; i += 8) {
      final batch = missing.skip(i).take(8);
      final got = await Future.wait(batch.map((d) async {
        try {
          return (d, (await _fetchDay(d)).rates);
        } catch (_) {
          return (d, null);
        }
      }));
      for (final (d, rates) in got) {
        if (rates == null) continue;
        _hist[d] = {
          for (final c in currencies)
            if (rates[c.code.toLowerCase()] != null)
              c.code: rates[c.code.toLowerCase()]!,
        };
        added = true;
      }
    }
    if (added) {
      final keep = (_hist.keys.toList()..sort()).reversed.take(400).toSet();
      _hist.removeWhere((k, _) => !keep.contains(k));
      try {
        await prefs.setString(_histKey, jsonEncode(_hist));
      } catch (_) {}
    }

    final out = <(DateTime, double)>[];
    for (final d in days) {
      final r = _hist[d];
      final f = r?[from], t = r?[to];
      if (f == null || t == null || f <= 0) continue;
      out.add((DateTime.parse(d), t / f));
    }
    return out;
  }

  /// API에 없는 통화는 스냅샷 값을 그대로 둔다 — 부분 실패에도 화면이 깨지지 않게.
  void _apply(Map<String, double> rates, Map<String, double>? prev) {
    for (final c in currencies) {
      final key = c.code.toLowerCase();
      final v = rates[key];
      if (v == null || v <= 0) continue;
      rate[c.code] = v;
      final p = prev?[key];
      change[c.code] = (p != null && p > 0) ? (v / p - 1) * 100 : 0;
    }
  }

  Future<_Day> _fetchDay(String day) async {
    for (var s = 0; s < 2; s++) {
      try {
        final res =
            await http.get(Uri.parse(_url(s, day))).timeout(_timeout);
        if (res.statusCode != 200) continue;
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final usd = json['usd'];
        if (usd is Map) {
          return _Day((json['date'] as String?) ?? day, _toDoubles(usd));
        }
      } catch (_) {
        // 다음 소스로
      }
    }
    throw Exception('rate source unavailable');
  }

  static Map<String, double> _toDoubles(Map m) => {
        for (final e in m.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
      };

  static String _prevDay(String iso) {
    final d = DateTime.parse('${iso}T00:00:00Z').subtract(const Duration(days: 1));
    return d.toIso8601String().substring(0, 10);
  }

  _Day? _readCache(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final rates = j['rates'];
      if (rates is! Map) return null;
      final prev = j['prev'];
      return _Day(
        (j['date'] as String?) ?? snapshotDate,
        _toDoubles(rates),
        prev is Map ? _toDoubles(prev) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class _Day {
  const _Day(this.date, this.rates, [this.prev]);
  final String date;
  final Map<String, double> rates;
  final Map<String, double>? prev;
}
