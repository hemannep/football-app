// lib/main.dart
//
// Entry point. Opens every Hive box the app touches BEFORE runApp().
//
// CRITICAL: every box that any service/provider reads with Hive.box(name)
// must be opened here, otherwise you get
//   HiveError: Box not found. Did you forget to call Hive.openBox()?
// at runtime (which is exactly what your logs show for 'app_settings').

import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/iap_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive offline cache ─────────────────────────────────────────────────
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(
        'matches_cache'), // api_service, extras_service, sportsdb_service, news_service, offline_pack_service
    Hive.openBox(
        'user_prefs'), // theme_provider, locale fallback, favorites, ads_removed, selected_league, user profile
    Hive.openBox('predictions'), // prediction_service local cache
    Hive.openBox('trivia_progress'), // trivia_screen streak + best
    Hive.openBox(
        'app_settings'), // locale_provider  ← MISSING in old main.dart, caused the crash
    Hive.openBox('fan_xp'), // fan_xp_service
    Hive.openBox('fan_polls'), // fan_polls_service
    Hive.openBox('live_cache'), // live_data_service — match / team / player / news cache
  ]);

  // ── Firebase (Auth + FCM + Crashlytics + Analytics + Remote Config) ────
  await Firebase.initializeApp();
  await FirebaseService.initialize();

  // ── Ads ────────────────────────────────────────────────────────────────
  await MobileAds.instance.initialize();

  // ── In-app purchase listener ───────────────────────────────────────────
  IapService.init();

  runApp(const ProviderScope(child: FootballFanHubApp()));
}
