import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/puzzle.dart';
import '../core/qa_hook.dart';
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
    final p = daily ? PathPuzzle.daily(day) : PathPuzzle.level(level);
    final saved = _boardKey == null ? null : AppStore.i.loadBoard(_boardKey!);
    game = Game(
      p,
      mode: widget.mode,
      levelNo: level,
      carried: daily
          ? (practice ? 0 : AppStore.i.carriedTime(day))
          : (saved?['secs'] is int ? saved!['secs'] as int : 0),
    );
    if (saved != null) game.restore(saved);
    game.addListener(_onGame);
    _publish();
    // 저장된 줄이 이미 끝까지 이어져 있으면 (기록 직전에 앱이 꺼진 경우) 지금 기록한다
    if (game.status == GameStatus.won) _onWin();
  }

  /// 하던 판을 저장하는 자리. 오늘 퍼즐 연습판은 저장하지 않는다.
  String? get _boardKey => daily
      ? (practice ? null : AppStore.dailyBoardKey(day))
      : AppStore.levelBoardKey(level);

  void _publish() => qaPublish({
    'n': game.n,
    'answer': game.puzzle.path,
    'path': game.path,
    'status': game.status.name,
    'level': daily ? 0 : level,
  });

  void _onGame() {
    _publish();
    if (game.status == GameStatus.won) {
      _onWin();
    } else {
      final k = _boardKey;
      if (k != null) AppStore.i.saveBoard(k, game.snapshot());
      _saveCarry();
    }
    if (mounted) setState(() {});
  }

  bool _recorded = false;
  int? _wonTime;

  /// 줄이 끝까지 이어지는 걸 보여 준 뒤에 결과 패널을 띄운다.
  bool _showWin = false;
  bool _panelArmed = false;
  Timer? _winTimer;

  Future<void> _onWin() async {
    if (_recorded) return;
    _recorded = true;
    _wonTime = game.seconds < 1 ? 1 : game.seconds;
    _winTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showWin = true;
        _panelArmed = false;
      });
      // 뜬 직후 0.45초는 버튼이 안 눌린다 — 마지막 칸을 연타하던 손가락이 패널 버튼에 떨어져 축하를 건너뛰지 않게
      _winTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _panelArmed = true);
      });
    });
    if (daily && !practice) {
      await AppStore.i.markDailySolved(day, _wonTime!);
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
      final k = _boardKey;
      if (k != null && game.status != GameStatus.won) {
        AppStore.i.saveBoard(k, game.snapshot());
      }
    }
  }

  @override
  void dispose() {
    _saveCarry();
    final k = _boardKey;
    if (k != null && game.status != GameStatus.won) {
      AppStore.i.saveBoard(k, game.snapshot());
    }
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _winTimer?.cancel();
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }

  void _next() {
    // 버튼을 두 번 누르면 두 번 불린다 — 승리 상태일 때만, 한 번만.
    if (game.status != GameStatus.won || !_showWin || !_panelArmed) return;
    _winTimer?.cancel();
    game.removeListener(_onGame);
    game.dispose();
    // 다음 단계는 저장된 진행에서 가져온다 (level++ 를 두 번 하면 한 단계를 건너뛴다)
    level = AppStore.i.level > level ? AppStore.i.level : level + 1;
    _recorded = false;
    _wonTime = null;
    _showWin = false;
    setState(_newGame);
    // 버튼의 두 번째 탭이 새 판에 떨어져 엉뚱한 줄이 생기지 않게
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
    final msg = switch (r) {
      RewardResult.rewarded => null,
      RewardResult.closedEarly => 'Watch the whole video to get your hint.',
      // 새 AdMob 앱은 출시 전까지 영상 재고가 거의 없다 → 영상이 없다고 막지 않고 그냥 준다 (캣도쿠 TestFlight 에서 사용자가 막힘)
      RewardResult.unavailable => 'No video right now — this one’s on us 🎁',
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
    if (game.status != GameStatus.playing || _busyAd) return;
    final yes = await showDialog<bool>(
      context: context,
      // 힌트를 두 번 누르면 두 번째 탭이 바깥을 눌러 창이 바로 닫힌다
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: const Text(
          'Need a hint?',
          style: TextStyle(fontWeight: FontWeight.w800, color: C.ink),
        ),
        content: Text(
          'Watch a short video and we’ll draw the way to the next number '
          '${_hintTarget()}(and fix any wrong turns).',
          style: const TextStyle(fontSize: 17, color: C.sub),
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

  String _hintTarget() {
    final k = game.correctPrefix;
    for (var i = k; i < game.puzzle.cells; i++) {
      final num = game.puzzle.numberAt[game.puzzle.path[i]];
      if (num > 0) return '$num ';
    }
    return '';
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
            // 패널·영상 대기 화면이 떠 있으면 뒤의 버튼(뒤로·되돌리기·힌트)은 눌리지 않게
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
                              fmtTime(_wonTime ?? game.seconds),
                              key: const Key('timer'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: C.ink,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: RuleChips(),
                    ),
                    SizedBox(height: 44, child: Center(child: _statusLine())),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Board(game: game),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _toolbar(),
                    const SizedBox(height: 8),
                    Ads.i.banner(),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
            if (game.status == GameStatus.won && _showWin) _winPanel(),
            if (_waitingVideo) _loadingVideo(),
          ],
        ),
      ),
    );
  }

  bool get _overlayUp =>
      _waitingVideo || (game.status == GameStatus.won && _showWin);

  Widget _statusLine() {
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
            final to = game.nextNumber - 1;
            msg = k == 0
                ? '💡 Here’s the way to $to!'
                : '💡 Fixed your line + the way to $to!';
            color = C.green;
          } else {
            msg = switch (game.lastBlock) {
              Block.wrongNumber =>
                'Go to ${game.nextNumber} first — numbers go in order!',
              Block.pastEnd => 'That’s the last number — fill every square!',
              Block.notNext => 'Draw from the end of your line 👆',
              null => null,
            };
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
        final p = game.puzzle;
        final String text;
        if (game.status == GameStatus.won) {
          text = '🐱 All ${p.cells} squares — solved!';
        } else if (game.puzzle.numberAt[game.head] == p.lastNumber) {
          // 마지막 숫자에 닿았는데 빈칸이 남았다 — 무엇을 해야 하는지 계속 보여 준다
          text = '⚠️ ${game.left} empty — slide back and fill them';
        } else {
          text = 'Next: ${game.nextNumber}  ·  ${game.left} squares left';
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            key: const Key('progress'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
                  game.puzzle.numberAt[game.head] == p.lastNumber &&
                      game.status != GameStatus.won
                  ? C.red
                  : C.ink,
            ),
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    final playing = game.status == GameStatus.playing;
    final canErase = playing && game.path.length > 1;
    Widget tool(Key key, String icon, String label, VoidCallback? onTap) {
      return Expanded(
        child: Material(
          color: C.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: C.line, width: 1.5),
          ),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Opacity(
                opacity: onTap == null ? 0.4 : 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        icon,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: C.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: C.ink,
                        ),
                      ),
                    ],
                  ),
                ),
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
          tool(const Key('undo'), '↶', 'Undo', canErase ? game.undo : null),
          const SizedBox(width: 8),
          tool(const Key('clear'), '⟲', 'Clear', canErase ? game.clear : null),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            height: 64,
            child: Material(
              color: const Color(0xFFFFE7A8),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const Key('hint'),
                borderRadius: BorderRadius.circular(16),
                onTap: playing ? _hint : null,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.all(4),
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
          ),
        ],
      ),
    );
  }

  Widget _panel(List<Widget> kids) => Positioned.fill(
    child: IgnorePointer(ignoring: !_panelArmed, child: _panelBody(kids)),
  );

  Widget _panelBody(List<Widget> kids) => Container(
    color: const Color(0x66000000),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(22),
    child: SingleChildScrollView(
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
          '🐱 All ${game.puzzle.cells} squares, one line. Purr-fect!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: C.sub),
        ),
      );
      kids.add(const SizedBox(height: 18));
      kids.add(
        BigButton(key: const Key('next'), label: 'Next Level', onTap: _next),
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
}
