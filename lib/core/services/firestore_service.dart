import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
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

  /// Top 20 leaderboard — TTL-cached get(), not a persistent snapshots() listener.
  Stream<List<Map<String, dynamic>>> leaderboardStream() async* {
    const key   = 'fs_trivia_lb';
    const keyAt = 'fs_trivia_lb_at';
    const ttl   = 15 * 60 * 1000; // 15 min
    final box   = Hive.box('live_cache');

    final hiveRaw = box.get(key);
    if (hiveRaw != null) {
      try {
        yield (jsonDecode(hiveRaw as String) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {}
    }

    final at  = box.get(keyAt) as int?;
    final age = at == null ? null : DateTime.now().millisecondsSinceEpoch - at;
    if (age != null && age < ttl) return;

    try {
      final snap = await _db
          .collection('leaderboard')
          .orderBy('bestScore', descending: true)
          .limit(20)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      await box.put(key, jsonEncode(list));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      yield list;
    } catch (_) {}
  }
}
