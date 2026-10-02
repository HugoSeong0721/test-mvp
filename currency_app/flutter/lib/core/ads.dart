import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'theme.dart';

/// AdMob 광고 단위 ID.
/// iOS 는 AdMob 콘솔의 "Currency Exchange" 앱에 만든 실제 배너 단위.
/// 안드로이드는 아직 AdMob 에 앱을 등록하지 않아 Google 공식 테스트 ID 를 쓴다 —
/// 등록 후 여기와 AndroidManifest.xml 의 APPLICATION_ID 를 함께 바꾼다.
class AdIds {
  static String get banner => Platform.isIOS
      ? 'ca-app-pub-4724352880074547/2514463130'
      : 'ca-app-pub-3940256099942544/6300978111';
}

Future<void> initAds() => MobileAds.instance.initialize();

/// 탭바 바로 위에 고정되는 320×50 배너.
/// 광고가 아직 안 왔거나 실패해도 자리를 비워 두어 화면이 출렁이지 않게 한다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $err');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = Fx.of(context);
    final ad = _ad;
    return Container(
      height: AdSize.banner.height.toDouble() + 10,
      decoration: BoxDecoration(
        color: fx.surface,
        border: Border(top: BorderSide(color: fx.line)),
      ),
      alignment: Alignment.center,
      child: _loaded && ad != null
          ? SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            )
          : null,
    );
  }
}
