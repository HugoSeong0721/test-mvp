import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
        RateStatus.live => '실시간',
        RateStatus.cache => '최근 저장',
        RateStatus.offline => '오프라인 기준값',
        RateStatus.loading => '',
      };

  /// 헤더 배지 글자: "08.22 · 실시간"
  String get stampText {
    if (status == RateStatus.loading) return '환율 불러오는 중…';
    final md = date.length >= 10 ? date.substring(5).replaceAll('-', '.') : date;
    return '$md · $statusLabel';
  }

  String get statusHelp => switch (status) {
        RateStatus.live => '방금 받아온 실시간 환율이에요',
        RateStatus.cache => '마지막으로 받아둔 환율 — 인터넷 연결 후 자동 갱신',
        _ => '오프라인 기준값 — 인터넷에 연결되면 자동으로 최신 환율로 바뀝니다',
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
