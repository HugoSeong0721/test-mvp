import 'package:flutter/material.dart';

import 'core/controller.dart';
import 'core/device.dart';
import 'core/location.dart';
import 'core/prefs.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

/// 앱 뿌리. 측정 컨트롤러의 수명(시계·위치 받기)을 여기서 관리한다.
class SpeedApp extends StatefulWidget {
  const SpeedApp({
    super.key,
    required this.source,
    required this.prefs,
    required this.io,
  });
  final LocationSource source;
  final Prefs prefs;
  final DeviceIO io;

  @override
  State<SpeedApp> createState() => _SpeedAppState();
}

class _SpeedAppState extends State<SpeedApp> {
  late final SpeedController c;

  @override
  void initState() {
    super.initState();
    c = SpeedController(
      source: widget.source,
      prefs: widget.prefs,
      io: widget.io,
    );
    WidgetsBinding.instance.addObserver(c);
    if (widget.prefs.seenSafety) c.start(prompt: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(c);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Speedometer',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: ListenableBuilder(
      listenable: c,
      builder: (context, _) => widget.prefs.seenSafety
          ? HomeScreen(c: c)
          : WelcomeScreen(
              onAccept: () {
                c.acceptSafety();
                c.start(prompt: true);
              },
            ),
    ),
  );
}
