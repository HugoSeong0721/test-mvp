import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/ads.dart';
import 'core/location.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (kIsWeb) {
    // 웹 미리보기 점검용 스위치: ?ads=slow|none|early (가짜 광고 상황), ?loc=lat,lng (가짜 위치)
    final q = Uri.base.queryParameters;
    Ads.i = webPreviewAds(q['ads']);
    final loc = q['loc']?.split(',');
    if (loc != null && loc.length == 2) {
      final lat = double.tryParse(loc[0]), lng = double.tryParse(loc[1]);
      if (lat != null && lng != null) LocationService.i = FakeLocation(LocationResult.found(lat, lng));
    }
  }
  await AppStore.i.load();
  Ads.i.init();
  // 웹 미리보기: 접근성 트리를 켜 둬야 화면 읽기·자동 점검이 버튼을 이름으로 찾는다.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const SolunarApp());
}

class SolunarApp extends StatelessWidget {
  const SolunarApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'Solunar', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const _Root());
}

/// Welcome until a place is chosen, then the main screen. Follows the store,
/// so picking a place anywhere (search, my location) switches this.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppStore.i,
    builder: (context, _) => AppStore.i.place == null ? const WelcomeScreen() : const HomeScreen(),
  );
}
