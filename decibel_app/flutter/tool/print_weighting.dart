// A·C 가중 필터 응답을 IEC 61672 표준값과 나란히 찍는다: dart run tool/print_weighting.dart
// ignore_for_file: avoid_print
import 'package:decibel/core/meter.dart';

void main() {
  final iec = <num, double>{31.5: -39.4, 63: -26.2, 125: -16.1, 250: -8.6, 500: -3.2, 1000: 0.0, 2000: 1.2, 4000: 1.0, 8000: -1.1};
  final f = WeightingFilter(Weighting.a, 48000);
  print('Hz      IEC A   ours(48k)  diff');
  iec.forEach((hz, want) {
    final got = f.responseDb(hz.toDouble());
    print('${hz.toString().padRight(7)} ${want.toStringAsFixed(1).padLeft(6)}  ${got.toStringAsFixed(2).padLeft(8)}  ${(got - want).toStringAsFixed(2).padLeft(6)}');
  });
}
