import 'dart:math' as math;

/// 대출 종류. 계산은 같고 입력 칸·기본값만 다르다.
enum LoanKind { mortgage, auto, personal }

/// 계산에 들어가는 값 (전부 달러, 금리는 연 %).
class LoanInput {
  const LoanInput({
    required this.price,
    this.down = 0,
    required this.rate,
    required this.termMonths,
    required this.startYear,
    required this.startMonth,
    this.taxYearly = 0,
    this.insuranceYearly = 0,
    this.hoaMonthly = 0,
    this.pmiRate = 0,
    this.extraMonthly = 0,
    this.extraFromYear = 0,
    this.extraFromMonth = 0,
    this.lumpSum = 0,
    this.lumpYear = 0,
    this.lumpMonth = 0,
    this.biweekly = false,
  });

  /// 집값·차값. 개인 대출이면 빌리는 돈 자체.
  final double price;

  /// 계약금(달러).
  final double down;

  /// 연 이자율 % (6.5 = 6.5%).
  final double rate;
  final int termMonths;

  /// 첫 납입 달.
  final int startYear, startMonth;

  final double taxYearly, insuranceYearly, hoaMonthly;

  /// PMI 연 % (대출 원금 기준). 계약금 20% 미만일 때만 붙는다.
  final double pmiRate;

  /// 매달 원금에 더 내는 돈.
  final double extraMonthly;

  /// 매달 추가 상환을 시작하는 달 (0 이면 첫 납입부터).
  final int extraFromYear, extraFromMonth;

  /// 한 번 크게 갚는 돈과 그 달 (0 이면 없음).
  final double lumpSum;
  final int lumpYear, lumpMonth;

  /// 격주 납부 — 2주마다 반씩 내면 1년에 26번 = 13달치. 대부분의 미국 대출사처럼
  /// 모아서 달마다 원금에 넣는다고 보고, 매달 원리금의 1/12 을 더 내는 것으로 계산한다.
  final bool biweekly;

  bool get hasExtras => extraMonthly > 0 || lumpSum > 0 || biweekly;

  double get loanAmount => math.max(0, price - down);

  /// 추가 상환을 모두 뺀 같은 대출 (비교 기준).
  LoanInput withoutExtras() => LoanInput(
    price: price,
    down: down,
    rate: rate,
    termMonths: termMonths,
    startYear: startYear,
    startMonth: startMonth,
    taxYearly: taxYearly,
    insuranceYearly: insuranceYearly,
    hoaMonthly: hoaMonthly,
    pmiRate: pmiRate,
  );
}

/// 상환표 한 줄 (한 달).
class Payment {
  const Payment({
    required this.n,
    required this.year,
    required this.month,
    required this.principal,
    required this.interest,
    required this.extra,
    required this.pmi,
    required this.balance,
  });

  /// 1부터 시작하는 회차.
  final int n;
  final int year, month;

  /// 이번 달 갚은 원금 (추가 상환 포함 안 함).
  final double principal;
  final double interest;

  /// 이번 달 추가로 갚은 원금.
  final double extra;
  final double pmi;

  /// 이번 달 납입 후 남은 원금.
  final double balance;

  double get totalPrincipal => principal + extra;
}

/// 1년 묶음 (상환표 연 단위 보기).
class YearRow {
  YearRow(this.year);
  final int year;
  double principal = 0, interest = 0, extra = 0, pmi = 0, balance = 0;
  int payments = 0;
  double get totalPrincipal => principal + extra;
}

class LoanResult {
  LoanResult._({
    required this.input,
    required this.loanAmount,
    required this.monthlyPI,
    required this.schedule,
    required this.totalInterest,
    required this.totalPmi,
  });

  final LoanInput input;
  final double loanAmount;

  /// 약정 월 원리금 (센트 반올림, 추가 상환 제외).
  final double monthlyPI;
  final List<Payment> schedule;
  final double totalInterest;
  final double totalPmi;

  double get monthlyTax => input.taxYearly / 12;
  double get monthlyInsurance => input.insuranceYearly / 12;
  double get monthlyHoa => input.hoaMonthly;

  /// 첫 달 PMI (없으면 0).
  double get monthlyPmi => schedule.isEmpty ? 0 : schedule.first.pmi;

  /// 화면 맨 위 "월 납입액" — 원리금 + 세금 + 보험 + HOA + PMI (추가 상환 제외).
  double get monthlyTotal =>
      monthlyPI + monthlyTax + monthlyInsurance + monthlyHoa + monthlyPmi;

  int get months => schedule.length;
  bool get isEmpty => schedule.isEmpty;

  /// 원금 + 이자 (추가 상환 포함 총 갚는 돈, 세금·보험 제외).
  double get totalOfPayments => loanAmount + totalInterest;

  /// 마지막 납입 달 (빈 대출이면 null).
  (int, int)? get payoff =>
      schedule.isEmpty ? null : (schedule.last.year, schedule.last.month);

  /// PMI 가 마지막으로 붙는 회차 (없으면 0).
  int get pmiMonths => schedule.where((p) => p.pmi > 0).length;

  List<YearRow> get yearly {
    final rows = <YearRow>[];
    for (final p in schedule) {
      if (rows.isEmpty || rows.last.year != p.year) rows.add(YearRow(p.year));
      final r = rows.last
        ..principal += p.principal
        ..interest += p.interest
        ..extra += p.extra
        ..pmi += p.pmi
        ..balance = p.balance;
      r.payments++;
    }
    return rows;
  }
}

double _cents(double v) => (v * 100).roundToDouble() / 100;

/// 표준 원리금 균등 상환 월 납입액. 금리 0 이면 원금 ÷ 개월.
double monthlyPayment(double principal, double ratePct, int months) {
  if (principal <= 0 || months <= 0) return 0;
  final i = ratePct / 1200;
  if (i <= 0) return principal / months;
  return principal * i / (1 - math.pow(1 + i, -months));
}

/// PMI 가 끝나는 기준 — 원금이 집값의 78% 이하로 내려가면 자동 해지 (미국 Homeowners Protection Act).
/// 그 전이라도 대출 기간의 절반이 지나면 끝난다 (같은 법의 midpoint 규정).
const pmiDropLtv = 0.78;

/// 계약금이 이 비율 미만이면 PMI 가 붙는다.
const pmiNeededBelow = 0.20;

LoanResult calculate(LoanInput input) {
  final p0 = input.loanAmount;
  final n = input.termMonths.clamp(1, 1200);
  final i = input.rate.clamp(0, 100) / 1200;
  final pi = _cents(monthlyPayment(p0, input.rate.clamp(0, 100), n));
  final extra = math.max(0.0, input.extraMonthly);
  final biweeklyExtra = input.biweekly ? _cents(pi / 12) : 0.0;
  final extraFrom = input.extraFromYear > 0
      ? input.extraFromYear * 12 + input.extraFromMonth - 1
      : 0;
  final lumpAt = input.lumpSum > 0 && input.lumpYear > 0
      ? input.lumpYear * 12 + input.lumpMonth - 1
      : -1;
  final pmiApplies =
      input.pmiRate > 0 &&
      input.price > 0 &&
      p0 > 0 &&
      input.down / input.price < pmiNeededBelow;
  final pmiMonthly = pmiApplies ? _cents(p0 * input.pmiRate / 100 / 12) : 0.0;
  final pmiStop = input.price * pmiDropLtv;

  final out = <Payment>[];
  var bal = p0;
  var totalInterest = 0.0, totalPmi = 0.0;
  var y = input.startYear, m = input.startMonth.clamp(1, 12);
  for (var k = 1; bal > 0.004 && k <= n; k++) {
    final interest = _cents(bal * i);
    final pmi = pmiApplies && bal > pmiStop && k <= n / 2 ? pmiMonthly : 0.0;
    double principal;
    if (k == n || pi - interest >= bal) {
      // 마지막 회차는 남은 원금을 전부 갚는다 (센트 반올림 오차 정리)
      principal = bal;
    } else {
      principal = _cents(pi - interest);
    }
    final now = y * 12 + m - 1;
    var want = biweeklyExtra;
    if (now >= extraFrom) want += extra;
    if (now == lumpAt) want += input.lumpSum;
    final ex = _cents(math.min(want, bal - principal));
    bal = _cents(bal - principal - ex);
    totalInterest += interest;
    totalPmi += pmi;
    out.add(
      Payment(
        n: k,
        year: y,
        month: m,
        principal: principal,
        interest: interest,
        extra: ex,
        pmi: pmi,
        balance: bal,
      ),
    );
    if (++m > 12) {
      m = 1;
      y++;
    }
  }
  return LoanResult._(
    input: input,
    loanAmount: p0,
    monthlyPI: pi,
    schedule: out,
    totalInterest: _cents(totalInterest),
    totalPmi: _cents(totalPmi),
  );
}

/// 추가 상환 효과 — 같은 대출을 추가 상환 없이 갚을 때와 비교.
class ExtraEffect {
  ExtraEffect(this.base, this.withExtra);
  final LoanResult base, withExtra;
  int get monthsSaved => base.months - withExtra.months;
  double get interestSaved =>
      _cents(base.totalInterest - withExtra.totalInterest);
  double get pmiSaved => _cents(base.totalPmi - withExtra.totalPmi);
}

ExtraEffect extraEffect(LoanInput input) =>
    ExtraEffect(calculate(input.withoutExtras()), calculate(input));
