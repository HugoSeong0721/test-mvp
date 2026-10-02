import 'package:flutter/material.dart';

import '../core/meter.dart';
import '../core/share.dart';
import '../core/store.dart';
import '../core/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: AppStore.i,
        builder: (context, _) {
          final s = AppStore.i;
          return ListView(
            key: const Key('settings-list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _section('CALIBRATION'),
              _card([
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Adjust reading',
                        style: TextStyle(
                          color: C.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _step(
                      Icons.remove,
                      const Key('trim-minus'),
                      'Lower by 0.5 dB',
                      () => s.setTrim(s.trim - 0.5),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        '${s.trim > 0
                            ? '+'
                            : s.trim < 0
                            ? '−'
                            : ''}${s.trim.abs().toStringAsFixed(1)} dB',
                        key: const Key('trim-value'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: C.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _step(
                      Icons.add,
                      const Key('trim-plus'),
                      'Raise by 0.5 dB',
                      () => s.setTrim(s.trim + 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phone microphones vary. If you have a trusted sound level meter, put both side by side and nudge this until they match.',
                  style: TextStyle(color: C.sub, fontSize: 13, height: 1.4),
                ),
                if (s.trim != 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('trim-reset'),
                      onPressed: () => s.setTrim(0),
                      child: const Text('Reset to default'),
                    ),
                  ),
              ]),
              _section('FREQUENCY WEIGHTING'),
              _card([
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Weighting>(
                    key: const Key('weighting'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: Weighting.a,
                        label: Text('dBA'),
                        tooltip: 'A-weighting',
                      ),
                      ButtonSegment(
                        value: Weighting.c,
                        label: Text('dBC'),
                        tooltip: 'C-weighting',
                      ),
                      ButtonSegment(
                        value: Weighting.z,
                        label: Text('dBZ'),
                        tooltip: 'Z-weighting',
                      ),
                    ],
                    selected: {s.weighting},
                    onSelectionChanged: (v) => s.setWeighting(v.first),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  switch (s.weighting) {
                    Weighting.a => 'dBA matches how people hear. Use it for noise complaints and hearing safety.',
                    Weighting.c => 'dBC keeps more bass — useful for music, engines and thumping.',
                    Weighting.z => 'dBZ is flat, with no weighting. Readings run higher than dBA.',
                  },
                  key: const Key('weighting-help'),
                  style: const TextStyle(
                    color: C.sub,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Changing this starts a new measurement. The current one stays in History.',
                  style: TextStyle(color: C.muted, fontSize: 12, height: 1.4),
                ),
              ]),
              _section('DISPLAY'),
              _card([
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    key: const Key('keep-awake'),
                    contentPadding: EdgeInsets.zero,
                    value: s.keepAwake,
                    onChanged: s.setKeepAwake,
                    title: const Text(
                      'Keep screen on while measuring',
                      style: TextStyle(color: C.ink),
                    ),
                    subtitle: const Text(
                      'Measuring pauses if the screen locks or you leave the app.',
                      style: TextStyle(color: C.sub, fontSize: 12),
                    ),
                  ),
                ),
              ]),
              _section('ABOUT'),
              _card([
                const Text(
                  'Not a certified sound level meter',
                  style: TextStyle(
                    color: C.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Phone microphones are good for everyday checks, not for legal or medical measurements. '
                  'Readings are estimates (A/C/Z weighting, Fast time weighting).',
                  style: TextStyle(color: C.sub, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your privacy',
                  style: TextStyle(
                    color: C.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The microphone is used only to measure loudness. Audio is never recorded, saved or sent anywhere — '
                  'only the numbers stay on your phone.',
                  style: TextStyle(color: C.sub, fontSize: 13, height: 1.4),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('privacy'),
                    onPressed: () => Outside.i.openUrl(kPrivacyUrl),
                    child: const Text('Privacy Policy'),
                  ),
                ),
                const Text(
                  '$kAppName 1.0 · © 2026 Soulfulfill',
                  style: TextStyle(color: C.muted, fontSize: 12),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      t,
      style: const TextStyle(
        color: C.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _step(IconData icon, Key key, String label, VoidCallback onTap) =>
      IconButton.filledTonal(
        key: key,
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
      );
}
