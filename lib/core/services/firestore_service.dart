import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get _uid => FirebaseService.instance.userId ?? 'anon';

  // ─── Predictions ──────────────────────────────────────────────────────────

  Future<void> savePrediction({
    required String matchId,
    required int homeGoals,
    required int awayGoals,
  }) async {
    await _db
        .collection('predictions')
        .doc(_uid)
        .collection('matches')
        .doc(matchId)
        .set({
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getPrediction(String matchId) async {
    final doc = await _db
        .collection('predictions')
        .doc(_uid)
        .collection('matches')
        .doc(matchId)
        .get();
    return doc.data();
  }

  // ─── Trivia ───────────────────────────────────────────────────────────────

  Future<void> saveTriviaResult({
    required String matchDay,
    required int score,
    required int streak,
  }) async {
    final ref = _db.collection('trivia').doc(_uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.data() ?? {};
      final currentBest = (current['bestScore'] as int?) ?? 0;
      final currentStreak = (current['bestStreak'] as int?) ?? 0;
      tx.set(
          ref,
          {
            'bestScore': score > currentBest ? score : currentBest,
            'bestStreak': streak > currentStreak ? streak : currentStreak,
            'lastPlayedDay': matchDay,
            'totalGamesPlayed': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
    // Also update leaderboard entry
    await _updateLeaderboard(score: score, streak: streak);
  }

  Future<Map<String, dynamic>?> getTriviaStats() async {
    final doc = await _db.collection('trivia').doc(_uid).get();
    return doc.data();
  }

  // ─── Leaderboard ─────────────────────────────────────────────────────────

  Future<void> _updateLeaderboard({
    required int score,
    required int streak,
  }) async {
    final ref = _db.collection('leaderboard').doc(_uid);
    await ref.set({
      'bestScore': score,
      'bestStreak': streak,
      'uid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Top 20 leaderboard — call this on the Trivia screen
  Stream<List<Map<String, dynamic>>> leaderboardStream() {
    return _db
        .collection('leaderboard')
        .orderBy('bestScore', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
