/// 캣도쿠 퍼즐 엔진 — 생성·검증·규칙 판정.
///
/// 규칙: 색 구역마다 고양이 1마리, 행·열마다 1마리, 고양이끼리는 대각선 포함 인접 금지.
/// 시드가 같으면 iOS·안드로이드·웹 어디서든 같은 판이 나와야 한다(오늘의 퍼즐은 모두 같은 판).
/// 그래서 난수는 곱셈 없이 시프트·XOR 만 쓰는 xorshift32 — 웹(JS 숫자)에서도 결과가 같다.
library;

class Rng {
  Rng(int seed)
    : _x = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF {
    for (var i = 0; i < 8; i++) {
      next();
    }
  }
  int _x;

  int next() {
    var x = _x;
    x = (x ^ (x << 13)) & 0xFFFFFFFF;
    x = (x ^ (x >> 17)) & 0xFFFFFFFF;
    x = (x ^ (x << 5)) & 0xFFFFFFFF;
    _x = x;
    return x;
  }

  double nextDouble() => next() / 4294967296.0;
  int nextInt(int n) => (nextDouble() * n).floor();

  void shuffle<T>(List<T> a) {
    for (var i = a.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
  }

  /// 문자열 → 32비트 시드. 곱셈 결과가 2^53 을 넘지 않게 31배 + 마스크.
  static int seedOf(String s) {
    var h = 7;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFFFF;
    }
    return h;
  }
}

class Puzzle {
  Puzzle(this.n, this.solution, this.region);

  /// 한 변 칸 수 (5~9).
  final int n;

  /// solution[r] = r 행 고양이의 열.
  final List<int> solution;

  /// region[r][c] = 색 구역 번호 (0..n-1).
  final List<List<int>> region;

  bool isSolutionCell(int r, int c) => solution[r] == c;

  static const _dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  /// 시드로 유일해 퍼즐을 만든다.
  /// 무작위 구역 → 다른 해가 있으면 그 해의 칸 하나를 이웃 구역으로 넘겨 해를 지우기를 반복.
  /// (그냥 다시 뽑기만 하면 8×8 부터 수천 번이 걸린다. 보정 방식은 9×9 도 수십 ms.)
  static Puzzle generate(int n, int seed) {
    final rng = Rng(seed);
    for (var attempt = 0; attempt < 200; attempt++) {
      final sol = _randomSolution(n, rng);
      final reg = _growRegions(n, rng, sol);
      for (var step = 0; step < 400; step++) {
        final alt = findOtherSolution(n, reg, sol);
        if (alt == null) return Puzzle(n, sol, reg);
        if (!_breakAlt(n, reg, sol, alt, rng)) break;
      }
    }
    throw StateError('puzzle generation failed (n=$n, seed=$seed)');
  }

  static List<int> _randomSolution(int n, Rng rng) {
    final cols = List<int>.filled(n, -1);
    final used = List<bool>.filled(n, false);
    bool bt(int r) {
      if (r == n) return true;
      final cand = <int>[];
      for (var c = 0; c < n; c++) {
        if (used[c]) continue;
        if (r > 0 && (c - cols[r - 1]).abs() < 2) continue;
        cand.add(c);
      }
      rng.shuffle(cand);
      for (final c in cand) {
        cols[r] = c;
        used[c] = true;
        if (bt(r + 1)) return true;
        used[c] = false;
      }
      return false;
    }

    if (!bt(0)) throw StateError('no solution for n=$n');
    return cols;
  }

  static List<List<int>> _growRegions(int n, Rng rng, List<int> sol) {
    final reg = List.generate(n, (_) => List<int>.filled(n, -1));
    for (var k = 0; k < n; k++) {
      reg[k][sol[k]] = k;
    }
    var left = n * n - n;
    while (left > 0) {
      final cand = <List<int>>[];
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          final g = reg[r][c];
          if (g < 0) continue;
          for (final d in _dirs) {
            final a = r + d[0], b = c + d[1];
            if (a < 0 || b < 0 || a >= n || b >= n || reg[a][b] >= 0) continue;
            cand.add([a, b, g]);
          }
        }
      }
      final p = cand[rng.nextInt(cand.length)];
      reg[p[0]][p[1]] = p[2];
      left--;
    }
    return reg;
  }

  static bool _breakAlt(
    int n,
    List<List<int>> reg,
    List<int> sol,
    List<int> alt,
    Rng rng,
  ) {
    final rows = [
      for (var r = 0; r < n; r++)
        if (alt[r] != sol[r]) r,
    ];
    rng.shuffle(rows);
    for (final r in rows) {
      final c = alt[r];
      final g = reg[r][c];
      final nb = <int>[];
      for (final d in _dirs) {
        final a = r + d[0], b = c + d[1];
        if (a < 0 || b < 0 || a >= n || b >= n) continue;
        final h = reg[a][b];
        if (h != g && !nb.contains(h)) nb.add(h);
      }
      rng.shuffle(nb);
      for (final h in nb) {
        reg[r][c] = h;
        if (_connected(n, reg, g)) return true;
        reg[r][c] = g;
      }
    }
    return false;
  }

  static bool _connected(int n, List<List<int>> reg, int g) {
    final cells = <int>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (reg[r][c] == g) cells.add(r * n + c);
      }
    }
    if (cells.isEmpty) return false;
    final seen = <int>{cells.first};
    final stack = [cells.first];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final r = p ~/ n, c = p % n;
      for (final d in _dirs) {
        final a = r + d[0], b = c + d[1];
        if (a < 0 || b < 0 || a >= n || b >= n || reg[a][b] != g) continue;
        if (seen.add(a * n + b)) stack.add(a * n + b);
      }
    }
    return seen.length == cells.length;
  }

  /// [sol] 과 다른 해가 있으면 돌려준다 (없으면 null = 유일해).
  static List<int>? findOtherSolution(
    int n,
    List<List<int>> reg,
    List<int> sol,
  ) {
    final colU = List<bool>.filled(n, false);
    final regU = List<bool>.filled(n, false);
    final cols = List<int>.filled(n, -1);
    List<int>? res;
    void bt(int r, int prev) {
      if (res != null) return;
      if (r == n) {
        for (var i = 0; i < n; i++) {
          if (cols[i] != sol[i]) {
            res = List.of(cols);
            return;
          }
        }
        return;
      }
      for (var c = 0; c < n; c++) {
        final g = reg[r][c];
        if (colU[c] || regU[g]) continue;
        if (r > 0 && (c - prev).abs() < 2) continue;
        colU[c] = regU[g] = true;
        cols[r] = c;
        bt(r + 1, c);
        colU[c] = regU[g] = false;
      }
    }

    bt(0, -9);
    return res;
  }

  /// 해의 개수 (cap 에서 멈춤). 테스트용.
  static int countSolutions(int n, List<List<int>> reg, {int cap = 2}) {
    var count = 0;
    final colU = List<bool>.filled(n, false);
    final regU = List<bool>.filled(n, false);
    void bt(int r, int prev) {
      if (count >= cap) return;
      if (r == n) {
        count++;
        return;
      }
      for (var c = 0; c < n; c++) {
        final g = reg[r][c];
        if (colU[c] || regU[g]) continue;
        if (r > 0 && (c - prev).abs() < 2) continue;
        colU[c] = regU[g] = true;
        bt(r + 1, c);
        colU[c] = regU[g] = false;
      }
    }

    bt(0, -9);
    return count;
  }

  /// 오늘의 퍼즐 — 기기 현지 날짜 기준. 7×7 (웹판과 같은 크기).
  static Puzzle daily(String dayKey) =>
      generate(7, Rng.seedOf('catdoku-daily-$dayKey'));

  /// 단계 모드의 판 크기. 처음엔 작게 시작해 9×9 에서 멈춘다 (폰에서 손가락으로 누를 수 있는 한계).
  static int sizeForLevel(int level) {
    if (level <= 3) return 5;
    if (level <= 10) return 6;
    if (level <= 25) return 7;
    if (level <= 50) return 8;
    return 9;
  }

  static Puzzle level(int level) =>
      generate(sizeForLevel(level), Rng.seedOf('catdoku-level-$level'));
}

/// 날짜 키 YYYYMMDD (기기 현지 시간).
String dayKeyOf(DateTime t) =>
    '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
