import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'store.dart';

/// 결제 하나: 비소모성 "전부 열기 + 배너 제거".
/// App Store Connect → 앱 → 수익화 → 앱 내 구입 에 같은 ID 로 만들어야 한다 (가격 $1.99).
const unlockAllId = 'com.soulfulfill.catdoku.unlockall';

enum BuyResult { purchased, cancelled, failed, unavailable }

/// 결제를 갈아끼울 수 있게 감싼다 — 테스트·웹 미리보기는 가짜.
abstract class Purchases {
  static Purchases i = kIsWeb ? FakePurchases() : StorePurchases();

  Future<void> init();

  /// 스토어에서 받은 가격 문자열 (예: "$1.99"). 아직 모르면 null.
  String? get price;

  Future<BuyResult> buyUnlockAll();

  /// "Restore purchase" — 다른 폰·재설치 후 산 것을 되찾는다. 찾으면 true.
  Future<bool> restore();
}

class StorePurchases extends Purchases {
  final _iap = InAppPurchase.instance;
  ProductDetails? _product;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<BuyResult>? _buying;
  Completer<bool>? _restoring;

  @override
  String? get price => _product?.price;

  @override
  Future<void> init() async {
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    try {
      if (!await _iap.isAvailable()) return;
      final r = await _iap.queryProductDetails({unlockAllId});
      if (r.productDetails.isNotEmpty) _product = r.productDetails.first;
    } catch (e) {
      debugPrint('IAP init failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != unlockAllId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await AppStore.i.setPremium(true);
          _buying?.complete(BuyResult.purchased);
          _restoring?.complete(true);
        case PurchaseStatus.canceled:
          _buying?.complete(BuyResult.cancelled);
        case PurchaseStatus.error:
          _buying?.complete(BuyResult.failed);
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      if (p.status != PurchaseStatus.pending) _buying = null;
    }
  }

  @override
  Future<BuyResult> buyUnlockAll() async {
    if (_product == null) await init();
    final product = _product;
    if (product == null) return BuyResult.unavailable;
    if (_buying != null) return _buying!.future;
    final c = _buying = Completer<BuyResult>();
    try {
      final ok = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!ok) {
        _buying = null;
        return BuyResult.failed;
      }
    } catch (e) {
      _buying = null;
      return BuyResult.failed;
    }
    return c.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        _buying = null;
        return BuyResult.failed;
      },
    );
  }

  void dispose() => _sub?.cancel();

  @override
  Future<bool> restore() async {
    final c = _restoring = Completer<bool>();
    try {
      await _iap.restorePurchases();
    } catch (_) {
      _restoring = null;
      return false;
    }
    // 산 기록이 없으면 스트림이 아무것도 안 보낸다 → 잠깐 기다렸다 false
    final found = await c.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => AppStore.i.premium,
    );
    _restoring = null;
    return found;
  }
}

/// 테스트·웹 미리보기용.
class FakePurchases extends Purchases {
  FakePurchases({this.result = BuyResult.purchased, this.restoreFinds = false});
  BuyResult result;
  bool restoreFinds;
  int buys = 0;

  @override
  Future<void> init() async {}

  @override
  String? get price => r'$1.99';

  @override
  Future<BuyResult> buyUnlockAll() async {
    buys++;
    if (result == BuyResult.purchased) await AppStore.i.setPremium(true);
    return result;
  }

  @override
  Future<bool> restore() async {
    if (restoreFinds) await AppStore.i.setPremium(true);
    return restoreFinds;
  }
}
