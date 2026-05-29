// lib/core/services/api_service.dart
//
// Complete drop-in replacement.
// What's new vs your previous version:
//   • fetchMatchById(int) — hits the per-match endpoint to get goal scorers
//     and other match-detail data the bulk /matches endpoint doesn't return.
//   • Live matches cache the detail for 30s, finished matches for 24h.
// Everything else (matches, standings, team, team matches) is unchanged.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../constants/api_constants.dart';
import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';

const _matchCacheMs = 5 * 60 * 1000; // 5 min
const _teamCacheMs = 24 * 60 * 60 * 1000; // 24 h
const _liveMatchCacheMs = 30 * 1000; // 30 s for live matches
const _finishedMatchCacheMs = 24 * 60 * 60 * 1000; // 24 h for finished matches

class ApiService {
  static const _headers = {'X-Auth-Token': ApiConstants.token};

  // ─── Matches per competition ─────────────────────────────────────────────
  static Future<List<Match>> fetchMatches(String competitionCode,
      {bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'matches_$competitionCode';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _matchCacheMs) {
        return (jsonDecode(cached) as List)
            .map((e) => Match.fromJson(e))
            .toList();
      }
    }

    try {
      final res = await http
          .get(
              Uri.parse(
                  '${ApiConstants.baseUrl}/competitions/$competitionCode/matches'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final compName = data['competition']?['name'];
        final list = (data['matches'] as List).map((e) {
          // Inject competition name (the matches endpoint doesn't echo it per match)
          final m = Map<String, dynamic>.from(e);
          m['competition'] = {'name': compName, 'code': competitionCode};
          return Match.fromJson(m);
        }).toList();
        await box.put(key, jsonEncode(list.map((m) => m.toJson()).toList()));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return list;
      }
    } catch (_) {}

    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map((e) => Match.fromJson(e))
          .toList();
    }
    return [];
  }

  // ─── Single match by ID — gets goal scorers ──────────────────────────────
  //
  // The bulk /matches endpoint returns matches WITHOUT goals.
  // To show "Saka 23'" etc., we fetch the per-match detail endpoint here.
  //
  // Finished matches cached 24h, live matches 30s.
  static Future<Match?> fetchMatchById(int matchId,
      {bool isFinished = false, bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'match_detail_$matchId';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    final maxAge = isFinished ? _finishedMatchCacheMs : _liveMatchCacheMs;
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < maxAge) {
        return Match.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
    }

    try {
      final res = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/matches/$matchId'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final m = Match.fromJson(data);
        await box.put(key, jsonEncode(m.toJson()));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return m;
      }
    } catch (_) {}

    if (cached != null) {
      return Match.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    return null;
  }

  // ─── RAW match details (lineups, bookings, substitutions, scorers) ───────
  //
  // football-data.org's /v4/matches/{id} endpoint returns the FULL match
  // representation including:
  //   • homeTeam.lineup / awayTeam.lineup        — starting XI
  //   • homeTeam.bench / awayTeam.bench          — substitutes
  //   • homeTeam.formation / awayTeam.formation  — e.g. "4-3-3"
  //   • homeTeam.coach / awayTeam.coach          — head coach
  //   • goals                                    — scorer + assist + minute
  //   • bookings                                 — yellow / red cards
  //   • substitutions                            — in / out players + minute
  //   • referees                                 — referee assignments
  //
  // Our Match model only extracts a subset, so we expose the raw map for
  // MatchDetailsResolver to mine. Same caching as fetchMatchById.
  static Future<Map<String, dynamic>?> fetchMatchDetailsRaw(int matchId,
      {bool isFinished = false, bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'match_raw_$matchId';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    final maxAge = isFinished ? _finishedMatchCacheMs : _liveMatchCacheMs;
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < maxAge) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    }

    try {
      final res = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/matches/$matchId'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await box.put(key, jsonEncode(data));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return data;
      }
    } catch (_) {}

    if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
    return null;
  }

  // ─── Standings per competition ───────────────────────────────────────────
  static Future<List<GroupTable>> fetchStandings(String competitionCode,
      {bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'standings_$competitionCode';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _matchCacheMs) {
        return (jsonDecode(cached) as List)
            .map((e) => GroupTable.fromJson(e))
            .toList();
      }
    }

    try {
      final res = await http
          .get(
              Uri.parse(
                  '${ApiConstants.baseUrl}/competitions/$competitionCode/standings'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final standings = (data['standings'] as List).map((s) {
          return {
            'group': s['group'] ?? s['stage'] ?? 'TOTAL',
            'table': s['table'] ?? []
          };
        }).toList();
        await box.put(key, jsonEncode(standings));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return standings.map((e) => GroupTable.fromJson(e)).toList();
      }
    } catch (_) {}

    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map((e) => GroupTable.fromJson(e))
          .toList();
    }
    return [];
  }

  // ─── Team detail (squad + crest + colors) ────────────────────────────────
  static Future<Map<String, dynamic>?> fetchTeam(int teamId,
      {bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'team_$teamId';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _teamCacheMs) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    }

    try {
      final res = await http
          .get(Uri.parse('${ApiConstants.baseUrl}/teams/$teamId'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await box.put(key, jsonEncode(data));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return data;
      }
    } catch (_) {}

    if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
    return null;
  }

  // ─── Team upcoming + recent matches ──────────────────────────────────────
  static Future<List<Match>> fetchTeamMatches(int teamId,
      {bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'team_matches_$teamId';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);

    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _matchCacheMs) {
        return (jsonDecode(cached) as List)
            .map((e) => Match.fromJson(e))
            .toList();
      }
    }

    try {
      final res = await http
          .get(
              Uri.parse(
                  '${ApiConstants.baseUrl}/teams/$teamId/matches?limit=20'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list =
            (data['matches'] as List).map((e) => Match.fromJson(e)).toList();
        await box.put(key, jsonEncode(list.map((m) => m.toJson()).toList()));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return list;
      }
    } catch (_) {}

    if (cached != null) {
      return (jsonDecode(cached) as List)
          .map((e) => Match.fromJson(e))
          .toList();
    }
    return [];
  }
}
