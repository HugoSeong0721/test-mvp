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
      carried: daily
          ? (practice ? 0 : AppStore.i.carriedTime(day))
          : (AppStore.i.loadBoard(AppStore.levelBoardKey(level))?['secs']
                    as int? ??
                0),
    );
    final saved = _boardKey == null ? null : AppStore.i.loadBoard(_boardKey!);
    if (saved != null) game.restore(saved);
    _showLost = game.status == GameStatus.lost;
    game.addListener(_onGame);
  }

  /// 하던 판을 저장하는 자리. 오늘 퍼즐 연습판은 저장하지 않는다.
  String? get _boardKey => daily
      ? (practice ? null : AppStore.dailyBoardKey(day))
      : AppStore.levelBoardKey(level);

  /// 마지막 하트를 잃은 칸이 빨갛게 번쩍이는 걸 보여 준 뒤에 패널을 띄운다.
  bool _showLost = false;
  Timer? _lostTimer;

  void _onGame() {
    if (game.status == GameStatus.won) {
      _onWin();
    } else {
      final k = _boardKey;
      if (k != null) AppStore.i.saveBoard(k, game.snapshot());
      _saveCarry();
    }
    if (game.status == GameStatus.lost && !_showLost && _lostTimer == null) {
      _lostTimer = Timer(const Duration(milliseconds: 1100), () {
        _lostTimer = null;
        if (mounted && game.status == GameStatus.lost) {
          setState(() => _showLost = true);
        }
      });
    }
    if (game.status != GameStatus.lost) _showLost = false;
    if (mounted) setState(() {});
  }

  bool _recorded = false;
  int? _wonTime;

  /// 승리 패널은 고양이들이 기뻐하는 걸 잠깐 보여 준 뒤에 띄운다.
  /// 마지막 칸을 두 번 누르면 두 번째 탭이 바로 뜬 패널 버튼(Next Level/Home)을 눌러 축하가 건너뛰어졌다.
  bool _showWin = false;
  Timer? _winTimer;

  Future<void> _onWin() async {
    if (_recorded) return;
    _recorded = true;
    _wonTime = game.seconds;
    _winTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showWin = true);
    });
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
    _lostTimer?.cancel();
    _winTimer?.cancel();
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  void _restart({bool next = false}) {
    // 버튼을 두 번 누르면 두 번 불린다 — 승리/패배 상태일 때만, 한 번만.
    if (next && game.status != GameStatus.won) return;
    if (!next && game.status != GameStatus.lost) return;
    _saveCarry();
    final k = _boardKey;
    if (k != null && !next) AppStore.i.clearBoard(k);
    _lostTimer?.cancel();
    _lostTimer = null;
    game.removeListener(_onGame);
    game.dispose();
    // 다음 단계는 저장된 진행에서 가져온다 (level++ 를 두 번 하면 한 단계를 건너뛰었다)
    if (next) level = AppStore.i.level > level ? AppStore.i.level : level + 1;
    _recorded = false;
    _wonTime = null;
    _showWin = false;
    _winTimer?.cancel();
    setState(_newGame);
    // 버튼의 두 번째 탭이 새 판에 떨어져 엉뚱한 고양이가 놓이지 않게
    game.blockInput();
  }

  /// 영상이 아직 안 받아져서 기다리는 중 (화면에 "Loading video…").
  bool _waitingVideo = false;

  Future<bool> _watchVideo(RewardPlacement placement) async {
    if (_busyAd) return false;
    _busyAd = true;
    game.pauseClock();
    if (!Ads.i.isReady(placement)) setState(() => _waitingVideo = true);
    final r = await Ads.i.showRewarded(placement);
    _busyAd = false;
    if (!mounted) return false;
    setState(() => _waitingVideo = false);
    game.resumeClock();
    game.blockInput();
    // 영상이 없으면(오프라인·광고 재고 없음·새 앱 검토 중) 그냥 준다 — 막혀서 그만두는 게 더 큰 손해.
    // 중간에 닫은 경우만 보상 없음.
    final msg = switch (r) {
      RewardResult.rewarded => null,
      RewardResult.closedEarly => 'Watch the whole video to get your reward.',
      RewardResult.unavailable => 'No video right now — this one’s on us! 🎁',
    };
    if (msg != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('ad-message'),
            content: Text(msg, style: const TextStyle(fontSize: 17)),
          ),
        );
    }
    return r != RewardResult.closedEarly;
  }

  Future<void> _hint() async {
    if (game.status != GameStatus.playing) return;
    final yes = await showDialog<bool>(
      context: context,
      // 힌트를 두 번 누르면 두 번째 탭이 바깥을 눌러 창이 바로 닫혔다
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: const Text(
          'Need a hint?',
          style: TextStyle(fontWeight: FontWeight.w800, color: C.ink),
        ),
        content: const Text(
          'Watch a short video and we’ll put one cat in the right spot '
          '(and clear any cats in the wrong place).',
          style: TextStyle(fontSize: 17, color: C.sub),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('▶ Watch video', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    game.blockInput();
    if (yes == true && await _watchVideo(RewardPlacement.hint)) {
      game.applyHint();
    }
  }

  Future<void> _continue() async {
    if (await _watchVideo(RewardPlacement.continueGame)) {
      game.continueWithHearts();
    }
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
            // 패널·영상 대기 화면이 떠 있으면 뒤의 버튼(뒤로·붓·힌트)은 눌리지 않게
            AbsorbPointer(
              absorbing: _overlayUp,
              child: ExcludeSemantics(
                excluding: _overlayUp,
                child: Column(
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
                          // 좁은 화면에서 날짜·연습 표시가 잘리지 않게 줄여서라도 다 보인다
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: C.ink,
                                ),
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
              ),
            ),
            if (game.status == GameStatus.won && _wonTime != null && _showWin)
              _winPanel(),
            if (game.status == GameStatus.lost && _showLost) _lostPanel(),
            if (_waitingVideo) _loadingVideo(),
          ],
        ),
      ),
    );
  }

  bool get _overlayUp =>
      _waitingVideo ||
      (game.status == GameStatus.won && _wonTime != null && _showWin) ||
      (game.status == GameStatus.lost && _showLost);

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
            final k = game.lastHintRemoved;
            msg = k == 0
                ? '💡 Here’s a cat in the right spot!'
                : '💡 Cleared $k wrong cat${k == 1 ? '' : 's'} + 1 right cat!';
            color = C.green;
          } else if (v != null) {
            msg = '💔 ${v.reason}';
          }
        }
        if (msg != null) {
          return Opacity(
            opacity: t < 0.8 ? 1 : (1 - t) / 0.2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                msg,
                key: const Key('event'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          );
        }
        if (game.stuck) {
          return const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '🤔 No spot left — move a cat or try 💡 Hint',
              key: Key('stuck'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: C.sub,
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
                          fontSize: 13,
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

  Widget _loadingVideo() => Positioned.fill(
    child: Container(
      key: const Key('loading-video'),
      color: const Color(0x88000000),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading video…',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

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
