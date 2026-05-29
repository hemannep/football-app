import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'ad_service.dart';

class IapService {
  static const String productId = 'remove_ads_lifetime';
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  static Future<bool> isAvailable() => _iap.isAvailable();

  static Future<List<ProductDetails>> products() async {
    final r = await _iap.queryProductDetails({productId});
    return r.productDetails;
  }

  static void init() {
    _sub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          if (p.productID == productId) AdService.setAdsRemoved(true);
        }
        if (p.pendingCompletePurchase) _iap.completePurchase(p);
      }
    });
  }

  static Future<void> buyRemoveAds() async {
    final r = await _iap.queryProductDetails({productId});
    if (r.productDetails.isEmpty) return;
    final purchaseParam = PurchaseParam(productDetails: r.productDetails.first);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static Future<void> restore() => _iap.restorePurchases();

  static void dispose() => _sub?.cancel();
}
