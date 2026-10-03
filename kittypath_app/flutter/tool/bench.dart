// ignore_for_file: avoid_print
// 생성 속도·숫자 개수 측정: dart run tool/bench.dart
import 'package:path_puzzle/core/puzzle.dart';

void main() {
  for (final n in [5, 6, 7, 8]) {
    final sw = Stopwatch()..start();
    var worst = 0, clues = 0;
    const k = 20;
    for (var s = 0; s < k; s++) {
      final t = Stopwatch()..start();
      final p = PathPuzzle.generate(n, Rng.seedOf('bench-$n-$s'));
      final ms = t.elapsedMilliseconds;
      if (ms > worst) worst = ms;
      clues += p.clues.length;
      final r = PathPuzzle.solve(n, p.clues, p.path, 2, 5000000);
      if (r.count != 1 || r.exhausted) print('NOT UNIQUE n=$n s=$s count=${r.count} ex=${r.exhausted}');
    }
    print('n=$n avg ${sw.elapsedMilliseconds ~/ k}ms worst ${worst}ms clues avg ${(clues / k).toStringAsFixed(1)}');
  }
}
