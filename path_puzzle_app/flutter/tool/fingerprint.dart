// ignore_for_file: avoid_print
import 'package:path_puzzle/core/puzzle.dart';

void main() {
  final a = PathPuzzle.daily('20261002');
  final b = PathPuzzle.level(30);
  print('${a.n}:${a.clues.join(',')}');
  print('${b.n}:${b.clues.join(',')}');
}
