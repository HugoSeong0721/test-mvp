import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'store.dart';

/// 보상형 광고를 보여 주는 자리. 자리마다 AdMob 광고 단위를 따로 둬서
/// 어느 쪽이 수익을 내는지 AdMob 보고서에서 나눠 볼 수 있게 한다.
enum RewardPlacement { hint, continueGame, unlockPack }

enum RewardResult {
  /// 끝까지 봐서 보상을 받았다.
  rewarded,

  /// 영상은 떴지만 보상 전에 닫았다.
  closedEarly,

  /// 기다려도 영상이 오지 않았다 (오프라인·광고 재고 없음·새 앱 검토 중).
  /// 화면은 이때 보상을 그냥 준다 (game_screen.dart _watchVideo).
  unavailable,
}

/// AdMob 광고 단위 ID — `soulfulfillable` 계정의 "Kitty Queens" iOS 앱 (앱 ID 는 ios/Runner/Info.plist).
/// 안드로이드는 AdMob 앱을 아직 안 만들어 Google 공식 테스트 ID.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static String get banner => _ios
      ? 'ca-app-pub-4724352880074547/8563658282'
      : 'ca-app-pub-3940256099942544/6300978111';
  static String rewarded(RewardPlacement p) => switch (p) {
    // 자리마다 다른 광고 단위 — AdMob 보고서에서 힌트·이어하기 수익을 나눠 본다.
    RewardPlacement.hint =>
      _ios
          ? 'ca-app-pub-4724352880074547/7250576612'
          : 'ca-app-pub-3940256099942544/5224354917',
    // 묶음 열기는 따로 단위를 만들기 전까지 이어하기 단위를 같이 쓴다.
    RewardPlacement.continueGame || RewardPlacement.unlockPack =>
      _ios
          ? 'ca-app-pub-4724352880074547/7933102895'
          : 'ca-app-pub-3940256099942544/5224354917',
  };
}

/// 광고를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기에서는 가짜를 쓴다.
abstract class Ads {
  static Ads i = kIsWeb ? FakeAds() : AdMobAds();

  /// 영상이 안 와 있을 때 최대 이만큼 기다린다.
  static const waitForVideo = Duration(seconds: 8);

  Future<void> init();

  /// 지금 바로 보여 줄 영상이 받아져 있나.
  bool isReady(RewardPlacement p);

  /// 보상형 광고를 보여 준다. 받아져 있지 않으면 [waitForVideo] 까지 기다린다.
  Future<RewardResult> showRewarded(RewardPlacement p);

  Widget banner();
}

class AdMobAds extends Ads {
  final Map<RewardPlacement, RewardedAd> _ready = {};
  final Set<RewardPlacement> _loading = {};
  final Map<RewardPlacement, int> _fails = {};
  final Map<RewardPlacement, Completer<void>> _waiters = {};

  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
    for (final p in RewardPlacement.values) {
      _load(p);
    }
  }

  @override
  bool isReady(RewardPlacement p) => _ready.containsKey(p);

  void _load(RewardPlacement p) {
    if (_loading.contains(p) || _ready.containsKey(p)) return;
    _loading.add(p);
    RewardedAd.load(
      adUnitId: AdIds.rewarded(p),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading.remove(p);
          _fails[p] = 0;
          _ready[p] = ad;
          _waiters.remove(p)?.complete();
        },
        onAdFailedToLoad: (err) {
          _loading.remove(p);
          final n = (_fails[p] ?? 0) + 1;
          _fails[p] = n;
          debugPrint('Rewarded ad ($p) failed to load: $err');
          // 10초, 20초, 40초 … 최대 2분 간격으로 다시 받아 둔다
          final wait = Duration(seconds: (10 << (n - 1)).clamp(10, 120));
          Timer(wait, () => _load(p));
        },
      ),
    );
  }

  @override
  Future<RewardResult> showRewarded(RewardPlacement p) async {
    if (!_ready.containsKey(p)) {
      _load(p);
      final w = _waiters.putIfAbsent(p, Completer<void>.new);
      try {
        await w.future.timeout(Ads.waitForVideo);
      } on TimeoutException {
        return RewardResult.unavailable;
      }
    }
    final ad = _ready.remove(p);
    if (ad == null) return RewardResult.unavailable;
    final done = Completer<RewardResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load(p);
        if (!done.isCompleted) {
          done.complete(
            earned ? RewardResult.rewarded : RewardResult.closedEarly,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _load(p);
        if (!done.isCompleted) done.complete(RewardResult.unavailable);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Widget banner() => const _AdBanner();
}

/// 테스트·웹 미리보기용. 기본은 곧바로 보상.
class FakeAds extends Ads {
  FakeAds({
    this.result = RewardResult.rewarded,
    this.delay = Duration.zero,
    this.ready = true,
  });
  RewardResult result;
  Duration delay;
  bool ready;
  final List<RewardPlacement> shown = [];
  int get rewardedShown => shown.length;

  @override
  Future<void> init() async {}

  @override
  bool isReady(RewardPlacement p) => ready;

  @override
  Future<RewardResult> showRewarded(RewardPlacement p) async {
    shown.add(p);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

  @override
  Widget banner() => const SizedBox(height: 60);
}

/// 웹 미리보기용 가짜 광고. 주소 뒤 `?ads=` 로 상황을 흉내 낸다 (점검용).
///   (없음) 바로 보상 · slow 3초 로딩 뒤 보상 · none 8초 기다려도 영상 없음 · early 보상 전에 닫음
FakeAds webPreviewAds(String? mode) => switch (mode) {
  'slow' => FakeAds(ready: false, delay: const Duration(seconds: 3)),
  'none' => FakeAds(
    ready: false,
    delay: Ads.waitForVideo,
    result: RewardResult.unavailable,
  ),
  'early' => FakeAds(result: RewardResult.closedEarly),
  _ => FakeAds(),
};

/// 배너 자리 — 결제(배너 제거)하면 사라진다.
class BannerSlot extends StatelessWidget {
  const BannerSlot({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppStore.i,
    builder: (context, _) =>
        AppStore.i.premium ? const SizedBox.shrink() : Ads.i.banner(),
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
