// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 누르고, 판 위에서 손가락으로 줄을 그어 본다.
// 막힌 길(버튼이 안 먹음)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)·
// 잘린 글자·화면 밖 버튼·다른 것에 덮인 버튼을 잡는다.
// 실행: flutter test test/robot_test.dart  → 누른 버튼 목록이 로그로, 화면 사진이 build/robot_shots/ 에 남는다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_puzzle/core/ads.dart';
import 'package:path_puzzle/core/puzzle.dart';
import 'package:path_puzzle/core/store.dart';
import 'package:path_puzzle/game/game.dart';
import 'package:path_puzzle/main.dart';
import 'package:path_puzzle/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pressed = <String>[];
final shots = <String>[];

/// 실제 기기 크기 (논리 픽셀 × 배율)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0),
};

var _fontsLoaded = false;

/// 테스트 기본 글꼴(Ahem)은 모든 글자가 정사각형이라 잘림 검사가 틀린다 → SDK 의 Roboto 를 넣는다 (속도계·대출 세션 노하우).
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final file = File('$root/$f');
      if (!file.existsSync()) {
        // ignore: avoid_print
        print('WARNING: font not found $root/$f');
        return;
      }
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await family('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> boot(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double ratio = 3,
  Map<String, Object> prefs = const {},
  FakeAds? ads,
  double textScale = 1,
}) async {
  await t.runAsync(loadFonts);
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues(prefs);
  Ads.i = ads ?? FakeAds();
  await AppStore.i.load();
  AppStore.i.clock = () => DateTime(2026, 10, 2, 9);
  await t.pumpWidget(const PathPuzzleApp());
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 600));
}

/// 버튼이 화면 안에 있고 다른 것에 덮이지 않았는지 확인한 뒤 누른다.
Future<void> press(WidgetTester t, Finder f, String label) async {
  expect(f, findsOneWidget, reason: 'button not found: $label');
  final center = t.getCenter(f);
  final screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  expect(
    screen.contains(center),
    isTrue,
    reason: 'off screen: $label at $center',
  );
  final ro = t.renderObject(f);
  final hit = t.hitTestOnBinding(center);
  expect(
    hit.path.any((e) => identical(e.target, ro)),
    isTrue,
    reason: 'covered / not tappable: $label',
  );
  await t.tap(f);
  pressed.add(label);
  await t.pump();
  await t.pump(const Duration(milliseconds: 450));
  await t.pump(const Duration(milliseconds: 450));
  expectNoTruncatedText(t, 'after $label');
}

/// 화면 글자가 '…' 이나 줄 수 제한으로 잘리지 않았는지.
void expectNoTruncatedText(WidgetTester t, String where) {
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is RenderParagraph && ro.attached) {
      expect(
        ro.didExceedMaxLines,
        isFalse,
        reason: 'truncated text $where: "${ro.text.toPlainText()}"',
      );
    }
  }
}

Future<void> shot(WidgetTester t, String name) async {
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final ratio = t.view.devicePixelRatio;
  await t.runAsync(() async {
    // 루트 레이어는 이미 기기 배율로 키워져 있다 → 물리 픽셀 영역을 찍고, 3배 기기는 2배로 줄여 저장
    final img = await layer.toImage(
      Offset.zero & t.view.physicalSize,
      pixelRatio: ratio > 2 ? 2 / ratio : 1,
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/robot_shots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  shots.add(name);
}

Game gameOf(WidgetTester t) {
  final st = t.state(find.byType(GameScreen)) as dynamic;
  return st.game as Game;
}

Offset cellCenter(WidgetTester t, int cell) {
  final g = gameOf(t);
  final rect = t.getRect(find.byKey(const Key('board')));
  final cs = rect.width / g.n;
  return rect.topLeft +
      Offset((cell % g.n + 0.5) * cs, (cell ~/ g.n + 0.5) * cs);
}

/// 손가락으로 칸들을 차례로 지나며 긋는다 (칸 가운데를 잇는 직선 움직임).
Future<void> draw(
  WidgetTester t,
  List<int> cells, {
  String? label,
  int pointer = 1,
}) async {
  final gesture = await t.startGesture(
    cellCenter(t, cells.first),
    kind: PointerDeviceKind.touch,
    pointer: pointer,
  );
  await t.pump(const Duration(milliseconds: 16));
  for (final c in cells.skip(1)) {
    await gesture.moveTo(cellCenter(t, c));
    await t.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  pressed.add(label ?? 'draw ${cells.length} squares');
  await t.pump(const Duration(milliseconds: 50));
}

/// 지금 줄 끝에서 정답대로 끝까지 긋는다 (줄이 정답 앞부분이어야 한다).
Future<void> drawRest(WidgetTester t) async {
  final g = gameOf(t);
  expect(g.correctPrefix, g.path.length, reason: 'line must be on the answer');
  await draw(
    t,
    g.puzzle.path.sublist(g.path.length - 1),
    label: 'draw to the end',
  );
  // 결과 패널은 0.9초 뒤에 뜨고, 그 뒤 0.45초는 버튼이 잠겨 있다
  await t.pump(const Duration(milliseconds: 1000));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      'ROBOT pressed ${pressed.length} buttons/strokes:\n'
      '${pressed.toSet().join(', ')}\n'
      'screenshots (${shots.length}): ${shots.join(', ')}',
    );
  });

  testWidgets('first launch shows how-to, then every home button works', (
    t,
  ) async {
    await boot(t);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.byKey(const Key('howto-demo')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await shot(t, '01-howto');
    await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
    expect(find.text('How to play'), findsNothing);
    expect(find.text('Today’s Puzzle'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    await shot(t, '02-home');
    await press(t, find.byKey(const Key('howto')), 'Home: How to play');
    expect(find.text('How to play'), findsOneWidget);
    await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
    // 두 번째 실행에는 안 뜬다
    await finish(t);
    await t.pumpWidget(const PathPuzzleApp());
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('How to play'), findsNothing);
    await finish(t);
  });

  testWidgets(
    'daily: draw, wrong number is blocked, slide back, undo, clear, hint, win, streak',
    (t) async {
      final ads = FakeAds();
      await boot(t, prefs: {'seenHowTo': true}, ads: ads);
      await press(t, find.text('Play'), 'Home: Today Play');
      expect(find.text('Today · Oct 2'), findsOneWidget);
      final g = gameOf(t);
      expect(g.n, PathPuzzle.dailySize);
      expect(g.path, [g.puzzle.clues.first]);
      expect(find.textContaining('Next: 2'), findsOneWidget);
      await shot(t, '03-daily-start');

      // 정답대로 6칸
      final sol = g.puzzle.path;
      await draw(t, sol.sublist(0, 7), label: 'draw 6 squares');
      expect(g.path, sol.sublist(0, 7));
      // 되돌아 2칸 → 지워진다
      await draw(t, [sol[6], sol[5], sol[4]], label: 'slide back 2');
      expect(g.path, sol.sublist(0, 5));

      // 순서가 아닌 숫자로 들어가기 → 막히고 이유가 보인다
      final next = g.nextNumber;
      int? wrongTarget;
      for (final c in PathPuzzle.neighbors(g.n)[g.head]) {
        final num = g.puzzle.numberAt[c];
        if (num > next) wrongTarget = c;
      }
      if (wrongTarget == null) {
        // 줄 끝 옆에 큰 숫자가 없으면, 큰 숫자 옆까지 정답을 따라가 본다
        for (
          var i = g.path.length;
          i < sol.length - 1 && wrongTarget == null;
          i++
        ) {
          await draw(t, [g.head, sol[i]]);
          for (final c in PathPuzzle.neighbors(g.n)[g.head]) {
            if (g.puzzle.numberAt[c] > g.nextNumber && !g.isOnPath(c)) {
              wrongTarget = c;
            }
          }
        }
      }
      expect(wrongTarget, isNotNull);
      final before = List<int>.of(g.path);
      await draw(t, [g.head, wrongTarget!], label: 'draw into a wrong number');
      expect(g.path, before, reason: 'wrong number must block');
      await t.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('first — numbers go in order'),
        findsOneWidget,
      );
      await shot(t, '04-wrong-number');
      await t.pump(const Duration(seconds: 3));

      // 줄 끝이 아닌 먼 빈칸에서 시작하면 아무것도 안 그어지고 알려 준다
      final far = sol.last;
      await draw(t, [far], label: 'touch a far square');
      expect(g.path, before);
      expect(find.textContaining('end of your line'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));

      await press(t, find.byKey(const Key('undo')), 'Undo');
      expect(g.path.length, before.length - 1);
      await press(t, find.byKey(const Key('clear')), 'Clear');
      expect(g.path.length, 1);

      // 틀린 길로 가 놓고 힌트: 취소 → 보기
      // 정답을 따라가다가 빈칸 쪽으로 엇나갈 수 있는 첫 자리에서 엇나간다
      int? wrongTurn;
      for (var k = 1; k < sol.length && wrongTurn == null; k++) {
        for (final c in PathPuzzle.neighbors(g.n)[g.head]) {
          if (c != sol[k] && !g.isOnPath(c) && g.puzzle.numberAt[c] == 0) {
            wrongTurn = c;
            break;
          }
        }
        if (wrongTurn == null) await draw(t, [g.head, sol[k]]);
      }
      await draw(t, [g.head, wrongTurn!], label: 'wrong turn');
      expect(g.correctPrefix, lessThan(g.path.length));
      await press(t, find.byKey(const Key('hint')), 'Hint');
      expect(find.text('Need a hint?'), findsOneWidget);
      await shot(t, '05-hint-dialog');
      await press(t, find.text('Not now'), 'Hint dialog: Not now');
      expect(ads.rewardedShown, 0);
      await press(t, find.byKey(const Key('hint')), 'Hint');
      await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
      expect(ads.rewardedShown, 1);
      expect(g.hintsUsed, 1);
      expect(g.correctPrefix, g.path.length, reason: 'hint fixes the line');
      expect(g.path.length, greaterThanOrEqualTo(1 + Game.minHintCells));
      expect(find.textContaining('Fixed your line'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      await shot(t, '06-after-hint');
      await t.pump(const Duration(seconds: 3));

      await drawRest(t);
      expect(g.status, GameStatus.won);
      expect(find.text('🎉 Solved!'), findsOneWidget);
      expect(find.text('🔥 1-day streak'), findsOneWidget);
      await shot(t, '07-daily-solved');
      await press(t, find.byKey(const Key('home')), 'Won: Home');
      expect(find.textContaining('✅ Solved in'), findsOneWidget);
      expect(find.byKey(const Key('streak')), findsOneWidget);

      // 다시 하면 연습
      await press(t, find.text('Play again'), 'Home: Today Play again');
      expect(find.text('Today · practice'), findsOneWidget);
      await drawRest(t);
      expect(find.textContaining('Practice run'), findsOneWidget);
      await press(t, find.byKey(const Key('to-levels')), 'Won: Play Levels');
      expect(find.text('Level 1'), findsOneWidget);
      expect(gameOf(t).n, 5);
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      expect(find.text('Today’s Puzzle'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets(
    'levels: win → next → back keeps progress and the half-drawn line',
    (t) async {
      await boot(t, prefs: {'seenHowTo': true});
      await press(t, find.text('Start'), 'Home: Level Start');
      var g = gameOf(t);
      expect(g.n, 5);
      await drawRest(t);
      expect(find.text('🎉 Level 1 cleared!'), findsOneWidget);
      expect(AppStore.i.level, 2);
      await press(t, find.byKey(const Key('next')), 'Won: Next Level');
      expect(find.text('Level 2'), findsOneWidget);
      g = gameOf(t);
      await draw(t, g.puzzle.path.sublist(0, 6));
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      expect(find.text('Level 2'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await press(t, find.text('Continue'), 'Home: Level Continue');
      g = gameOf(t);
      expect(g.path, g.puzzle.path.sublist(0, 6), reason: 'line kept');
      await drawRest(t);
      await press(t, find.byKey(const Key('home')), 'Won: Home');
      expect(find.text('Level 3'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('a fast swipe that skips squares still fills them in order', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    final sol = g.puzzle.path;
    // 정답에서 같은 방향으로 곧게 3칸 이상 가는 구간을 찾아 한 번에 휙 긋는다
    var i = 0;
    var run = 0;
    for (var k = 1; k + 2 < sol.length; k++) {
      final d1 = sol[k] - sol[k - 1], d2 = sol[k + 1] - sol[k];
      final d3 = sol[k + 2] - sol[k + 1];
      if (d1 == d2 && d2 == d3) {
        i = k - 1;
        run = 3;
        break;
      }
    }
    expect(run, 3, reason: 'answer has a straight run of 3 moves');
    await draw(t, sol.sublist(0, i + 1));
    final gesture = await t.startGesture(cellCenter(t, sol[i]));
    await t.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(cellCenter(t, sol[i + 3])); // 한 이벤트에 3칸
    await t.pump(const Duration(milliseconds: 16));
    await gesture.up();
    pressed.add('fast swipe 3 squares');
    expect(g.path, sol.sublist(0, i + 4));
    await finish(t);
  });

  testWidgets('a second finger does not draw', (t) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    final sol = g.puzzle.path;
    final one = await t.startGesture(cellCenter(t, sol[0]), pointer: 1);
    await one.moveTo(cellCenter(t, sol[1]));
    await t.pump(const Duration(milliseconds: 16));
    final two = await t.startGesture(cellCenter(t, sol[2]), pointer: 2);
    await two.moveTo(cellCenter(t, sol[3]));
    await t.pump(const Duration(milliseconds: 16));
    await two.up();
    await one.up();
    pressed.add('two-finger touch');
    expect(g.path, sol.sublist(0, 2));
    await finish(t);
  });

  testWidgets(
    'no video yet → "Loading video…" → tells the user, line unchanged',
    (t) async {
      final ads = FakeAds(
        result: RewardResult.unavailable,
        ready: false,
        delay: const Duration(seconds: 3),
      );
      await boot(t, prefs: {'seenHowTo': true}, ads: ads);
      await press(t, find.text('Play'), 'Home: Today Play');
      await press(t, find.byKey(const Key('hint')), 'Hint');
      await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
      expect(find.text('Loading video…'), findsOneWidget);
      await shot(t, '08-loading-video');
      await t.pump(const Duration(seconds: 3));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading video…'), findsNothing);
      expect(
        find.textContaining('No video available right now'),
        findsOneWidget,
      );
      expect(ads.shown, [RewardPlacement.hint]);
      expect(gameOf(t).path.length, 1);
      expect(gameOf(t).hintsUsed, 0);
      await finish(t);
    },
  );

  testWidgets('closing the video early gives no hint and says why', (t) async {
    final ads = FakeAds(result: RewardResult.closedEarly);
    await boot(t, prefs: {'seenHowTo': true}, ads: ads);
    await press(t, find.text('Start'), 'Home: Level Start');
    await press(t, find.byKey(const Key('hint')), 'Hint');
    await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
    expect(gameOf(t).hintsUsed, 0);
    expect(find.textContaining('Watch the whole video'), findsOneWidget);
    // 끝까지 보면 힌트
    ads.result = RewardResult.rewarded;
    await t.pump(const Duration(seconds: 5));
    await press(t, find.byKey(const Key('hint')), 'Hint');
    await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
    expect(gameOf(t).hintsUsed, 1);
    await finish(t);
  });

  testWidgets(
    'double taps: one dialog, one video, no stray line under the dialog',
    (t) async {
      final ads = FakeAds(delay: const Duration(seconds: 1));
      await boot(t, prefs: {'seenHowTo': true}, ads: ads);
      await press(t, find.text('Play'), 'Home: Today Play');
      final g = gameOf(t);
      // 힌트 두 번 → 창은 그대로 하나
      final h = t.getCenter(find.byKey(const Key('hint')));
      await t.tapAt(h);
      await t.pump(const Duration(milliseconds: 60));
      await t.tapAt(h);
      pressed.add('Hint (double tap)');
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Need a hint?'), findsOneWidget);
      // Not now 두 번 → 두 번째 탭이 판에 떨어져도 줄이 생기지 않는다
      final btn = t.getCenter(find.text('Not now'));
      await t.tapAt(btn);
      await t.pump(const Duration(milliseconds: 80));
      await t.tapAt(btn);
      pressed.add('Hint dialog: Not now (double tap)');
      await t.pump(const Duration(milliseconds: 600));
      expect(g.path.length, 1);
      // Watch video 두 번 → 영상 1번
      await press(t, find.byKey(const Key('hint')), 'Hint');
      final watch = t.getCenter(find.text('▶ Watch video'));
      await t.tapAt(watch);
      await t.pump(const Duration(milliseconds: 50));
      await t.tapAt(watch);
      pressed.add('Hint dialog: Watch video (double tap)');
      await t.pump(const Duration(seconds: 2));
      expect(ads.rewardedShown, 1);
      expect(g.hintsUsed, 1);
      await finish(t);
    },
  );

  testWidgets('double-tapping Next Level does not skip a level', (t) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    // 마지막 칸을 그은 손가락이 바로 뜬 패널 버튼을 누르면 무시된다
    final g0 = gameOf(t);
    await draw(t, g0.puzzle.path, label: 'draw whole line');
    await t.pump(const Duration(milliseconds: 950));
    expect(find.byKey(const Key('next')), findsOneWidget);
    await t.tap(find.byKey(const Key('next')), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.text('🎉 Level 1 cleared!'),
      findsOneWidget,
      reason: 'panel ignores taps for 0.45s',
    );
    await t.pump(const Duration(milliseconds: 500));
    final next = t.getCenter(find.byKey(const Key('next')));
    await t.tapAt(next);
    await t.pump(const Duration(milliseconds: 40));
    await t.tapAt(next);
    await t.pump(const Duration(milliseconds: 40));
    await t.tapAt(next);
    pressed.add('Won: Next Level (triple tap)');
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Level 2'), findsOneWidget, reason: 'no level skipped');
    expect(gameOf(t).path.length, 1, reason: 'no stray line from extra taps');
    // 패널이 떠 있을 때 뒤의 버튼은 눌리지 않는다
    await drawRest(t);
    await t.tap(find.byKey(const Key('clear')), warnIfMissed: false);
    await t.pump();
    expect(gameOf(t).status, GameStatus.won);
    expect(gameOf(t).path.length, gameOf(t).puzzle.cells);
    await finish(t);
  });

  testWidgets('daily: Back keeps the line and the clock keeps counting', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true, 'dailyCarry_20261002': 75});
    expect(find.textContaining('1:15 so far'), findsOneWidget);
    await press(t, find.text('Play'), 'Home: Today Play');
    var g = gameOf(t);
    expect(g.seconds, greaterThanOrEqualTo(75));
    expect(find.text('1:15'), findsOneWidget);
    await draw(t, g.puzzle.path.sublist(0, 5));
    await press(t, find.byKey(const Key('back')), 'Game: Back');
    await press(t, find.text('Play'), 'Home: Today Play');
    g = gameOf(t);
    expect(g.path, g.puzzle.path.sublist(0, 5));
    expect(g.seconds, greaterThanOrEqualTo(75));
    await finish(t);
  });

  testWidgets('a corrupted save never traps the player on a grey screen', (
    t,
  ) async {
    // 캣도쿠 점검 3차: 깨진 저장 한 줄로 회색 화면에 갇혔다 → 같은 일을 일부러 만들어 본다
    for (final bad in [
      '{"n":6,"path":"oops","secs":"x","hints":"y"}',
      '{"n":6,"path":[1,2,"z"],"secs":5}',
      'not json at all',
      '{"n":"6","path":null}',
    ]) {
      await boot(
        t,
        prefs: {
          'seenHowTo': true,
          'board_daily_20261002': bad,
          'level': 2,
          'board_level_2': bad,
        },
      );
      await press(t, find.text('Play'), 'Home: Today Play (corrupted save)');
      expect(gameOf(t).path.length, 1, reason: 'fresh line for $bad');
      expect(find.byKey(const Key('board')), findsOneWidget);
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      await press(
        t,
        find.text('Continue'),
        'Home: Level Continue (corrupted save)',
      );
      expect(gameOf(t).path.length, 1);
      await finish(t);
    }
  });

  testWidgets('home rolls over to the new day while open', (t) async {
    await boot(
      t,
      prefs: {
        'seenHowTo': true,
        'dailySolved_20261002': 40,
        'streak': 1,
        'streakDay': '20261002',
      },
    );
    expect(find.textContaining('Solved in 0:40'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    AppStore.i.clock = () => DateTime(2026, 10, 3, 0, 1);
    await t.pump(const Duration(seconds: 21));
    expect(find.textContaining('Solved in'), findsNothing);
    expect(find.text('Play'), findsOneWidget);
    expect(find.textContaining('Sat, Oct 3'), findsOneWidget);
    await finish(t);
  });

  for (final e in devices.entries) {
    testWidgets('layout on ${e.key}: every screen, 8x8 board, panel', (
      t,
    ) async {
      final (size, ratio) = e.value;
      final tag = e.key.split(' (').first.replaceAll(' ', '-');
      await boot(t, size: size, ratio: ratio, prefs: {'level': 30});
      expect(find.text('How to play'), findsOneWidget);
      expectNoTruncatedText(t, 'how-to');
      await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
      await press(t, find.text('Continue'), 'Home: Level Continue');
      final g = gameOf(t);
      expect(g.n, 8);
      final rect = t.getRect(find.byKey(const Key('board')));
      final cell = rect.width / 8;
      // 손가락으로 그을 수 있는 크기 (Apple 권장 44pt 에 가깝게, 최소 40pt)
      expect(
        cell,
        greaterThanOrEqualTo(40),
        reason: 'cell ${cell.toStringAsFixed(1)}pt',
      );
      for (final k in ['board', 'undo', 'clear', 'hint', 'back', 'timer']) {
        final r = t.getRect(find.byKey(Key(k)));
        expect(
          r.bottom <= size.height && r.top >= 0 && r.right <= size.width + 0.5,
          isTrue,
          reason: '$k off screen: $r',
        );
      }
      await draw(t, g.puzzle.path.sublist(0, 20));
      await shot(t, '09-level30-8x8-$tag');
      await drawRest(t);
      expect(find.byKey(const Key('panel')), findsOneWidget);
      expect(
        t.getRect(find.byKey(const Key('panel'))).bottom <= size.height,
        isTrue,
      );
      expectNoTruncatedText(t, 'win panel');
      await shot(t, '10-level-cleared-$tag');
      await press(t, find.byKey(const Key('home')), 'Won: Home');
      await press(t, find.text('Play'), 'Home: Today Play');
      await draw(t, gameOf(t).puzzle.path.sublist(0, 4));
      expectNoTruncatedText(t, 'daily');
      // 화면 문구에 한글이 섞이지 않았는지 (미국 대상)
      final ko = RegExp(r'[가-힣]');
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        expect(ko.hasMatch(w.data ?? ''), isFalse, reason: 'Korean: ${w.data}');
      }
      await finish(t);
    });
  }

  testWidgets('large text (135%) on iPhone SE: nothing cut off or covered', (
    t,
  ) async {
    await boot(
      t,
      size: const Size(375, 667),
      ratio: 2,
      prefs: {'level': 30},
      textScale: 1.35,
    );
    expectNoTruncatedText(t, 'how-to 135%');
    await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it (135%)');
    await shot(t, '11-home-SE-135');
    await press(t, find.text('Continue'), 'Home: Level Continue (135%)');
    await press(t, find.byKey(const Key('hint')), 'Hint (135%)');
    await press(t, find.text('Not now'), 'Hint dialog: Not now (135%)');
    await drawRest(t);
    expectNoTruncatedText(t, 'win panel 135%');
    await shot(t, '12-cleared-SE-135');
    await press(t, find.byKey(const Key('next')), 'Won: Next Level (135%)');
    await finish(t);
  });
}
