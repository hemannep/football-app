import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'ad_service.dart';

class IapService {
  static const String productId = 'remove_ads_monthly';
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;

  static Future<bool> isAvailable() => _iap.isAvailable();

  static Future<List<ProductDetails>> products() async {
    final r = await _iap.queryProductDetails({productId});
    return r.productDetails;
  }

  static void init() {
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen((purchases) {
      var sawSubscription = false;
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          if (p.productID == productId) {
            sawSubscription = true;
            AdService.setAdsSubscriptionActive(true);
          }
        } else if (p.status == PurchaseStatus.error) {
          debugPrint('IAP purchase error: ${p.error}');
        }
        if (p.pendingCompletePurchase) _iap.completePurchase(p);
      }
      if (purchases.isNotEmpty && !sawSubscription) {
        AdService.setAdsSubscriptionActive(false);
      }
    });

    // Refresh entitlement on app start. Active subscriptions should be returned
    // by the store; if the user has cancelled/expired, the local 35-day window
    // naturally lapses instead of granting a lifetime entitlement.
    restore();
  }

  static Future<bool> buyRemoveAds() async {
    final r = await _iap.queryProductDetails({productId});
    if (r.error != null) {
      debugPrint('IAP product query error: ${r.error}');
    }
    if (r.productDetails.isEmpty) return false;
    final purchaseParam = PurchaseParam(productDetails: r.productDetails.first);
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static Future<void> restore() => _iap.restorePurchases();

  static void dispose() => _sub?.cancel();
}
