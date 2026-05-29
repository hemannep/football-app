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

void _log(String m) {
  if (kDebugMode) debugPrint('[BSD] $m');
}

class BsdService {
  static Map<String, String> get _headers => {
        'Authorization': 'Token ${ApiKeys.bsdToken}',
        'Accept': 'application/json',
      };

  static bool get _hasToken =>
      ApiKeys.bsdToken.isNotEmpty &&
      ApiKeys.bsdToken != 'PASTE_YOUR_BSD_TOKEN_HERE';

  // ─── Resolve fd.org match → BSD event id ───────────────────────────────────
  //
  // Cached permanently (30d) under bsd_evt_<matchKey>.
  static Future<int?> resolveEventId({
    required DateTime utcDate,
    required String homeName,
    required String awayName,
  }) async {
    if (!_hasToken) {
      _log('No BSD token set — skipping. Add it in api_keys.dart.');
      return null;
    }

    final box = Hive.box('matches_cache');
    final dateStr = utcDate.toIso8601String().substring(0, 10);
    final key = 'bsd_evt_${dateStr}_${_loose(homeName)}_${_loose(awayName)}';
    final keyAt = '${key}_at';

    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < const Duration(days: 30).inMilliseconds) {
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
    await box.put(key, null);
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

    final url = Uri.parse('${ApiKeys.bsdBase}/events/'
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
      final url = Uri.parse('${ApiKeys.bsdBase}/events/$eventId/lineups/');
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

  // BSD lineup shape (defensive): expects something like
  //   { "home": {"formation": "...", "starters": [...], "bench": [...]},
  //     "away": {...} }
  // where each player has name / shirt_number / position.
  static MatchLineups? _parseLineups(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);

    TeamLineup? side(dynamic raw) {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      final starters =
          (m['starters'] ?? m['lineup'] ?? m['startXI'] ?? []) as List;
      final bench = (m['bench'] ?? m['substitutes'] ?? []) as List;
      if (starters.isEmpty && bench.isEmpty) return null;

      LineupPlayer parse(dynamic p, bool starting) {
        final pm = Map<String, dynamic>.from(p as Map);
        return LineupPlayer(
          name:
              (pm['name'] ?? pm['player_name'] ?? pm['player'] ?? '') as String,
          shirtNumber:
              _asInt(pm['shirt_number'] ?? pm['number'] ?? pm['shirtNumber']),
          position: _shortPos(
              (pm['position'] ?? pm['pos'] ?? pm['role'])?.toString()),
          isStarting: starting,
          isCaptain: (pm['is_captain'] ?? pm['captain'] ?? false) == true,
        );
      }

      return TeamLineup(
        formation: (m['formation'] ?? m['formation_str'])?.toString(),
        starters: starters.map((p) => parse(p, true)).toList(),
        bench: bench.map((p) => parse(p, false)).toList(),
      );
    }

    final home = side(map['home'] ?? map['home_lineup']);
    final away = side(map['away'] ?? map['away_lineup']);
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
      final url = Uri.parse('${ApiKeys.bsdBase}/events/$eventId/incidents/');
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
            ? (data['incidents'] ?? data['results'] ?? []) as List
            : const []);
    final out = <MatchIncident>[];
    for (final e in raw) {
      final m = Map<String, dynamic>.from(e as Map);
      final type =
          (m['type'] ?? m['incident_type'] ?? '').toString().toLowerCase();
      final minute = _asInt(m['minute'] ?? m['time'] ?? m['min']) ?? 0;
      // home/away resolution: BSD gives team_id; compare to home if provided,
      // else fall back to an explicit is_home/side field.
      bool isHome;
      final teamId = _asInt(m['team_id'] ?? m['team']);
      if (homeTeamId != null && teamId != null) {
        isHome = teamId == homeTeamId;
      } else {
        final side =
            (m['side'] ?? m['team_side'] ?? '').toString().toLowerCase();
        isHome = side == 'home' || (m['is_home'] == true);
      }

      String mappedType;
      String? subtype;
      if (type.contains('goal')) {
        mappedType = 'goal';
        if (type.contains('own')) subtype = 'ownGoal';
        if (type.contains('pen')) subtype = 'penalty';
      } else if (type.contains('red') || type.contains('yellowred')) {
        mappedType = 'redCard';
      } else if (type.contains('yellow') || type.contains('card')) {
        mappedType = 'yellowCard';
      } else if (type.contains('sub')) {
        mappedType = 'substitution';
      } else {
        continue; // ignore unknown incident types
      }

      out.add(MatchIncident(
        minute: minute,
        type: mappedType,
        player:
            (m['player'] ?? m['player_name'] ?? m['player_in'] ?? m['scorer'])
                ?.toString(),
        assistOrOff:
            (m['assist'] ?? m['assist_name'] ?? m['player_out'])?.toString(),
        isHome: isHome,
        subtype: subtype,
      ));
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
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
      final url = Uri.parse('${ApiKeys.bsdBase}/events/$eventId/stats/');
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
    final home = (map['home'] ?? map['home_stats']) as Map?;
    final away = (map['away'] ?? map['away_stats']) as Map?;
    if (home == null || away == null) return const [];
    final h = Map<String, dynamic>.from(home);
    final a = Map<String, dynamic>.from(away);

    // (label, key) pairs in display order. Keys are best-effort; missing ones
    // are skipped so we never show empty rows.
    const rows = <List<String>>[
      ['Possession', 'possession'],
      ['Shots', 'shots'],
      ['Shots on target', 'shots_on_target'],
      ['Shots off target', 'shots_off_target'],
      ['Total shots', 'total_shots'],
      ['Corners', 'corners'],
      ['Fouls', 'fouls'],
      ['Offsides', 'offsides'],
      ['Yellow cards', 'yellow_cards'],
      ['Red cards', 'red_cards'],
      ['Passes', 'passes'],
      ['Pass accuracy', 'pass_accuracy_pct'],
      ['Saves', 'saves'],
    ];

    final out = <MatchStat>[];
    for (final r in rows) {
      final label = r[0], k = r[1];
      final hv = _statValue(h[k]);
      final av = _statValue(a[k]);
      if (hv == null && av == null) continue;
      final suffix = (k == 'possession' || k == 'pass_accuracy_pct') ? '%' : '';
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
      return (m['value'] ?? m['pct'] ?? m['total']) as num?;
    }
    return num.tryParse(v.toString());
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
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
