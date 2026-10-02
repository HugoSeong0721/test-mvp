/// 한붓 경로 퍼즐 엔진 — 생성·유일해 검증.
///
/// 규칙 2개: ① 모든 칸을 한 번씩 지난다 ② 숫자는 1 → 2 → 3 … 순서대로 지난다 (1에서 시작, 마지막 숫자에서 끝).
/// 시드가 같으면 iOS·안드로이드·웹 어디서든 같은 판이 나와야 한다(오늘의 퍼즐은 모두 같은 판).
/// 그래서 난수는 곱셈 없이 시프트·XOR 만 쓰는 xorshift32 (캣도쿠 엔진과 같음) — 웹(JS 숫자)에서도 결과가 같다.
/// 풀이기의 탐색 한도도 "노드 수"로 세서 기기 속도와 상관없이 같은 판이 나온다.
library;

import 'dart:typed_data';

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

/// 풀이 결과. [count] 는 찾은 해의 수(cap 에서 멈춤), [exhausted] 는 탐색 한도를 넘어 다 못 봤다는 뜻.
class SolveResult {
  SolveResult(this.count, this.other, this.exhausted);
  final int count;

  /// [PathPuzzle.solve] 에 넘긴 경로와 다른 해 (없으면 null).
  final List<int>? other;
  final bool exhausted;
}

class PathPuzzle {
  PathPuzzle(this.n, this.path, this.clues) : numberAt = Int32List(n * n) {
    for (var k = 0; k < clues.length; k++) {
      numberAt[clues[k]] = k + 1;
    }
  }

  /// 한 변 칸 수 (5~8).
  final int n;

  /// 정답 경로 — 칸 번호(r*n+c) 순서. 길이 n*n.
  final List<int> path;

  /// 숫자 칸 — clues[k] 가 숫자 k+1 이 적힌 칸. 첫 칸은 경로 시작, 마지막 칸은 경로 끝.
  final List<int> clues;

  /// 칸마다 적힌 숫자 (없으면 0).
  final Int32List numberAt;

  int get cells => n * n;
  int get lastNumber => clues.length;

  // ── 생성 ──

  /// 시드로 유일해 퍼즐을 만든다.
  ///  1) 무작위 한붓 경로 (지그재그에서 시작해 backbite 이동을 많이 섞는다)
  ///  2) 경로 양 끝 + 고르게 띄운 숫자 몇 개
  ///  3) 다른 해가 있으면 그 해가 처음 갈라지는 칸에 숫자를 하나 더 → 그 해는 순서가 어긋나 사라진다
  ///  4) 목표 개수까지 숫자를 하나씩 빼 보며, 빼도 유일하면 뺀다 (숫자가 적을수록 어렵다)
  static PathPuzzle generate(int n, int seed, {int? targetClues}) {
    final rng = Rng(seed);
    final total = n * n;
    final target = targetClues ?? defaultClues(n);
    for (var attempt = 0; attempt < 50; attempt++) {
      final path = randomPath(n, rng);
      final pos = Int32List(total);
      for (var i = 0; i < total; i++) {
        pos[path[i]] = i;
      }
      // 처음 숫자: 양 끝 + 목표보다 조금 많게 고르게
      final idx = <int>{0, total - 1};
      final start = target + 2;
      for (var k = 1; k < start - 1; k++) {
        final base = (k * (total - 1)) ~/ (start - 1);
        final jitter = rng.nextInt(3) - 1;
        idx.add((base + jitter).clamp(1, total - 2));
      }
      // 유일해가 될 때까지 숫자 추가
      var unique = false;
      for (var guard = 0; guard < total; guard++) {
        final r = solve(n, _cluesOf(path, idx), path);
        if (!r.exhausted && r.count == 1) {
          unique = true;
          break;
        }
        final alt = r.other;
        if (alt != null) {
          // 처음 갈라지는 자리 i: 정답은 path[i], 다른 해는 Y=alt[i] 로 간다.
          // path[i] 에 숫자를 붙이면 다른 해는 Y 를 그 숫자보다 먼저 지나 순서가 어긋난다.
          // (path[i] 가 이미 숫자면 Y 에 숫자를 붙인다 — 다른 해는 Y 를 더 앞 숫자보다 먼저 지난다)
          var i = 0;
          while (alt[i] == path[i]) {
            i++;
          }
          idx.add(idx.contains(i) ? pos[alt[i]] : i);
        } else {
          // 탐색 한도를 넘었다 → 가장 긴 구간 가운데에 숫자를 넣어 탐색을 좁힌다
          idx.add(_midOfLongestGap(idx, total));
        }
      }
      if (!unique) continue;
      // 목표 개수까지 빼 보기 (양 끝은 그대로)
      final inner = idx.where((i) => i != 0 && i != total - 1).toList()..sort();
      rng.shuffle(inner);
      for (final i in inner) {
        if (idx.length <= target) break;
        idx.remove(i);
        final r = solve(n, _cluesOf(path, idx), path);
        if (r.exhausted || r.count != 1) idx.add(i);
      }
      return PathPuzzle(n, path, _cluesOf(path, idx));
    }
    throw StateError('puzzle generation failed (n=$n, seed=$seed)');
  }

  /// 판 크기별 기본 숫자 개수 — 숫자 사이 평균 4~5칸.
  static int defaultClues(int n) => switch (n) {
    <= 4 => 5,
    5 => 7,
    6 => 9,
    7 => 11,
    _ => 13,
  };

  static List<int> _cluesOf(List<int> path, Set<int> idx) => [
    for (final i in idx.toList()..sort()) path[i],
  ];

  static int _midOfLongestGap(Set<int> idx, int total) {
    final s = idx.toList()..sort();
    var best = 0, at = 1;
    for (var k = 0; k + 1 < s.length; k++) {
      final gap = s[k + 1] - s[k];
      if (gap > best) {
        best = gap;
        at = s[k] + gap ~/ 2;
      }
    }
    return at;
  }

  /// 모든 칸을 지나는 무작위 경로. 지그재그 경로에 backbite 이동
  /// (끝점을 이웃 칸과 이어 붙이고 고리를 끊어 내는 것)을 충분히 반복한다.
  static List<int> randomPath(int n, Rng rng) {
    final total = n * n;
    final p = <int>[
      for (var r = 0; r < n; r++)
        for (var k = 0; k < n; k++) r * n + (r.isEven ? k : n - 1 - k),
    ];
    final pos = Int32List(total);
    for (var i = 0; i < total; i++) {
      pos[p[i]] = i;
    }
    void reverse(int a, int b) {
      while (a < b) {
        final t = p[a];
        p[a] = p[b];
        p[b] = t;
        pos[p[a]] = a;
        pos[p[b]] = b;
        a++;
        b--;
      }
    }

    final moves = 12 * total * n;
    final nb = neighbors(n);
    for (var m = 0; m < moves; m++) {
      if (rng.nextInt(2) == 0) {
        // 머리 쪽: p[0] 과 이웃 p[i] 를 잇고 p[i-1]–p[i] 를 끊는다 → p[0..i-1] 뒤집기
        final h = p[0];
        final x = nb[h][rng.nextInt(nb[h].length)];
        final i = pos[x];
        if (i <= 1) continue;
        reverse(0, i - 1);
      } else {
        final last = total - 1;
        final t = p[last];
        final x = nb[t][rng.nextInt(nb[t].length)];
        final i = pos[x];
        if (i >= last - 1) continue;
        reverse(i + 1, last);
      }
    }
    return p;
  }

  static final Map<int, List<Int32List>> _nbCache = {};

  /// 칸마다 위·아래·왼쪽·오른쪽 이웃.
  static List<Int32List> neighbors(int n) => _nbCache.putIfAbsent(n, () {
    return [
      for (var cell = 0; cell < n * n; cell++)
        Int32List.fromList([
          if (cell ~/ n > 0) cell - n,
          if (cell ~/ n < n - 1) cell + n,
          if (cell % n > 0) cell - 1,
          if (cell % n < n - 1) cell + 1,
        ]),
    ];
  });

  /// 탐색 한도 (노드 수). 넘으면 "유일한지 모름"으로 보고 숫자를 더 넣는다.
  static const nodeLimit = 60000;

  /// 칸 둘레 8칸 (위부터 시계 방향, 판 밖은 -1). 칸을 지웠을 때 남은 칸이 끊기는지 빠르게 보려고.
  static final Map<int, List<Int32List>> _ringCache = {};
  static List<Int32List> _ring(int n) => _ringCache.putIfAbsent(n, () {
    const dr = [-1, -1, 0, 1, 1, 1, 0, -1];
    const dc = [0, 1, 1, 1, 0, -1, -1, -1];
    return [
      for (var cell = 0; cell < n * n; cell++)
        Int32List.fromList([
          for (var k = 0; k < 8; k++)
            (cell ~/ n + dr[k] < 0 ||
                    cell ~/ n + dr[k] >= n ||
                    cell % n + dc[k] < 0 ||
                    cell % n + dc[k] >= n)
                ? -1
                : (cell ~/ n + dr[k]) * n + cell % n + dc[k],
        ]),
    ];
  });

  /// 숫자 [clues] 로 풀이를 센다 (최대 [cap] 개). [known] 을 주면 그것과 다른 해를 [SolveResult.other] 로 돌려준다.
  ///
  /// 가지치기 (웹에서도 빠르게 — 칸마다 남은 이웃 수를 들고 다니며 바뀐 곳만 본다):
  ///  · 빈칸은 들어오고 나갈 이웃이 2개 있어야 한다 (끝 칸은 1개)
  ///  · 줄 끝 옆에 "이웃이 하나뿐인 빈칸"이 있으면 지금 거기로 가야 한다 (둘이면 막힘)
  ///  · 남은 빈칸이 두 덩어리로 끊기면 막힘
  static SolveResult solve(
    int n,
    List<int> clues, [
    List<int>? known,
    int cap = 2,
    int limit = nodeLimit,
  ]) {
    final total = n * n;
    final nb = neighbors(n);
    final ring = _ring(n);
    final order = Int32List(total)..fillRange(0, total, -1);
    for (var k = 0; k < clues.length; k++) {
      order[clues[k]] = k;
    }
    final lastK = clues.length - 1;
    final end = clues[lastK];
    final seen = Uint8List(total);
    final deg = Int32List(total); // 아직 안 지난 이웃 수
    for (var u = 0; u < total; u++) {
      deg[u] = nb[u].length;
    }
    final path = Int32List(total);
    final stack = Int32List(total);
    final mark = Int32List(total);
    var stamp = 0;
    var count = 0;
    var nodes = 0;
    var exhausted = false;
    List<int>? other;

    void visit(int v) {
      seen[v] = 1;
      for (final w in nb[v]) {
        deg[w]--;
      }
    }

    void unvisit(int v) {
      seen[v] = 0;
      for (final w in nb[v]) {
        deg[w]++;
      }
    }

    // v 를 지운 뒤 남은 빈칸이 한 덩어리인가. v 의 위·아래·좌·우 빈칸이 둘레 8칸을 따라 이어져 있으면 그렇다.
    // 아니면(드묾) 직접 칠해 본다.
    bool connectedAfter(int v, int left) {
      final rg = ring[v];
      var gap = -1; // 둘레에서 빈칸이 아닌 자리 하나 (거기서부터 돌며 덩어리를 센다)
      for (var k = 0; k < 8; k++) {
        if (rg[k] < 0 || seen[rg[k]] != 0) {
          gap = k;
          break;
        }
      }
      var runs = 0;
      if (gap < 0) {
        runs = 1; // 둘레가 다 빈칸 — 한 덩어리
      } else {
        var inRun = false, orth = false;
        for (var i = 1; i <= 8; i++) {
          final k = (gap + i) & 7;
          final c = rg[k];
          final on = c >= 0 && seen[c] == 0;
          if (on) {
            if (!inRun) {
              inRun = true;
              orth = false;
            }
            if (k.isEven) orth = true; // 위·오른쪽·아래·왼쪽 (v 와 바로 붙은 칸)
          } else if (inRun) {
            inRun = false;
            if (orth) runs++;
          }
        }
      }
      if (runs <= 1) return true;
      stamp++;
      var start = -1;
      for (final w in nb[v]) {
        if (seen[w] == 0) {
          start = w;
          break;
        }
      }
      if (start < 0) return left == 0;
      var sp = 0, reached = 0;
      mark[start] = stamp;
      stack[sp++] = start;
      while (sp > 0) {
        final u = stack[--sp];
        reached++;
        for (final w in nb[u]) {
          if (seen[w] == 0 && mark[w] != stamp) {
            mark[w] = stamp;
            stack[sp++] = w;
          }
        }
      }
      return reached == left;
    }

    void dfs(int h, int depth, int nextK) {
      if (count >= cap || exhausted) return;
      if (++nodes > limit) {
        exhausted = true;
        return;
      }
      if (depth == total - 1) {
        count++;
        if (known != null && other == null) {
          for (var i = 0; i < total; i++) {
            if (path[i] != known[i]) {
              other = List<int>.of(path);
              break;
            }
          }
        }
        return;
      }
      final left = total - depth - 1; // 아직 안 지난 칸 수
      // 줄 끝 옆의 빈칸 중 이웃이 하나뿐인 칸 → 지금 거기로 가야 한다
      var forced = -1;
      for (final u in nb[h]) {
        if (seen[u] != 0) continue;
        if (u == end) {
          if (deg[u] == 0 && left > 1) return;
          continue;
        }
        if (deg[u] <= 1) {
          if (deg[u] == 0 && left > 1) return;
          if (forced >= 0) return;
          forced = u;
        }
      }
      for (final v in nb[h]) {
        if (seen[v] != 0) continue;
        if (forced >= 0 && v != forced) continue;
        final o = order[v];
        if (o >= 0 && o != nextK) continue;
        if (o == lastK && left != 1) continue;
        visit(v);
        path[depth + 1] = v;
        var ok = left - 1 == 0 || deg[v] >= 1;
        if (ok) {
          // 옛 줄 끝 h 의 이웃은 h 라는 출구를 잃었다 → 들어오고 나갈 길이 남았나
          for (final u in nb[h]) {
            if (seen[u] != 0) continue;
            if (u == end ? deg[u] < 1 : deg[u] < 2) {
              ok = false;
              break;
            }
          }
        }
        if (ok) ok = connectedAfter(v, left - 1);
        if (ok) dfs(v, depth + 1, o >= 0 ? nextK + 1 : nextK);
        unvisit(v);
        if (count >= cap || exhausted) return;
      }
    }

    final s = clues[0];
    visit(s);
    path[0] = s;
    dfs(s, 0, 1);
    return SolveResult(count, other, exhausted);
  }

  // ── 모드 ──

  /// 오늘의 퍼즐 — 기기 현지 날짜 기준.
  static const dailySize = 6;
  static PathPuzzle daily(String dayKey) =>
      generate(dailySize, Rng.seedOf('pathpuzzle-daily-$dayKey'));

  /// 단계 모드의 판 크기. 5×5 에서 시작해 8×8 에서 멈춘다 (폰에서 손가락으로 그릴 수 있는 한계).
  static int sizeForLevel(int level) {
    if (level <= 3) return 5;
    if (level <= 10) return 6;
    if (level <= 25) return 7;
    return 8;
  }

  static PathPuzzle level(int level) =>
      generate(sizeForLevel(level), Rng.seedOf('pathpuzzle-level-$level'));
}

/// 날짜 키 YYYYMMDD (기기 현지 시간).
String dayKeyOf(DateTime t) =>
    '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
