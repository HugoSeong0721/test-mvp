import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'core/rate_service.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'features/chart/chart_screen.dart';
import 'features/converter/converter_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await AppStore.i.load();
  // 환율은 기다리지 않는다 — 스냅샷으로 먼저 그리고 도착하면 갈아끼운다
  RateService.i.load();
  runApp(const SomRateApp());
}

class SomRateApp extends StatelessWidget {
  const SomRateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '솜 환율',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Fx.light, Brightness.light),
      darkTheme: buildTheme(Fx.dark, Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.i,
      builder: (context, _) =>
          AppStore.i.onboarded ? const _Shell() : const OnboardingScreen(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: fx.appBg,
      ),
      child: Scaffold(
        backgroundColor: fx.appBg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const [ConverterScreen(), ChartScreen()],
          ),
        ),
        bottomNavigationBar: _TabBar(
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    return Container(
      decoration: BoxDecoration(
        color: fx.appBg,
        border: Border(top: BorderSide(color: fx.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Row(
            children: [
              _tab(context, 0, Icons.swap_horiz_rounded, '변환'),
              _tab(context, 1, Icons.show_chart_rounded, '차트'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, IconData icon, String label) {
    final fx = Fx.of(context);
    final on = i == index;
    final color = on ? fx.accent : fx.muted;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
