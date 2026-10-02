import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/ads.dart';
import 'core/device.dart';
import 'core/location.dart';
import 'core/platform_location.dart';
import 'core/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await Prefs.load();
  Ads.i.init();
  // 웹 미리보기: `?demo=1` 이면 가짜 주행(화면에 DEMO 표시). 앱 빌드에는 없다.
  final demo = kIsWeb && Uri.base.queryParameters['demo'] == '1';
  final LocationSource source = demo
      ? DemoDriveSource()
      : createPlatformSource();
  // 웹 미리보기: 접근성 트리를 켜 둬야 자동 점검이 버튼을 이름으로 찾는다.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(SpeedApp(source: source, prefs: prefs, io: RealDeviceIO()));
}
