// 계산 엔진 검증 — 널리 알려진 납입액(은행·계산기 사이트 값)과 따로 짠 파이썬 계산 결과에 맞춘다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mortgage/core/loan.dart';

LoanInput loan(
  double amount,
  double rate,
  int months, {
  double extra = 0,
  double price = 0,
  double pmi = 0,
  double tax = 0,
  double ins = 0,
  double hoa = 0,
}) {
  final p = price > 0 ? price : amount;
  return LoanInput(
    price: p,
    down: p - amount,
    rate: rate,
    termMonths: months,
    startYear: 2026,
    startMonth: 11,
    extraMonthly: extra,
    pmiRate: pmi,
    taxYearly: tax,
    insuranceYearly: ins,
    hoaMonthly: hoa,
  );
}

void main() {
  test('standard monthly payments match published values', () {
    expect(calculate(loan(320000, 6.5, 360)).monthlyPI, 2022.62);
    expect(calculate(loan(200000, 6, 360)).monthlyPI, 1199.10);
    expect(calculate(loan(250000, 4, 180)).monthlyPI, 1849.22);
    expect(calculate(loan(30000, 7, 60)).monthlyPI, 594.04);
    expect(calculate(loan(10000, 12, 36)).monthlyPI, 332.14);
  });

  test('schedule pays the loan to exactly zero in the term', () {
    for (final (a, r, n, interest) in [
      (320000.0, 6.5, 360, 408140.64),
      (200000.0, 6.0, 360, 231677.04),
      (250000.0, 4.0, 180, 82859.53),
      (30000.0, 7.0, 60, 5642.12),
      (10000.0, 12.0, 36, 1957.18),
    ]) {
      final res = calculate(loan(a, r, n));
      expect(res.months, n, reason: '$a @ $r%');
      expect(res.schedule.last.balance, 0);
      expect(res.totalInterest, closeTo(interest, 0.01), reason: '$a @ $r%');
      final principal = res.schedule.fold<double>(
        0,
        (s, p) => s + p.totalPrincipal,
      );
      expect(principal, closeTo(a, 0.01));
    }
  });

  test('zero interest splits the loan evenly', () {
    final res = calculate(loan(12000, 0, 24));
    expect(res.monthlyPI, 500);
    expect(res.totalInterest, 0);
    expect(res.months, 24);
  });

  test('extra monthly payment shortens the loan and saves interest', () {
    final e = extraEffect(loan(320000, 6.5, 360, extra: 200));
    expect(e.withExtra.months, 281);
    expect(e.monthsSaved, 79);
    expect(e.withExtra.totalInterest, closeTo(302712.79, 0.01));
    expect(e.interestSaved, closeTo(408140.64 - 302712.79, 0.01));
    expect(e.withExtra.schedule.last.balance, 0);
  });

  test('extra bigger than the balance pays off in one month', () {
    final res = calculate(loan(1000, 5, 12, extra: 5000));
    expect(res.months, 1);
    expect(res.schedule.single.balance, 0);
  });

  test('PMI only below 20% down and stops at 78% loan-to-value', () {
    // 집값 40만, 계약금 10% → 대출 36만, PMI 연 0.5%
    final res = calculate(loan(360000, 6.5, 360, price: 400000, pmi: 0.5));
    expect(res.monthlyPmi, 150);
    final last = res.schedule.lastWhere((p) => p.pmi > 0);
    final next = res.schedule[last.n]; // last.n 은 1부터라 다음 회차 인덱스
    expect(next.pmi, 0);
    expect(next.balance, lessThanOrEqualTo(400000 * pmiDropLtv));
    expect(res.schedule[last.n - 2].balance, greaterThan(400000 * pmiDropLtv));
    expect(res.totalPmi, closeTo(150.0 * res.pmiMonths, 0.001));

    // 계약금 20% 면 PMI 없음
    final noPmi = calculate(loan(320000, 6.5, 360, price: 400000, pmi: 0.5));
    expect(noPmi.monthlyPmi, 0);
    expect(noPmi.totalPmi, 0);
  });

  test('extra payments also end PMI sooner', () {
    final e = extraEffect(
      loan(360000, 6.5, 360, price: 400000, pmi: 0.5, extra: 300),
    );
    expect(e.withExtra.pmiMonths, lessThan(e.base.pmiMonths));
    expect(e.pmiSaved, greaterThan(0));
  });

  test('monthly total adds taxes, insurance, HOA and PMI', () {
    final res = calculate(
      loan(
        360000,
        6.5,
        360,
        price: 400000,
        pmi: 0.5,
        tax: 4800,
        ins: 1800,
        hoa: 50,
      ),
    );
    expect(res.monthlyTax, 400);
    expect(res.monthlyInsurance, 150);
    expect(
      res.monthlyTotal,
      closeTo(res.monthlyPI + 400 + 150 + 50 + 150, 1e-9),
    );
  });

  test('dates roll over the year and the yearly table sums months', () {
    final res = calculate(loan(30000, 7, 60));
    expect(res.schedule.first.year, 2026);
    expect(res.schedule.first.month, 11);
    expect(res.schedule[2].year, 2027);
    expect(res.schedule[2].month, 1);
    expect(res.payoff, (2031, 10));
    final years = res.yearly;
    expect(years.first.payments, 2);
    expect(years.map((y) => y.payments).reduce((a, b) => a + b), 60);
    expect(
      years.fold<double>(0, (s, y) => s + y.interest),
      closeTo(res.totalInterest, 0.01),
    );
    expect(years.last.balance, 0);
  });

  test('empty or nonsense inputs do not crash', () {
    expect(calculate(loan(0, 6, 360)).isEmpty, isTrue);
    expect(calculate(loan(0, 6, 360)).monthlyTotal, 0);
    final big = calculate(loan(99999999, 99, 480));
    expect(big.schedule.last.balance, 0);
    expect(big.monthlyPI.isFinite, isTrue);
    // 계약금이 집값보다 크면 대출 0
    final over = calculate(
      const LoanInput(
        price: 100,
        down: 500,
        rate: 5,
        termMonths: 12,
        startYear: 2026,
        startMonth: 1,
      ),
    );
    expect(over.loanAmount, 0);
    expect(over.isEmpty, isTrue);
  });
}
