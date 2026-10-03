import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/puzzle.dart';
import '../core/purchases.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'game_screen.dart';
import 'unlock.dart';

/// 단계 목록: 깬 단계(✓, 다시 하기), 지금 단계, 남은 단계, 잠긴 묶음을 한눈에.
/// (사용자 요청 2026-10-03: "깼던 이전 거로 돌아가거나 앞으로 몇 개나 남았는지 볼 수 없나")
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AppStore.i.addListener(_refresh);
    // 지금 단계가 보이게 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.3);
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStore.i.removeListener(_refresh);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _play(int lv) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen.level(lv)));
    _refresh();
  }

  void _say(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 17))),
      );
  }

  Future<void> _restore() async {
    final found = await Purchases.i.restore();
    if (!mounted) return;
    _say(
      found
          ? '🎉 Purchase restored — all levels unlocked.'
          : 'No previous purchase found for this Apple ID.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStore.i;
    final packs = <(int, int)>[];
    for (var a = 1; a <= AppStore.totalLevels;) {
      final p = AppStore.packOf(a);
      packs.add(p);
      a = p.$2 + 1;
    }
    // 처음으로 잠긴 묶음만 "열기" 버튼을 보여 준다
    final firstLocked = packs.indexWhere((p) => !s.isOpen(p.$1));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('levels-back'),
                    tooltip: 'Back',
                    iconSize: 30,
                    color: C.ink,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Levels',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: C.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${s.levelsSolved} / ${AppStore.totalLevels} solved',
                    key: const Key('levels-count'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: C.sub,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: s.levelsSolved / AppStore.totalLevels,
                  minHeight: 10,
                  color: C.green,
                  backgroundColor: const Color(0x22000000),
                ),
              ),
            ),
            // 500칸을 다 만들어 둬야 '지금 단계'로 바로 스크롤할 수 있다 (게으른 목록은 아직 안 만든 칸을 못 찾는다)
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < packs.length; i++)
                      _pack(packs[i], i == firstLocked),
                    if (!s.premium)
                      Center(
                        child: TextButton(
                          key: const Key('restore'),
                          onPressed: _restore,
                          child: const Text(
                            'Restore purchase',
                            style: TextStyle(fontSize: 17, color: C.sub),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const BannerSlot(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _pack((int, int) p, bool firstLocked) {
    final s = AppStore.i;
    final (a, b) = p;
    final open = s.isOpen(a);
    final solved = [
      for (var lv = a; lv <= b; lv++)
        if (lv < s.level) lv,
    ].length;
    final sizes = {Puzzle.sizeForLevel(a), Puzzle.sizeForLevel(b)};
    final sizeText = sizes.map((n) => '$n×$n').join('–');
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${open ? '' : '🔒 '}Levels $a–$b',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: C.ink,
                  ),
                ),
              ),
              Text(
                a == 1 ? 'Free · $sizeText' : sizeText,
                style: const TextStyle(fontSize: 15, color: C.muted),
              ),
              const SizedBox(width: 10),
              Text(
                '$solved/${b - a + 1}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: C.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!open && firstLocked) ...[
            Container(
              key: const Key('unlock-box'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadow,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unlock the next 20 levels',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: C.ink,
                    ),
                  ),
                  SizedBox(height: 10),
                  UnlockChoices(),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [for (var lv = a; lv <= b; lv++) _tile(lv)],
          ),
        ],
      ),
    );
  }

  Widget _tile(int lv) {
    final s = AppStore.i;
    final done = lv < s.level;
    final current = lv == s.level;
    final open = s.isOpen(lv);
    Color bg = C.card;
    Color fg = C.ink;
    String text = '$lv';
    if (done) {
      bg = const Color(0xFFD9F2DF);
      fg = C.green;
    } else if (current && open) {
      bg = C.ink;
      fg = C.gold;
    } else if (!open) {
      bg = const Color(0xFFE8E0D2);
      fg = C.muted;
      text = '🔒';
    } else {
      fg = C.muted;
    }
    return Material(
      key: current ? _currentKey : null,
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('level-$lv'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (done || (current && open)) {
            _play(lv);
          } else if (!open) {
            _say('Unlock this pack first — see the box above.');
          } else {
            _say('Solve Level ${s.level} first.');
          }
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
              if (done)
                const Text(
                  '✓',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: C.green,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
