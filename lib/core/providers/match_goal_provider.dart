// lib/core/providers/match_goals_provider.dart
//
// Fetches goal-scorer data for a single match.
//
// WHY NOT just read from Firestore?  The relay uses the bulk
// /competitions/{code}/matches endpoint which does NOT include the
// goals/bookings/substitutions fields (football-data.org omits them from
// bulk responses).  Those fields are only present in the individual
// GET /matches/{id} endpoint.  We call that directly here and cache in Hive.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/live_data_service.dart';
import '../../shared/models/match.dart';

final matchGoalsProvider =
    FutureProvider.family.autoDispose<Match?, int>((ref, matchId) async {
  // Individual FD endpoint includes goals, bookings, substitutions, referees.
  final raw = await ApiService.fetchMatchDetailsRaw(
    matchId,
    isFinished: true,
  );
  if (raw != null) {
    try {
      // Ensure required fields before parsing into Match model.
      final m = Map<String, dynamic>.from(raw);
      m['competition'] ??= <String, dynamic>{'code': 'UNK', 'name': 'Unknown'};
      m['utcDate']     ??= DateTime.now().toUtc().toIso8601String();
      return Match.fromJson(m);
    } catch (_) {}
  }
  // Fallback: Firestore match doc (goals may be empty but at least has score).
  return LiveDataService.instance.getMatch(matchId);
});
