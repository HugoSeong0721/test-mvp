import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'screens/intro_screen.dart';
import 'screens/meter_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppStore.i.load();
  Ads.i.init();
  // 웹 미리보기: 접근성 트리를 켜 둬야 자동 점검이 버튼을 이름으로 찾는다.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const DecibelApp());
}

class DecibelApp extends StatelessWidget {
  const DecibelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: kAppName,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: AppStore.i.seenIntro ? const MeterScreen() : const IntroScreen(),
  );
}
