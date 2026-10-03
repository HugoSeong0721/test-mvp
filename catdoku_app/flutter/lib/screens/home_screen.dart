import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/puzzle.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'game_screen.dart';
import 'how_to.dart';
import 'levels_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // 홈은 저장소가 바뀔 때마다 다시 그린다 (뒤로 가기·Play Levels 로 돌아와도 숫자가 늦지 않게).
  // 날짜가 바뀌면(자정, 다음 날 아침 다시 열기) 오늘 퍼즐 카드를 새로 그린다.
  String _day = AppStore.i.todayKey;
  Timer? _dayCheck;

  void _refresh() {
    if (mounted) setState(() => _day = AppStore.i.todayKey);
  }

  void _checkDay() {
    if (AppStore.i.todayKey != _day) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    AppStore.i.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    _dayCheck?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppStore.i.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
    _dayCheck = Timer.periodic(const Duration(seconds: 20), (_) => _checkDay());
    if (!AppStore.i.seenHowTo) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AppStore.i.setSeenHowTo();
        if (mounted) await showHowTo(context);
      });
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.i;
    final day = s.todayKey;
    final solved = s.solvedTime(day);
    final carried = s.carriedTime(day);
    final lv = s.level;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                children: [
                  Row(
                    children: [
                      const Text('🐱', style: TextStyle(fontSize: 38)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Kitty Queens',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: C.ink,
                            ),
                          ),
                        ),
                      ),
                      if (s.streak > 0)
                        Container(
                          key: const Key('streak'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: C.card,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: shadow,
                          ),
                          child: Text(
                            '🔥 ${s.streak}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: C.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _card(
                    key: const Key('daily-card'),
                    emoji: '☀️',
                    title: 'Today’s Puzzle',
                    sub: solved > 0
                        ? '✅ Solved in ${fmtTime(solved)} · ${fmtDay(s.clock())}'
                        : carried > 0
                        ? '⏱ ${fmtTime(carried)} so far · ${fmtDay(s.clock())}'
                        : '${fmtDay(s.clock())} · 7×7',
                    button: solved > 0 ? 'Play again' : 'Play',
                    onTap: () => _open(const GameScreen.daily()),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    key: const Key('level-card'),
                    emoji: '🏆',
                    icon: Icons.emoji_events_rounded,
                    title: s.allLevelsDone ? 'All levels done!' : 'Level $lv',
                    sub: s.allLevelsDone
                        ? '${AppStore.totalLevels} of ${AppStore.totalLevels} solved 🎉'
                        : '${Puzzle.sizeForLevel(lv)}×${Puzzle.sizeForLevel(lv)} · '
                              '${s.levelsSolved} of ${AppStore.totalLevels} solved',
                    button: s.allLevelsDone
                        ? 'See all levels'
                        : !s.isOpen(lv)
                        ? 'Unlock Level $lv'
                        : lv == 1
                        ? 'Start'
                        : 'Continue',
                    onTap: () => _open(
                      !s.allLevelsDone && s.isOpen(lv)
                          ? GameScreen.level(lv)
                          : const LevelsScreen(),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      key: const Key('all-levels'),
                      onPressed: () => _open(const LevelsScreen()),
                      child: const Text(
                        '▦ All levels',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: C.sub,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const RuleChips(big: true),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      key: const Key('howto'),
                      onPressed: () => showHowTo(context),
                      child: const Text(
                        '? How to play',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: C.sub,
                        ),
                      ),
                    ),
                  ),
                  if (s.bestStreak > 0 || s.dailyTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Best streak ${s.bestStreak} · ${s.dailyTotal} daily '
                        '${s.dailyTotal == 1 ? 'puzzle' : 'puzzles'} solved',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: C.muted),
                      ),
                    ),
                ],
              ),
            ),
            const BannerSlot(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Key key,
    required String emoji,
    IconData? icon,
    required String title,
    required String sub,
    required String button,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: C.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: const Color(0x40785A28),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  icon != null
                      ? Icon(icon, size: 34, color: const Color(0xFFE6A817))
                      : Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: C.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(sub, style: const TextStyle(fontSize: 17, color: C.sub)),
              const SizedBox(height: 14),
              BigButton(label: button, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}
