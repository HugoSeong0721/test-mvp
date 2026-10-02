import 'package:flutter/foundation.dart';
import 'package:catdoku/core/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every level size makes a unique-solution puzzle', () {
    final sw = Stopwatch()..start();
    for (final lv in [1, 2, 3, 4, 10, 11, 25, 26, 50, 51, 52, 80, 120]) {
      final p = Puzzle.level(lv);
      expect(p.n, Puzzle.sizeForLevel(lv));
      expect(Puzzle.countSolutions(p.n, p.region), 1, reason: 'level $lv');
      // 해답이 규칙을 모두 지키는지
      for (var r = 0; r < p.n; r++) {
        expect(p.solution.toSet().length, p.n);
        if (r > 0) {
          expect((p.solution[r] - p.solution[r - 1]).abs() >= 2, isTrue);
        }
      }
      expect(
        {for (var r = 0; r < p.n; r++) p.region[r][p.solution[r]]}.length,
        p.n,
      );
    }
    // ignore: avoid_print
    print('13 levels generated in ${sw.elapsedMilliseconds} ms');
  });

  test('daily puzzle is the same for the same day and differs by day', () {
    final a = Puzzle.daily('20261002');
    final b = Puzzle.daily('20261002');
    final c = Puzzle.daily('20261003');
    expect(a.solution, b.solution);
    expect(a.region, b.region);
    expect(
      listEquals(a.solution, c.solution) &&
          a.region.toString() == c.region.toString(),
      isFalse,
    );
  });

  test('a year of daily puzzles are unique and fast', () {
    final sw = Stopwatch()..start();
    var d = DateTime(2026, 10, 1);
    for (var i = 0; i < 365; i++) {
      final p = Puzzle.daily(dayKeyOf(d));
      expect(Puzzle.countSolutions(7, p.region), 1);
      d = d.add(const Duration(days: 1));
    }
    // ignore: avoid_print
    print('365 dailies in ${sw.elapsedMilliseconds} ms');
  });

  test('levels 51-150 (9x9) all generate', () {
    final sw = Stopwatch()..start();
    var worst = 0;
    for (var lv = 51; lv <= 150; lv++) {
      final t = sw.elapsedMilliseconds;
      final p = Puzzle.level(lv);
      expect(Puzzle.countSolutions(9, p.region), 1);
      final dt = sw.elapsedMilliseconds - t;
      if (dt > worst) worst = dt;
    }
    // ignore: avoid_print
    print('100 9x9 levels in ${sw.elapsedMilliseconds} ms, worst $worst ms');
  });
}
