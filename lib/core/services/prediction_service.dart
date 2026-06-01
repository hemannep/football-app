// lib/core/services/prediction_service.dart
//
// Handles all Firestore reads/writes for the prediction system:
//   • Save / update a user prediction
//   • Settle predictions once a match finishes (auto point calculation)
//   • Fetch community prediction stats for a match (% home/draw/away)
//   • Leaderboard stream (top 50 users by points)

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../shared/models/match.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

class UserPrediction {
  final String matchKey;
  final String uid;
  final String countryCode;
  final String homeTla;
  final String awayTla;
  final String homeName;
  final String awayName;
  final int homeGoals;
  final int awayGoals;
  final DateTime submittedAt;
  final int pointsEarned;
  final bool settled;

  const UserPrediction({
    required this.matchKey,
    required this.uid,
    required this.homeTla,
    required this.countryCode,
    required this.awayTla,
    required this.homeName,
    required this.awayName,
    required this.homeGoals,
    required this.awayGoals,
    required this.submittedAt,
    required this.pointsEarned,
    required this.settled,
  });

  // Who the user predicted to win
  String get predictedWinner {
    if (homeGoals > awayGoals) return homeTla;
    if (awayGoals > homeGoals) return awayTla;
    return 'DRAW';
  }

  factory UserPrediction.fromMap(Map<String, dynamic> m) => UserPrediction(
        matchKey: m['matchKey'] ?? '',
        uid: m['uid'] ?? '',
        homeTla: m['homeTla'] ?? '',
        awayTla: m['awayTla'] ?? '',
        homeName: m['homeName'] ?? '',
        awayName: m['awayName'] ?? '',
        homeGoals: m['homeGoals'] ?? 0,
        awayGoals: m['awayGoals'] ?? 0,
        submittedAt: m['submittedAt'] is Timestamp
            ? (m['submittedAt'] as Timestamp).toDate()
            : DateTime.tryParse(m['submittedAt']?.toString() ?? '') ??
                DateTime.now(),
        pointsEarned: m['pointsEarned'] ?? 0,
        settled: m['settled'] ?? false,
        countryCode: '',
      );

  Map<String, dynamic> toMap() => {
        'matchKey': matchKey,
        'uid': uid,
        'homeTla': homeTla,
        'awayTla': awayTla,
        'homeName': homeName,
        'awayName': awayName,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'pointsEarned': pointsEarned,
        'settled': settled,
      };
}

class LeaderboardEntry {
  final String uid;
  final String countryCode;
  final String displayName;
  final int totalPoints;
  final int predictionsCount;
  final int correctScores; // exact score predictions
  final DateTime lastUpdated;

  const LeaderboardEntry({
    required this.countryCode,
    required this.uid,
    required this.displayName,
    required this.totalPoints,
    required this.predictionsCount,
    required this.correctScores,
    required this.lastUpdated,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
        countryCode: m['countryCode'] ?? '',
        uid: m['uid'] ?? '',
        displayName: m['displayName'] ??
            'Fan #${(m['uid'] ?? '').toString().substring(0, 6)}',
        totalPoints: m['totalPoints'] ?? 0,
        predictionsCount: m['predictionsCount'] ?? 0,
        correctScores: m['correctScores'] ?? 0,
        lastUpdated: m['lastUpdated'] is Timestamp
            ? (m['lastUpdated'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

class CommunityStats {
  final int totalPredictions;
  final int homePredictions;
  final int drawPredictions;
  final int awayPredictions;

  const CommunityStats({
    required this.totalPredictions,
    required this.homePredictions,
    required this.drawPredictions,
    required this.awayPredictions,
  });

  double get homePct =>
      totalPredictions == 0 ? 0 : homePredictions / totalPredictions;
  double get drawPct =>
      totalPredictions == 0 ? 0 : drawPredictions / totalPredictions;
  double get awayPct =>
      totalPredictions == 0 ? 0 : awayPredictions / totalPredictions;

  factory CommunityStats.fromMap(Map<String, dynamic> m) => CommunityStats(
        totalPredictions: m['total'] ?? 0,
        homePredictions: m['home'] ?? 0,
        drawPredictions: m['draw'] ?? 0,
        awayPredictions: m['away'] ?? 0,
      );

  static const empty = CommunityStats(
    totalPredictions: 0,
    homePredictions: 0,
    drawPredictions: 0,
    awayPredictions: 0,
  );
}

// ─── Service ─────────────────────────────────────────────────────────────────

// Hive TTL keys for cached Firestore reads (avoids persistent snapshots()).
const _kMyPredsAt  = 'ps_my_preds_at';
const _kCommStatsPrefix = 'ps_comm_';
const _kLbKey  = 'ps_leaderboard';
const _kLbAt   = 'ps_leaderboard_at';
const _kMyPredsListKey = 'ps_my_preds_list';

// TTLs (ms)
const _kMyPredsTtl   = 10 * 60 * 1000; // 10 min
const _kCommStatsTtl =  5 * 60 * 1000; //  5 min
const _kLbTtl        = 15 * 60 * 1000; // 15 min

class PredictionService {
  PredictionService._();
  static final PredictionService instance = PredictionService._();

  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anon';

  // ── Collection references ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _myPreds =>
      _db.collection('predictions').doc(_uid).collection('matches');

  DocumentReference<Map<String, dynamic>> _leaderboardDoc() =>
      _db.collection('leaderboard').doc(_uid);

  DocumentReference<Map<String, dynamic>> _communityDoc(String matchKey) =>
      _db.collection('match_predictions').doc(matchKey);

  // ── Save / update a prediction ───────────────────────────────────────────

  Future<void> submitPrediction({
    required Match match,
    required int homeGoals,
    required int awayGoals,
  }) async {
    final pred = UserPrediction(
      matchKey: match.matchKey,
      uid: _uid,
      homeTla: match.homeTeam.tla,
      awayTla: match.awayTeam.tla,
      homeName: match.homeTeam.name,
      awayName: match.awayTeam.name,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      submittedAt: DateTime.now(),
      pointsEarned: 0,
      settled: false,
      countryCode: '',
    );

    // 1. Save user's personal prediction
    await _myPreds.doc(match.matchKey).set(pred.toMap());

    // 2. Update community aggregation atomically
    final winner = pred.predictedWinner;
    final increment = FieldValue.increment(1);
    await _communityDoc(match.matchKey).set({
      'total': increment,
      'home':
          winner == match.homeTeam.tla ? increment : FieldValue.increment(0),
      'draw': winner == 'DRAW' ? increment : FieldValue.increment(0),
      'away':
          winner == match.awayTeam.tla ? increment : FieldValue.increment(0),
      'matchKey': match.matchKey,
      'homeTla': match.homeTeam.tla,
      'awayTla': match.awayTeam.tla,
    }, SetOptions(merge: true));

    // 3. Cache locally in Hive too (offline fallback)
    await Hive.box('predictions').put(match.matchKey, {
      'matchKey': match.matchKey,
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'homeTla': match.homeTeam.tla,
      'awayTla': match.awayTeam.tla,
      'homeName': match.homeTeam.name,
      'awayName': match.awayTeam.name,
      'submittedAt': DateTime.now().toIso8601String(),
      'pointsEarned': 0,
      'settled': false,
    });
  }

  // ── Settle predictions once a match finishes ─────────────────────────────
  // Call this from your live score provider when status → FINISHED

  Future<void> settleMatch(Match match) async {
    if (!match.isFinished) return;
    final actualHome = match.score.homeGoals;
    final actualAway = match.score.awayGoals;
    if (actualHome == null || actualAway == null) return;

    try {
      final doc = await _myPreds.doc(match.matchKey).get();
      if (!doc.exists) return;

      final pred = UserPrediction.fromMap(doc.data()!);
      if (pred.settled) return; // already settled

      final pts = _calcPoints(
        predHome: pred.homeGoals,
        predAway: pred.awayGoals,
        actualHome: actualHome,
        actualAway: actualAway,
      );
      final isExact =
          pred.homeGoals == actualHome && pred.awayGoals == actualAway;

      // Update prediction doc
      await _myPreds.doc(match.matchKey).update({
        'pointsEarned': pts,
        'settled': true,
      });

      // Update leaderboard using transaction to avoid race conditions
      await _db.runTransaction((tx) async {
        final lb = await tx.get(_leaderboardDoc());
        final current = lb.data() ?? {};
        tx.set(
          _leaderboardDoc(),
          {
            'uid': _uid,
            'displayName':
                current['displayName'] ?? 'Fan #${_uid.substring(0, 6)}',
            'totalPoints': (current['totalPoints'] ?? 0) + pts,
            'predictionsCount': (current['predictionsCount'] ?? 0) + 1,
            'correctScores':
                (current['correctScores'] ?? 0) + (isExact ? 1 : 0),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Also update Hive cache
      final hiveBox = Hive.box('predictions');
      final cached = hiveBox.get(match.matchKey);
      if (cached is Map) {
        final updated = Map<String, dynamic>.from(cached);
        updated['pointsEarned'] = pts;
        updated['settled'] = true;
        await hiveBox.put(match.matchKey, updated);
      }
    } catch (e) {
      debugPrint('PredictionService.settleMatch error: $e');
    }
  }

  // ── Fetch my prediction for a single match ───────────────────────────────

  Future<UserPrediction?> getMyPrediction(String matchKey) async {
    try {
      final doc = await _myPreds.doc(matchKey).get();
      if (!doc.exists) return null;
      return UserPrediction.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ── Stream all my predictions (for stats card) ───────────────────────────
  // One-shot get() with 10-min Hive cache. Re-fetches after submission via
  // ref.invalidate(myPredictionsProvider) in the notifier.

  Stream<List<UserPrediction>> myPredictionsStream() async* {
    final box = Hive.box('predictions');

    // Serve Hive cache immediately so the UI is never blank.
    final hiveRaw = box.get(_kMyPredsListKey);
    if (hiveRaw != null) {
      try {
        final list = (jsonDecode(hiveRaw as String) as List)
            .map((e) => UserPrediction.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        yield list;
      } catch (_) {}
    }

    // Respect TTL — skip Firestore if cache is fresh.
    final at = box.get(_kMyPredsAt) as int?;
    final age = at == null ? null
        : DateTime.now().millisecondsSinceEpoch - at;
    if (age != null && age < _kMyPredsTtl) return;

    try {
      final snap =
          await _myPreds.orderBy('submittedAt', descending: true).get();
      final preds =
          snap.docs.map((d) => UserPrediction.fromMap(d.data())).toList();
      await box.put(
          _kMyPredsListKey,
          jsonEncode(preds.map((p) => p.toMap()).toList()));
      await box.put(_kMyPredsAt, DateTime.now().millisecondsSinceEpoch);
      yield preds;
    } catch (_) {}
  }

  // Invalidate the my-predictions cache so the next watch() re-fetches.
  Future<void> invalidateMyPredictions() async {
    await Hive.box('predictions').delete(_kMyPredsAt);
  }

  // ── Community stats for a match ──────────────────────────────────────────
  // One-shot get() with 5-min Hive cache — no persistent collection listener.

  Stream<CommunityStats> communityStatsStream(String matchKey) async* {
    final box = Hive.box('predictions');
    final cacheKey = '$_kCommStatsPrefix$matchKey';
    final cacheAt  = '${cacheKey}_at';

    final hiveRaw = box.get(cacheKey);
    if (hiveRaw != null) {
      try {
        yield CommunityStats.fromMap(
            jsonDecode(hiveRaw as String) as Map<String, dynamic>);
      } catch (_) {}
    }

    final at = box.get(cacheAt) as int?;
    final age = at == null ? null
        : DateTime.now().millisecondsSinceEpoch - at;
    if (age != null && age < _kCommStatsTtl) return;

    try {
      final snap = await _communityDoc(matchKey).get();
      if (snap.exists && snap.data() != null) {
        final stats = CommunityStats.fromMap(snap.data()!);
        await box.put(cacheKey, jsonEncode(snap.data()));
        await box.put(cacheAt, DateTime.now().millisecondsSinceEpoch);
        yield stats;
      } else {
        yield CommunityStats.empty;
      }
    } catch (_) {}
  }

  // ── Leaderboard (top 50) ─────────────────────────────────────────────────
  // One-shot get() with 15-min Hive cache — was a persistent 50-doc listener.

  Stream<List<LeaderboardEntry>> leaderboardStream() async* {
    final box = Hive.box('predictions');

    final hiveRaw = box.get(_kLbKey);
    if (hiveRaw != null) {
      try {
        final list = (jsonDecode(hiveRaw as String) as List)
            .map((e) => LeaderboardEntry.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList();
        yield list;
      } catch (_) {}
    }

    final at = box.get(_kLbAt) as int?;
    final age = at == null ? null
        : DateTime.now().millisecondsSinceEpoch - at;
    if (age != null && age < _kLbTtl) return;

    try {
      final snap = await _db
          .collection('leaderboard')
          .orderBy('totalPoints', descending: true)
          .limit(50)
          .get();
      final entries =
          snap.docs.map((d) => LeaderboardEntry.fromMap(d.data())).toList();
      await box.put(
          _kLbKey, jsonEncode(snap.docs.map((d) => d.data()).toList()));
      await box.put(_kLbAt, DateTime.now().millisecondsSinceEpoch);
      yield entries;
    } catch (_) {}
  }

  // ── Set a display name (optional, users can personalise) ─────────────────

  Future<void> setDisplayName(String name) async {
    await _leaderboardDoc().set(
      {'displayName': name, 'uid': _uid},
      SetOptions(merge: true),
    );
  }

  // ── Points calculator ────────────────────────────────────────────────────

  int _calcPoints({
    required int predHome,
    required int predAway,
    required int actualHome,
    required int actualAway,
  }) {
    if (predHome == actualHome && predAway == actualAway) return 5; // exact
    final predSign = predHome.compareTo(predAway);
    final actualSign = actualHome.compareTo(actualAway);
    if (predSign == actualSign) return 3; // correct result
    return 0;
  }
}
