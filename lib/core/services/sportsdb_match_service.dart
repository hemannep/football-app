// lib/core/services/sportsdb_match_service.dart
//
// TheSportsDB match-enrichment service.
//
// CRITICAL CONTEXT:
//   The API-Football free tier is locked to seasons 2021–2023 — it returns
//   `{plan: Free plans do not have access to this season}` for anything
//   newer. That makes it unusable for international 2026 or any 2025/26 match.
//
//   TheSportsDB free tier ("123" key) DOES cover current matches via the
//   lookup-by-id endpoints. The flow:
//     1. eventsday.php?d=DATE&s=Soccer  → list of soccer events that day
//     2. match by team-name normalization → get idEvent
//     3. lookuplineup.php?id=idEvent    → starting XI + substitutes
//     4. lookuptimeline.php?id=idEvent  → goal/card/sub events
//     5. lookupeventstats.php?id=idEvent → match statistics
//
// All responses cached in Hive (box 'matches_cache') to respect TheSportsDB's
// 30 req/min free limit.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../constants/api_keys.dart';

// ─── Models (mirror existing ExtrasService shapes so resolver adapts easily) ─

class SdbLineupPlayer {
  final String name;
  final int? shirtNumber;
  final String? position;
  final bool isStarting;
  const SdbLineupPlayer({
    required this.name,
    this.shirtNumber,
    this.position,
    required this.isStarting,
  });
}

class SdbTeamLineup {
  final String teamName;
  final String? formation;
  final List<SdbLineupPlayer> starters;
  final List<SdbLineupPlayer> bench;
  const SdbTeamLineup({
    required this.teamName,
    this.formation,
    required this.starters,
    required this.bench,
  });
}

class SdbMatchLineups {
  final SdbTeamLineup? home;
  final SdbTeamLineup? away;
  const SdbMatchLineups({this.home, this.away});
}

class SdbTimelineEvent {
  final int minute;
  final String type; // Goal / Yellow Card / Red Card / Substitution
  final String? detail;
  final String? player;
  final String? assistOrOff;
  final bool isHome;
  const SdbTimelineEvent({
    required this.minute,
    required this.type,
    this.detail,
    this.player,
    this.assistOrOff,
    required this.isHome,
  });
}

class SdbStat {
  final String name;
  final String home;
  final String away;
  const SdbStat({required this.name, required this.home, required this.away});
}

// ─── Service ────────────────────────────────────────────────────────────────

class SportsDbMatchService {
  static final SportsDbMatchService _instance =
      SportsDbMatchService._internal();
  factory SportsDbMatchService() => _instance;
  SportsDbMatchService._internal();

  static const bool debug =
      kDebugMode && bool.fromEnvironment('DEBUG_SPORTS_API');
  static const String _box = 'matches_cache';
  static const String _miss = '__MISS__';

  // In-flight dedup cache — prevents 3 simultaneous providers hammering SDB
  // for the same match at the same time.  The Future is shared so the HTTP
  // call is only made once; all callers await the same result.
  final Map<String, Future<String?>> _resolving = {};

  // Cache TTLs (ms)
  static const int _ttlEventId = 30 * 24 * 60 * 60 * 1000; // 30 d
  static const int _ttlLineup = 24 * 60 * 60 * 1000; // 24 h
  static const int _ttlLive = 60 * 1000; // 60 s
  static const int _ttlFinished = 24 * 60 * 60 * 1000; // 24 h

  String get _base => '${ApiKeys.sportsDbBase}/${ApiKeys.sportsDbKey}';

  void _log(String msg) {
    if (debug) debugPrint('[SportsDB] $msg');
  }

  // ─── Cache helpers ────────────────────────────────────────────────────────

  Box _getBox() => Hive.box(_box);

  dynamic _cached(String key, int ttlMs) {
    final b = _getBox();
    final raw = b.get(key);
    final at = b.get('${key}__at') as int?;
    if (raw == null || at == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - at > ttlMs) return null;
    return raw;
  }

  Future<void> _cache(String key, dynamic v) async {
    final b = _getBox();
    await b.put(key, v);
    await b.put('${key}__at', DateTime.now().millisecondsSinceEpoch);
  }

  // ─── Name normalization (same approach as ApiFootball) ────────────────────

  static const Map<String, String> _aliases = {
    'afc bournemouth': 'bournemouth',
    'tottenham hotspur fc': 'tottenham',
    'manchester united fc': 'manchester united',
    'manchester city fc': 'manchester city',
    'leeds united fc': 'leeds united',
    'newcastle united fc': 'newcastle',
    'west ham united fc': 'west ham',
    'wolverhampton wanderers fc': 'wolverhampton wanderers',
    'brighton & hove albion fc': 'brighton',
    'nottingham forest fc': 'nottingham forest',
    'fc bayern münchen': 'bayern munich',
    'fc bayern munchen': 'bayern munich',
    'paris saint-germain fc': 'paris saint-germain',
    'real madrid cf': 'real madrid',
    'fc barcelona': 'barcelona',
    'fc internazionale milano': 'internazionale',
    'inter milan': 'internazionale',
    'as roma': 'roma',
    'ssc napoli': 'napoli',
    'olympique de marseille': 'marseille',
    'olympique lyonnais': 'lyon',
    'republic of ireland': 'ireland',
    'united states': 'usa',
    'united states of america': 'usa',
    'ivory coast': "cote d'ivoire",
    'south korea': 'korea republic',
    'czech republic': 'czechia',
  };

  static const Map<String, String> _ascii = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ñ': 'n',
    'ç': 'c',
    'ß': 'ss',
  };

  String _fold(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_ascii[ch] ?? ch);
    }
    return b.toString();
  }

  String _normalize(String name) {
    var s = _fold(name.toLowerCase().trim());
    if (_aliases.containsKey(s)) s = _aliases[s]!;
    s = s.replaceAll(RegExp(r'\b(fc|cf|ac|sc|ssc|cd|rc|as|ss|us|afc)\b'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  bool _namesMatch(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final wa = na.split(' ').where((w) => w.length >= 2).toSet();
    final wb = nb.split(' ').where((w) => w.length >= 2).toSet();
    if (wa.isEmpty || wb.isEmpty) return false;
    final smaller = wa.length <= wb.length ? wa : wb;
    final larger = wa.length <= wb.length ? wb : wa;
    return smaller.every(larger.contains);
  }

  // ─── Public: resolve event ID ─────────────────────────────────────────────
  //
  // [dateUtc] should be the UTC kickoff time. We try the local date first
  // (matches the kickoff day in most cases) and ±1 day to handle UTC
  // edge cases (e.g. 22:00 BST = 21:00 UTC).
  Future<String?> resolveEventId({
    required DateTime dateUtc,
    required String homeTeam,
    required String awayTeam,
  }) {
    final dateStr = dateUtc.toUtc().toIso8601String().substring(0, 10);
    final cacheKey =
        'sdb_evt_${dateStr}_${_normalize(homeTeam)}_${_normalize(awayTeam)}';

    // Check Hive first (survives app restarts).
    final hived = _cached(cacheKey, _ttlEventId);
    if (hived != null) {
      if (hived == _miss) return Future.value(null);
      _log('cached eventId "$homeTeam vs $awayTeam" = $hived');
      return Future.value(hived as String);
    }

    // Dedup: if another caller is already resolving this exact match, share
    // the same Future instead of issuing parallel API calls.
    if (_resolving.containsKey(cacheKey)) {
      return _resolving[cacheKey]!;
    }

    final future = _doResolve(cacheKey, dateStr, homeTeam, awayTeam);
    _resolving[cacheKey] = future;
    future.whenComplete(() => _resolving.remove(cacheKey));
    return future;
  }

  Future<String?> _doResolve(
      String cacheKey, String dateStr, String homeTeam, String awayTeam) async {
    _log('resolving "$homeTeam" vs "$awayTeam" on $dateStr');

    // Try the kickoff date first, then ±1 day for timezone safety.
    final candidates = <String>[
      dateStr,
      _shiftDate(dateStr, 1),
      _shiftDate(dateStr, -1),
    ];

    for (final d in candidates) {
      final id = await _searchOnDate(d, homeTeam, awayTeam);
      if (id != null) {
        await _cache(cacheKey, id);
        return id;
      }
    }
    _log('FAILED to resolve "$homeTeam" vs "$awayTeam"');
    await _cache(cacheKey, _miss);
    return null;
  }

  String _shiftDate(String date, int days) {
    final dt = DateTime.parse(date).add(Duration(days: days));
    return dt.toIso8601String().substring(0, 10);
  }

  Future<String?> _searchOnDate(
      String dateStr, String homeTeam, String awayTeam) async {
    // Always try the generic Soccer bucket first (covers all domestic leagues).
    // Only fall back to competition-specific buckets if Soccer returns nothing,
    // because each extra call burns from the 30 req/min free limit.
    final primaryUrl = '$_base/eventsday.php?d=$dateStr&s=Soccer';
    final result = await _searchUrl(primaryUrl, homeTeam, awayTeam, dateStr);
    if (result != null) return result;

    // Secondary: competition-specific buckets for UCL / global tournament / Euro which
    // SportsDB doesn't include in the generic Soccer feed.
    for (final league in [
      'UEFA+Champions+League',
      'World+Cup',
      'UEFA+European+Championship',
    ]) {
      final url = '$_base/eventsday.php?d=$dateStr&l=$league';
      final r = await _searchUrl(url, homeTeam, awayTeam, dateStr);
      if (r != null) return r;
    }
    return null;
  }

  Future<String?> _searchUrl(
      String endpoint, String homeTeam, String awayTeam, String dateStr) async {
    try {
      final url = Uri.parse(endpoint);
      _log('GET $url');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      _log('  → status ${res.statusCode}');
      if (res.statusCode == 429) return null; // rate-limited; stop early
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final events = body['events'];
      if (events == null || events is! List || events.isEmpty) return null;
      _log('  → ${events.length} events on $dateStr');

      for (final raw in events) {
        final e = Map<String, dynamic>.from(raw as Map);
        final h = (e['strHomeTeam'] ?? '') as String;
        final a = (e['strAwayTeam'] ?? '') as String;
        if (_namesMatch(h, homeTeam) && _namesMatch(a, awayTeam)) {
          final id = e['idEvent'] as String?;
          _log('  ✓ matched "$h" vs "$a" → idEvent=$id');
          return id;
        }
      }
    } catch (e) {
      _log('eventsday error: $e');
    }
    return null;
  }

  // ─── Lineups ──────────────────────────────────────────────────────────────
  Future<SdbMatchLineups?> fetchLineups(String eventId,
      {required String homeName, required String awayName}) async {
    final key = 'sdb_lineup_$eventId';
    final cached = _cached(key, _ttlLineup);
    if (cached != null) {
      try {
        return _parseLineupsJson(
            jsonDecode(cached as String) as Map<String, dynamic>,
            homeName: homeName,
            awayName: awayName);
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$_base/lookuplineup.php?id=$eventId');
      _log('GET $url');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      _log('  → status ${res.statusCode}');
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await _cache(key, jsonEncode(body));
      return _parseLineupsJson(body, homeName: homeName, awayName: awayName);
    } catch (e) {
      _log('fetchLineups error: $e');
    }
    return null;
  }

  SdbMatchLineups? _parseLineupsJson(Map<String, dynamic> body,
      {required String homeName, required String awayName}) {
    final lineup = body['lineup'];
    if (lineup == null || lineup is! List || lineup.isEmpty) return null;

    final homePlayers = <SdbLineupPlayer>[];
    final awayPlayers = <SdbLineupPlayer>[];
    final homeBench = <SdbLineupPlayer>[];
    final awayBench = <SdbLineupPlayer>[];

    for (final raw in lineup) {
      final p = Map<String, dynamic>.from(raw as Map);
      final teamName = (p['strTeam'] ?? '') as String;
      final isHome = _namesMatch(teamName, homeName);
      final isAway = _namesMatch(teamName, awayName);
      if (!isHome && !isAway) continue;

      final isStarter = (p['strSubstitute'] ?? 'No').toString() != 'Yes';
      final player = SdbLineupPlayer(
        name: (p['strPlayer'] ?? '') as String,
        shirtNumber: int.tryParse((p['intSquadNumber'] ?? '').toString()),
        position: p['strPosition'] as String?,
        isStarting: isStarter,
      );

      if (isHome) {
        (isStarter ? homePlayers : homeBench).add(player);
      } else {
        (isStarter ? awayPlayers : awayBench).add(player);
      }
    }

    _log(
        'lineups parsed: home ${homePlayers.length}+${homeBench.length}, away ${awayPlayers.length}+${awayBench.length}');

    if (homePlayers.isEmpty && awayPlayers.isEmpty) return null;

    SdbTeamLineup? home;
    SdbTeamLineup? away;
    if (homePlayers.isNotEmpty || homeBench.isNotEmpty) {
      home = SdbTeamLineup(
        teamName: homeName,
        starters: homePlayers,
        bench: homeBench,
      );
    }
    if (awayPlayers.isNotEmpty || awayBench.isNotEmpty) {
      away = SdbTeamLineup(
        teamName: awayName,
        starters: awayPlayers,
        bench: awayBench,
      );
    }
    return SdbMatchLineups(home: home, away: away);
  }

  // ─── Timeline (goals / cards / subs) ──────────────────────────────────────
  Future<List<SdbTimelineEvent>> fetchTimeline(String eventId,
      {required String homeName, bool isFinished = false}) async {
    final key = 'sdb_tl_$eventId';
    final ttl = isFinished ? _ttlFinished : _ttlLive;
    final cached = _cached(key, ttl);
    if (cached != null) {
      try {
        return _parseTimelineJson(
            jsonDecode(cached as String) as Map<String, dynamic>,
            homeName: homeName);
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$_base/lookuptimeline.php?id=$eventId');
      _log('GET $url');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      _log('  → status ${res.statusCode}');
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await _cache(key, jsonEncode(body));
      return _parseTimelineJson(body, homeName: homeName);
    } catch (e) {
      _log('fetchTimeline error: $e');
    }
    return const [];
  }

  List<SdbTimelineEvent> _parseTimelineJson(Map<String, dynamic> body,
      {required String homeName}) {
    final tl = body['timeline'];
    if (tl == null || tl is! List) return const [];
    final out = <SdbTimelineEvent>[];
    for (final raw in tl) {
      final t = Map<String, dynamic>.from(raw as Map);
      final teamName = (t['strHome'] ?? t['strTeam'] ?? '') as String;
      out.add(SdbTimelineEvent(
        minute: int.tryParse((t['intTime'] ?? '0').toString()) ?? 0,
        type: (t['strTimeline'] ?? '') as String,
        detail: t['strTimelineDetail'] as String?,
        player: t['strPlayer'] as String?,
        assistOrOff: t['strAssist'] as String?,
        isHome: _namesMatch(teamName, homeName),
      ));
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────
  Future<List<SdbStat>> fetchStats(String eventId,
      {bool isFinished = false}) async {
    final key = 'sdb_st_$eventId';
    final ttl = isFinished ? _ttlFinished : _ttlLive;
    final cached = _cached(key, ttl);
    if (cached != null) {
      try {
        return _parseStatsJson(
            jsonDecode(cached as String) as Map<String, dynamic>);
      } catch (_) {}
    }

    try {
      final url = Uri.parse('$_base/lookupeventstats.php?id=$eventId');
      _log('GET $url');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      _log('  → status ${res.statusCode}');
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      await _cache(key, jsonEncode(body));
      return _parseStatsJson(body);
    } catch (e) {
      _log('fetchStats error: $e');
    }
    return const [];
  }

  List<SdbStat> _parseStatsJson(Map<String, dynamic> body) {
    final st = body['eventstats'];
    if (st == null || st is! List) return const [];
    final out = <SdbStat>[];
    for (final raw in st) {
      final s = Map<String, dynamic>.from(raw as Map);
      out.add(SdbStat(
        name: (s['strStat'] ?? '') as String,
        home: (s['intHome'] ?? '0').toString(),
        away: (s['intAway'] ?? '0').toString(),
      ));
    }
    return out;
  }
}
