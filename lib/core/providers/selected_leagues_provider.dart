// lib/core/providers/selected_leagues_provider.dart
//
// Tracks the user's currently-selected competition (e.g. WC, PL, LL).
// Persisted to Hive 'user_prefs' under key 'selected_league'.

import 'package:hive/hive.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../shared/models/leagues.dart';

class SelectedLeagueNotifier extends StateNotifier<League> {
  SelectedLeagueNotifier() : super(_load());

  static League _load() {
    try {
      final code = Hive.box('user_prefs')
          .get('selected_league', defaultValue: 'WC') as String;
      return Leagues.fromCode(code);
    } catch (_) {
      return Leagues.wc;
    }
  }

  void select(League l) {
    state = l;
    try {
      Hive.box('user_prefs').put('selected_league', l.code);
    } catch (_) {/* in-memory only until next launch */}
  }
}

final selectedLeagueProvider =
    StateNotifierProvider<SelectedLeagueNotifier, League>(
        (ref) => SelectedLeagueNotifier());
