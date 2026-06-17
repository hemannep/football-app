// lib/core/services/bsd_service.dart
//
// Bzzoiro Sports Data (BSD) — match detail enrichment on the free tier.
//
// football-data.org's free tier does NOT include lineups, bookings, subs, or
// match statistics (those are paid TIER_THREE). BSD provides all of that for
// free with no rate limits, so we use it for the match-details screen only.
//
// FLOW
//   1. Our app's Match.id is a football-data.org id — BSD doesn't know it.
//      So we resolve a BSD event id by (date, home team, away team).
//   2. With the BSD event id we hit the v2 sub-resources:
//        /events/{id}/lineups    → MatchLineups
//        /events/{id}/incidents  → List<MatchIncident>
//        /events/{id}/stats      → List<MatchStat>
//   3. Resolved event ids are cached 30 days (the mapping is permanent).
//      Lineups/stats/incidents cached 12h finished / 30s live.
//
// All parsing is defensive: BSD field names are best-effort mapped, and any
// missing field degrades gracefully to null/empty rather than throwing.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../constants/api_keys.dart';
import 'extras_service.dart';
import 'firebase_service.dart';

void _log(String m) {
  const enabled = bool.fromEnvironment('DEBUG_SPORTS_API');
  if (kDebugMode && enabled) debugPrint('[BSD] $m');
}

class BsdService {
  static const _miss = '__MISS__';

  /// Runtime token: Remote Config takes precedence over the compile-time
  /// --dart-define fallback so the token can be rotated without a rebuild.
  static String get _token {
    final rc = FirebaseService.instance.bsdToken;
    if (rc.isNotEmpty) return rc;
    return ApiKeys.bsdToken; // --dart-define=BSD_TOKEN=... fallback
  }

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (!_usingProxy) 'Authorization': 'Token $_token',
      };

  static String get _baseUrl {
    final remote = FirebaseService.instance.bsdBaseUrl.trim();
    return remote.isNotEmpty ? remote : ApiKeys.bsdBase;
  }

  static bool get _usingProxy => !_baseUrl.contains('sports.bzzoiro.com');

  static bool get _hasToken {
    if (_usingProxy) return true;
    final t = _token;
    final ok = t.isNotEmpty && t != 'PASTE_YOUR_BSD_TOKEN_HERE';
    if (!ok) {
      _log(
          'Token missing — RC="${FirebaseService.instance.bsdToken.isEmpty ? "empty" : "set"}" '
          'dart-define="${ApiKeys.bsdToken.isEmpty ? "empty" : "set"}". '
          'Set bsd_token in Firebase Remote Config or pass --dart-define=BSD_TOKEN=...');
    }
    return ok;
  }

  // ─── Resolve fd.org match → BSD event id ───────────────────────────────────
  //
  // Cached permanently (30d) under bsd_evt_<matchKey>.
  static Future<int?> resolveEventId({
    required DateTime utcDate,
    required String homeName,
    required String awayName,
  }) async {
    if (!_hasToken) {
      _log('No BSD token set — skipping enrichment fetch.');
      return null;
    }

    final box = Hive.box('matches_cache');
    final dateStr = utcDate.toIso8601String().substring(0, 10);
    final key = 'bsd_evt_${dateStr}_${_loose(homeName)}_${_loose(awayName)}';
    final keyAt = '${key}_at';

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < const Duration(days: 30).inMilliseconds) {
        if (cached == _miss || cached == null) return null;
        return cached as int?;
      }
    }

    // Search a ±1 day window (timezone slack) using the team_name filter.
    for (final probe in [homeName, awayName]) {
      final id = await _searchEvent(dateStr, probe, homeName, awayName);
      if (id != null) {
        await box.put(key, id);
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
        return id;
      }
    }
    _log('FAILED to resolve "$homeName" vs "$awayName" on $dateStr');
    // Cache the miss for a day so we don't hammer on every screen open.
    await box.put(key, _miss);
    await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
    return null;
  }

  static Future<int?> _searchEvent(
      String dateStr, String probeTeam, String home, String away) async {
    // Widen the date window by a day on each side for timezone differences.
    final d = DateTime.parse(dateStr);
    final from = d.subtract(const Duration(days: 1));
    final to = d.add(const Duration(days: 1));
    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);

    final url = Uri.parse('$_baseUrl/events/'
        '?team_name=${Uri.encodeQueryComponent(probeTeam)}'
        '&date_from=$fromStr&date_to=$toStr&limit=50');
    _log('GET $url');
    try {
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → status ${res.statusCode}');
      if (res.statusCode != 200) {
        final snip =
            res.body.length > 160 ? res.body.substring(0, 160) : res.body;
        _log('  → body: $snip');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      _log('  → ${results.length} candidate events');
      final lh = _loose(home), la = _loose(away);
      for (final e in results) {
        final m = Map<String, dynamic>.from(e as Map);
        final h = _loose((m['home_team'] ?? '') as String);
        final a = _loose((m['away_team'] ?? '') as String);
        // Accept either orientation; team names from different sources vary
        // slightly so we use a contains-both fuzzy check.
        final matchA = (_similar(h, lh) && _similar(a, la));
        final matchB = (_similar(h, la) && _similar(a, lh));
        if (matchA || matchB) {
          final id = m['id'] as int?;
          _log('  ✓ matched event id=$id');
          return id;
        }
      }
    } catch (e) {
      _log('  EXCEPTION $e');
    }
    return null;
  }

  // ─── Lineups ───────────────────────────────────────────────────────────────
  static Future<MatchLineups?> fetchLineups(int eventId,
      {bool isLive = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'bsd_lineups_$eventId';
    final keyAt = '${key}_at';
    final ttl = isLive ? 30 * 1000 : 12 * 60 * 60 * 1000;

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < ttl) {
        return MatchLineups.fromJson(
            jsonDecode(cached as String) as Map<String, dynamic>);
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/events/$eventId/lineups/');
      _log('GET $url');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → lineups status ${res.statusCode}');
      if (res.statusCode != 200) return _cachedLineups(box, key);
      final data = jsonDecode(res.body);
      final lineups = _parseLineups(data);
      if (lineups != null) {
        await box.put(key, jsonEncode(lineups.toJson()));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      }
      return lineups;
    } catch (e) {
      _log('  lineups EXCEPTION $e');
      return _cachedLineups(box, key);
    }
  }

  static MatchLineups? _cachedLineups(Box box, String key) {
    final c = box.get(key);
    if (c == null) return null;
    try {
      return MatchLineups.fromJson(
          jsonDecode(c as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // BSD lineup shapes vary between documented examples and live payloads.
  // Accept both nested team objects and flat rows; normalize into the tiny
  // app model used by the pitch UI.
  static MatchLineups? _parseLineups(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);

    TeamLineup? side(dynamic raw) {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      final explicitStarterRows = m['starters'] ??
          m['starting_xi'] ??
          m['startingXI'] ??
          m['start_xi'] ??
          m['startXI'];
      final fallbackRows = m['lineup'] ?? m['players'];
      var starters = _asList(explicitStarterRows ?? fallbackRows);
      var bench = _asList(m['bench'] ??
          m['substitutes'] ??
          m['subs'] ??
          m['substitute_players']);
      if (explicitStarterRows == null &&
          fallbackRows != null &&
          bench.isEmpty) {
        final mixed = _asList(fallbackRows).whereType<Map>().toList();
        starters = mixed
            .where((row) =>
                (_asBool(row['is_substitute'] ??
                        row['substitute'] ??
                        row['isSubstitute'] ??
                        row['strSubstitute']) ??
                    false) ==
                false)
            .toList();
        bench = mixed
            .where((row) =>
                (_asBool(row['is_substitute'] ??
                        row['substitute'] ??
                        row['isSubstitute'] ??
                        row['strSubstitute']) ??
                    false) ==
                true)
            .toList();
      }
      if (starters.isEmpty && bench.isEmpty) return null;

      LineupPlayer parse(dynamic p, bool starting) {
        final pm = Map<String, dynamic>.from(p as Map);
        final player = pm['player'] is Map
            ? Map<String, dynamic>.from(pm['player'] as Map)
            : pm;
        return LineupPlayer(
          name: (player['name'] ??
                  player['player_name'] ??
                  pm['player_name'] ??
                  pm['name'] ??
                  '')
              .toString(),
          shirtNumber: _asInt(player['shirt_number'] ??
              player['shirtNumber'] ??
              player['number'] ??
              pm['shirt_number'] ??
              pm['shirtNumber'] ??
              pm['number'] ??
              pm['jersey']),
          position: _shortPos((player['position'] ??
                  player['pos'] ??
                  player['role'] ??
                  pm['position'] ??
                  pm['pos'] ??
                  pm['role'])
              ?.toString()),
          isStarting: starting,
          isCaptain:
              (player['is_captain'] ?? player['captain'] ?? pm['captain']) ==
                  true,
        );
      }

      return TeamLineup(
        formation: (m['formation'] ?? m['formation_str'])?.toString(),
        starters: starters.map((p) => parse(p, true)).toList(),
        bench: bench.map((p) => parse(p, false)).toList(),
      );
    }

    final root = map['lineups'] is Map
        ? Map<String, dynamic>.from(map['lineups'] as Map)
        : map;

    var home = side(root['home'] ?? root['home_lineup'] ?? root['homeLineup']);
    var away = side(root['away'] ?? root['away_lineup'] ?? root['awayLineup']);

    final flat = _asList(root['lineup'] ?? root['players']);
    if ((home == null || away == null) && flat.isNotEmpty) {
      final homeStarters = <LineupPlayer>[];
      final homeBench = <LineupPlayer>[];
      final awayStarters = <LineupPlayer>[];
      final awayBench = <LineupPlayer>[];

      for (final item in flat.whereType<Map>()) {
        final row = Map<String, dynamic>.from(item);
        final isHome = _isHomeRow(row);
        if (isHome == null) continue;
        final isSub = _asBool(row['is_substitute'] ??
                row['substitute'] ??
                row['isSubstitute'] ??
                row['strSubstitute']) ??
            false;
        final name =
            _nameFrom(row['name'] ?? row['player_name'] ?? row['player']);
        final player = LineupPlayer(
          name: name ?? '',
          shirtNumber: _asInt(
              row['shirt_number'] ?? row['shirtNumber'] ?? row['number']),
          position: _shortPos(
              (row['position'] ?? row['pos'] ?? row['strPosition'])
                  ?.toString()),
          isStarting: !isSub,
          isCaptain: _asBool(row['is_captain'] ?? row['captain']) ?? false,
        );
        if (player.name.trim().isEmpty) continue;
        final target = isHome
            ? (isSub ? homeBench : homeStarters)
            : (isSub ? awayBench : awayStarters);
        target.add(player);
      }

      home ??= (homeStarters.isEmpty && homeBench.isEmpty)
          ? null
          : TeamLineup(
              formation:
                  (root['home_formation'] ?? root['homeFormation'])?.toString(),
              starters: homeStarters,
              bench: homeBench,
            );
      away ??= (awayStarters.isEmpty && awayBench.isEmpty)
          ? null
          : TeamLineup(
              formation:
                  (root['away_formation'] ?? root['awayFormation'])?.toString(),
              starters: awayStarters,
              bench: awayBench,
            );
    }

    if (home == null && away == null) return null;
    return MatchLineups(home: home, away: away);
  }

  // ─── Incidents (goals + cards + subs) ──────────────────────────────────────
  static Future<List<MatchIncident>> fetchIncidents(int eventId,
      {bool isLive = false, int? homeTeamId}) async {
    final box = Hive.box('matches_cache');
    final key = 'bsd_inc_$eventId';
    final keyAt = '${key}_at';
    final ttl = isLive ? 30 * 1000 : 12 * 60 * 60 * 1000;

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < ttl) {
        final list = (jsonDecode(cached as String) as List)
            .map((j) => MatchIncident.fromJson(j as Map<String, dynamic>))
            .toList();
        return list;
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/events/$eventId/incidents/');
      _log('GET $url');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → incidents status ${res.statusCode}');
      if (res.statusCode != 200) return _cachedIncidents(box, key);
      final data = jsonDecode(res.body);
      final list = _parseIncidents(data, homeTeamId);
      await box.put(key, jsonEncode(list.map((i) => i.toJson()).toList()));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      return list;
    } catch (e) {
      _log('  incidents EXCEPTION $e');
      return _cachedIncidents(box, key);
    }
  }

  static List<MatchIncident> _cachedIncidents(Box box, String key) {
    final c = box.get(key);
    if (c == null) return const [];
    try {
      return (jsonDecode(c as String) as List)
          .map((j) => MatchIncident.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<MatchIncident> _parseIncidents(dynamic data, int? homeTeamId) {
    final raw = data is List
        ? data
        : (data is Map
            ? _asList(data['incidents'] ?? data['results'])
            : const []);
    final out = <MatchIncident>[];
    for (final e in raw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(e);
      final type =
          (m['type'] ?? m['incident_type'] ?? '').toString().toLowerCase();
      final detail =
          (m['detail'] ?? m['card_type'] ?? m['cardType'] ?? m['subtype'] ?? '')
              .toString()
              .toLowerCase();
      final time = m['time'] is Map ? m['time'] as Map : null;
      final minute =
          _asInt(m['minute'] ?? time?['elapsed'] ?? m['time'] ?? m['min']) ?? 0;
      // home/away resolution: BSD gives team_id; compare to home if provided,
      // else fall back to an explicit is_home/side field.
      bool isHome;
      final teamId = _idFrom(m['team_id'] ?? m['team']);
      if (homeTeamId != null && teamId != null) {
        isHome = teamId == homeTeamId;
      } else {
        final side = _isHomeRow(m);
        isHome = side ?? false;
      }

      String mappedType;
      String? subtype;
      if (type.contains('goal')) {
        mappedType = 'goal';
        if (type.contains('own') || detail.contains('own')) subtype = 'ownGoal';
        if (type.contains('pen') || detail.contains('pen')) subtype = 'penalty';
      } else if (type.contains('red') || type.contains('yellowred')) {
        mappedType = 'redCard';
      } else if (type.contains('yellow') || type.contains('card')) {
        mappedType = detail.contains('red') ? 'redCard' : 'yellowCard';
      } else if (type.contains('sub')) {
        mappedType = 'substitution';
      } else {
        continue; // ignore unknown incident types
      }

      out.add(MatchIncident(
        minute: minute,
        type: mappedType,
        player: _nameFrom(m['player'] ??
            m['player_name'] ??
            m['player_in'] ??
            m['playerIn'] ??
            m['scorer']),
        assistOrOff: _nameFrom(m['assist'] ??
            m['assist_name'] ??
            m['player_out'] ??
            m['playerOut'] ??
            m['assistOrOff']),
        isHome: isHome,
        subtype: subtype,
      ));
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
  }

  // ─── Player stats ──────────────────────────────────────────────────────────
  //
  // BSD /events/{id}/player-stats/ — per-player ratings, goals, assists, shots,
  // passes, tackles, etc.  Updates every minute during live matches.
  // TTL: 60s live / 12h finished.
  static Future<List<PlayerMatchStat>> fetchPlayerStats(int eventId,
      {bool isLive = false, int? homeTeamId}) async {
    final box = Hive.box('matches_cache');
    final key = 'bsd_pstats_$eventId';
    final keyAt = '${key}_at';
    final ttl = isLive ? 60 * 1000 : 12 * 60 * 60 * 1000;

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < ttl) {
        return (jsonDecode(cached as String) as List)
            .map((j) => PlayerMatchStat.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/events/$eventId/player-stats/');
      _log('GET $url');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → player-stats status ${res.statusCode}');
      if (res.statusCode != 200) return _cachedPlayerStats(box, key);
      final data = jsonDecode(res.body);
      final list = _parsePlayerStats(data, homeTeamId);
      await box.put(key, jsonEncode(list.map((s) => s.toJson()).toList()));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      return list;
    } catch (e) {
      _log('  player-stats EXCEPTION $e');
      return _cachedPlayerStats(box, key);
    }
  }

  static List<PlayerMatchStat> _cachedPlayerStats(Box box, String key) {
    final c = box.get(key);
    if (c == null) return const [];
    try {
      return (jsonDecode(c as String) as List)
          .map((j) => PlayerMatchStat.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<PlayerMatchStat> _parsePlayerStats(
      dynamic data, int? homeTeamId) {
    final raw = data is List
        ? data
        : (data is Map
            ? _asList(
                data['player_stats'] ?? data['results'] ?? data['players'])
            : const []);
    final out = <PlayerMatchStat>[];
    for (final item in raw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(item);
      final teamId = _asInt(m['team_id']);
      final isHome = homeTeamId != null && teamId != null
          ? teamId == homeTeamId
          : _isHomeRow(m) ?? false;
      final name =
          _nameFrom(m['player_name'] ?? m['name'] ?? m['player']) ?? '';
      if (name.isEmpty) continue;
      out.add(PlayerMatchStat(
        playerId: _asInt(m['player_id'] ?? m['id']),
        teamId: teamId,
        isHome: isHome,
        name: name,
        position: _shortPos((m['position'] ?? m['pos'])?.toString()),
        minutesPlayed: _asInt(m['minutes_played'] ?? m['minutes']) ?? 0,
        rating: _asDouble(m['rating']),
        isSubstitute: _asBool(m['substitute'] ?? m['is_substitute']) ?? false,
        goals: _asInt(m['goals'] ?? m['goals_scored']) ?? 0,
        assists: _asInt(m['goal_assist'] ?? m['assists']) ?? 0,
        expectedGoals: _asDouble(m['expected_goals'] ?? m['xg']),
        expectedAssists: _asDouble(m['expected_assists'] ?? m['xa']),
        totalShots: _asInt(m['total_shots'] ?? m['shots']) ?? 0,
        shotsOnTarget: _asInt(m['shots_on_target']) ?? 0,
        totalPasses: _asInt(m['total_pass'] ?? m['passes']) ?? 0,
        accuratePasses: _asInt(m['accurate_pass'] ?? m['accurate_passes']) ?? 0,
        keyPasses: _asInt(m['key_pass'] ?? m['key_passes']),
        totalTackles: _asInt(m['total_tackle'] ?? m['tackles']) ?? 0,
        interceptions: _asInt(m['interception'] ?? m['interceptions']) ?? 0,
        yellowCards: _asInt(m['yellow_card'] ?? m['yellow_cards']) ?? 0,
        redCards: _asInt(m['red_card'] ?? m['red_cards']) ?? 0,
        saves: _asInt(m['saves']),
      ));
    }
    return out;
  }

  // ─── Metadata (funfacts, jerseys, AI preview) ───────────────────────────────
  //
  // BSD /events/{id}/metadata/ — editorial pre-match content.
  // TTL: 6h (content is set before kickoff and doesn't change mid-match).
  static Future<MatchMetadata?> fetchMetadata(int eventId) async {
    final box = Hive.box('matches_cache');
    final key = 'bsd_meta_$eventId';
    final keyAt = '${key}_at';
    const ttl = 6 * 60 * 60 * 1000;

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < ttl) {
        return MatchMetadata.fromJson(
            jsonDecode(cached as String) as Map<String, dynamic>);
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/events/$eventId/metadata/');
      _log('GET $url');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → metadata status ${res.statusCode}');
      if (res.statusCode != 200) return _cachedMetadata(box, key);
      final data = jsonDecode(res.body);
      final meta = _parseMetadata(data);
      if (meta != null && !meta.isEmpty) {
        await box.put(key, jsonEncode(meta.toJson()));
        await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      }
      return meta;
    } catch (e) {
      _log('  metadata EXCEPTION $e');
      return _cachedMetadata(box, key);
    }
  }

  static MatchMetadata? _cachedMetadata(Box box, String key) {
    final c = box.get(key);
    if (c == null) return null;
    try {
      return MatchMetadata.fromJson(
          jsonDecode(c as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static MatchMetadata? _parseMetadata(dynamic data) {
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);

    final rawFacts = _asList(m['funfacts'] ?? m['fun_facts'] ?? m['facts']);
    final funfacts = rawFacts
        .whereType<Map>()
        .map((f) {
          final fm = Map<String, dynamic>.from(f);
          return MatchFunFact(
            typeId: _asInt(fm['type_id'] ?? fm['typeId']) ?? 0,
            sentence: (fm['sentence'] ?? fm['text'] ?? '').toString().trim(),
          );
        })
        .where((f) => f.sentence.isNotEmpty)
        .toList();

    final aiPreviewRaw = m['ai_preview'];
    final aiPreview = aiPreviewRaw is Map
        ? aiPreviewRaw['text']?.toString()
        : aiPreviewRaw?.toString();

    final jerseyRaw = m['jerseys'] is Map ? m['jerseys'] as Map : null;
    MatchJerseys? jerseys;
    if (jerseyRaw != null) {
      JerseyColors? parseSide(dynamic raw) {
        if (raw is! Map) return null;
        final r = Map<String, dynamic>.from(raw);
        // BSD: {player: {primary, secondary}, GK: {primary, secondary}}
        final player = r['player'] is Map
            ? Map<String, dynamic>.from(r['player'] as Map)
            : r;
        final primary =
            player['primary']?.toString() ?? player['color']?.toString();
        final secondary =
            player['secondary']?.toString() ?? player['stripe']?.toString();
        if (primary == null && secondary == null) return null;
        return JerseyColors(primary: primary, secondary: secondary);
      }

      jerseys = MatchJerseys(
        home: parseSide(jerseyRaw['home']),
        away: parseSide(jerseyRaw['away']),
      );
    }

    final meta = MatchMetadata(
      funfacts: funfacts,
      aiPreview: aiPreview,
      jerseys: jerseys,
    );
    return meta.isEmpty ? null : meta;
  }

  // ─── Stats (possession, shots, corners …) ──────────────────────────────────
  static Future<List<MatchStat>> fetchStats(int eventId,
      {bool isLive = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'bsd_stats_$eventId';
    final keyAt = '${key}_at';
    final ttl = isLive ? 30 * 1000 : 12 * 60 * 60 * 1000;

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < ttl) {
        return (jsonDecode(cached as String) as List)
            .map((j) => MatchStat.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/events/$eventId/stats/');
      _log('GET $url');
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      _log('  → stats status ${res.statusCode}');
      if (res.statusCode != 200) return _cachedStats(box, key);
      final data = jsonDecode(res.body);
      final list = _parseStats(data);
      await box.put(key, jsonEncode(list.map((s) => s.toJson()).toList()));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      return list;
    } catch (e) {
      _log('  stats EXCEPTION $e');
      return _cachedStats(box, key);
    }
  }

  static List<MatchStat> _cachedStats(Box box, String key) {
    final c = box.get(key);
    if (c == null) return const [];
    try {
      return (jsonDecode(c as String) as List)
          .map((j) => MatchStat.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // BSD v2 stats are split per side and use structured ratio objects:
  //   {"value": 2, "total": 14, "pct": 14}
  // We render a friendly subset in a fixed order.
  static List<MatchStat> _parseStats(dynamic data) {
    if (data is! Map) return const [];
    final map = Map<String, dynamic>.from(data);
    final stats = map['stats'] is Map
        ? Map<String, dynamic>.from(map['stats'] as Map)
        : map;
    final home = (stats['home'] ?? stats['home_stats']) as Map?;
    final away = (stats['away'] ?? stats['away_stats']) as Map?;
    if (home == null || away == null) return const [];
    final h = Map<String, dynamic>.from(home);
    final a = Map<String, dynamic>.from(away);

    // (label, key) pairs in display order. Keys are best-effort; missing ones
    // are skipped so we never show empty rows.
    const rows = <List<String>>[
      ['Possession', 'possession,ball_possession'],
      ['Shots on Goal', 'shots_on_target,shots_on_goal,on_target'],
      ['Shots off Goal', 'shots_off_target,shots_off_goal,off_target'],
      ['Total Shots', 'total_shots,shots'],
      ['Blocked Shots', 'blocked_shots,shots_blocked'],
      ['Shots inside Box', 'shots_inside_box,shots_insidebox'],
      ['Shots outside Box', 'shots_outside_box,shots_outsidebox'],
      ['Corner Kicks', 'corners,corner_kicks'],
      ['Fouls', 'fouls'],
      ['Offsides', 'offsides'],
      ['Yellow Cards', 'yellow_cards'],
      ['Red Cards', 'red_cards'],
      ['Passes', 'passes'],
      ['Pass Accuracy', 'pass_accuracy_pct,pass_accuracy'],
      ['Tackles', 'tackles,total_tackle,total_tackles'],
      ['Saves', 'saves'],
    ];

    final out = <MatchStat>[];
    for (final r in rows) {
      final label = r[0], keys = r[1].split(',');
      final hv = _firstStatValue(h, keys);
      final av = _firstStatValue(a, keys);
      if (hv == null && av == null) continue;
      final suffix =
          label == 'Possession' || label == 'Pass Accuracy' ? '%' : '';
      out.add(MatchStat(
        name: label,
        homeValue: '${hv ?? 0}$suffix',
        awayValue: '${av ?? 0}$suffix',
      ));
    }
    return out;
  }

  // Stat values can be a number, or {"value":x,"total":y,"pct":z}.
  static num? _statValue(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      return _statValue(m['value'] ?? m['pct'] ?? m['total']);
    }
    return num.tryParse(v.toString());
  }

  static num? _firstStatValue(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final value = _statValue(m[key]);
      if (value != null) return value;
    }
    return null;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  static List _asList(dynamic v) => v is List ? v : const [];

  static bool? _asBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == 'yes' || s == '1' || s == 'home') return true;
    if (s == 'false' || s == 'no' || s == '0' || s == 'away') return false;
    return null;
  }

  static bool? _isHomeRow(Map<String, dynamic> row) {
    final direct = _asBool(row['is_home'] ??
        row['isHome'] ??
        row['home'] ??
        row['strHome'] ??
        row['team_side'] ??
        row['side']);
    if (direct != null) return direct;
    final side =
        (row['side'] ?? row['team_side'] ?? '').toString().toLowerCase();
    if (side == 'home') return true;
    if (side == 'away') return false;
    return null;
  }

  static String? _nameFrom(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.trim().isEmpty ? null : v.trim();
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final name = m['name'] ?? m['player_name'] ?? m['strPlayer'];
      if (name != null && name.toString().trim().isNotEmpty) {
        return name.toString().trim();
      }
    }
    return v.toString();
  }

  static int? _idFrom(dynamic v) {
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      return _asInt(m['id'] ?? m['team_id'] ?? m['teamId']);
    }
    return _asInt(v);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _loose(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // Fuzzy: one name contains the distinctive part of the other. Handles
  // "FC Bayern München" vs "Bayern Munich" by comparing the longest token.
  static bool _similar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    // Compare the longest 4+ char run shared.
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    for (var len = shorter.length; len >= 4; len--) {
      for (var i = 0; i + len <= shorter.length; i++) {
        if (longer.contains(shorter.substring(i, i + len))) return true;
      }
    }
    return false;
  }

  static String? _shortPos(String? full) {
    if (full == null) return null;
    final s = full.toLowerCase();
    if (s.contains('keep') || s.contains('goal') || s == 'g' || s == 'gk') {
      return 'G';
    }
    if (s.contains('back') || s.contains('defen') || s == 'd') return 'D';
    if (s.contains('mid') || s == 'm') return 'M';
    if (s.contains('forward') ||
        s.contains('strik') ||
        s.contains('attack') ||
        s.contains('wing') ||
        s == 'f') {
      return 'F';
    }
    return null;
  }
}
