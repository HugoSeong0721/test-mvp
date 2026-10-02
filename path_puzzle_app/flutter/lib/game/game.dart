import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/puzzle.dart';

enum GameStatus { playing, won }

enum GameMode { daily, level }

/// 줄을 못 그은 이유 — 화면에 잠깐 띄운다.
enum Block {
  /// 순서가 아닌 숫자 칸으로 들어가려 했다.
  wrongNumber,

  /// 마지막 숫자에 닿았는데 아직 빈칸이 남았다 — 끝 숫자 너머로는 못 간다.
  pastEnd,

  /// 줄 끝과 붙어 있지 않은 칸을 눌렀다.
  notNext,
}

/// 한 판의 상태. 화면과 분리해서 테스트 로봇이 직접 두드릴 수 있다.
///
/// 줄은 늘 숫자 1에서 시작한다. 손가락으로 끌면 줄 끝에서 이어지고,
/// 이미 지난 칸으로 되돌아가면 그 칸 뒤가 지워진다(탭 순환·실패·하트 없음).
class Game extends ChangeNotifier {
  Game(this.puzzle, {required this.mode, this.levelNo = 0, this.carried = 0})
    : _onPath = List<int>.filled(puzzle.cells, -1) {
    _reset();
  }

  final PathPuzzle puzzle;
  final GameMode mode;
  final int levelNo;

  int get n => puzzle.n;

  /// 지금까지 그은 줄 (칸 번호). 첫 칸은 늘 숫자 1.
  final List<int> path = [];
  final List<int> _onPath; // 칸 → 줄에서의 순서 (없으면 -1)

  int get head => path.last;
  bool isOnPath(int cell) => _onPath[cell] >= 0;
  int indexOnPath(int cell) => _onPath[cell];

  /// 다음에 지나야 할 숫자. 다 지났으면 lastNumber + 1.
  int nextNumber = 2;
  int get filled => path.length;
  int get left => puzzle.cells - path.length;

  int hintsUsed = 0;
  GameStatus status = GameStatus.playing;

  /// 줄을 못 그었을 때 (화면에 이유·흔들림). 번호가 바뀌면 다시 보여 준다.
  Block? lastBlock;
  int blockSeq = 0;
  int? blockedCell;

  /// 힌트로 방금 그어 준 칸들.
  List<int> lastHintCells = const [];
  int hintSeq = 0;

  /// 화면 상태줄에 띄울 마지막 사건 (막힘 또는 힌트).
  int eventSeq = 0;
  bool lastEventIsHint = false;

  // ── 시간 ──
  final int carried; // 앞선 시도에서 이어지는 시간
  final Stopwatch _watch = Stopwatch()..start();
  int get seconds => carried + _watch.elapsed.inSeconds;
  void pauseClock() => _watch.stop();
  void resumeClock() {
    if (status == GameStatus.playing) _watch.start();
  }

  void _reset() {
    for (final c in path) {
      _onPath[c] = -1;
    }
    path
      ..clear()
      ..add(puzzle.clues.first);
    _onPath[puzzle.clues.first] = 0;
    nextNumber = 2;
  }

  bool adjacent(int a, int b) {
    final ar = a ~/ n, ac = a % n, br = b ~/ n, bc = b % n;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  void _truncate(int len) {
    while (path.length > len) {
      final c = path.removeLast();
      _onPath[c] = -1;
      if (puzzle.numberAt[c] > 0) nextNumber = puzzle.numberAt[c];
    }
  }

  void _block(Block b, int cell) {
    lastBlock = b;
    blockedCell = cell;
    blockSeq++;
    eventSeq++;
    lastEventIsHint = false;
  }

  /// 줄 끝에서 [cell] 로 한 칸 나아가거나, 줄 위의 칸이면 거기까지 되돌린다.
  /// 나아갔거나 되돌렸으면 true.
  bool step(int cell) {
    if (status != GameStatus.playing) return false;
    if (cell == head) return false;
    final at = _onPath[cell];
    if (at >= 0) {
      _truncate(at + 1);
      notifyListeners();
      return true;
    }
    if (!adjacent(head, cell)) {
      _block(Block.notNext, cell);
      notifyListeners();
      return false;
    }
    if (puzzle.numberAt[head] == puzzle.lastNumber) {
      _block(Block.pastEnd, cell);
      notifyListeners();
      return false;
    }
    final num = puzzle.numberAt[cell];
    if (num > 0 && num != nextNumber) {
      _block(Block.wrongNumber, cell);
      notifyListeners();
      return false;
    }
    _onPath[cell] = path.length;
    path.add(cell);
    if (num > 0) nextNumber = num + 1;
    if (path.length == puzzle.cells && num == puzzle.lastNumber) {
      _end();
    }
    notifyListeners();
    return true;
  }

  /// 손가락이 [cell] 에 와 있다 — 빨리 그어서 칸을 건너뛰었으면 사이 칸을 차례로 채운다.
  /// 막히면 거기서 멈춘다.
  void dragTo(int cell) {
    if (status != GameStatus.playing || cell == head) return;
    if (_onPath[cell] >= 0 || adjacent(head, cell)) {
      step(cell);
      return;
    }
    final tr = cell ~/ n, tc = cell % n;
    for (var guard = 0; guard < 2 * n && head != cell; guard++) {
      final hr = head ~/ n, hc = head % n;
      final dr = tr - hr, dc = tc - hc;
      // 더 많이 남은 쪽으로 한 칸. 그쪽이 막히면 다른 쪽.
      final first = dr.abs() >= dc.abs()
          ? (hr + dr.sign) * n + hc
          : hr * n + hc + dc.sign;
      final second = dr.abs() >= dc.abs()
          ? (dc == 0 ? -1 : hr * n + hc + dc.sign)
          : (dr == 0 ? -1 : (hr + dr.sign) * n + hc);
      if (_canEnter(first)) {
        step(first);
      } else if (second >= 0 && _canEnter(second)) {
        step(second);
      } else {
        step(first); // 막힌 이유를 보여 준다
        return;
      }
    }
  }

  bool _canEnter(int cell) {
    if (_onPath[cell] >= 0) return false;
    if (puzzle.numberAt[head] == puzzle.lastNumber) return false;
    final num = puzzle.numberAt[cell];
    return num == 0 || num == nextNumber;
  }

  /// 줄 끝 한 칸 지우기 (숫자 1은 남는다).
  void undo() {
    if (status != GameStatus.playing || path.length <= 1) return;
    _truncate(path.length - 1);
    notifyListeners();
  }

  /// 줄을 다 지우고 숫자 1만 남긴다.
  void clear() {
    if (status != GameStatus.playing || path.length <= 1) return;
    _truncate(1);
    notifyListeners();
  }

  void _end() {
    status = GameStatus.won;
    _watch.stop();
  }

  /// 정답과 같은 앞부분 길이.
  int get correctPrefix {
    var k = 0;
    while (k < path.length && path[k] == puzzle.path[k]) {
      k++;
    }
    return k;
  }

  /// 힌트(보상형 광고 뒤): 정답에서 벗어난 부분을 지우고, 다음 숫자까지 정답 줄을 그어 준다.
  /// 영상을 봤는데 줄이 줄기만 하는 일이 없게 — 늘 최소 [minHintCells] 칸은 앞으로 간다.
  static const minHintCells = 3;
  int lastHintRemoved = 0;

  void applyHint() {
    if (status != GameStatus.playing) return;
    hintsUsed++;
    hintSeq++;
    eventSeq++;
    lastEventIsHint = true;
    final keep = correctPrefix;
    lastHintRemoved = path.length - keep;
    _truncate(keep);
    final sol = puzzle.path;
    final added = <int>[];
    var i = keep;
    while (i < sol.length) {
      final c = sol[i];
      _onPath[c] = path.length;
      path.add(c);
      added.add(c);
      i++;
      final num = puzzle.numberAt[c];
      if (num > 0) {
        nextNumber = num + 1;
        if (added.length >= minHintCells) break;
      }
    }
    lastHintCells = added;
    if (path.length == puzzle.cells) _end();
    notifyListeners();
  }

  // ── 입력 잠깐 막기 ──
  // 창 버튼을 두 번 누르면 두 번째 탭이 창 아래 판에 떨어진다 (캣도쿠에서 겪음).
  bool _blocked = false;
  Timer? _blockTimer;
  bool get inputBlocked => _blocked;
  void blockInput([Duration d = const Duration(milliseconds: 450)]) {
    _blocked = true;
    _blockTimer?.cancel();
    _blockTimer = Timer(d, () => _blocked = false);
  }

  // ── 저장/복원 ── 뒤로 갔다 와도 줄이 그대로 남게.
  Map<String, Object> snapshot() => {
    'n': n,
    'path': List<int>.of(path),
    'secs': seconds,
    'hints': hintsUsed,
  };

  /// 저장된 줄을 한 칸씩 다시 그어 본다 — 규칙에 맞는 데까지만 살린다.
  void restore(Map<String, dynamic> s) {
    if (s['n'] != n) return;
    final saved = (s['path'] as List?)?.cast<int>() ?? const <int>[];
    if (saved.isEmpty || saved.first != puzzle.clues.first) return;
    for (final c in saved.skip(1)) {
      if (c < 0 || c >= puzzle.cells || !step(c)) break;
    }
    hintsUsed = (s['hints'] as int?) ?? 0;
    // 복원 중 생긴 막힘 표시는 지운다
    lastBlock = null;
    eventSeq = 0;
    notifyListeners();
  }

  @visibleForTesting
  void solveAllButLast() {
    for (final c in puzzle.path.skip(path.length).take(
      puzzle.cells - path.length - 1,
    )) {
      if (!step(c)) break;
    }
  }

  @override
  void dispose() {
    _blockTimer?.cancel();
    _watch.stop();
    super.dispose();
  }
}
