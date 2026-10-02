import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/puzzle.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../game/game.dart';
import 'board.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen.daily({super.key}) : mode = GameMode.daily, level = 0;
  const GameScreen.level(this.level, {super.key}) : mode = GameMode.level;

  final GameMode mode;
  final int level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late Game game;
  late int level = widget.level;
  late final String day = AppStore.i.todayKey;
  Timer? _tick;
  bool _busyAd = false;

  bool get daily => widget.mode == GameMode.daily;

  /// 오늘 퍼즐을 이미 풀었으면 이후 판은 연습 — 기록이 바뀌지 않는다.
  /// 판을 시작할 때 정해진다 (푼 직후 화면이 연습으로 바뀌지 않게).
  bool practice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newGame();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && game.status == GameStatus.playing) setState(() {});
    });
  }

  void _newGame() {
    practice = daily && AppStore.i.solvedTime(day) > 0;
    final p = daily ? Puzzle.daily(day) : Puzzle.level(level);
    game = Game(
      p,
      mode: widget.mode,
      levelNo: level,
      carried: daily && !practice ? AppStore.i.carriedTime(day) : 0,
    );
    game.addListener(_onGame);
  }

  void _onGame() {
    if (game.status == GameStatus.won) _onWin();
    if (game.status == GameStatus.lost) _saveCarry();
    if (mounted) setState(() {});
  }

  bool _recorded = false;
  int? _wonTime;
  Future<void> _onWin() async {
    if (_recorded) return;
    _recorded = true;
    _wonTime = game.seconds;
    if (daily && !practice) {
      await AppStore.i.markDailySolved(
        day,
        game.seconds < 1 ? 1 : game.seconds,
      );
    } else if (!daily) {
      await AppStore.i.completeLevel(level);
    }
    if (mounted) setState(() {});
  }

  void _saveCarry() {
    if (daily && !practice && game.status != GameStatus.won) {
      AppStore.i.setCarriedTime(day, game.seconds);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      game.resumeClock();
    } else {
      game.pauseClock();
      _saveCarry();
    }
  }

  @override
  void dispose() {
    _saveCarry();
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  void _restart({bool next = false}) {
    _saveCarry();
    game.removeListener(_onGame);
    game.dispose();
    if (next) level++;
    _recorded = false;
    _wonTime = null;
    setState(_newGame);
  }

  Future<bool> _watchVideo() async {
    if (_busyAd) return false;
    _busyAd = true;
    game.pauseClock();
    final ok = await Ads.i.showRewarded();
    _busyAd = false;
    game.resumeClock();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video right now. Please try again in a moment.'),
        ),
      );
    }
    return ok;
  }

  Future<void> _hint() async {
    if (game.status != GameStatus.playing) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: const Text(
          'Need a hint?',
          style: TextStyle(fontWeight: FontWeight.w800, color: C.ink),
        ),
        content: const Text(
          'Watch a short video and we’ll put one cat in the right spot '
          '(or move a cat that’s in the wrong place).',
          style: TextStyle(fontSize: 17, color: C.sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(fontSize: 17)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('▶ Watch video', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
    if (yes == true && await _watchVideo()) game.applyHint();
  }

  Future<void> _continue() async {
    if (await _watchVideo()) game.continueWithHearts();
  }

  @override
  Widget build(BuildContext context) {
    final title = daily
        ? (practice
              ? 'Today · practice'
              : 'Today · ${fmtDayShort(AppStore.i.clock())}')
        : 'Level $level';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 14, 0),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('back'),
                        tooltip: 'Back',
                        iconSize: 30,
                        color: C.ink,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: C.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: shadow,
                        ),
                        child: Text(
                          fmtTime(game.seconds),
                          key: const Key('timer'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: C.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Hearts(game.hearts),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: RuleChips(),
                ),
                SizedBox(height: 40, child: Center(child: _statusLine())),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Board(game: game),
                  ),
                ),
                const SizedBox(height: 12),
                _palette(),
                const SizedBox(height: 8),
                Ads.i.banner(),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
            if (game.status == GameStatus.won && _wonTime != null) _winPanel(),
            if (game.status == GameStatus.lost) _lostPanel(),
          ],
        ),
      ),
    );
  }

  Widget _statusLine() {
    final v = game.lastViolation;
    return TweenAnimationBuilder<double>(
      key: ValueKey(game.eventSeq),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2200),
      builder: (context, t, _) {
        String? msg;
        var color = C.red;
        if (game.eventSeq > 0 && t < 1) {
          if (game.lastEventIsHint) {
            msg = game.lastHintRemoved
                ? '💡 That cat was in the wrong spot'
                : '💡 Here’s a cat in the right spot!';
            color = C.green;
          } else if (v != null) {
            msg = '💔 ${v.reason}';
          }
        }
        if (msg != null) {
          return Opacity(
            opacity: t < 0.8 ? 1 : (1 - t) / 0.2,
            child: Text(
              msg,
              key: const Key('event'),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          );
        }
        return Text(
          '🐱 ${game.cats} of ${game.n} cats placed',
          key: const Key('progress'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: C.ink,
          ),
        );
      },
    );
  }

  Widget _palette() {
    Widget brush(Brush b, String icon, String label) {
      final on = game.brush == b;
      return Expanded(
        child: Material(
          color: on ? C.ink : C.card,
          borderRadius: BorderRadius.circular(16),
          elevation: on ? 3 : 1,
          child: InkWell(
            key: Key('brush-${b.name}'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => game.setBrush(b),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    icon,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: on ? Colors.white : C.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: on ? C.gold : C.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          brush(Brush.cat, '🐱', 'Cat'),
          const SizedBox(width: 8),
          brush(Brush.mark, '✕', 'Mark'),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            height: 64,
            child: Material(
              color: const Color(0xFFFFE7A8),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const Key('hint'),
                borderRadius: BorderRadius.circular(16),
                onTap: game.status == GameStatus.playing ? _hint : null,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '💡 Hint',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
                        ),
                      ),
                      Text(
                        '▶ video',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: C.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> kids) => Positioned.fill(
    child: Container(
      color: const Color(0x66000000),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      child: Container(
        key: const Key('panel'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: shadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: kids),
      ),
    ),
  );

  Widget _winPanel() {
    final s = _wonTime ?? game.seconds;
    final kids = <Widget>[
      Text(
        daily ? '🎉 Solved!' : '🎉 Level $level cleared!',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: C.ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        fmtTime(s),
        key: const Key('win-time'),
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: C.green,
        ),
      ),
    ];
    if (daily) {
      final streak = AppStore.i.streak;
      kids.add(
        Text(
          practice
              ? 'Practice run — today’s time is ${fmtTime(AppStore.i.solvedTime(day))}'
              : '🔥 $streak-day streak',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: C.sub,
          ),
        ),
      );
      kids.add(const SizedBox(height: 6));
      kids.add(
        const Text(
          'A new puzzle arrives tomorrow.',
          style: TextStyle(fontSize: 16, color: C.muted),
        ),
      );
      kids.add(const SizedBox(height: 18));
      kids.add(
        BigButton(
          key: const Key('to-levels'),
          label: 'Play Levels',
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen.level(AppStore.i.level),
            ),
          ),
        ),
      );
    } else {
      kids.add(
        Text(
          'All ${game.n} cats are home. Purr-fect!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: C.sub),
        ),
      );
      kids.add(const SizedBox(height: 18));
      kids.add(
        BigButton(
          key: const Key('next'),
          label: 'Next Level',
          onTap: () => _restart(next: true),
        ),
      );
    }
    kids.add(const SizedBox(height: 10));
    kids.add(
      BigButton(
        key: const Key('home'),
        label: 'Home',
        color: C.card,
        textColor: C.ink,
        onTap: () => Navigator.pop(context),
      ),
    );
    return _panel(kids);
  }

  Widget _lostPanel() => _panel([
    const Text(
      '💔 Out of hearts!',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: C.ink),
    ),
    const SizedBox(height: 8),
    const Text(
      'Keep your cats where they are and get 3 more hearts.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 17, color: C.sub),
    ),
    const SizedBox(height: 18),
    BigButton(
      key: const Key('continue'),
      icon: '▶',
      label: 'Watch video: +3 ❤️',
      color: C.green,
      textColor: Colors.white,
      onTap: _continue,
    ),
    const SizedBox(height: 10),
    BigButton(
      key: const Key('restart'),
      label: 'Start over',
      onTap: () => _restart(),
    ),
    const SizedBox(height: 10),
    BigButton(
      key: const Key('home'),
      label: 'Home',
      color: C.card,
      textColor: C.ink,
      onTap: () => Navigator.pop(context),
    ),
  ]);
}
