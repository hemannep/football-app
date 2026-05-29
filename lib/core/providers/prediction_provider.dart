// lib/core/providers/prediction_provider.dart
//
// All Riverpod providers for the prediction + leaderboard system.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/prediction_service.dart';
import '../../shared/models/match.dart';

// ── My predictions stream ────────────────────────────────────────────────────

final myPredictionsProvider = StreamProvider<List<UserPrediction>>((ref) {
  return PredictionService.instance.myPredictionsStream();
});

// ── My stats (derived from stream) ──────────────────────────────────────────

final myStatsProvider = Provider((ref) {
  final preds = ref.watch(myPredictionsProvider).value ?? [];
  final total = preds.fold<int>(0, (acc, p) => acc + p.pointsEarned);
  final settled = preds.where((p) => p.settled).length;
  final exactScores =
      preds.where((p) => p.settled && p.pointsEarned == 5).length;
  return (
    points: total,
    submitted: preds.length,
    settled: settled,
    exactScores: exactScores,
  );
});

// ── Community stats per match ────────────────────────────────────────────────

final communityStatsProvider =
    StreamProvider.family<CommunityStats, String>((ref, matchKey) {
  return PredictionService.instance.communityStatsStream(matchKey);
});

// ── Leaderboard ──────────────────────────────────────────────────────────────

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return PredictionService.instance.leaderboardStream();
});

// ── Submit prediction (AsyncNotifier) ────────────────────────────────────────

class PredictionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required Match match,
    required int homeGoals,
    required int awayGoals,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => PredictionService.instance.submitPrediction(
              match: match,
              homeGoals: homeGoals,
              awayGoals: awayGoals,
            ));
  }
}

final predictionNotifierProvider =
    AsyncNotifierProvider<PredictionNotifier, void>(PredictionNotifier.new);
