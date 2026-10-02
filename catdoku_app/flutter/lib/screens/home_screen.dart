import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/puzzle.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'game_screen.dart';
import 'how_to.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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
    if (mounted) setState(() {});
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
                    title: 'Level $lv',
                    sub:
                        '${Puzzle.sizeForLevel(lv)}×${Puzzle.sizeForLevel(lv)} · '
                        '${s.levelsSolved} solved',
                    button: lv == 1 ? 'Start' : 'Continue',
                    onTap: () => _open(GameScreen.level(lv)),
                  ),
                  const SizedBox(height: 22),
                  const RuleChips(big: true),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      key: const Key('howto'),
                      onPressed: () => showHowTo(context),
                      child: const Text(
                        '❓ How to play',
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
                        'Best streak ${s.bestStreak} · ${s.dailyTotal} daily puzzles solved',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: C.muted),
                      ),
                    ),
                ],
              ),
            ),
            Ads.i.banner(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Key key,
    required String emoji,
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
                  Text(emoji, style: const TextStyle(fontSize: 30)),
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
