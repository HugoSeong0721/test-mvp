/// 미국식 표기 — $1,234.56, Oct 2056.
library;

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const monthsLong = [
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

String group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// $1,234 (센트 없이, 반올림).
String money(double v) {
  final neg = v < 0;
  final s = group(v.abs().round().toString());
  return '${neg ? '-' : ''}\$$s';
}

/// $1,234.56
String money2(double v) {
  final neg = v < 0;
  final cents = (v.abs() * 100).round();
  final s =
      '${group((cents ~/ 100).toString())}.${(cents % 100).toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}\$$s';
}

/// $408k / $1.2M — 좁은 차트 눈금용.
String moneyShort(double v) {
  final a = v.abs();
  if (a >= 1e6) {
    final m = a / 1e6;
    return '\$${m >= 10 ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
  }
  if (a >= 1e3) return '\$${(a / 1e3).round()}k';
  return '\$${a.round()}';
}

/// 소수 끝의 0 을 뗀다: 6.50 → 6.5, 20.0 → 20.
String trimNum(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

String monthYear(int year, int month) => '${months[month - 1]} $year';

/// 79개월 → "6 yr 7 mo"
String duration(int m) {
  final y = m ~/ 12, r = m % 12;
  if (y == 0) return '$r mo';
  if (r == 0) return '$y yr';
  return '$y yr $r mo';
}

/// 360개월 → "30 years", 60 → "60 months (5 years)"
String termLabel(int m) {
  if (m % 12 == 0) {
    final y = m ~/ 12;
    return y == 1 ? '1 year' : '$y years';
  }
  return '$m months';
}
