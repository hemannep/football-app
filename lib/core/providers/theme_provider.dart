import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:hive/hive.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_load());

  static ThemeMode _load() {
    try {
      final v = Hive.box('user_prefs').get('theme_mode', defaultValue: 'dark');
      return v == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    Hive.box('user_prefs')
        .put('theme_mode', state == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
    (ref) => ThemeModeNotifier());
