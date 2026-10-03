import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 방침: 배너 + 사용자가 원해서 보는 보상형 하나(30일 물때표 24시간 열기). 전면 광고 없음 —
/// 1등 앱의 "물때 보려는데 30초 광고" 불만의 정반대가 우리 무기. 기본 7일은 늘 무료.
enum RewardResult {
  /// 끝까지 봐서 보상을 받았다.
  rewarded,

  /// 영상은 떴지만 보상 전에 닫았다.
  closedEarly,

  /// 기다려도 영상이 오지 않았다 (오프라인·광고 재고 없음).
  unavailable,
}

/// AdMob 광고 단위 ID — `soulfulfillable` AdMob 계정의 iOS 앱 "Glance Tides"
/// (앱 ID ca-app-pub-4724352880074547~3021266571 → ios/Runner/Info.plist 의 GADApplicationIdentifier).
/// 단위: `banner`, `rewarded_30day`. 안드로이드는 출시 전이라 Google 테스트 ID.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-4724352880074547/9191837537'
      : 'ca-app-pub-3940256099942544/6300978111';
  static String get rewardedMonth => _ios
      ? 'ca-app-pub-4724352880074547/4912847027'
      : 'ca-app-pub-3940256099942544/5224354917';
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기에서는 가짜를 쓴다.
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  /// 영상이 안 와 있을 때 최대 이만큼 기다린다.
  static const waitForVideo = Duration(seconds: 8);

  Future<void> init();

  /// 지금 바로 보여 줄 영상이 받아져 있나.
  bool get isReady;

  /// 보상형 광고를 보여 준다. 받아져 있지 않으면 [waitForVideo] 까지 기다린다.
  Future<RewardResult> showRewarded();

  Widget banner();
}

class AdMobAds extends Ads {
  RewardedAd? _ready;
  bool _loading = false;
  int _fails = 0;
  Completer<void>? _waiter;

  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _load();
  }

  @override
  bool get isReady => _ready != null;

  void _load() {
    if (_loading || _ready != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewardedMonth,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _fails = 0;
          _ready = ad;
          _waiter?.complete();
          _waiter = null;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          _fails++;
          debugPrint('Rewarded ad failed to load: $err');
          // 10초, 20초, 40초 … 최대 2분 간격으로 다시 받아 둔다
          Timer(Duration(seconds: (10 << (_fails - 1)).clamp(10, 120)), _load);
        },
      ),
    );
  }

  @override
  Future<RewardResult> showRewarded() async {
    if (_ready == null) {
      _load();
      final w = _waiter ??= Completer<void>();
      try {
        await w.future.timeout(Ads.waitForVideo);
      } on TimeoutException {
        return RewardResult.unavailable;
      }
    }
    final ad = _ready;
    _ready = null;
    if (ad == null) return RewardResult.unavailable;
    final done = Completer<RewardResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
        if (!done.isCompleted) {
          done.complete(
            earned ? RewardResult.rewarded : RewardResult.closedEarly,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _load();
        if (!done.isCompleted) done.complete(RewardResult.unavailable);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Widget banner() => const _AdBanner();
}

/// 테스트·웹 미리보기용. 기본은 곧바로 보상. 배너는 자리만 잡는다 (화면 배치가 실제와 같게).
class FakeAds extends Ads {
  FakeAds({
    this.result = RewardResult.rewarded,
    this.delay = Duration.zero,
    this.ready = true,
  });

  RewardResult result;
  Duration delay;
  bool ready;
  int shown = 0;

  @override
  Future<void> init() async {}

  @override
  bool get isReady => ready;

  @override
  Future<RewardResult> showRewarded() async {
    shown++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

  @override
  Widget banner() => const SizedBox(
    key: Key('ad-banner'),
    height: 60,
    child: Center(
      child: Text(
        'Ad',
        style: TextStyle(fontSize: 11, color: Color(0xFF9AA8B8)),
      ),
    ),
  );
}

/// 웹 미리보기용 가짜 광고. 주소 뒤 `?ads=` 로 상황을 흉내 낸다 (점검용).
///   (없음) 1.5초 "영상" 뒤 보상 · slow 4초 로딩 뒤 보상 · none 8초 기다려도 영상 없음 · early 보상 전에 닫음
FakeAds webPreviewAds(String? mode) => switch (mode) {
  'slow' => FakeAds(ready: false, delay: const Duration(seconds: 4)),
  'none' => FakeAds(
    ready: false,
    delay: Ads.waitForVideo,
    result: RewardResult.unavailable,
  ),
  'early' => FakeAds(
    result: RewardResult.closedEarly,
    delay: const Duration(milliseconds: 800),
  ),
  _ => FakeAds(delay: const Duration(milliseconds: 1500)),
};

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
