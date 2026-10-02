import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loan.dart';

/// 화면에서 고치는 값 하나하나. 대출 종류마다 따로 저장된다.
class Scenario {
  Scenario({
    required this.kind,
    required this.price,
    required this.down,
    required this.downIsPercent,
    required this.rate,
    required this.termMonths,
    required this.startYear,
    required this.startMonth,
    this.tax = 0,
    this.taxIsPercent = true,
    this.insurance = 0,
    this.hoa = 0,
    this.pmiRate = 0,
    this.extra = 0,
    this.tradeIn = 0,
    this.salesTax = 0,
  });

  final LoanKind kind;
  double price;

  /// [downIsPercent] 면 %, 아니면 달러. 마지막으로 고친 쪽이 기준 — 집값을 바꿔도 그쪽이 유지된다.
  double down;
  bool downIsPercent;
  double rate;
  int termMonths;
  int startYear, startMonth;

  /// 재산세: [taxIsPercent] 면 집값의 연 %, 아니면 연 달러.
  double tax;
  bool taxIsPercent;

  /// 주택 보험 연 달러.
  double insurance;

  /// HOA 월 달러.
  double hoa;

  /// PMI 연 %.
  double pmiRate;
  double extra;

  /// 자동차: 보상 판매 차값(달러), 판매세 %. 판매세는 (차값 − 보상 판매)에 붙는다 — 대부분 주의 방식.
  double tradeIn;
  double salesTax;

  bool get hasDown => kind != LoanKind.personal;
  bool get hasFees => kind == LoanKind.mortgage;
  bool get isAuto => kind == LoanKind.auto;

  double get salesTaxDollars =>
      isAuto ? (price - tradeIn).clamp(0, double.infinity) * salesTax / 100 : 0;

  /// 실제로 빌리는 돈.
  double get loanAmount => isAuto
      ? (price + salesTaxDollars - tradeIn - downDollars).clamp(
          0,
          double.infinity,
        )
      : (price - downDollars).clamp(0, double.infinity);

  double get downDollars => !hasDown
      ? 0
      : downIsPercent
      ? price * down / 100
      : down;
  double get downPercent => !hasDown || price <= 0
      ? 0
      : downIsPercent
      ? down
      : down / price * 100;

  double get taxYearly => !hasFees
      ? 0
      : taxIsPercent
      ? price * tax / 100
      : tax;
  double get taxPercent => !hasFees || price <= 0
      ? 0
      : taxIsPercent
      ? tax
      : tax / price * 100;

  /// PMI 가 실제로 붙는가 (계약금 20% 미만 + PMI 율 입력).
  bool get pmiApplies =>
      hasFees && pmiRate > 0 && price > 0 && downPercent < pmiNeededBelow * 100;

  LoanInput toInput() => LoanInput(
    // 자동차는 판매세·보상 판매를 반영한 금액에서 계약금을 뺀다 (PMI 가 없어 price 는 계산에만 쓰인다)
    price: isAuto ? price + salesTaxDollars - tradeIn : price,
    down: downDollars,
    rate: rate,
    termMonths: termMonths,
    startYear: startYear,
    startMonth: startMonth,
    taxYearly: taxYearly,
    insuranceYearly: hasFees ? insurance : 0,
    hoaMonthly: hasFees ? hoa : 0,
    pmiRate: hasFees ? pmiRate : 0,
    extraMonthly: extra,
  );

  Map<String, Object> toJson() => {
    'price': price,
    'down': down,
    'downIsPercent': downIsPercent,
    'rate': rate,
    'termMonths': termMonths,
    'startYear': startYear,
    'startMonth': startMonth,
    'tax': tax,
    'taxIsPercent': taxIsPercent,
    'insurance': insurance,
    'hoa': hoa,
    'pmiRate': pmiRate,
    'extra': extra,
    'tradeIn': tradeIn,
    'salesTax': salesTax,
  };

  /// 저장된 값이 깨졌으면 기본값으로 돌아간다.
  static Scenario fromJson(LoanKind kind, Map<String, dynamic> j, Scenario d) {
    double n(String k, double fb) {
      final v = j[k];
      return v is num && v.isFinite && v >= 0 ? v.toDouble() : fb;
    }

    int i(String k, int fb) {
      final v = j[k];
      return v is int && v > 0 ? v : fb;
    }

    bool b(String k, bool fb) {
      final v = j[k];
      return v is bool ? v : fb;
    }

    return Scenario(
      kind: kind,
      price: n('price', d.price),
      down: n('down', d.down),
      downIsPercent: b('downIsPercent', d.downIsPercent),
      rate: n('rate', d.rate),
      termMonths: i('termMonths', d.termMonths).clamp(1, 600),
      startYear: i('startYear', d.startYear),
      startMonth: i('startMonth', d.startMonth).clamp(1, 12),
      tax: n('tax', d.tax),
      taxIsPercent: b('taxIsPercent', d.taxIsPercent),
      insurance: n('insurance', d.insurance),
      hoa: n('hoa', d.hoa),
      pmiRate: n('pmiRate', d.pmiRate),
      extra: n('extra', d.extra),
      tradeIn: n('tradeIn', d.tradeIn),
      salesTax: n('salesTax', d.salesTax),
    );
  }

  /// 처음 열었을 때 값. 금리는 "오늘의 금리"가 아니라 고쳐 쓰라는 예시값이다.
  static Scenario defaults(LoanKind kind, DateTime now) {
    final next = DateTime(now.year, now.month + 1);
    return switch (kind) {
      LoanKind.mortgage => Scenario(
        kind: kind,
        price: 400000,
        down: 20,
        downIsPercent: true,
        rate: 7.0,
        termMonths: 360,
        startYear: next.year,
        startMonth: next.month,
        // 미국 평균 재산세 0.90% (ATTOM 2025), 주택 보험 연 약 \$2,400 (Bankrate·NerdWallet)
        tax: 0.9,
        taxIsPercent: true,
        insurance: 2400,
        hoa: 0,
        // PMI 는 신용점수에 따라 연 0.46~1.5% (Urban Institute)
        pmiRate: 0.6,
      ),
      LoanKind.auto => Scenario(
        kind: kind,
        // 신차 평균 대출 기간 69.5개월 (Experian 2026 Q2)
        price: 40000,
        down: 5000,
        downIsPercent: false,
        rate: 7.0,
        termMonths: 72,
        startYear: next.year,
        startMonth: next.month,
        tradeIn: 0,
        salesTax: 0,
      ),
      LoanKind.personal => Scenario(
        kind: kind,
        price: 10000,
        down: 0,
        downIsPercent: false,
        rate: 12.0,
        termMonths: 36,
        startYear: next.year,
        startMonth: next.month,
      ),
    };
  }
}

/// 기기에 남는 값. 서버 없음 — 오프라인에서도 그대로 동작한다.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore i = AppStore._();

  late SharedPreferences _p;

  /// 테스트에서 날짜를 고정할 수 있게 시계를 바꿔 끼운다.
  DateTime Function() clock = DateTime.now;

  final Map<LoanKind, Scenario> _cache = {};

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _cache.clear();
  }

  LoanKind get kind {
    final k = _p.getString('kind');
    return LoanKind.values.firstWhere(
      (e) => e.name == k,
      orElse: () => LoanKind.mortgage,
    );
  }

  Future<void> setKind(LoanKind k) async {
    await _p.setString('kind', k.name);
    notifyListeners();
  }

  Scenario scenario(LoanKind k) => _cache.putIfAbsent(k, () {
    final d = Scenario.defaults(k, clock());
    final raw = _p.getString('scenario_${k.name}');
    if (raw == null) return d;
    try {
      return Scenario.fromJson(k, jsonDecode(raw) as Map<String, dynamic>, d);
    } catch (_) {
      return d;
    }
  });

  Future<void> save(Scenario s) async {
    await _p.setString('scenario_${s.kind.name}', jsonEncode(s.toJson()));
    notifyListeners();
  }

  /// 이 종류를 처음 값으로 되돌린다.
  Future<Scenario> reset(LoanKind k) async {
    await _p.remove('scenario_${k.name}');
    _cache.remove(k);
    final s = scenario(k);
    notifyListeners();
    return s;
  }
}
