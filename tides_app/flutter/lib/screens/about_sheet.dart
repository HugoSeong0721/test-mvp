import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';

const privacyUrl =
    'https://soulfulfillable.github.io/test-mvp/tides-privacy.html';

/// Opens a link in Safari. Tests replace it.
Future<bool> Function(Uri) openLink = (u) =>
    launchUrl(u, mode: LaunchMode.externalApplication);

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Palette.bg,
  builder: (_) => const AboutSheet(),
);

class AboutSheet extends StatefulWidget {
  const AboutSheet({super.key});

  @override
  State<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<AboutSheet> {
  final store = AppStore.i;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Height units',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SegmentedButton<Units>(
                    key: const Key('units-toggle'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: Units.feet,
                        label: Text('Feet'),
                        tooltip: 'Feet',
                      ),
                      ButtonSegment(
                        value: Units.meters,
                        label: Text('Meters'),
                        tooltip: 'Meters',
                      ),
                    ],
                    selected: {store.units},
                    onSelectionChanged: (v) async {
                      await store.setUnits(v.first);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'About the data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tide times and heights are NOAA CO-OPS predictions (tidesandcurrents.noaa.gov), '
                'in feet or meters above Mean Lower Low Water (MLLW), shown in each station’s local time. '
                'For reference stations the chart is NOAA’s 6-minute prediction series. Subordinate stations '
                'only have NOAA high/low times; their chart is estimated between those points.\n\n'
                'Predictions are astronomical and do not include wind, storms or river flow. '
                'Sunrise, sunset and moon phase are calculated on your device.\n\n'
                'Predictions are saved on your device, so the last week you opened still shows without signal.',
                style: TextStyle(
                  fontSize: 14,
                  color: Palette.sub,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.warnBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Not for navigation. Always check official sources and local conditions before going out on the water.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Palette.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                key: const Key('privacy-link'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLink(Uri.parse(privacyUrl)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('close-settings'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
