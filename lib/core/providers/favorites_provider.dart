// lib/core/providers/favorites_provider.dart
//
// Tracks the user's favourite teams (by TLA). Persisted to Hive box
// 'user_prefs' under key 'favorite_teams' as a List<String>.

import 'package:hive/hive.dart';
import 'package:flutter_riverpod/legacy.dart';

class FavoritesState {
  final Set<String> teamTlas;
  const FavoritesState({this.teamTlas = const {}});

  FavoritesState copyWith({Set<String>? teamTlas}) =>
      FavoritesState(teamTlas: teamTlas ?? this.teamTlas);
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier() : super(_load());

  static FavoritesState _load() {
    try {
      final tlas = (Hive.box('user_prefs')
              .get('favorite_teams', defaultValue: <String>[]) as List)
          .cast<String>()
          .toSet();
      return FavoritesState(teamTlas: tlas);
    } catch (_) {
      return const FavoritesState();
    }
  }

  bool isFavorite(String tla) => state.teamTlas.contains(tla);

  void toggle(String tla) {
    final s = {...state.teamTlas};
    if (s.contains(tla)) {
      s.remove(tla);
    } else {
      s.add(tla);
    }
    state = state.copyWith(teamTlas: s);
    try {
      Hive.box('user_prefs').put('favorite_teams', s.toList());
    } catch (_) {/* ignore — in-memory is enough until next launch */}
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>(
        (ref) => FavoritesNotifier());