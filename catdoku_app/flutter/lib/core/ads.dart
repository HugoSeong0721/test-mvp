import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 광고 단위 ID.
/// 아직 AdMob 에 Catdoku 앱을 만들지 않아 Google 공식 **테스트 ID** 를 쓴다.
/// 콘솔에서 앱·광고 단위를 만들면 여기와 ios/Runner/Info.plist 의 GADApplicationIdentifier,
/// android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID 를 함께 바꾼다.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';
  static String get rewarded => _ios
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹에서는 가짜를 쓴다.
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  Future<void> init();

  /// 보상형 광고를 보여 주고, 끝까지 봐서 보상을 받았으면 true.
  Future<bool> showRewarded();

  Widget banner();
}

class AdMobAds extends Ads {
  RewardedAd? _rewarded;
  bool _loading = false;

  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadRewarded();
  }

  void _loadRewarded() {
    if (_loading || _rewarded != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          debugPrint('Rewarded ad failed to load: $err');
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Widget banner() => const _AdBanner();
}

/// 테스트·웹 미리보기용. 보상형은 곧바로 보상을 준다.
class FakeAds extends Ads {
  FakeAds({this.reward = true});
  bool reward;
  int rewardedShown = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded() async {
    rewardedShown++;
    return reward;
  }

  @override
  Widget banner() => const SizedBox(height: 60);
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
    final ad = _ad;
    return SizedBox(
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
