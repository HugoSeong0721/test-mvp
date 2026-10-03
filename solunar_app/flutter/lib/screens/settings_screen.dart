import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// Opens links. Tests swap it out.
Future<bool> Function(Uri) openLink = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

final privacyUrl = Uri.parse('https://soulfulfillable.github.io/test-mvp/solunar-privacy.html');

/// Shooting-light offsets and what the app does.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppStore.i,
    builder: (context, _) {
      final s = AppStore.i;
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          child: ListView(
            key: const Key('settings-list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              const SectionTitle('Legal shooting light'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stepper(
                      label: 'Starts before sunrise',
                      value: s.beforeSunrise,
                      keyPrefix: 'before',
                      onChanged: (v) => s.setLegalOffsets(before: v),
                    ),
                    const Divider(height: 20),
                    _Stepper(
                      label: 'Ends after sunset',
                      value: s.afterSunset,
                      keyPrefix: 'after',
                      onChanged: (v) => s.setLegalOffsets(after: v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick set',
                      style: TextStyle(fontSize: 12.5, color: Palette.sub, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Preset(k: 'preset-30-30', label: '30 min / 30 min', before: 30, after: 30),
                        _Preset(k: 'preset-30-0', label: '30 min / sunset', before: 30, after: 0),
                        _Preset(k: 'preset-0-0', label: 'Sunrise / sunset', before: 0, after: 0),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Shooting hours are set by each state and differ by species and season. Many states allow big game '
                      'from 30 minutes before sunrise to 30 minutes after sunset; federal rules for ducks and geese usually '
                      'end at sunset. Always check your state’s current regulations — this app only does the math.',
                      key: Key('legal-note'),
                      style: TextStyle(fontSize: 13, color: Palette.sub, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('About'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'All times are worked out on your phone from the positions of the sun and moon — no internet needed. '
                      'Moon: Meeus, Astronomical Algorithms. Sun: NOAA solar equations. Moonrise and moonset follow the '
                      'US Naval Observatory definition (upper edge of the moon on the horizon).',
                      style: TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Town names: GeoNames (geonames.org), CC BY 4.0.',
                      style: TextStyle(fontSize: 13, color: Palette.sub),
                    ),
                    SizedBox(height: 4),
                    Text('Your location stays on this device.', style: TextStyle(fontSize: 13, color: Palette.sub)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('privacy-link'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLink(privacyUrl),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.keyPrefix, required this.onChanged});
  final String label;
  final int value;
  final String keyPrefix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
      ),
      IconButton.outlined(
        key: Key('$keyPrefix-minus'),
        tooltip: '$label: 5 minutes less',
        onPressed: value <= 0 ? null : () => onChanged(value - 5),
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 64,
        child: Text(
          '$value min',
          key: Key('$keyPrefix-value'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      IconButton.outlined(
        key: Key('$keyPrefix-plus'),
        tooltip: '$label: 5 minutes more',
        onPressed: value >= 90 ? null : () => onChanged(value + 5),
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

class _Preset extends StatelessWidget {
  const _Preset({required this.k, required this.label, required this.before, required this.after});
  final String k;
  final String label;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final s = AppStore.i;
    final on = s.beforeSunrise == before && s.afterSunset == after;
    return ChoiceChip(
      key: Key(k),
      label: Text(label),
      selected: on,
      onSelected: (_) => s.setLegalOffsets(before: before, after: after),
    );
  }
}
