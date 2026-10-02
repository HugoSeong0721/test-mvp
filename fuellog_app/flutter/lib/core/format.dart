/// 화면에 보이는 숫자·날짜 글자. 미국식 (1,234.56 · Sep 28, 2026).
library;

import 'units.dart';

String group(String digits) {
  final neg = digits.startsWith('-');
  final s = neg ? digits.substring(1) : digits;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

/// 소수 [decimals] 자리, 정수부는 쉼표.
String grouped(double v, [int decimals = 0]) {
  final s = v.toStringAsFixed(decimals);
  final dot = s.indexOf('.');
  final out = dot < 0 ? group(s) : group(s.substring(0, dot)) + s.substring(dot);
  return out == '-0' || RegExp(r'^-0\.0*$').hasMatch(out) ? out.substring(1) : out;
}

/// 끝의 0 을 뗀다: 12.500 → 12.5, 12.000 → 12
String trimNum(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s == '-0' ? '0' : s;
}

String money(double v) => v < 0 ? '-\$${grouped(-v, 2)}' : '\$${grouped(v, 2)}';

/// 큰 금액은 센트 없이 ($1,234)
String moneyShort(double v) => v.abs() >= 1000 ? '\$${grouped(v, 0)}' : money(v);

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _month = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monShort(int m) => _mon[m - 1];
String fmtDate(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';
String fmtDayMonth(DateTime d) => '${_mon[d.month - 1]} ${d.day}';
String fmtMonthYear(int y, int m) => '${_month[m - 1]} $y';

/// 단위를 붙인 글자.
class Fmt {
  const Fmt(this.u);
  final Units u;

  String get dShort => u.distance.short;
  String get vShort => u.volume.short;
  String get eShort => u.economy.short;

  String distNum(double miles, [int decimals = 0]) => grouped(u.distance.fromMiles(miles), decimals);
  String dist(double miles, [int decimals = 0]) => '${distNum(miles, decimals)} $dShort';

  String volNum(double gal) {
    final t = trimNum(u.volume.fromGallons(gal), 3);
    final dot = t.indexOf('.');
    return dot < 0 ? group(t) : group(t.substring(0, dot)) + t.substring(dot);
  }

  String vol(double gal) => '${volNum(gal)} $vShort';

  /// 단가 ($/gal 또는 $/L) — 주유소처럼 소수 셋째 자리
  double pricePerUnit(double perGallon) => u.volume == VolumeUnit.gal ? perGallon : perGallon / litersPerGallon;
  String price(double perGallon) => '\$${pricePerUnit(perGallon).toStringAsFixed(3)}/$vShort';

  double economy(double mpg) => u.economy.fromMpg(mpg);
  String econNum(double mpg) => economy(mpg).toStringAsFixed(1);
  String econ(double mpg) => '${econNum(mpg)} $eShort';

  /// 거리당 비용 ($/mi, $/km)
  String perDist(double perMile) {
    final v = u.distance == DistanceUnit.mi ? perMile : perMile / kmPerMile;
    return '\$${v.toStringAsFixed(v < 1 ? 3 : 2)}/$dShort';
  }
}
