// ignore_for_file: avoid_print
// 판 하나를 글자로 그려 본다: dart run tool/show.dart 6 seed   (오늘의 퍼즐: dart run tool/show.dart 6 20261002 daily)
import 'package:path_puzzle/core/puzzle.dart';

void main(List<String> a) {
  final n = int.parse(a[0]);
  final p = a.length > 2 && a[2] == 'daily'
      ? PathPuzzle.daily(a[1])
      : PathPuzzle.generate(n, Rng.seedOf(a[1]));
  final pos = List.filled(p.n * p.n, 0);
  for (var i = 0; i < p.path.length; i++) {
    pos[p.path[i]] = i;
  }
  for (var r = 0; r < p.n; r++) {
    final nums = [
      for (var c = 0; c < p.n; c++)
        p.numberAt[r * p.n + c] == 0
            ? ' .'
            : p.numberAt[r * p.n + c].toString().padLeft(2),
    ].join(' ');
    final order = [
      for (var c = 0; c < p.n; c++) pos[r * p.n + c].toString().padLeft(2),
    ].join(' ');
    print('$nums     $order');
  }
  print('clues ${p.clues.length}');
}
