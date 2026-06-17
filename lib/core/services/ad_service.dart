// lib/core/services/ad_service.dart
//
// Monetisation strategy (revenue ≈ retention):
//
//   1. Banner       — ONE banner only, pinned above bottom nav (in app.dart).
//                     NEVER mid-screen, NEVER inside a list.
//                     Sub-screens no longer add their own AdBannerWidget; the
//                     persistent banner is always visible already.
//
//   2. Interstitial — Frequency-capped:
//                     • Min 90 s gap between any two interstitials.
//                     • Min 3 "meaningful actions" between any two.
//                     • Never on app launch (kills first impression).
//                     • Never within 10 s of app foreground.
//                     • Fires at natural transitions only:
//                         - After every 3rd prediction submit
//                         - After trivia round finishes
//                         - When user pops back from MatchDetails (rate-limited)
//
//   3. Rewarded     — Opt-in only (user taps "watch ad for hint"). Highest
//                     eCPM, zero UX harm. Already wired into trivia hints.
//
// IAP $1.99/month 'Remove Ads' subscription wipes all of the above while active.

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import '../constants/admob_ids.dart';

class AdService {
  // ── Test vs production ad unit IDs ────────────────────────────────────────
  static String get bannerId =>
      kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : AdMobIds.bannerId;
  static String get interstitialId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : AdMobIds.interstitialId;
  static String get rewardedId => kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'
      : AdMobIds.rewardedId;

  // ── Remove-ads subscription entitlement ──────────────────────────────────
  static const _adsSubActiveKey = 'ads_subscription_active';
  static const _adsSubVerifiedAtKey = 'ads_subscription_verified_at';
  static const _adsSubGraceMs = 35 * 24 * 60 * 60 * 1000;

  static bool get adsRemoved {
    final box = Hive.box('user_prefs');
    final active = box.get(_adsSubActiveKey, defaultValue: false) as bool;
    final verifiedAt = box.get(_adsSubVerifiedAtKey) as int?;
    if (!active || verifiedAt == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - verifiedAt;
    return age < _adsSubGraceMs;
  }

  static Future<void> setAdsSubscriptionActive(bool v) async {
    final box = Hive.box('user_prefs');
    await box.put(_adsSubActiveKey, v);
    await box.put(_adsSubVerifiedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  @Deprecated('Use setAdsSubscriptionActive for monthly entitlements.')
  static Future<void> setAdsRemoved(bool v) => setAdsSubscriptionActive(v);

  // ── Frequency capping for interstitials ───────────────────────────────────
  /// Minimum seconds between any two interstitials.
  static const _minIntervalSeconds = 90;

  /// Minimum number of "actions" (prediction submits, trivia rounds,
  /// match-details opens) between any two interstitials.
  static const _minActionsBetween = 3;

  /// Time the app most recently came to the foreground. Used to suppress
  /// interstitials in the first N seconds (so the user gets to USE the app
  /// before being interrupted).
  static DateTime _lastForeground = DateTime.now();
  static void markForeground() => _lastForeground = DateTime.now();
  static const _foregroundGraceSeconds = 10;

  static DateTime _lastShown =
      DateTime.fromMillisecondsSinceEpoch(0); // never shown
  static int _actionsSinceLastShown = 0;

  /// Call whenever something "meaningful" happens that would otherwise be a
  /// candidate for showing an ad (submitting a prediction, finishing trivia,
  /// opening match details, popping back from a screen). Returns the new
  /// action count so callers don't have to read it back.
  static int recordAction() {
    _actionsSinceLastShown++;
    return _actionsSinceLastShown;
  }

  /// True when *all* frequency caps allow an interstitial to be shown right
  /// now. Use this before calling [showInterstitialIfReady].
  static bool get canShowInterstitial {
    if (adsRemoved) return false;
    if (_interstitial == null) return false; // not preloaded
    final now = DateTime.now();
    if (now.difference(_lastForeground).inSeconds < _foregroundGraceSeconds) {
      return false;
    }
    if (now.difference(_lastShown).inSeconds < _minIntervalSeconds) {
      return false;
    }
    if (_actionsSinceLastShown < _minActionsBetween) {
      return false;
    }
    return true;
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  static BannerAd? createBanner({void Function()? onLoaded}) {
    if (adsRemoved) return null;
    final ad = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner failed: ${err.code} ${err.message}');
          ad.dispose();
        },
      ),
    );
    ad.load();
    return ad;
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  static InterstitialAd? _interstitial;
  static bool _loadingInterstitial = false;

  static Future<void> loadInterstitial() async {
    if (adsRemoved || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  /// Try to show an interstitial respecting all frequency caps.
  /// Returns true if an ad was actually shown.
  static bool showInterstitialIfReady() {
    if (!canShowInterstitial) return false;
    final ad = _interstitial!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _interstitial = null;
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _interstitial = null;
        loadInterstitial();
      },
    );
    ad.show();
    _interstitial = null;
    _lastShown = DateTime.now();
    _actionsSinceLastShown = 0;
    return true;
  }

  /// LEGACY API — kept so old call sites compile. Internally redirects to
  /// the frequency-capped version. Use [showInterstitialIfReady] for new
  /// code where you want to know whether the ad actually fired.
  static void showInterstitial() {
    if (!showInterstitialIfReady()) {
      // Still preload for next time.
      loadInterstitial();
    }
  }

  // ── Rewarded (opt-in only) ────────────────────────────────────────────────
  static Future<void> showRewarded(VoidCallback onReward) async {
    if (adsRemoved) {
      onReward();
      return;
    }
    await RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) => a.dispose(),
            onAdFailedToShowFullScreenContent: (a, _) {
              a.dispose();
              onReward();
            },
          );
          ad.show(onUserEarnedReward: (_, __) => onReward());
        },
        onAdFailedToLoad: (err) {
          onReward();
        },
      ),
    );
  }
}
