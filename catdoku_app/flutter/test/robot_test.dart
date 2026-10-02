// 테스트 로봇 — 모든 화면의 모든 버튼을 실제로 눌러 본다.
// 막힌 길(버튼이 안 먹음)·뒤로가기 불가·깨진 레이아웃(overflow 는 Flutter 가 예외로 던져 테스트 실패)을 잡는다.
// 실행: flutter test test/robot_test.dart  → 누른 버튼 목록이 로그로 찍힌다.
import 'package:catdoku/core/ads.dart';
import 'package:catdoku/core/puzzle.dart';
import 'package:catdoku/core/store.dart';
import 'package:catdoku/game/game.dart';
import 'package:catdoku/main.dart';
import 'package:catdoku/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pressed = <String>[];

/// 실제 기기 크기 (논리 픽셀 × 배율)
const devices = {
  'iPhone 13 (1170x2532)': (Size(390, 844), 3.0),
  'iPhone SE (750x1334)': (Size(375, 667), 2.0),
  'iPhone 15 Pro Max (1290x2796)': (Size(430, 932), 3.0),
};

Future<void> boot(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double ratio = 3,
  Map<String, Object> prefs = const {},
  FakeAds? ads,
}) async {
  t.view.physicalSize = size * ratio;
  t.view.devicePixelRatio = ratio;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  Ads.i = ads ?? FakeAds();
  await AppStore.i.load();
  AppStore.i.clock = () => DateTime(2026, 10, 2, 9);
  await t.pumpWidget(const CatdokuApp());
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> press(WidgetTester t, Finder f, String label) async {
  expect(f, findsOneWidget, reason: 'button not found: $label');
  await t.tap(f);
  pressed.add(label);
  await t.pump();
  await t.pump(const Duration(milliseconds: 450));
  await t.pump(const Duration(milliseconds: 450));
}

Game gameOf(WidgetTester t) {
  final st = t.state(find.byType(GameScreen)) as dynamic;
  return st.game as Game;
}

Future<void> tapCell(WidgetTester t, int r, int c, {String? label}) async {
  final g = gameOf(t);
  final rect = t.getRect(find.byKey(const Key('board')));
  final cs = rect.width / g.n;
  await t.tapAt(rect.topLeft + Offset((c + 0.5) * cs, (r + 0.5) * cs));
  pressed.add(label ?? 'cell($r,$c)');
  await t.pump(const Duration(milliseconds: 50));
  // 반칙 뒤에는 판이 0.7초 잠긴다 — 로봇은 사람처럼 잠깐 기다린다
  await t.pump(const Duration(milliseconds: 700));
}

/// 정답이 아니고 놓인 고양이와 부딪히는 칸 하나.
(int, int) conflictCell(Game g) {
  for (var r = 0; r < g.n; r++) {
    for (var c = 0; c < g.n; c++) {
      if (g.cells[r][c] == Mark.cat) continue;
      if (g.conflictsWith(r, c).isNotEmpty) return (r, c);
    }
  }
  throw StateError('no conflict cell');
}

Future<void> solveRest(WidgetTester t) async {
  final g = gameOf(t);
  if (g.brush != Brush.cat) {
    await press(t, find.byKey(const Key('brush-cat')), 'Cat brush');
  }
  for (var r = 0; r < g.n; r++) {
    final c = g.puzzle.solution[r];
    if (g.cells[r][c] != Mark.cat) await tapCell(t, r, c);
  }
  // 승리 패널은 0.9초 뒤에 뜬다
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print(
      'ROBOT pressed ${pressed.length} buttons/cells:\n'
      '${pressed.where((p) => !p.startsWith('cell')).toSet().join(', ')}',
    );
  });

  testWidgets('first launch shows how-to, then every home button works', (
    t,
  ) async {
    await boot(t);
    expect(find.text('How to play'), findsOneWidget);
    await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
    expect(find.text('How to play'), findsNothing);
    expect(find.text('Today’s Puzzle'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    await press(t, find.byKey(const Key('howto')), 'Home: How to play');
    expect(find.text('How to play'), findsOneWidget);
    await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
    // 두 번째 실행에는 안 뜬다
    await finish(t);
    await t.pumpWidget(const CatdokuApp());
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('How to play'), findsNothing);
    await finish(t);
  });

  testWidgets(
    'daily: mark/clear never costs a heart, mistakes, hint, continue, win, streak',
    (t) async {
      final ads = FakeAds();
      await boot(t, prefs: {'seenHowTo': true}, ads: ads);
      await press(t, find.text('Play'), 'Home: Today Play');
      expect(find.text('Today · Oct 2'), findsOneWidget);
      var g = gameOf(t);
      expect(g.n, 7);
      expect(g.hearts, 3);

      // ✕ 붓: 찍고 다시 눌러 지워도 하트는 그대로 (웹판 문제 재발 방지)
      await press(t, find.byKey(const Key('brush-mark')), 'Mark brush');
      final s0 = g.puzzle.solution[0];
      final wrong = (0 + 3, s0); // 같은 열 — 고양이였다면 반칙
      await tapCell(t, wrong.$1, wrong.$2);
      expect(g.cells[wrong.$1][wrong.$2], Mark.cross);
      await tapCell(t, wrong.$1, wrong.$2);
      expect(g.cells[wrong.$1][wrong.$2], Mark.empty);
      expect(g.hearts, 3, reason: 'clearing a mark must not cost a heart');

      // ✕ 붓으로 한 줄 끌기
      final rect = t.getRect(find.byKey(const Key('board')));
      final cs = rect.width / g.n;
      final gesture = await t.startGesture(
        rect.topLeft + Offset(cs * 0.5, cs * 6.5),
      );
      for (var c = 1; c < 7; c++) {
        await gesture.moveTo(rect.topLeft + Offset(cs * (c + 0.5), cs * 6.5));
        await t.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      pressed.add('drag-mark row');
      expect(
        [for (var c = 0; c < 7; c++) g.cells[6][c]]
            .every((m) => m == Mark.cross),
        isTrue,
      );
      // 고양이 붓으로 ✕ 칸을 누르면 고양이 시도 — 정답 칸이면 그대로 놓인다
      await press(t, find.byKey(const Key('brush-cat')), 'Cat brush');
      await tapCell(t, 6, g.puzzle.solution[6]);
      expect(g.cells[6][g.puzzle.solution[6]], Mark.cat);
      // 고양이를 다시 누르면 치워진다
      await tapCell(t, 6, g.puzzle.solution[6]);
      expect(g.cats, 0);

      // 정답 고양이 1마리 + 반칙 1번
      await tapCell(t, 0, s0);
      expect(g.cats, 1);
      expect(find.text('🐱 1 of 7 cats placed'), findsOneWidget);
      var bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      expect(g.hearts, 2);
      expect(g.cells[bad.$1][bad.$2], isNot(Mark.cat));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('💔'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));

      // 힌트: 취소 → 보기
      await press(t, find.byKey(const Key('hint')), 'Hint');
      expect(find.text('Need a hint?'), findsOneWidget);
      await press(t, find.text('Not now'), 'Hint dialog: Not now');
      expect(ads.rewardedShown, 0);
      await press(t, find.byKey(const Key('hint')), 'Hint');
      await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
      expect(ads.rewardedShown, 1);
      expect(g.cats, 2);
      expect(g.hintsUsed, 1);

      // 하트를 다 잃는다 → 영상 보고 계속
      while (g.status == GameStatus.playing) {
        bad = conflictCell(g);
        await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      }
      await t.pump(const Duration(milliseconds: 1300));
      expect(find.text('💔 Out of hearts!'), findsOneWidget);
      await press(t, find.byKey(const Key('continue')), 'Lost: Watch video +3');
      expect(g.status, GameStatus.playing);
      expect(g.hearts, 3);
      expect(g.cats, 2, reason: 'continue keeps the board');

      await solveRest(t);
      expect(g.status, GameStatus.won);
      expect(find.text('🎉 Solved!'), findsOneWidget);
      expect(find.text('🔥 1-day streak'), findsOneWidget);
      expect(AppStore.i.solvedTime('20261002'), greaterThanOrEqualTo(0));
      await press(t, find.byKey(const Key('home')), 'Won: Home');
      expect(find.textContaining('✅ Solved in'), findsOneWidget);
      expect(find.byKey(const Key('streak')), findsOneWidget);

      // 다시 하면 연습
      await press(t, find.text('Play again'), 'Home: Today Play again');
      expect(find.text('Today · practice'), findsOneWidget);
      await solveRest(t);
      expect(find.textContaining('Practice run'), findsOneWidget);
      await press(t, find.byKey(const Key('to-levels')), 'Won: Play Levels');
      expect(find.text('Level 1'), findsOneWidget);
      g = gameOf(t);
      expect(g.n, 5);
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      expect(find.text('Today’s Puzzle'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('levels: lose → start over → win → next → back keeps progress', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    var g = gameOf(t);
    expect(g.n, 5);
    await tapCell(t, 0, g.puzzle.solution[0]);
    while (g.status == GameStatus.playing) {
      final bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
    }
    await t.pump(const Duration(milliseconds: 1300));
    await press(t, find.byKey(const Key('restart')), 'Lost: Start over');
    g = gameOf(t);
    expect(g.hearts, 3);
    expect(g.cats, 0);
    await solveRest(t);
    expect(find.text('🎉 Level 1 cleared!'), findsOneWidget);
    expect(AppStore.i.level, 2);
    await press(t, find.byKey(const Key('next')), 'Won: Next Level');
    expect(find.text('Level 2'), findsOneWidget);
    await press(t, find.byKey(const Key('back')), 'Game: Back');
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await press(t, find.text('Continue'), 'Home: Level Continue');
    // 진 뒤 Home 버튼
    g = gameOf(t);
    await tapCell(t, 0, g.puzzle.solution[0]);
    while (g.status == GameStatus.playing) {
      final bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
    }
    await t.pump(const Duration(milliseconds: 1300));
    await press(t, find.byKey(const Key('home')), 'Lost: Home');
    expect(find.text('Today’s Puzzle'), findsOneWidget);
    await finish(t);
  });

  testWidgets('hint removes a wrongly placed cat and says so', (t) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Play'), 'Home: Today Play');
    final g = gameOf(t);
    // 규칙엔 안 걸리지만 정답이 아닌 자리
    (int, int)? wrong;
    for (var r = 0; r < g.n && wrong == null; r++) {
      for (var c = 0; c < g.n; c++) {
        if (!g.puzzle.isSolutionCell(r, c)) {
          wrong = (r, c);
          break;
        }
      }
    }
    await tapCell(t, wrong!.$1, wrong.$2);
    expect(g.cats, 1);
    await press(t, find.byKey(const Key('hint')), 'Hint');
    await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
    // 잘못 놓인 고양이는 치우고, 맞는 자리에 하나 놓는다 (영상 보고 손해 보는 일 없게)
    expect(g.cats, 1);
    expect(g.cells[wrong.$1][wrong.$2], isNot(Mark.cat));
    expect(g.lastHint, isNotNull);
    expect(g.puzzle.isSolutionCell(g.lastHint!.$1, g.lastHint!.$2), isTrue);
    expect(find.text('💡 Cleared 1 wrong cat + 1 right cat!'), findsOneWidget);
    await finish(t);
  });

  testWidgets('no video yet → "Loading video…" → free hint, game continues', (
    t,
  ) async {
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
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Loading video…'), findsNothing);
    // 영상이 없으면 막히지 않게 그냥 준다
    expect(find.textContaining('this one’s on us'), findsOneWidget);
    expect(ads.shown, [RewardPlacement.hint]);
    expect(gameOf(t).cats, 1);
    expect(gameOf(t).status, GameStatus.playing);
    await finish(t);
  });

  testWidgets('closing the video early gives no reward and says why', (
    t,
  ) async {
    final ads = FakeAds(result: RewardResult.closedEarly);
    await boot(t, prefs: {'seenHowTo': true}, ads: ads);
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    await tapCell(t, 0, g.puzzle.solution[0]);
    while (g.status == GameStatus.playing) {
      final bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
    }
    await t.pump(const Duration(milliseconds: 1300));
    await press(t, find.byKey(const Key('continue')), 'Lost: Watch video +3');
    expect(ads.shown, [RewardPlacement.continueGame]);
    expect(
      g.status,
      GameStatus.lost,
      reason: 'no reward → still out of hearts',
    );
    expect(find.textContaining('Watch the whole video'), findsOneWidget);
    expect(find.text('💔 Out of hearts!'), findsOneWidget);
    // 다시 보고 끝까지 보면 이어진다
    ads.result = RewardResult.rewarded;
    await press(t, find.byKey(const Key('continue')), 'Lost: Watch video +3');
    expect(g.status, GameStatus.playing);
    expect(g.hearts, 3);
    await finish(t);
  });

  testWidgets('double-tapping a video button shows only one video', (t) async {
    final ads = FakeAds(delay: const Duration(seconds: 1));
    await boot(t, prefs: {'seenHowTo': true}, ads: ads);
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    await tapCell(t, 0, g.puzzle.solution[0]);
    while (g.status == GameStatus.playing) {
      final bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
    }
    await t.pump(const Duration(milliseconds: 1300));
    await t.tap(find.byKey(const Key('continue')));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const Key('continue')), warnIfMissed: false);
    pressed.add('Lost: Watch video +3 (double tap)');
    await t.pump(const Duration(seconds: 2));
    expect(ads.rewardedShown, 1);
    expect(g.hearts, 3);
    await finish(t);
  });

  testWidgets(
    'Back keeps the board; leaving while out of hearts does not refill them',
    (t) async {
      await boot(t, prefs: {'seenHowTo': true});
      await press(t, find.text('Play'), 'Home: Today Play');
      var g = gameOf(t);
      final s0 = g.puzzle.solution[0];
      await tapCell(t, 0, s0);
      await press(t, find.byKey(const Key('brush-mark')), 'Mark brush');
      await tapCell(t, 6, 0);
      await press(t, find.byKey(const Key('brush-cat')), 'Cat brush');
      final bad = conflictCell(g);
      await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      expect(g.hearts, 2);
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      await press(t, find.text('Play'), 'Home: Today Play');
      g = gameOf(t);
      expect(g.cells[0][s0], Mark.cat, reason: 'cat kept');
      expect(g.cells[6][0], Mark.cross, reason: 'mark kept');
      expect(g.hearts, 2, reason: 'hearts kept');
      expect(find.text('🐱 1 of 7 cats placed'), findsOneWidget);
      // 하트를 다 잃고 나갔다 오면 그대로 '하트 없음'
      while (g.status == GameStatus.playing) {
        final b = conflictCell(g);
        await tapCell(t, b.$1, b.$2, label: 'cell(conflict)');
      }
      // 마지막 반칙의 빨간 표시를 먼저 보여 주고 패널은 조금 뒤에
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('💔 Out of hearts!'), findsNothing);
      await t.pump(const Duration(milliseconds: 1000));
      expect(find.text('💔 Out of hearts!'), findsOneWidget);
      await press(t, find.byKey(const Key('home')), 'Lost: Home');
      await press(t, find.text('Play'), 'Home: Today Play');
      expect(gameOf(t).status, GameStatus.lost);
      expect(find.text('💔 Out of hearts!'), findsOneWidget);
      // Start over 는 판을 비운다
      await press(t, find.byKey(const Key('restart')), 'Lost: Start over');
      expect(gameOf(t).cats, 0);
      expect(gameOf(t).hearts, 3);
      await press(t, find.byKey(const Key('back')), 'Game: Back');
      await press(t, find.text('Play'), 'Home: Today Play');
      expect(gameOf(t).cats, 0);
      await finish(t);
    },
  );

  testWidgets('home is never stale: Play Levels → clear → Home shows Level 2', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Play'), 'Home: Today Play');
    await solveRest(t);
    await press(t, find.byKey(const Key('to-levels')), 'Won: Play Levels');
    await solveRest(t);
    expect(find.text('🎉 Level 1 cleared!'), findsOneWidget);
    await press(t, find.byKey(const Key('home')), 'Won: Home');
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('1 daily puzzle solved'), findsOneWidget);
    await finish(t);
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

  testWidgets(
    'a second tap after closing the hint dialog does not hit the board',
    (t) async {
      await boot(t, prefs: {'seenHowTo': true});
      await press(t, find.text('Play'), 'Home: Today Play');
      final g = gameOf(t);
      await t.tap(find.byKey(const Key('hint')));
      await t.pump(const Duration(milliseconds: 400));
      final btn = t.getCenter(find.text('Not now'));
      await t.tapAt(btn);
      await t.pump(const Duration(milliseconds: 80));
      await t.tapAt(btn); // 두 번째 탭이 판 위로 떨어진다
      await t.pump(const Duration(milliseconds: 50));
      pressed.add('Hint dialog: Not now (double tap)');
      expect(g.cats, 0);
      expect(g.hearts, 3);
      await t.pump(const Duration(seconds: 1));
      await finish(t);
    },
  );

  testWidgets(
    'double-tapping Next Level / Start over: no skipped level, no stray cat',
    (t) async {
      await boot(t, prefs: {'seenHowTo': true});
      await press(t, find.text('Start'), 'Home: Level Start');
      await solveRest(t);
      final next = t.getCenter(find.byKey(const Key('next')));
      await t.tapAt(next);
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(next); // 두 번째 탭
      await t.pump(const Duration(milliseconds: 40));
      await t.tapAt(next); // 세 번째 탭
      pressed.add('Won: Next Level (triple tap)');
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Level 2'), findsOneWidget, reason: 'no level skipped');
      var g = gameOf(t);
      expect(g.cats, 0, reason: 'no stray cat from the extra taps');
      // 하트를 다 잃고 Start over 를 두 번
      await tapCell(t, 0, g.puzzle.solution[0]);
      while (g.status == GameStatus.playing) {
        final bad = conflictCell(g);
        await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      }
      await t.pump(const Duration(milliseconds: 1300));
      final again = t.getCenter(find.byKey(const Key('restart')));
      await t.tapAt(again);
      await t.pump(const Duration(milliseconds: 60));
      await t.tapAt(again);
      pressed.add('Lost: Start over (double tap)');
      await t.pump(const Duration(seconds: 1));
      g = gameOf(t);
      expect(g.cats, 0);
      expect(g.hearts, 3);
      // 패널이 떠 있을 때 뒤의 붓·뒤로 버튼은 눌리지 않는다
      await tapCell(t, 0, g.puzzle.solution[0]);
      while (g.status == GameStatus.playing) {
        final bad = conflictCell(g);
        await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      }
      await t.pump(const Duration(milliseconds: 1300));
      await t.tap(find.byKey(const Key('brush-mark')), warnIfMissed: false);
      await t.pump();
      expect(
        g.brush,
        Brush.cat,
        reason: 'brush behind the panel must not change',
      );
      await finish(t);
    },
  );

  testWidgets('double-tapping Hint still leaves the dialog open', (t) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Play'), 'Home: Today Play');
    final h = t.getCenter(find.byKey(const Key('hint')));
    await t.tapAt(h);
    await t.pump(const Duration(milliseconds: 60));
    await t.tapAt(h);
    pressed.add('Hint (double tap)');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Need a hint?'), findsOneWidget);
    await press(t, find.text('Not now'), 'Hint dialog: Not now');
    await finish(t);
  });

  testWidgets('double-tapping a rule-breaking square costs only one heart', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    await tapCell(t, 0, g.puzzle.solution[0]);
    final bad = conflictCell(g);
    final rect = t.getRect(find.byKey(const Key('board')));
    final cs = rect.width / g.n;
    final at = rect.topLeft + Offset((bad.$2 + 0.5) * cs, (bad.$1 + 0.5) * cs);
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 110));
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 60));
    await t.tapAt(at);
    pressed.add('cell(conflict) triple tap');
    await t.pump(const Duration(seconds: 1));
    expect(g.hearts, 2);
    await finish(t);
  });

  testWidgets(
    'double-tapping the last square shows the win panel (not skip it)',
    (t) async {
      await boot(t, prefs: {'seenHowTo': true});
      await press(t, find.text('Start'), 'Home: Level Start');
      final g = gameOf(t);
      for (var r = 0; r < g.n - 1; r++) {
        await tapCell(t, r, g.puzzle.solution[r]);
      }
      final rect = t.getRect(find.byKey(const Key('board')));
      final cs = rect.width / g.n;
      final last = g.n - 1;
      final at =
          rect.topLeft +
          Offset((g.puzzle.solution[last] + 0.5) * cs, (last + 0.5) * cs);
      await t.tapAt(at);
      await t.pump(const Duration(milliseconds: 120));
      await t.tapAt(at);
      pressed.add('last cell double tap');
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('🎉 Level 1 cleared!'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      await finish(t);
    },
  );

  testWidgets('Mark brush: never deletes a cat; dragging from a ✕ erases ✕s', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    final s0 = g.puzzle.solution[0];
    await tapCell(t, 0, s0);
    await press(t, find.byKey(const Key('brush-mark')), 'Mark brush');
    await tapCell(t, 0, s0);
    expect(g.cells[0][s0], Mark.cat, reason: 'Mark must not delete a cat');
    final rect = t.getRect(find.byKey(const Key('board')));
    final cs = rect.width / g.n;
    final y = cs * (g.n - 0.5);
    // 맨 아래 줄을 ✕ 로 끌어 칠한 뒤, ✕ 에서 시작해 다시 끌면 지워진다
    for (final erase in [false, true]) {
      final gs = await t.startGesture(rect.topLeft + Offset(cs * 0.5, y));
      for (var c = 1; c < g.n; c++) {
        await gs.moveTo(rect.topLeft + Offset(cs * (c + 0.5), y));
        await t.pump(const Duration(milliseconds: 16));
      }
      await gs.up();
      await t.pump(const Duration(milliseconds: 100));
      final row = [for (var c = 0; c < g.n; c++) g.cells[g.n - 1][c]];
      expect(
        row.every((m) => m == (erase ? Mark.empty : Mark.cross)),
        isTrue,
        reason: erase ? 'drag from ✕ erases' : 'drag marks',
      );
    }
    pressed.add('drag-mark / drag-erase');
    await finish(t);
  });

  testWidgets('a broken saved board does not crash the game screen', (t) async {
    await boot(t, prefs: {'seenHowTo': true, 'board_level_1': '{"n":5}'});
    await press(t, find.text('Start'), 'Home: Level Start');
    expect(find.text('Level 1'), findsOneWidget);
    expect(gameOf(t).cats, 0);
    await press(t, find.byKey(const Key('back')), 'Game: Back');
    await finish(t);
  });

  testWidgets('dead end (a wrong cat leaves no spot) is explained on screen', (
    t,
  ) async {
    await boot(t, prefs: {'seenHowTo': true});
    await press(t, find.text('Start'), 'Home: Level Start');
    final g = gameOf(t);
    // 규칙엔 맞지만 정답이 아닌 고양이를 놓아 막다른 길을 만든다 (못 만들면 판을 바꿔 시도)
    var made = false;
    for (var r = 0; r < g.n && !made; r++) {
      for (var c = 0; c < g.n && !made; c++) {
        if (g.puzzle.isSolutionCell(r, c) || g.cells[r][c] == Mark.cat) {
          continue;
        }
        if (g.conflictsWith(r, c).isNotEmpty) continue;
        await tapCell(t, r, c);
        made = g.stuck;
      }
    }
    expect(made, isTrue, reason: 'could not build a dead end on level 1');
    await t.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('stuck')), findsOneWidget);
    // 힌트를 쓰면 틀린 고양이를 치워 다시 길이 열린다
    await press(t, find.byKey(const Key('hint')), 'Hint');
    await press(t, find.text('▶ Watch video'), 'Hint dialog: Watch video');
    expect(g.stuck, isFalse);
    expect(find.byKey(const Key('stuck')), findsNothing);
    await finish(t);
  });

  testWidgets('daily clock carries over after losing', (t) async {
    await boot(t, prefs: {'seenHowTo': true, 'dailyCarry_20261002': 75});
    expect(find.textContaining('1:15 so far'), findsOneWidget);
    await press(t, find.text('Play'), 'Home: Today Play');
    expect(gameOf(t).seconds, greaterThanOrEqualTo(75));
    expect(find.text('1:15'), findsOneWidget);
    await finish(t);
  });

  for (final e in devices.entries) {
    testWidgets('layout on ${e.key}: every screen, 9x9 board, panels', (
      t,
    ) async {
      final (size, ratio) = e.value;
      await boot(t, size: size, ratio: ratio, prefs: {'level': 60});
      expect(find.text('How to play'), findsOneWidget);
      await press(t, find.byKey(const Key('howto-ok')), 'How-to: Got it');
      await press(t, find.text('Continue'), 'Home: Level Continue');
      final g = gameOf(t);
      expect(g.n, 9);
      final rect = t.getRect(find.byKey(const Key('board')));
      final cell = rect.width / 9;
      // 손가락으로 누를 수 있는 크기 (Apple 권장 44pt 에 가깝게, 최소 34pt)
      expect(
        cell,
        greaterThanOrEqualTo(34),
        reason: 'cell ${cell.toStringAsFixed(1)}pt',
      );
      // 판·팔레트·배너가 화면 안에
      for (final k in [
        'board',
        'brush-cat',
        'brush-mark',
        'hint',
        'back',
        'timer',
      ]) {
        final r = t.getRect(find.byKey(Key(k)));
        expect(
          r.bottom <= size.height && r.top >= 0 && r.right <= size.width + 0.5,
          isTrue,
          reason: '$k off screen: $r',
        );
      }
      await solveRest(t);
      expect(find.byKey(const Key('panel')), findsOneWidget);
      final p = t.getRect(find.byKey(const Key('panel')));
      expect(p.bottom <= size.height, isTrue);
      await press(t, find.byKey(const Key('home')), 'Won: Home');
      await press(t, find.text('Play'), 'Home: Today Play');
      final g2 = gameOf(t);
      await tapCell(t, 0, g2.puzzle.solution[0]);
      while (g2.status == GameStatus.playing) {
        final bad = conflictCell(g2);
        await tapCell(t, bad.$1, bad.$2, label: 'cell(conflict)');
      }
      await t.pump(const Duration(milliseconds: 1300));
      expect(
        t.getRect(find.byKey(const Key('panel'))).bottom <= size.height,
        isTrue,
      );
      // 화면 문구에 한글이 섞이지 않았는지 (미국 대상)
      final ko = RegExp(r'[가-힣]');
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        expect(
          ko.hasMatch(w.data ?? ''),
          isFalse,
          reason: 'Korean text: ${w.data}',
        );
      }
      await finish(t);
    });
  }

  test('level sizes grow 5 → 9', () {
    expect([1, 4, 11, 26, 51, 500].map(Puzzle.sizeForLevel).toList(), [
      5,
      6,
      7,
      8,
      9,
      9,
    ]);
  });
}
