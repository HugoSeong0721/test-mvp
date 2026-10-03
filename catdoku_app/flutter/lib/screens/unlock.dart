import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/purchases.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// 잠긴 묶음을 여는 두 가지 길: 영상 1개 → 다음 20단계, 또는 $1.99 → 전부 + 배너 제거.
/// 단계 목록 화면과 승리 패널(다음 단계가 잠겼을 때)에서 같이 쓴다.
class UnlockChoices extends StatefulWidget {
  const UnlockChoices({super.key, this.onUnlocked});

  /// 열리고 나서 할 일 (예: 다음 단계 시작).
  final VoidCallback? onUnlocked;

  @override
  State<UnlockChoices> createState() => _UnlockChoicesState();
}

class _UnlockChoicesState extends State<UnlockChoices> {
  bool _busy = false;

  void _say(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg, style: const TextStyle(fontSize: 17))),
      );
  }

  Future<void> _video() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await Ads.i.showRewarded(RewardPlacement.unlockPack);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == RewardResult.closedEarly) {
      _say('Watch the whole video to unlock the levels.');
      return;
    }
    // 영상이 없으면(광고 재고 없음·오프라인) 그냥 연다 — 막혀서 그만두지 않게.
    await AppStore.i.unlockNextPack();
    _say(
      r == RewardResult.unavailable
          ? 'No video right now — 20 levels unlocked anyway! 🎁'
          : '🎉 20 new levels unlocked!',
    );
    widget.onUnlocked?.call();
  }

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await Purchases.i.buyUnlockAll();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuyResult.purchased:
        _say('🎉 All levels unlocked. Thank you!');
        widget.onUnlocked?.call();
      case BuyResult.cancelled:
        break;
      case BuyResult.failed:
        _say('Purchase didn’t go through. Please try again.');
      case BuyResult.unavailable:
        _say(
          'The App Store isn’t available right now. Please try again later.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = Purchases.i.price ?? r'$1.99';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BigButton(
          key: const Key('unlock-video'),
          icon: '▶',
          label: 'Watch a video: +20 levels',
          color: C.green,
          textColor: Colors.white,
          onTap: _busy ? null : _video,
        ),
        const SizedBox(height: 10),
        BigButton(
          key: const Key('unlock-buy'),
          label: 'Unlock all · no ads · $price',
          onTap: _busy ? null : _buy,
        ),
      ],
    );
  }
}
