// 퍼즐 엔진 검사 — 모든 판이 규칙에 맞고, 해가 딱 하나이고, 같은 날엔 어디서나 같은 판인지.
// 웹(JS)에서도 같은 판인지: flutter test --platform chrome test/puzzle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:path_puzzle/core/puzzle.dart';

/// 한 칸씩 위·아래·좌·우로만 움직이며 모든 칸을 한 번씩 지나는가.
void expectValidPath(int n, List<int> path) {
  expect(path.length, n * n);
  expect(path.toSet().length, n * n, reason: 'every square exactly once');
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1], b = path[i];
    final d = (a ~/ n - b ~/ n).abs() + (a % n - b % n).abs();
    expect(d, 1, reason: 'step $i is not to a neighbour');
  }
}

/// 판 지문 — 숫자 칸 위치를 이어 붙인 것.
String fingerprint(PathPuzzle p) => '${p.n}:${p.clues.join(',')}';

void main() {
  test('random paths cover every square with neighbour steps (3x3 … 8x8)', () {
    for (var n = 3; n <= 8; n++) {
      for (var s = 0; s < 10; s++) {
        expectValidPath(n, PathPuzzle.randomPath(n, Rng(1000 * n + s)));
      }
    }
  });

  test('generated puzzles: start on 1, end on the last number, one solution', () {
    for (final n in [5, 6, 7, 8]) {
      for (var s = 0; s < 12; s++) {
        final p = PathPuzzle.generate(n, Rng.seedOf('t-$n-$s'));
        expectValidPath(n, p.path);
        expect(p.clues.first, p.path.first);
        expect(p.clues.last, p.path.last);
        // 숫자는 정답 줄을 따라 1, 2, 3 … 순서
        var last = -1;
        for (final c in p.clues) {
          final i = p.path.indexOf(c);
          expect(i, greaterThan(last));
          last = i;
        }
        // 넉넉한 한도로 다시 풀어도 해는 하나
        final r = PathPuzzle.solve(n, p.clues, p.path, 2, 20000000);
        expect(r.exhausted, isFalse);
        expect(r.count, 1, reason: 'n=$n seed=$s must have one solution');
        expect(
          p.clues.length,
          inInclusiveRange(PathPuzzle.defaultClues(n), n * n ~/ 2),
        );
      }
    }
  });

  test('fast solver counts exactly like brute force (4x4, 5x5)', () {
    // 가지치기가 해를 하나라도 빠뜨리면 "해가 하나"라고 잘못 믿게 된다 → 무식한 풀이와 개수를 맞춰 본다
    int brute(int n, List<int> clues) {
      final nb = PathPuzzle.neighbors(n);
      final order = List.filled(n * n, -1);
      for (var k = 0; k < clues.length; k++) {
        order[clues[k]] = k;
      }
      final seen = List.filled(n * n, false);
      var count = 0;
      void go(int h, int depth, int next) {
        if (depth == n * n - 1) {
          count++;
          return;
        }
        for (final v in nb[h]) {
          if (seen[v]) continue;
          final o = order[v];
          if (o >= 0 && o != next) continue;
          if (o == clues.length - 1 && depth + 1 != n * n - 1) continue;
          seen[v] = true;
          go(v, depth + 1, o >= 0 ? next + 1 : next);
          seen[v] = false;
        }
      }

      seen[clues.first] = true;
      go(clues.first, 0, 1);
      return count;
    }

    var compared = 0;
    for (final n in [4, 5]) {
      for (var s = 0; s < 40; s++) {
        final rng = Rng(s * 7 + n);
        final path = PathPuzzle.randomPath(n, rng);
        // 양 끝 + 무작위 0~3개
        final idx = <int>{0, n * n - 1};
        final extra = rng.nextInt(4);
        for (var k = 0; k < extra; k++) {
          idx.add(1 + rng.nextInt(n * n - 2));
        }
        final clues = [for (final i in idx.toList()..sort()) path[i]];
        final want = brute(n, clues);
        final got = PathPuzzle.solve(n, clues, null, 1 << 30, 1 << 30);
        expect(got.count, want, reason: 'n=$n s=$s clues=$clues');
        compared++;
      }
    }
    expect(compared, 80);
  });

  test('solver finds the second solution when numbers are too few', () {
    // 2x2 에서 1 과 끝만 있으면 해가 둘일 수 없다(끝이 정해지면 유일) → 3x3 지그재그 + 양 끝만
    final path = [0, 1, 2, 5, 4, 3, 6, 7, 8];
    final r = PathPuzzle.solve(3, [0, 8], path);
    expect(r.count, 2);
    expect(r.other, isNotNull);
    expect(r.other, isNot(path));
    expectValidPath(3, r.other!);
  });

  test('same seed → same puzzle; different days → different puzzles', () {
    final a = PathPuzzle.daily('20261002');
    final b = PathPuzzle.daily('20261002');
    expect(fingerprint(a), fingerprint(b));
    expect(a.path, b.path);
    final c = PathPuzzle.daily('20261003');
    expect(fingerprint(c), isNot(fingerprint(a)));
  });

  test('daily puzzle is identical on every platform (fixed fingerprint)', () {
    // 이 값이 바뀌면 이미 배포된 앱과 오늘의 퍼즐이 달라진다 — 생성기를 고칠 땐 날짜 시드 이름도 바꿀 것
    expect(fingerprint(PathPuzzle.daily('20261002')), dailyFingerprint);
    expect(fingerprint(PathPuzzle.level(30)), level30Fingerprint);
  });

  test('a month of daily puzzles: 6x6, unique, fast', () {
    final sw = Stopwatch()..start();
    var worst = 0;
    for (var d = 1; d <= 30; d++) {
      final t = Stopwatch()..start();
      final p = PathPuzzle.daily('202611${d.toString().padLeft(2, '0')}');
      worst = t.elapsedMilliseconds > worst ? t.elapsedMilliseconds : worst;
      expect(p.n, PathPuzzle.dailySize);
      final r = PathPuzzle.solve(p.n, p.clues, p.path, 2, 20000000);
      expect(r.count, 1);
    }
    // ignore: avoid_print
    print('30 daily puzzles in ${sw.elapsedMilliseconds}ms (worst ${worst}ms)');
    expect(worst, lessThan(1500));
  });

  test('level sizes grow 5 → 8', () {
    expect([1, 3, 4, 10, 11, 25, 26, 500].map(PathPuzzle.sizeForLevel).toList(), [
      5,
      5,
      6,
      6,
      7,
      7,
      8,
      8,
    ]);
  });
}

const dailyFingerprint = '6:35,18,0,13,14,25,9,29,3';
const level30Fingerprint = '8:43,49,50,41,52,45,63,17,24,10,31,20,21';
