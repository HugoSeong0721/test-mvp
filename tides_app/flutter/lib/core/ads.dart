import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 광고 단위 ID.
/// 아직 AdMob 에 이 앱을 만들지 않아 Google 공식 **테스트 ID** 를 쓴다.
/// 콘솔에서 앱·광고 단위를 만들면 여기와 ios/Runner/Info.plist 의 GADApplicationIdentifier,
/// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 함께 바꾼다.
///
/// 방침: 배너만. 전면 광고 없음 — 1등 앱의 "물때 보려는데 30초 광고" 불만의 정반대가 우리 무기.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기에서는 가짜를 쓴다.
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  Future<void> init();

  Widget banner();
}

class AdMobAds extends Ads {
  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  @override
  Widget banner() => const _AdBanner();
}

/// 테스트·웹 미리보기용: 배너 자리만 잡는다 (화면 배치가 실제와 같게).
class FakeAds extends Ads {
  @override
  Future<void> init() async {}

  @override
  Widget banner() => const SizedBox(
        key: Key('ad-banner'),
        height: 60,
        child: Center(
          child: Text('Ad', style: TextStyle(fontSize: 11, color: Color(0xFF9AA8B8))),
        ),
      );
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
      key: const Key('ad-banner'),
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
