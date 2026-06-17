import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'user_profile_service.dart';

/// Top-level handler required by FCM for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebase_core.Firebase.initializeApp();
  debugPrint('FCM background: ${message.notification?.title}');
  await NotificationService.instance.showRemoteMessage(message);
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  String? get userId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  // ─── Init (called from main.dart) ────────────────────────────────────────

  static Future<void> initialize() async {
    // 1. Crashlytics — catch Flutter framework errors
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // 2. Anonymous auth — gives every device a stable UID.
    await instance._signInAnonymously();

    // 3. Sync user profile after auth so we read leaderboard/{realUid}, not
    // leaderboard/anon.
    await UserProfileService.instance.syncFromFirestore();

    // 4. FCM
    await instance._initFCM();

    // 5. Remote Config — defaults so app works offline
    await instance._initRemoteConfig();

    // 6. Analytics — set user ID so events are tied to the device
    if (instance.userId != null) {
      await instance._analytics.setUserId(id: instance.userId);
    }
  }

  // ─── Anonymous Auth ───────────────────────────────────────────────────────

  Future<void> _signInAnonymously() async {
    if (_auth.currentUser != null) return; // already signed in
    try {
      await _auth.signInAnonymously();
      debugPrint('FirebaseService: signed in as ${_auth.currentUser?.uid}');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseService: auth failed — ${e.code}');
    }
  }

  // ─── FCM ──────────────────────────────────────────────────────────────────

  Future<void> _initFCM() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await NotificationService.instance.initialize();
    await NotificationService.instance.configureForegroundPresentation();

    final settings = await NotificationService.instance.requestPermissions();
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // Subscribe to topic so you can blast all users from Firebase console
    await _fcm.subscribeToTopic('wc26_all');

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('FCM foreground: ${message.notification?.title}');
      if (defaultTargetPlatform == TargetPlatform.android) {
        await NotificationService.instance.showRemoteMessage(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM opened app: ${message.messageId ?? message.data}');
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initial message: '
          '${initialMessage.messageId ?? initialMessage.data}');
    }

    _fcm.onTokenRefresh.listen((token) {
      debugPrint('FCM token refreshed: ${token.isNotEmpty}');
    });

    final token = await _fcm.getToken();
    debugPrint('FCM token available: ${token != null && token.isNotEmpty}');
    // Optionally store token in Firestore for per-user targeting
  }

  Future<void> subscribeToMatchAlerts(String matchId) =>
      _fcm.subscribeToTopic('match_$matchId');

  Future<void> unsubscribeFromMatchAlerts(String matchId) =>
      _fcm.unsubscribeFromTopic('match_$matchId');

  // ─── Remote Config ────────────────────────────────────────────────────────

  Future<void> _initRemoteConfig() async {
    // In debug mode use Duration.zero so the token is always fetched fresh
    // on every launch — critical for getting bsd_token on first run.
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 15),
      minimumFetchInterval:
          kDebugMode ? Duration.zero : const Duration(hours: 1),
    ));
    // Worker URL is the default for both providers — keys live in the Worker,
    // never in the app binary.  Remote Config can override these at runtime
    // (e.g. to point at a different Worker deployment) without a rebuild.
    await _remoteConfig.setDefaults({
      'ads_enabled': true,
      'predictor_enabled': true,
      'trivia_enabled': true,
      'api_base_url':
          'https://football-fan-hub-proxy.footballapp.workers.dev/api/fd/v4',
      'bsd_base_url':
          'https://football-fan-hub-proxy.footballapp.workers.dev/api/bsd',
      'interstitial_frequency': 3,
      'bsd_token': '', // Worker holds the real token; this stays empty
    });
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      final token = _remoteConfig.getString('bsd_token');
      debugPrint('RemoteConfig fetched (updated=$updated) '
          'bsd_token_set=${token.isNotEmpty}');
    } catch (e) {
      debugPrint('RemoteConfig fetch failed: $e');
    }
  }

  bool get adsEnabled => _remoteConfig.getBool('ads_enabled');
  bool get predictorEnabled => _remoteConfig.getBool('predictor_enabled');
  bool get triviaEnabled => _remoteConfig.getBool('trivia_enabled');
  int get interstitialFrequency =>
      _remoteConfig.getInt('interstitial_frequency');

  /// BSD token from Firebase Remote Config.
  /// Set key 'bsd_token' in the Firebase Console → Remote Config.
  String get bsdToken => _remoteConfig.getString('bsd_token');

  /// Optional Firebase Functions / proxy base URL for football-data.org.
  /// Example: https://us-central1-football-fan-hub-2026.cloudfunctions.net/api/fd
  String get apiBaseUrl => _remoteConfig.getString('api_base_url');

  /// Optional Firebase Functions / proxy base URL for BSD.
  /// Example: https://us-central1-football-fan-hub-2026.cloudfunctions.net/api/bsd
  String get bsdBaseUrl => _remoteConfig.getString('bsd_base_url');

  // ─── Analytics helpers ────────────────────────────────────────────────────

  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  Future<void> logPredictionSubmitted(String matchId) =>
      _analytics.logEvent(name: 'prediction_submitted', parameters: {
        'match_id': matchId,
        'uid': userId ?? 'anon',
      });

  Future<void> logTriviaCompleted({
    required String matchDay,
    required int score,
    required int streak,
  }) =>
      _analytics.logEvent(name: 'trivia_completed', parameters: {
        'match_day': matchDay,
        'score': score,
        'streak': streak,
      });

  Future<void> logAdRemoved() => _analytics.logEvent(name: 'iap_remove_ads');

  Future<void> logBracketSimulated() =>
      _analytics.logEvent(name: 'bracket_simulated');
}
