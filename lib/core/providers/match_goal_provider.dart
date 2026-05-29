// lib/core/providers/match_goals_provider.dart
//
// Lazily fetches the goal-scorer list for a single match from Firestore.
// The match document in the relay already contains the full goals array, so
// no separate API call is needed — we reuse LiveDataService.getMatch().

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/live_data_service.dart';
import '../../shared/models/match.dart';

final matchGoalsProvider =
    FutureProvider.family.autoDispose<Match?, int>((ref, matchId) async {
  return LiveDataService.instance.getMatch(matchId);
});
