import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고는 하단 배너 하나뿐. 전면·영상 광고는 넣지 않는다 (운전 중 안전 + 1등 앱 불만의 정반대).
///
/// AdMob 광고 단위 ID — 아직 AdMob 에 이 앱을 만들지 않아 Google 공식 **테스트 ID**.
/// 콘솔에서 앱·배너 단위를 만들면 여기와 ios/Runner/Info.plist 의 GADApplicationIdentifier,
/// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 함께 바꾼다.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';
}

abstract class Ads {
  static Ads i = kIsWeb ? PreviewAds() : AdMobAds();
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

/// 테스트용 — 자리만 차지한다.
class FakeAds extends Ads {
  @override
  Future<void> init() async {}

  @override
  Widget banner() => const SizedBox(key: Key('banner'), height: 60);
}

/// 웹 미리보기 — 배너가 들어갈 자리를 회색 상자로 보여 준다.
class PreviewAds extends Ads {
  @override
  Future<void> init() async {}

  @override
  Widget banner() => SizedBox(
    key: const Key('banner'),
    height: 60,
    child: Center(
      child: Container(
        width: 320,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1C222B),
          border: Border.all(color: const Color(0xFF2A323D)),
        ),
        child: const Text(
          'Banner ad space (320×50)',
          style: TextStyle(color: Color(0xFF5E6878), fontSize: 12),
        ),
      ),
    ),
  );
}

/// 320×50 배너. 광고가 안 와도 자리를 비워 둬 화면이 출렁이지 않는다.
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
