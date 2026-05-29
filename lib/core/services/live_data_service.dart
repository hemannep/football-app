// lib/core/services/live_data_service.dart
//
// READ LAYER for the relay-powered API.
//
// The relay (GitHub Actions) writes match/standings/lineup data into Firestore.
// This service is how the Flutter app READS it — replacing the direct
// football-data.org calls in ApiService for live tournament data.
//
// It is deliberately SEPARATE from FirestoreService (which owns user data:
// predictions, trivia, leaderboard). This file owns relay-sourced data only.
//
// Design guarantees the project demands:
//   • Riverpod-friendly: exposes a singleton + plain methods/streams that
//     providers can wrap. (Providers added at the bottom.)
//   • Offline-first: every read is mirrored into Hive ('live_cache' box).
//     If Firestore is unreachable, the last cached payload is served.
//   • Null-safe: every field is defensively parsed; missing data -> sane default.
//   • Local time: Match.fromJson() already calls .toLocal(), so all match
//     times render in the user's timezone automatically.
//   • Cheap: getMeta() reads ONE doc to learn what's live before anything else.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';

class LiveDataService {
  LiveDataService._();
  static final LiveDataService instance = LiveDataService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Box get _box => Hive.box('live_cache');

  // ─── Hive helpers ──────────────────────────────────────────────────────────

  /// Recursively converts Firestore-specific types so jsonEncode never throws.
  /// Timestamp  → ISO-8601 string
  /// GeoPoint / DocumentReference / anything else → toString()
  static dynamic _toJsonSafe(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.fromEntries(
        v.entries.map((e) => MapEntry(e.key.toString(), _toJsonSafe(e.value))),
      );
    }
    if (v is List) return v.map(_toJsonSafe).toList();
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String || v is num || v is bool || v == null) return v;
    // Fallback for GeoPoint, DocumentReference, etc.
    return v.toString();
  }

  void _cache(String key, Object value) {
    try {
      _box.put(key, jsonEncode(_toJsonSafe(value)));
      _box.put('${key}_at', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Caching is best-effort; never let it break a read.
    }
  }

  dynamic _readCache(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// How old the cached value for [key] is, in ms (or null if never cached).
  int? cacheAgeMs(String key) {
    final at = _box.get('${key}_at');
    if (at is! int) return null;
    return DateTime.now().millisecondsSinceEpoch - at;
  }

  // ─── meta/relay — read FIRST, 1 cheap doc ───────────────────────────────────
  /// Returns the relay heartbeat: { liveMatchIds, lastRunIso, windowOpen }.
  /// Falls back to cache when offline.
  Future<RelayMeta> getMeta() async {
    const key = 'meta_relay';
    try {
      final doc = await _db.collection('meta').doc('relay').get();
      final data = doc.data();
      if (data != null) {
        _cache(key, data);
        return RelayMeta.fromJson(data);
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) {
      return RelayMeta.fromJson(Map<String, dynamic>.from(cached));
    }
    return const RelayMeta(
        liveMatchIds: [], lastRunIso: null, windowOpen: false);
  }

  // ─── Match document normalisation ──────────────────────────────────────────
  /// Match.fromJson calls DateTime.parse(j['utcDate']) which only accepts
  /// strings.  The relay may write utcDate as a Firestore Timestamp or as an
  /// ISO-8601 string — both are handled here.  All other Timestamp fields are
  /// also converted so _cache (jsonEncode) never throws.
  static Map<String, dynamic> _normalizeMatchDoc(Map<String, dynamic> raw) {
    final out = _toJsonSafe(raw) as Map<String, dynamic>;
    // Ensure utcDate is always a parseable string.
    final ud = out['utcDate'];
    if (ud == null || ud.toString().isEmpty) {
      out['utcDate'] = DateTime.now().toUtc().toIso8601String();
    }
    // competition.code fallback: some relay builds omit the competition object.
    if (out['competition'] == null) {
      out['competition'] = <String, dynamic>{'code': 'WC', 'name': 'FIFA World Cup 2026'};
    }
    return out;
  }

  /// Parse a match document, returning null instead of throwing on bad data.
  static Match? _safeParseMatch(Map<String, dynamic> raw) {
    try {
      return Match.fromJson(_normalizeMatchDoc(raw));
    } catch (_) {
      return null;
    }
  }

  // ─── Matches ────────────────────────────────────────────────────────────────
  /// Real-time stream of ALL matches, ordered by kickoff.
  Stream<List<Match>> watchMatches() {
    return _db.collection('matches').orderBy('utcDate').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => _safeParseMatch(d.data()))
          .whereType<Match>()
          .toList();
      _cache('matches_all', list.map((m) => m.toJson()).toList());
      return list;
    });
  }

  /// One-shot fetch of all matches. Offline-first: serves Hive cache on failure.
  Future<List<Match>> getMatches() async {
    try {
      final snap = await _db.collection('matches').orderBy('utcDate').get();
      final list = snap.docs
          .map((d) => _safeParseMatch(d.data()))
          .whereType<Match>()
          .toList();
      _cache('matches_all', list.map((m) => m.toJson()).toList());
      return list;
    } catch (_) {}
    final cached = _readCache('matches_all');
    if (cached is List) {
      return cached
          .map((e) => _safeParseMatch(Map<String, dynamic>.from(e as Map)))
          .whereType<Match>()
          .toList();
    }
    return [];
  }

  /// Today's matches (local day), derived from the full list.
  Future<List<Match>> getMatchesForDay(DateTime localDay) async {
    final all = await getMatches();
    return all.where((m) => m.sameDay(localDay)).toList();
  }

  /// Stream a single match doc — drives live score updates on the detail screen.
  Stream<Match?> watchMatch(int matchId) {
    return _db
        .collection('matches')
        .doc(matchId.toString())
        .snapshots()
        .map((doc) => doc.exists ? _safeParseMatch(doc.data()!) : null);
  }

  /// One-shot single match with goals/cards/subs (cached, offline-safe).
  Future<Match?> getMatch(int matchId) async {
    final key = 'match_$matchId';
    try {
      final doc =
          await _db.collection('matches').doc(matchId.toString()).get();
      if (doc.exists) {
        final m = _safeParseMatch(doc.data()!);
        if (m != null) _cache(key, m.toJson());
        return m;
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) {
      return _safeParseMatch(Map<String, dynamic>.from(cached));
    }
    return null;
  }

  /// Raw match map including Bzzoiro fields (incidents, bzzLineups, liveStats…).
  /// Timestamps are converted to ISO strings so jsonEncode and the tab widgets
  /// can consume the result without cloud_firestore imports.
  Future<Map<String, dynamic>?> getMatchRaw(int matchId) async {
    final key = 'match_raw_$matchId';
    try {
      final doc =
          await _db.collection('matches').doc(matchId.toString()).get();
      if (doc.exists) {
        final safe = _toJsonSafe(doc.data()) as Map<String, dynamic>;
        _cache(key, safe);
        return safe;
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  // ─── Lineups ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLineup(int matchId) async {
    final key = 'lineup_$matchId';
    try {
      final doc = await _db.collection('lineups').doc(matchId.toString()).get();
      if (doc.exists) {
        _cache(key, doc.data()!);
        return doc.data();
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  // ─── Standings ──────────────────────────────────────────────────────────────
  /// All group tables. Each doc is { group, table:[...] }, matching
  /// GroupTable.fromJson() in standing.dart.
  Future<List<GroupTable>> getStandings() async {
    const key = 'standings_all';
    try {
      final snap = await _db.collection('standings').get();
      final raw = snap.docs.map((d) => d.data()).toList();
      _cache(key, raw);
      return raw.map((e) => GroupTable.fromJson(e)).toList();
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is List) {
      return cached
          .map((e) => GroupTable.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Live stream of standings for screens that should update during matches.
  Stream<List<GroupTable>> watchStandings() {
    return _db.collection('standings').snapshots().map((snap) {
      final raw = snap.docs.map((d) => d.data()).toList();
      _cache('standings_all', raw);
      return raw.map((e) => GroupTable.fromJson(e)).toList();
    });
  }

  // ─── Bracket ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getBracket() async {
    const key = 'bracket_current';
    try {
      final doc = await _db.collection('bracket').doc('current').get();
      if (doc.exists) {
        _cache(key, doc.data()!);
        return doc.data();
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  // ─── Teams (populated by the daily seed workflow) ─────────────────────────
  /// Full team profile + squad. Single doc read, offline-safe.
  Future<Map<String, dynamic>?> getTeam(int teamId) async {
    final key = 'team_$teamId';
    try {
      final doc = await _db.collection('teams').doc(teamId.toString()).get();
      if (doc.exists) {
        _cache(key, doc.data()!);
        return doc.data();
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  /// All 48 WC teams, sorted by name. Useful for the team picker on the
  /// Predictor/Comparison screens.
  Future<List<Map<String, dynamic>>> getAllTeams() async {
    const key = 'teams_all';
    try {
      final snap = await _db.collection('teams').orderBy('name').get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      return list;
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // ─── Players ─────────────────────────────────────────────────────────────
  /// Single player by id. Player docs include teamId/teamName/teamCrest so a
  /// player-detail screen needs only this one read.
  Future<Map<String, dynamic>?> getPlayer(int playerId) async {
    final key = 'player_$playerId';
    try {
      final doc =
          await _db.collection('players').doc(playerId.toString()).get();
      if (doc.exists) {
        _cache(key, doc.data()!);
        return doc.data();
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  /// All players for a given team. Used on the Team Details screen.
  /// (Single-field where queries are auto-indexed — no composite index needed.)
  Future<List<Map<String, dynamic>>> getPlayersForTeam(int teamId) async {
    final key = 'players_team_$teamId';
    try {
      final snap = await _db
          .collection('players')
          .where('teamId', isEqualTo: teamId)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      return list;
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // ─── News (populated hourly by scripts/news_worker.js) ────────────────────
  /// Latest [limit] football news articles, newest first.
  Future<List<Map<String, dynamic>>> getNews({int limit = 30}) async {
    final key = 'news_$limit';
    try {
      final snap = await _db
          .collection('news')
          .orderBy('publishedAtMs', descending: true)
          .limit(limit)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      return list;
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// Stream of latest news for the News screen — auto-updates when the worker
  /// publishes new articles.
  Stream<List<Map<String, dynamic>>> watchNews({int limit = 30}) {
    return _db
        .collection('news')
        .orderBy('publishedAtMs', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      _cache('news_$limit', list);
      return list;
    });
  }
}

/// Lightweight model for the meta/relay heartbeat doc.
class RelayMeta {
  final List<int> liveMatchIds;
  final String? lastRunIso;
  final bool windowOpen;

  const RelayMeta({
    required this.liveMatchIds,
    required this.lastRunIso,
    required this.windowOpen,
  });

  factory RelayMeta.fromJson(Map<String, dynamic> j) {
    final ids = (j['liveMatchIds'] as List?) ?? const [];
    return RelayMeta(
      liveMatchIds: ids.map((e) => (e as num).toInt()).toList(),
      lastRunIso: j['lastRunIso'] as String?,
      windowOpen: j['windowOpen'] == true,
    );
  }

  bool get anyLive => liveMatchIds.isNotEmpty;

  /// "Updated X min ago" label for the live screens (per the doc's checklist).
  String get freshnessLabel {
    if (lastRunIso == null) return 'Waiting for first update…';
    final last = DateTime.tryParse(lastRunIso!);
    if (last == null) return '';
    final mins = DateTime.now().toUtc().difference(last.toUtc()).inMinutes;
    if (mins <= 0) return 'Updated just now';
    if (mins == 1) return 'Updated 1 min ago';
    return 'Updated $mins min ago';
  }
}

// ─── Riverpod providers ────────────────────────────────────────────────────────
final liveDataServiceProvider = Provider<LiveDataService>(
  (ref) => LiveDataService.instance,
);

/// Real-time matches stream for Home/Fixtures.
final matchesStreamProvider = StreamProvider<List<Match>>(
  (ref) => ref.watch(liveDataServiceProvider).watchMatches(),
);

/// Relay heartbeat — drives the "Updated X min ago" label and live polling.
final relayMetaProvider = FutureProvider<RelayMeta>(
  (ref) => ref.watch(liveDataServiceProvider).getMeta(),
);

/// Live standings stream for the Standings screen.
final standingsStreamProvider = StreamProvider<List<GroupTable>>(
  (ref) => ref.watch(liveDataServiceProvider).watchStandings(),
);

/// Single match stream for the match-detail screen.
final matchStreamProvider = StreamProvider.family<Match?, int>(
  (ref, matchId) => ref.watch(liveDataServiceProvider).watchMatch(matchId),
);

/// Single team profile (with squad) by team id — for the Team Details screen.
final teamProvider = FutureProvider.family<Map<String, dynamic>?, int>(
  (ref, teamId) => ref.watch(liveDataServiceProvider).getTeam(teamId),
);

/// Single player by id — for the Player Details screen / debutant spotlight.
final playerProvider = FutureProvider.family<Map<String, dynamic>?, int>(
  (ref, playerId) => ref.watch(liveDataServiceProvider).getPlayer(playerId),
);

/// All players for a team id — for the squad list on Team Details.
final playersForTeamProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, teamId) => ref.watch(liveDataServiceProvider).getPlayersForTeam(teamId),
);

/// Live news stream for the News screen.
final newsStreamProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(liveDataServiceProvider).watchNews(),
);
