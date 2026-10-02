import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/brand.dart';
import 'core/notify.dart';
import 'core/persist.dart';
import 'core/sample.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 웹 미리보기 ?demo=1: 예시 기록으로 바로 둘러보기 (아이폰 앱에는 없는 길). 진짜 기록과 따로 저장된다.
  final demo = kIsWeb && Uri.base.queryParameters['demo'] == '1';
  if (demo) AppStore.i.persist = Persist.demo();
  await AppStore.i.load();
  if (demo && !AppStore.i.hasVehicle) AppStore.i.replaceAll(sampleData(AppStore.i.now()));
  Ads.i.init();
  Notifier.i.init();
  // 웹 미리보기: 접근성 트리를 켜 둬야 화면 읽기·자동 점검이 버튼을 이름으로 찾는다.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const FuelApp());
}

class FuelApp extends StatelessWidget {
  const FuelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    home: ListenableBuilder(
      listenable: AppStore.i,
      // 차가 하나도 없으면(처음 켬, 또는 다 지움) 첫 화면
      builder: (context, _) => AppStore.i.hasVehicle ? const HomeShell() : const WelcomeScreen(),
    ),
  );
}
