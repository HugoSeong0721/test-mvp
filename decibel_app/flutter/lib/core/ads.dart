import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 광고 단위 ID.
/// 아직 AdMob 에 이 앱을 만들지 않아 Google 공식 **테스트 ID** 를 쓴다.
/// 콘솔에서 앱·광고 단위를 만들면 여기와 ios/Runner/Info.plist 의 GADApplicationIdentifier,
/// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 함께 바꾼다.
///
/// 방침(기획서): 배너만. 측정 중 전면 광고 금지 — 광고 소리가 측정을 망친다는 경쟁 앱 리뷰가 있다.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기에서는 빈 자리.
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  Future<void> init();
  Widget banner();
}

class AdMobAds extends Ads {
  @override
  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('ads init failed: $e');
    }
  }

  @override
  Widget banner() => const _AdBanner();
}

class FakeAds extends Ads {
  @override
  Future<void> init() async {}

  @override
  Widget banner() => const SizedBox(height: 60, key: Key('banner'));
}

/// 화면 맨 아래 320×50 배너. 광고가 안 와도 자리를 비워 둬 화면이 출렁이지 않는다.
class _AdBanner extends StatefulWidget {
  const _AdBanner();

  @override
  State<_AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<_AdBanner> {
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
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
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
    final ad = _ad;
    return SizedBox(
      key: const Key('banner'),
      height: AdSize.banner.height.toDouble() + 10,
      child: Center(
        child: _loaded && ad != null
            ? SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              )
            : null,
      ),
    );
  }
}
