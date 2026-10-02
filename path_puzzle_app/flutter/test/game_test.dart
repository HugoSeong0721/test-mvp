// 한 판의 규칙 검사 — 화면 없이 Game 을 직접 두드린다.
// 3×3 시범 판: 정답 0 1 2 / 5 4 3 / 6 7 8 순서, 숫자 1 = 0번 칸, 2 = 4번 칸, 3 = 8번 칸.
import 'package:flutter_test/flutter_test.dart';
import 'package:path_puzzle/core/puzzle.dart';
import 'package:path_puzzle/game/game.dart';

PathPuzzle demo() => PathPuzzle(3, [0, 1, 2, 5, 4, 3, 6, 7, 8], [0, 4, 8]);

Game newGame() => Game(demo(), mode: GameMode.level, levelNo: 1);

void main() {
  test('the line always starts on 1', () {
    final g = newGame();
    expect(g.path, [0]);
    expect(g.nextNumber, 2);
    expect(g.left, 8);
  });

  test('step forward, slide back to erase, jump back to an earlier square', () {
    final g = newGame();
    expect(g.step(1), isTrue);
    expect(g.step(2), isTrue);
    expect(g.step(5), isTrue);
    expect(g.path, [0, 1, 2, 5]);
    // 바로 앞 칸으로 되돌아가면 지워진다
    expect(g.step(2), isTrue);
    expect(g.path, [0, 1, 2]);
    // 숫자 2 를 지나고 나서 1 칸으로 되돌리면 2 도 지워지고 다음 숫자는 다시 2
    g.step(5);
    g.step(4);
    expect(g.nextNumber, 3);
    g.step(0);
    expect(g.path, [0]);
    expect(g.nextNumber, 2);
  });

  test('numbers must go in order — no heart, no penalty, just blocked', () {
    final g = newGame();
    g.step(3);
    g.step(6);
    g.step(7);
    // 7 옆의 8 은 숫자 3 — 아직 2 를 안 지났다
    expect(g.step(8), isFalse);
    expect(g.lastBlock, Block.wrongNumber);
    expect(g.blockedCell, 8);
    expect(g.path, [0, 3, 6, 7]);
  });

  test('cannot jump to a square that is not next to the end of the line', () {
    final g = newGame();
    expect(g.step(8), isFalse);
    expect(g.lastBlock, Block.notNext);
    expect(g.path, [0]);
  });

  test('reaching the last number early: cannot go past it, must slide back', () {
    final g = newGame();
    for (final c in [1, 2, 5, 4, 7, 8]) {
      expect(g.step(c), isTrue);
    }
    expect(g.status, GameStatus.playing, reason: '3 and 6 are still empty');
    expect(g.left, 2);
    // 끝 숫자 너머로는 못 간다 (8 은 구석이라 붙은 빈칸이 없다 → 아무 칸이나)
    expect(g.step(5), isTrue, reason: 'stepping back onto the line erases');
    expect(g.path, [0, 1, 2, 5]);
  });

  test('past-end block when the last number has an empty neighbour', () {
    // 0 1 2 / 5 4 3 / 6 7 8 에서 끝을 4번 칸(가운데)으로 바꾼 판: 0→1→2→5→4 로 끝 숫자에 닿은 뒤 3 으로 가려 하면 막힌다
    final p = PathPuzzle(3, [0, 3, 6, 7, 8, 5, 2, 1, 4], [0, 4]);
    final g = Game(p, mode: GameMode.level);
    for (final c in [1, 2, 5, 4]) {
      g.step(c);
    }
    expect(g.step(3), isFalse);
    expect(g.lastBlock, Block.pastEnd);
  });

  test('fast drag that skips squares fills the squares in between', () {
    final g = newGame();
    g.dragTo(2); // 0 → 2 (같은 줄 두 칸 건너)
    expect(g.path, [0, 1, 2]);
    g.dragTo(8); // 2 → 8 아래로 두 칸: 5 는 들어가고 8 은 숫자 3 이라 막힌다
    expect(g.path, [0, 1, 2, 5]);
    expect(g.lastBlock, Block.wrongNumber);
  });

  test('following the answer wins and stops the clock', () {
    final g = newGame();
    for (final c in demo().path.skip(1)) {
      g.step(c);
    }
    expect(g.status, GameStatus.won);
    expect(g.left, 0);
    final s = g.seconds;
    expect(g.step(7), isFalse, reason: 'no drawing after the win');
    expect(g.seconds, s);
  });

  test('undo / clear', () {
    final g = newGame();
    g.step(1);
    g.step(2);
    g.undo();
    expect(g.path, [0, 1]);
    g.clear();
    expect(g.path, [0]);
    g.undo();
    expect(g.path, [0], reason: '1 always stays');
  });

  test('hint fixes wrong turns and draws to the next number', () {
    final g = newGame();
    g.step(3); // 정답은 0 → 1 쪽
    g.applyHint();
    expect(g.lastHintRemoved, 1);
    expect(g.path, [0, 1, 2, 5, 4]);
    expect(g.nextNumber, 3);
    expect(g.lastHintCells, [1, 2, 5, 4]);
    expect(g.hintsUsed, 1);
    // 다음 힌트는 끝까지 — 그리고 이긴다
    g.applyHint();
    expect(g.status, GameStatus.won);
  });

  test('hint always moves at least 3 squares even if the next number is close', () {
    final p = PathPuzzle(3, [0, 1, 2, 5, 4, 3, 6, 7, 8], [0, 1, 8]);
    final g = Game(p, mode: GameMode.level);
    g.applyHint();
    expect(g.path.length, greaterThanOrEqualTo(1 + Game.minHintCells));
  });

  test('save / restore keeps the line; a broken save keeps only the valid part', () {
    final g = newGame();
    for (final c in [1, 2, 5]) {
      g.step(c);
    }
    final snap = g.snapshot();
    final g2 = newGame()..restore(snap);
    expect(g2.path, [0, 1, 2, 5]);
    expect(g2.eventSeq, 0, reason: 'no stray message after restoring');
    final g3 = newGame()
      ..restore({
        'n': 3,
        'path': [0, 1, 7, 8],
        'secs': 3,
      });
    expect(g3.path, [0, 1]);
    final g4 = newGame()
      ..restore({
        'n': 4,
        'path': [0, 1],
        'secs': 3,
      });
    expect(g4.path, [0], reason: 'wrong board size is ignored');
  });
}
