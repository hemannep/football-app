// lib/core/providers/locale_provider.dart
//
// Riverpod state holder for the user's selected locale.
//
// Persistence: Hive box 'app_settings', key 'locale'. Stored as a language
// code string (e.g. "en", "hi", "ja"). On startup we read it; setLocale()
// writes it back so the choice survives restarts.
//
// IMPORTANT: 'app_settings' box must be opened in main.dart BEFORE this
// provider is read. Old main.dart was missing that call, which caused the
// runtime HiveError seen on language selection.

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The 12 locales the app supports — keep in sync with the AppL10n
/// supportedLocales (generated automatically from the ARB files).
const supportedLanguageCodes = <String>[
  'en',
  'hi',
  'ne',
  'es',
  'fr',
  'de',
  'ru',
  'zh',
  'ja',
  'ko',
  'pt',
  'ar',
];

/// Optional: human-readable native names for each language, shown in the
/// language picker. The English name is included as a fallback for screen
/// readers / accessibility.
const languageNativeNames = <String, String>{
  'en': 'English',
  'hi': 'हिन्दी',
  'ne': 'नेपाली',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'ru': 'Русский',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'pt': 'Português',
  'ar': 'العربية',
};

const languageEnglishNames = <String, String>{
  'en': 'English',
  'hi': 'Hindi',
  'ne': 'Nepali',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'ru': 'Russian',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'pt': 'Portuguese',
  'ar': 'Arabic',
};

/// State notifier. Holds the current Locale. Writes through to Hive.
class LocaleController extends StateNotifier<Locale> {
  LocaleController(super.initial);

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final box = Hive.box('app_settings');
      await box.put('locale', locale.languageCode);
    } catch (e) {
      // Box not open — fail soft, the locale still updates in memory.
      debugPrint('LocaleController.setLocale: box not open — $e');
    }
  }
}

/// Reads the stored locale on startup, defaulting to system locale if it's
/// supported, otherwise English.
Locale resolveInitialLocale() {
  try {
    final box = Hive.box('app_settings');
    final stored = box.get('locale') as String?;
    if (stored != null && supportedLanguageCodes.contains(stored)) {
      return Locale(stored);
    }
  } catch (_) {
    // Hive not open yet — fall through.
  }
  // System locale, if supported.
  final system = WidgetsBinding.instance.platformDispatcher.locale;
  if (supportedLanguageCodes.contains(system.languageCode)) {
    return Locale(system.languageCode);
  }
  return const Locale('en');
}

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController(resolveInitialLocale());
});
