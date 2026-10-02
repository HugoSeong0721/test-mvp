import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets.dart';

/// 처음 켰을 때 한 번, 그리고 홈의 "How to play" 에서.
/// 글은 짧게 — 규칙 3개와 조작 2개가 전부.
Future<void> showHowTo(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: C.bg,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How to play',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: C.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Put one cat in every color.',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: C.sub,
                  ),
                ),
                const SizedBox(height: 16),
                _row('🎨', 'Each color gets exactly 1 cat.'),
                _row('↔️', 'Each row and each column gets 1 cat.'),
                _row('🙀', 'Cats can’t touch — not even corners.'),
                const Divider(height: 28),
                _row(
                  '🐱',
                  'Pick Cat, then tap a square to place a cat. Tap it again to take it back.',
                ),
                _row(
                  '✕',
                  'Pick Mark to note squares with no cat. Drag to mark many.',
                ),
                _row(
                  '💔',
                  'Break a rule and you lose a heart. 3 hearts per game.',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
          child: BigButton(
            key: const Key('howto-ok'),
            label: 'Got it!',
            onTap: () => Navigator.pop(ctx),
          ),
        ),
      ],
    ),
  ),
);

Widget _row(String icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 44,
        child: Text(
          icon,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: C.ink,
          ),
        ),
      ),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, height: 1.3, color: C.ink),
        ),
      ),
    ],
  ),
);
