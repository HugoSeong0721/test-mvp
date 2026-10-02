import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'meter_screen.dart';

/// 처음 한 번: 마이크를 왜 쓰는지 정직하게 알리고 시스템 권한 창으로 넘긴다.
/// (Apple 지침상 버튼은 "Allow" 가 아니라 "Continue" — 실제 허용은 시스템 창에서.)
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  Future<void> _go(BuildContext context) async {
    await AppStore.i.setSeenIntro();
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const MeterScreen(autoStart: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.card2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: C.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: C.sub,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.graphic_eq, color: C.accent, size: 56),
                  const SizedBox(height: 14),
                  const Text(
                    'How loud is it\naround you?',
                    style: TextStyle(
                      color: C.ink,
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Free decibel meter. No subscription, no sign-up.',
                    style: TextStyle(color: C.sub, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  point(
                    Icons.mic_none,
                    'Uses your microphone',
                    'Only to measure loudness while this screen is open.',
                  ),
                  point(
                    Icons.lock_outline,
                    'Nothing is recorded',
                    'Audio is never saved or sent. Only the numbers stay on your phone.',
                  ),
                  point(
                    Icons.description_outlined,
                    'Free noise reports',
                    'Save a report with time, average and max to share with a neighbor or landlord.',
                  ),
                  point(
                    Icons.info_outline,
                    'Everyday accuracy',
                    'Phone mics are not certified meters. You can fine-tune the reading in Settings.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('intro-continue'),
                      onPressed: () => _go(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Next, iPhone will ask to use the microphone.',
                      style: TextStyle(color: C.muted, fontSize: 12),
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
}
