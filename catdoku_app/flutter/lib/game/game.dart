import 'package:flutter/foundation.dart';

import '../core/puzzle.dart';

enum Brush { cat, mark }

enum Mark { empty, cross, cat }

enum GameStatus { playing, won, lost }

enum GameMode { daily, level }

/// 규칙 위반 한 건 — 화면에 빨갛게 번쩍이고 이유를 띄운다.
class Violation {
  Violation(this.r, this.c, this.reason, this.culprits);
  final int r, c;
  final String reason;
  final List<(int, int)> culprits;
}

/// 한 판의 상태. 화면과 분리해서 테스트 로봇이 직접 두드릴 수 있다.
class Game extends ChangeNotifier {
  Game(this.puzzle, {required this.mode, this.levelNo = 0, this.carried = 0})
    : cells = List.generate(puzzle.n, (_) => List.filled(puzzle.n, Mark.empty)),
      _auto = List.generate(puzzle.n, (_) => List.filled(puzzle.n, 0));

  final Puzzle puzzle;
  final GameMode mode;
  final int levelNo;

  int get n => puzzle.n;
  static const maxHearts = 3;

  final List<List<Mark>> cells;
  final List<List<int>> _auto; // 고양이가 깔아 둔 자동 ✕ 개수
  final Map<int, List<int>> _autoBy = {};

  Brush brush = Brush.cat;
  int hearts = maxHearts;
  int cats = 0;
  int hintsUsed = 0;
  int continues = 0;
  GameStatus status = GameStatus.playing;

  /// 마지막 위반 (화면 애니메이션용). 같은 칸 연속 위반도 구분되게 번호를 붙인다.
  Violation? lastViolation;
  int violationSeq = 0;

  /// 힌트로 방금 놓은/치운 칸.
  (int, int)? lastHint;
  int hintSeq = 0;

  /// 힌트가 잘못 놓인 고양이를 치웠으면 true (놓았으면 false).
  bool lastHintRemoved = false;

  /// 화면 상태줄에 띄울 마지막 사건 (위반 또는 힌트). 번호가 바뀌면 다시 띄운다.
  int eventSeq = 0;
  bool lastEventIsHint = false;

  // ── 시간 ──
  final int carried; // 오늘 퍼즐: 앞선 시도에서 이어지는 시간
  final Stopwatch _watch = Stopwatch()..start();
  int get seconds => carried + _watch.elapsed.inSeconds;
  void pauseClock() => _watch.stop();
  void resumeClock() {
    if (status == GameStatus.playing) _watch.start();
  }

  bool isAutoCross(int r, int c) => _auto[r][c] > 0;

  /// 화면 가장자리 표시용 — 그 행/열/구역에 고양이가 있나.
  bool rowDone(int r) => cells[r].contains(Mark.cat);
  bool colDone(int c) =>
      [for (var r = 0; r < n; r++) cells[r][c]].contains(Mark.cat);
  bool regionDone(int g) {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (puzzle.region[r][c] == g && cells[r][c] == Mark.cat) return true;
      }
    }
    return false;
  }

  void setBrush(Brush b) {
    brush = b;
    notifyListeners();
  }

  /// 칸을 누른다. 고른 붓에 따라:
  ///  🐱 붓 — 빈칸/✕ → 고양이 시도, 고양이 → 치우기
  ///  ✕ 붓 — 빈칸 → ✕, ✕ → 지우기, 고양이 → 치우고 ✕
  /// 반환값: 끌어서 이어 칠할 때 쓸 동작 (✕ 칠하기 중이면 true).
  bool tap(int r, int c) {
    if (status != GameStatus.playing) return false;
    final cur = cells[r][c];
    if (brush == Brush.mark) {
      if (cur == Mark.cross) {
        cells[r][c] = Mark.empty;
        notifyListeners();
        return false;
      }
      if (cur == Mark.cat) _removeCat(r, c);
      cells[r][c] = Mark.cross;
      notifyListeners();
      return true;
    }
    if (cur == Mark.cat) {
      _removeCat(r, c);
      notifyListeners();
      return false;
    }
    _tryCat(r, c);
    notifyListeners();
    return false;
  }

  /// ✕ 붓으로 끌 때 지나간 빈칸에 ✕.
  void dragMark(int r, int c) {
    if (status != GameStatus.playing || brush != Brush.mark) return;
    if (cells[r][c] != Mark.empty) return;
    cells[r][c] = Mark.cross;
    notifyListeners();
  }

  void _tryCat(int r, int c) {
    final conf = conflictsWith(r, c);
    if (conf.isNotEmpty) {
      hearts--;
      violationSeq++;
      eventSeq++;
      lastEventIsHint = false;
      lastViolation = Violation(r, c, conf.first.$3, [
        for (final f in conf) (f.$1, f.$2),
      ]);
      if (hearts <= 0) {
        hearts = 0;
        _end(GameStatus.lost);
      }
      return;
    }
    _placeCat(r, c);
    if (cats == n) _end(GameStatus.won);
  }

  /// 지금 놓인 고양이 중 (r,c) 와 부딪히는 것들.
  List<(int, int, String)> conflictsWith(int r, int c) {
    final out = <(int, int, String)>[];
    for (var r2 = 0; r2 < n; r2++) {
      for (var c2 = 0; c2 < n; c2++) {
        if (cells[r2][c2] != Mark.cat) continue;
        String? why;
        if ((r2 - r).abs() <= 1 && (c2 - c).abs() <= 1) {
          why = 'Cats can’t touch!';
        } else if (r2 == r) {
          why = 'One cat per row!';
        } else if (c2 == c) {
          why = 'One cat per column!';
        } else if (puzzle.region[r2][c2] == puzzle.region[r][c]) {
          why = 'One cat per color!';
        }
        if (why != null) out.add((r2, c2, why));
      }
    }
    return out;
  }

  List<int> _blockedBy(int r, int c) {
    final out = <int>{};
    void add(int a, int b) {
      if (a < 0 || b < 0 || a >= n || b >= n || (a == r && b == c)) return;
      out.add(a * n + b);
    }

    for (var i = 0; i < n; i++) {
      add(r, i);
      add(i, c);
    }
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        add(r + dr, c + dc);
      }
    }
    for (var a = 0; a < n; a++) {
      for (var b = 0; b < n; b++) {
        if (puzzle.region[a][b] == puzzle.region[r][c]) add(a, b);
      }
    }
    return out.toList();
  }

  void _placeCat(int r, int c) {
    cells[r][c] = Mark.cat;
    cats++;
    final list = _blockedBy(r, c);
    _autoBy[r * n + c] = list;
    for (final p in list) {
      _auto[p ~/ n][p % n]++;
    }
  }

  void _removeCat(int r, int c) {
    cells[r][c] = Mark.empty;
    cats--;
    for (final p in _autoBy.remove(r * n + c) ?? const <int>[]) {
      _auto[p ~/ n][p % n]--;
    }
  }

  void _end(GameStatus s) {
    status = s;
    _watch.stop();
  }

  /// 힌트(보상형 광고 뒤): 엉뚱한 자리에 있는 고양이가 있으면 먼저 치워 주고,
  /// 없으면 아직 고양이가 없는 구역 하나의 정답 칸에 고양이를 놓는다.
  void applyHint() {
    if (status != GameStatus.playing) return;
    hintsUsed++;
    hintSeq++;
    eventSeq++;
    lastEventIsHint = true;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (cells[r][c] == Mark.cat && !puzzle.isSolutionCell(r, c)) {
          _removeCat(r, c);
          lastHint = (r, c);
          lastHintRemoved = true;
          notifyListeners();
          return;
        }
      }
    }
    for (var r = 0; r < n; r++) {
      final c = puzzle.solution[r];
      if (cells[r][c] != Mark.cat) {
        if (cells[r][c] == Mark.cross) cells[r][c] = Mark.empty;
        _placeCat(r, c);
        lastHint = (r, c);
        lastHintRemoved = false;
        if (cats == n) _end(GameStatus.won);
        notifyListeners();
        return;
      }
    }
  }

  /// 하트를 다 잃은 뒤 영상을 보면 판을 그대로 두고 하트를 채워 계속한다.
  void continueWithHearts() {
    if (status != GameStatus.lost) return;
    continues++;
    hearts = maxHearts;
    status = GameStatus.playing;
    _watch.start();
    notifyListeners();
  }

  @visibleForTesting
  void solveAllButOne() {
    for (var r = 0; r < n - 1; r++) {
      final c = puzzle.solution[r];
      if (cells[r][c] != Mark.cat) _placeCat(r, c);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _watch.stop();
    super.dispose();
  }
}
