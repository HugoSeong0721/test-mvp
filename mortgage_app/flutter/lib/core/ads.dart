import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'theme.dart';

/// AdMob 광고 단위 ID (soulfulfillable 계정, 앱 Glance Mortgage ~9582805496, 2026-10-03).
/// iOS 는 실제 ID, 안드로이드는 아직 AdMob 앱이 없어 Google 공식 테스트 ID.
/// 앱 ID 는 ios/Runner/Info.plist 의 GADApplicationIdentifier 와 짝.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-4724352880074547/4605810985'
      : 'ca-app-pub-3940256099942544/6300978111';
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기에서는 가짜를 쓴다.
/// 방침: 배너만. 계산하는 동안 전면 광고는 띄우지 않는다 (plans/mortgage-app.md).
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  Future<void> init();
  Widget banner();
}

class AdMobAds extends Ads {
  @override
  Future<void> init() => MobileAds.instance.initialize();

  @override
  Widget banner() => const _AdBanner();
}

/// 테스트·웹 미리보기용 — 배너 자리만 보여 준다.
class FakeAds extends Ads {
  int bannersBuilt = 0;

  @override
  Future<void> init() async {}

  @override
  Widget banner() {
    bannersBuilt++;
    return const _FakeBanner();
  }
}

/// 배너 높이 (320×50 + 위아래 여백). 광고가 안 와도 자리를 비워 둬 화면이 출렁이지 않는다.
const bannerHeight = 60.0;

class _FakeBanner extends StatelessWidget {
  const _FakeBanner();

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return SizedBox(
      key: const Key('banner'),
      height: bannerHeight,
      child: Center(
        child: Container(
          width: 320,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tk.surface2,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Ad', style: TextStyle(color: tk.muted, fontSize: 12)),
        ),
      ),
    );
  }
}

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
      height: bannerHeight,
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
