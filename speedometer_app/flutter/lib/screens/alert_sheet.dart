import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import 'widgets.dart';
import '../core/units.dart';

/// 속도 경고 설정 — 켜기/끄기, 속도 (±1, ±5), 소리.
Future<void> showAlertSheet(
  BuildContext context,
  SpeedController c,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => ListenableBuilder(
    listenable: c,
    builder: (ctx, _) {
      final unit = c.unit.label;
      Widget step(String key, String label, int delta) => SizedBox(
        width: 58,
        height: 52,
        child: OutlinedButton(
          key: Key(key),
          onPressed: () => c.changeAlertLimit(delta),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: C.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            semanticsLabel: '${delta > 0 ? 'plus' : 'minus'} ${delta.abs()}',
            style: const TextStyle(
              color: C.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      return SheetFrame(
        title: 'Speed Alert',
        doneKey: 'alert-done',
        children: [
          const SizedBox(height: 4),
          SwitchListTile(
            key: const Key('alert-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Alert me above',
              style: TextStyle(color: C.ink, fontSize: 17),
            ),
            subtitle: const Text(
              'Screen turns red when you go over.',
              style: TextStyle(color: C.sub),
            ),
            value: c.alertOn,
            onChanged: c.setAlertOn,
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: c.alertOn ? 1 : 0.45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                step('alert-minus5', '−5', -5),
                step('alert-minus', '−1', -1),
                Column(
                  children: [
                    Text(
                      '${c.alertLimit}',
                      key: const Key('alert-value'),
                      style: const TextStyle(
                        color: C.ink,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        fontFeatures: tabular,
                      ),
                    ),
                    Text(
                      unit,
                      style: const TextStyle(
                        color: C.sub,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                step('alert-plus', '+1', 1),
                step('alert-plus5', '+5', 5),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            key: const Key('sound-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Sound',
              style: TextStyle(color: C.ink, fontSize: 17),
            ),
            subtitle: const Text(
              'Beep + vibration. Off = vibration only.',
              style: TextStyle(color: C.sub),
            ),
            value: c.prefs.sound,
            onChanged: c.setSound,
          ),
          const SizedBox(height: 4),
          const Text(
            'This is your own limit — the app does not know road speed limits. '
            'Always follow posted limits.',
            style: TextStyle(color: C.muted, fontSize: 13, height: 1.35),
          ),
        ],
      );
    },
  ),
);
