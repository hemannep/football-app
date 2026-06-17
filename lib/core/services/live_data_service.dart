// lib/core/services/live_data_service.dart
//
// READ LAYER for the relay-powered API.
//
// ─── Firestore read budget ────────────────────────────────────────────────────
//
// BEFORE (snapshots on full collections):
//   Open app           → collection('matches').snapshots()  → ~1 000 reads
//   League switch ×2   → re-subscribe × 2                  → ~2 000 reads
//   Team details       → direct watchMatches() listener    → ~1 000 reads
//   Team comparison ×2 → watchMatches().first × 2          → ~2 000 reads
//   AI insights ×2     → watchMatches().first × 2          → ~2 000 reads
//   Standings          → collection('standings').snapshots → ~60 reads
//   News               → collection('news').snapshots      → ~30 reads
//   Per-session total                                       → ~8 090 reads
//
// AFTER (in-memory TTL + meta-freshness checks):
//   Warm session (cache valid)    → 1 meta read  → ≤ 3 reads/session
//   Cold session (cache expired)  → meta + full fetches → ~1 091 reads
//   Live match detail             → single-doc snapshot  (unchanged — acceptable)
//
// Strategy
//   1. In-memory TTL cache  — per-process, zero cost for repeated widget builds.
//   2. Meta-freshness check — compare relay's lastRunIso with our Hive write timestamp.
//      Only reads from Firestore when the relay has pushed something new.
//   3. watchXxx() → async* generators that emit once immediately (from cache)
//      then re-check at the TTL interval.  No persistent collection listeners.
//   4. watchMatch() / watchMatchRaw() keep their single-doc snapshots — a live
//      match detail legitimately needs real-time pushes (1 read/update).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';
import 'api_service.dart';

class LiveDataService {
  LiveDataService._();
  static final LiveDataService instance = LiveDataService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Box get _box => Hive.box('live_cache');

  // ─── TTL constants ────────────────────────────────────────────────────────
  static const _metaTtl = Duration(minutes: 2);
  static const _matchesTtl = Duration(minutes: 5);
  static const _standingsTtl = Duration(minutes: 15);
  static const _newsTtl = Duration(minutes: 30);
  static const _staticTtl = Duration(hours: 24); // teams / players
  static const _lineupTtl = Duration(minutes: 20);

  // ─── In-memory TTL cache ─────────────────────────────────────────────────
  // Keyed by the same string used for Hive so the two layers are consistent.
  // Lives for the process lifetime — survives widget rebuilds, dies on restart.
  final Map<String, ({Object data, int expiresMs})> _mem = {};

  T? _memGet<T>(String key) {
    final e = _mem[key];
    if (e == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > e.expiresMs) {
      _mem.remove(key);
      return null;
    }
    return e.data as T?;
  }

  void _memPut(String key, Object data, Duration ttl) {
    _mem[key] = (
      data: data,
      expiresMs: DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds,
    );
  }

  /// Evict a single key from both memory and Hive so the next read is forced
  /// to go to Firestore. Useful after a manual pull-to-refresh.
  void evict(String key) {
    _mem.remove(key);
    _box.delete(key);
    _box.delete('${key}_at');
  }

  // ─── Hive helpers ─────────────────────────────────────────────────────────

  static dynamic _toJsonSafe(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.fromEntries(
        v.entries.map((e) => MapEntry(e.key.toString(), _toJsonSafe(e.value))),
      );
    }
    if (v is List) return v.map(_toJsonSafe).toList();
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is String || v is num || v is bool || v == null) return v;
    return v.toString();
  }

  void _cache(String key, Object value) {
    try {
      _box.put(key, jsonEncode(_toJsonSafe(value)));
      _box.put('${key}_at', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
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

  int? _cacheAgeMs(String key) {
    final at = _box.get('${key}_at');
    if (at is! int) return null;
    return DateTime.now().millisecondsSinceEpoch - at;
  }

  // ─── Freshness helper ─────────────────────────────────────────────────────
  // Returns true when our Hive cache for [key] was written AFTER the relay's
  // last run — meaning Firestore has nothing new for us.
  bool _hiveIsFresh(String key, RelayMeta meta) {
    final cacheAt = _box.get('${key}_at') as int?;
    if (cacheAt == null) return false;
    final relayAt = meta.lastRunIso != null
        ? DateTime.tryParse(meta.lastRunIso!)?.millisecondsSinceEpoch
        : null;
    if (relayAt == null) return false;
    return cacheAt >= relayAt;
  }

  // ─── Normalizers ──────────────────────────────────────────────────────────
  static Map<String, dynamic> _normalizeMatchDoc(Map<String, dynamic> raw) {
    final out = _toJsonSafe(raw) as Map<String, dynamic>;
    final ud = out['utcDate'];
    if (ud == null || ud.toString().isEmpty) {
      out['utcDate'] = DateTime.now().toUtc().toIso8601String();
    }
    if (out['competition'] == null) {
      out['competition'] = <String, dynamic>{
        'code': 'WC',
        'name': 'International Football 2026',
      };
    }
    return out;
  }

  static Match? _safeParseMatch(Map<String, dynamic> raw) {
    try {
      return Match.fromJson(_normalizeMatchDoc(raw));
    } catch (_) {
      return null;
    }
  }

  List<Match> _parseMatchList(List cached) => cached
      .map((e) => _safeParseMatch(Map<String, dynamic>.from(e as Map)))
      .whereType<Match>()
      .toList();

  List<GroupTable> _parseStandingsList(List cached) => cached
      .map((e) => GroupTable.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  // ─── meta/relay ───────────────────────────────────────────────────────────
  /// 1 Firestore read per 2-min window; 0 reads from memory cache after that.
  Future<RelayMeta> getMeta() async {
    const key = 'meta_relay';
    final mem = _memGet<RelayMeta>(key);
    if (mem != null) return mem;
    try {
      final doc = await _db.collection('meta').doc('relay').get();
      final data = doc.data();
      if (data != null) {
        _cache(key, data);
        final meta = RelayMeta.fromJson(data);
        _memPut(key, meta, _metaTtl);
        return meta;
      }
    } catch (_) {}
    final cached = _readCache(key);
    if (cached is Map) {
      return RelayMeta.fromJson(Map<String, dynamic>.from(cached));
    }
    return const RelayMeta(
        liveMatchIds: [], lastRunIso: null, windowOpen: false);
  }

  // ─── Matches ──────────────────────────────────────────────────────────────

  /// Cached one-shot fetch. Read cost:
  ///   • Memory hit (within 5 min)   → 0 reads
  ///   • Hive fresh vs relay meta     → 1 read (meta only)
  ///   • Stale / first run            → 1 (meta) + N (matches)
  Future<List<Match>> getMatches() async {
    const key = 'matches_all';

    // Layer 1: in-memory
    final mem = _memGet<List<Match>>(key);
    if (mem != null) return mem;

    // Layer 2: Hive freshness check against relay meta
    try {
      final meta = await getMeta();
      if (_hiveIsFresh(key, meta)) {
        final cached = _readCache(key);
        if (cached is List) {
          final list = _parseMatchList(cached);
          _memPut(key, list, _matchesTtl);
          return list;
        }
      }
    } catch (_) {
      final cached = _readCache(key);
      if (cached is List) {
        final list = _parseMatchList(cached);
        _memPut(key, list, _matchesTtl);
        return list;
      }
    }

    // Layer 3: Firestore get() — only when relay has newer data
    try {
      final snap = await _db.collection('matches').orderBy('utcDate').get();
      final list = snap.docs
          .map((d) => _safeParseMatch(d.data()))
          .whereType<Match>()
          .toList();
      _cache(key, list.map((m) => m.toJson()).toList());
      _memPut(key, list, _matchesTtl);
      return list;
    } catch (_) {}

    // Layer 4: stale Hive fallback (offline)
    final cached = _readCache(key);
    if (cached is List) return _parseMatchList(cached);
    return [];
  }

  /// TTL-aware stream. Emits immediately from cache, then re-checks every
  /// [_matchesTtl]. No persistent Firestore collection listener.
  Stream<List<Match>> watchMatches() async* {
    yield await getMatches();
    while (true) {
      await Future.delayed(_matchesTtl);
      _mem.remove('matches_all'); // expire so next getMatches() re-checks meta
      yield await getMatches();
    }
  }

  Future<List<Match>> getMatchesForDay(DateTime localDay) async {
    final all = await getMatches();
    return all.where((m) => m.sameDay(localDay)).toList();
  }

  /// Single-doc snapshot — kept for live match detail screen. Costs 1 read per
  /// Firestore push (only while viewing a live match).
  Stream<Match?> watchMatch(int matchId) {
    return _db
        .collection('matches')
        .doc(matchId.toString())
        .snapshots()
        .map((doc) => doc.exists ? _safeParseMatch(doc.data()!) : null);
  }

  Future<Match?> getMatch(int matchId) async {
    final key = 'match_$matchId';
    try {
      final doc = await _db.collection('matches').doc(matchId.toString()).get();
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

  Future<Map<String, dynamic>?> getMatchRaw(int matchId) async {
    final key = 'match_raw_$matchId';
    try {
      final doc = await _db.collection('matches').doc(matchId.toString()).get();
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

  /// Real-time single-doc stream for the match detail screen.
  /// Kept as snapshots() intentionally — 1 read per relay push, justified.
  Stream<Map<String, dynamic>?> watchMatchRaw(int matchId) {
    return _db.collection('matches').doc(matchId.toString()).snapshots().map(
        (doc) => doc.exists
            ? (_toJsonSafe(doc.data()) as Map<String, dynamic>)
            : null);
  }

  /// Smart stream that avoids a persistent Firestore listener for non-live
  /// matches.  Only live/paused matches keep the real-time snapshots() open;
  /// finished and upcoming matches get a single cached get() instead.
  Stream<Map<String, dynamic>?> watchMatchRawSmart(
      int matchId, bool isLiveOrPaused) async* {
    if (isLiveOrPaused) {
      // Real-time updates justified — relay pushes every ~5 min.
      yield* watchMatchRaw(matchId);
    } else {
      // One-shot fetch + 30-min Hive cache.  0 persistent listeners.
      final key = 'match_raw_$matchId';
      final age = _cacheAgeMs(key);
      if (age != null && age < const Duration(minutes: 30).inMilliseconds) {
        final cached = _readCache(key);
        if (cached is Map) {
          yield Map<String, dynamic>.from(cached);
          return;
        }
      }
      final data = await getMatchRaw(matchId);
      FirestoreReadCounter.increment();
      yield data;
    }
  }

  // ─── Lineups ──────────────────────────────────────────────────────────────

  /// lineups/{matchId} — written by relay.js after API-Football fetch.
  /// 20-min TTL (relay only stores lineups every 20 min when live).
  Future<Map<String, dynamic>?> getLineup(int matchId) async {
    final key = 'lineup_$matchId';

    // Memory TTL
    final mem = _memGet<Map<String, dynamic>>(key);
    if (mem != null) return mem;

    // Hive TTL (20 min)
    final age = _cacheAgeMs(key);
    if (age != null && age < _lineupTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is Map) {
        final data = Map<String, dynamic>.from(cached);
        _memPut(key, data, _lineupTtl);
        return data;
      }
    }

    // Firestore get()
    try {
      final doc = await _db.collection('lineups').doc(matchId.toString()).get();
      if (doc.exists) {
        final safe = _toJsonSafe(doc.data()) as Map<String, dynamic>;
        _cache(key, safe);
        _memPut(key, safe, _lineupTtl);
        return safe;
      }
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  // ─── Standings ────────────────────────────────────────────────────────────

  /// All standings (used by Format Guide / Qualification Simulator).
  Future<List<GroupTable>> getStandings() async {
    const key = 'standings_all';

    final mem = _memGet<List<GroupTable>>(key);
    if (mem != null) return mem;

    try {
      final meta = await getMeta();
      if (_hiveIsFresh(key, meta)) {
        final cached = _readCache(key);
        if (cached is List) {
          final list = _parseStandingsList(cached);
          _memPut(key, list, _standingsTtl);
          return list;
        }
      }
    } catch (_) {
      final cached = _readCache(key);
      if (cached is List) return _parseStandingsList(cached);
    }

    try {
      final snap = await _db.collection('standings').get();
      final raw = snap.docs.map((d) => d.data()).toList();
      if (raw.isNotEmpty) {
        _cache(key, raw);
        final list = raw.map((e) => GroupTable.fromJson(e)).toList();
        _memPut(key, list, _standingsTtl);
        return list;
      }
      // Firestore empty → relay hasn't written standings yet (only writes
      // at top-of-hour). Fall through to direct API fetch below.
    } catch (_) {}

    // ── Direct API fallback (relay not run yet / top-of-hour not hit) ─────────
    // Returns data immediately; relay will populate Firestore on next top-of-hour.
    try {
      final list = await ApiService.fetchStandings('WC');
      if (list.isNotEmpty) return list;
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is List) return _parseStandingsList(cached);
    return [];
  }

  Stream<List<GroupTable>> watchStandings() async* {
    yield await getStandings();
    while (true) {
      await Future.delayed(_standingsTtl);
      _mem.remove('standings_all');
      yield await getStandings();
    }
  }

  /// Standings for a single competition code.
  Future<List<GroupTable>> getStandingsByLeague(String competitionCode) async {
    final key = 'standings_$competitionCode';

    final mem = _memGet<List<GroupTable>>(key);
    if (mem != null) return mem;

    try {
      final meta = await getMeta();
      if (_hiveIsFresh(key, meta)) {
        final cached = _readCache(key);
        if (cached is List) {
          final list = _parseStandingsList(cached);
          _memPut(key, list, _standingsTtl);
          return list;
        }
      }
    } catch (_) {
      final cached = _readCache(key);
      if (cached is List) return _parseStandingsList(cached);
    }

    try {
      final snap = await _db
          .collection('standings')
          .where('competitionCode', isEqualTo: competitionCode)
          .get();
      final raw = snap.docs.map((d) => d.data()).toList();
      if (raw.isNotEmpty) {
        _cache(key, raw);
        final list = raw.map((e) => GroupTable.fromJson(e)).toList();
        _memPut(key, list, _standingsTtl);
        return list;
      }
    } catch (_) {}

    // Direct API fallback when Firestore standings are empty.
    try {
      final list = await ApiService.fetchStandings(competitionCode);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is List) return _parseStandingsList(cached);
    return [];
  }

  Stream<List<GroupTable>> watchStandingsByLeague(
      String competitionCode) async* {
    yield await getStandingsByLeague(competitionCode);
    while (true) {
      await Future.delayed(_standingsTtl);
      _mem.remove('standings_$competitionCode');
      yield await getStandingsByLeague(competitionCode);
    }
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

  // ─── Teams ────────────────────────────────────────────────────────────────

  /// 24-hour TTL — seed runs once daily; teams don't change mid-tournament.
  Future<Map<String, dynamic>?> getTeam(int teamId) async {
    final key = 'team_$teamId';

    final mem = _memGet<Map<String, dynamic>>(key);
    if (mem != null) return mem;

    final age = _cacheAgeMs(key);
    if (age != null && age < _staticTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is Map) {
        final data = Map<String, dynamic>.from(cached);
        _memPut(key, data, _staticTtl);
        return data;
      }
    }

    try {
      final doc = await _db.collection('teams').doc(teamId.toString()).get();
      if (doc.exists) {
        final data = doc.data()!;
        _cache(key, data);
        _memPut(key, data, _staticTtl);
        return data;
      }
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllTeams() async {
    const key = 'teams_all';

    final mem = _memGet<List<Map<String, dynamic>>>(key);
    if (mem != null) return mem;

    final age = _cacheAgeMs(key);
    if (age != null && age < _staticTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is List) {
        final list =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _memPut(key, list, _staticTtl);
        return list;
      }
    }

    try {
      final snap = await _db.collection('teams').orderBy('name').get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      _memPut(key, list, _staticTtl);
      return list;
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ─── Players ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPlayer(int playerId) async {
    final key = 'player_$playerId';

    final mem = _memGet<Map<String, dynamic>>(key);
    if (mem != null) return mem;

    final age = _cacheAgeMs(key);
    if (age != null && age < _staticTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is Map) {
        final data = Map<String, dynamic>.from(cached);
        _memPut(key, data, _staticTtl);
        return data;
      }
    }

    try {
      final doc =
          await _db.collection('players').doc(playerId.toString()).get();
      if (doc.exists) {
        final data = doc.data()!;
        _cache(key, data);
        _memPut(key, data, _staticTtl);
        return data;
      }
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is Map) return Map<String, dynamic>.from(cached);
    return null;
  }

  Future<List<Map<String, dynamic>>> getPlayersForTeam(int teamId) async {
    final key = 'players_team_$teamId';

    final mem = _memGet<List<Map<String, dynamic>>>(key);
    if (mem != null) return mem;

    final age = _cacheAgeMs(key);
    if (age != null && age < _staticTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is List) {
        final list =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _memPut(key, list, _staticTtl);
        return list;
      }
    }

    try {
      final snap = await _db
          .collection('players')
          .where('teamId', isEqualTo: teamId)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      _memPut(key, list, _staticTtl);
      return list;
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ─── News ─────────────────────────────────────────────────────────────────
  // News is time-based (hourly worker), so TTL is checked against wall-clock
  // rather than relay meta (which only tracks match data).

  Future<List<Map<String, dynamic>>> getNews({int limit = 30}) async {
    final key = 'news_$limit';

    final mem = _memGet<List<Map<String, dynamic>>>(key);
    if (mem != null) return mem;

    // Hive time-based TTL (30 min)
    final age = _cacheAgeMs(key);
    if (age != null && age < _newsTtl.inMilliseconds) {
      final cached = _readCache(key);
      if (cached is List) {
        final list =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _memPut(key, list, _newsTtl);
        return list;
      }
    }

    try {
      final snap = await _db
          .collection('news')
          .orderBy('publishedAtMs', descending: true)
          .limit(limit)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      _cache(key, list);
      _memPut(key, list, _newsTtl);
      return list;
    } catch (_) {}

    final cached = _readCache(key);
    if (cached is List) {
      return cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Stream<List<Map<String, dynamic>>> watchNews({int limit = 30}) async* {
    yield await getNews(limit: limit);
    while (true) {
      await Future.delayed(_newsTtl);
      _mem.remove('news_$limit');
      yield await getNews(limit: limit);
    }
  }
}

// ─── Relay meta model ─────────────────────────────────────────────────────────
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

// ─── Riverpod providers ───────────────────────────────────────────────────────

final liveDataServiceProvider = Provider<LiveDataService>(
  (ref) => LiveDataService.instance,
);

/// TTL-aware matches stream. Emits from cache instantly; re-fetches only when
/// the relay has written new data since our last Hive fill.
final matchesStreamProvider = StreamProvider<List<Match>>(
  (ref) => ref.watch(liveDataServiceProvider).watchMatches(),
);

/// Relay heartbeat — 1 read per 2-min window max.
final relayMetaProvider = FutureProvider<RelayMeta>(
  (ref) => ref.watch(liveDataServiceProvider).getMeta(),
);

/// All standings — TTL-aware, 15-min polling.
final standingsStreamProvider = StreamProvider<List<GroupTable>>(
  (ref) => ref.watch(liveDataServiceProvider).watchStandings(),
);

/// Standings for a single competition — TTL-aware, 15-min polling.
final standingsByLeagueProvider =
    StreamProvider.family<List<GroupTable>, String>(
  (ref, code) =>
      ref.watch(liveDataServiceProvider).watchStandingsByLeague(code),
);

/// Single match snapshot — autoDispose so the Firestore listener closes when
/// the screen is no longer visible.  Uses watchMatchRawSmart internally so
/// non-live matches do a cached get() instead of keeping a persistent listener.
final matchStreamProvider = StreamProvider.family.autoDispose<Match?, Match>(
  (ref, m) {
    final svc = ref.watch(liveDataServiceProvider);
    final live = m.isLive || m.status == 'PAUSED';
    return svc.watchMatchRawSmart(m.id, live).map((raw) {
      if (raw == null) return null;
      return LiveDataService._safeParseMatch(raw);
    });
  },
);

/// Team profile + squad. 24-hour TTL.
final teamProvider = FutureProvider.family<Map<String, dynamic>?, int>(
  (ref, teamId) => ref.watch(liveDataServiceProvider).getTeam(teamId),
);

/// Squad list for a team. 24-hour TTL.
final playersForTeamProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, teamId) => ref.watch(liveDataServiceProvider).getPlayersForTeam(teamId),
);

/// Single player. 24-hour TTL.
final playerProvider = FutureProvider.family<Map<String, dynamic>?, int>(
  (ref, playerId) => ref.watch(liveDataServiceProvider).getPlayer(playerId),
);

/// News articles. 30-min TTL.
final newsStreamProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(liveDataServiceProvider).watchNews(),
);

/// Confirmed lineup from the `lineups` collection.
/// Written by relay.js via API-Football (best-effort — may be sparse).
/// Falls back gracefully to null; lineups_tab uses bzzLineups as primary source.
final lineupProvider = FutureProvider.family<Map<String, dynamic>?, int>(
  (ref, matchId) => ref.watch(liveDataServiceProvider).getLineup(matchId),
);

// ─── Firestore daily read counter ────────────────────────────────────────────
//
// Call FirestoreReadCounter.increment() on every Firestore get() or
// snapshots() trigger that goes to the server.  The counter resets at
// midnight local time.  When todayCount ≥ 40 000 the app warns; at 48 000
// non-critical reads are suppressed.  All values live in the Hive
// 'live_cache' box so they survive process restarts within the same day.

class FirestoreReadCounter {
  static const _kCount = 'frc_count';
  static const _kDate = 'frc_date';
  static const _warnAt = 40000;
  static const _stopAt = 48000;

  static Box get _box => Hive.box('live_cache');

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  static void _resetIfNewDay() {
    if (_box.get(_kDate) != _today) {
      _box.put(_kDate, _today);
      _box.put(_kCount, 0);
    }
  }

  static void increment([int n = 1]) {
    _resetIfNewDay();
    final current = (_box.get(_kCount) as int?) ?? 0;
    _box.put(_kCount, current + n);
  }

  static int get todayCount {
    _resetIfNewDay();
    return (_box.get(_kCount) as int?) ?? 0;
  }

  static bool get isApproachingLimit => todayCount >= _warnAt;
  static bool get isCritical => todayCount >= _stopAt;
}
