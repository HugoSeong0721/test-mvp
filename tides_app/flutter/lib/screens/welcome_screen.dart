import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'stations_screen.dart';
import 'widgets.dart';

/// First launch: find the nearest station, or search.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _locating = false;
  String? _error;

  Future<void> _nearMe() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    final r = await AppStore.i.useMyLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _error = r.ok ? null : r.message;
    });
  }

  void _search() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const StationsScreen()));

  @override
  Widget build(BuildContext context) {
    final count = AppStore.i.db.all.length;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: const WaveArt(height: 170),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Tides near you',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'High and low tide times, tide charts, sunrise and moon phase — '
                          'from NOAA predictions for $count coastal stations.',
                          style: const TextStyle(
                            fontSize: 16.5,
                            color: Palette.sub,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Notice(
                            key: const Key('welcome-error'),
                            text: _error!,
                            icon: Icons.location_off_outlined,
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          key: const Key('welcome-near-me'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _nearMe,
                          icon: _locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(
                            _locating
                                ? 'Finding nearest station…'
                                : 'Use My Location',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('welcome-search'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                          label: const Text('Search Stations'),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your location stays on this device. Not for navigation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Palette.faint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
