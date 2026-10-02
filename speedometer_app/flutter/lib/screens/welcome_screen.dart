import 'package:flutter/material.dart';

import '../core/theme.dart';

const _tips = [
  (
    Icons.do_not_touch_outlined,
    'Set it up before you go. Don’t touch your phone while driving.',
  ),
  (
    Icons.phone_iphone,
    'Mount your phone where you can glance at it. The screen stays on.',
  ),
  (
    Icons.lock_outline,
    'Speed comes from your phone’s GPS. Your location never leaves this device.',
  ),
];

/// 첫 실행 1회 — 운전 중 조작 금지 안내 + 위치 권한 이유.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onAccept});
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Icon(Icons.speed, size: 64, color: C.accent),
                const SizedBox(height: 18),
                const Text(
                  'Before you drive',
                  style: TextStyle(
                    color: C.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                for (final (icon, text) in _tips) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: C.accent, size: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: C.ink,
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                const Text(
                  'Road speed limits are not shown. Set your own speed alert, and always follow posted limits.',
                  style: TextStyle(color: C.sub, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('accept'),
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text(
                    'I Understand — Allow Location',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 설정에서 다시 보기.
Future<void> showSafetyDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Driving safety'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icon, text) in _tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: C.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: const TextStyle(height: 1.3)),
                ),
              ],
            ),
          ),
      ],
    ),
    actions: [
      FilledButton(
        key: const Key('safety-ok'),
        onPressed: () => Navigator.pop(ctx),
        child: const Text('OK'),
      ),
    ],
  ),
);
