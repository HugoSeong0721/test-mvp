import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppStore.i.load();
  Ads.i.init();
  // 웹 미리보기: 접근성 트리를 켜 둬야 화면 읽기·자동 점검이 버튼을 이름으로 찾는다.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const TidesApp());
}

class TidesApp extends StatelessWidget {
  const TidesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tides',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      );
}

/// Welcome until a station is chosen, then the tide screen. Follows the store,
/// so picking a station anywhere (search, near me) switches this.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppStore.i,
        builder: (context, _) =>
            AppStore.i.station == null ? const WelcomeScreen() : const HomeScreen(),
      );
}
