import 'dart:math' as math;

import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##0', 'en_US');
final _grouped2 = NumberFormat('#,##0.00', 'en_US');

/// 스마트 정밀도 — 경쟁사의 "120 USD → 0.00 BTC" 문제를 피한다.
/// 1 이상은 소수 2자리, 1만 이상은 정수, 1 미만은 유효숫자 4자리 기준.
String fmtAmount(double v) {
  if (!v.isFinite) return '—';
  final a = v.abs();
  if (a == 0) return '0';
  if (a >= 10000) return _grouped.format(v);
  if (a >= 1) return _grouped2.format(v);
  final digits = _smallDigits(a);
  return NumberFormat('0.${'#' * digits}', 'en_US').format(v);
}

int _smallDigits(double a) =>
    math.min(10, 3 - (math.log(a) / math.ln10).floor());

/// 입력 버퍼를 그대로 보여준다 — 정수부만 천 단위로 묶고, 소수부는 치는 대로.
String fmtBuf(String buf) {
  if (buf.isEmpty) return '0';
  final dot = buf.indexOf('.');
  final intPart = dot < 0 ? buf : buf.substring(0, dot);
  final grouped = intPart.isEmpty ? '0' : _grouped.format(int.parse(intPart));
  if (dot < 0) return grouped;
  return '$grouped.${buf.substring(dot + 1)}';
}

/// 화면에 보이던 금액을 이어서 입력할 수 있게 버퍼 문자열로 되돌린다.
String rawStr(double v) {
  if (!v.isFinite || v == 0) return '';
  final a = v.abs();
  var s = a >= 10000
      ? v.toStringAsFixed(0)
      : a >= 1
          ? v.toStringAsFixed(2)
          : v.toStringAsFixed(_smallDigits(a));
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 버퍼 → 숫자. "1704." 처럼 점으로 끝나도 안전하게.
double bufValue(String buf) {
  final s = buf.endsWith('.') ? buf.substring(0, buf.length - 1) : buf;
  return double.tryParse(s) ?? 0;
}

/// "▲0.32%" / "▼0.25%" / "·0.00%"
String chgText(double d) {
  final arrow = d > 0.005 ? '▲' : d < -0.005 ? '▼' : '·';
  return '$arrow${d.abs().toStringAsFixed(2)}%';
}
