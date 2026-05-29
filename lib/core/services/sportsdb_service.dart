// lib/core/services/sportsdb_service.dart
//
// TheSportsDB free-tier integration + Wikipedia photo fallback.
//
// Photo lookup pipeline for a single player:
//   1. searchplayers.php?p={name}     → TheSportsDB (free, has most pros)
//   2. Wikipedia API thumbnail        → fallback (no key, has nearly everyone)
//
// All player metadata (bio, career, position, height, nationality)
// also comes via TheSportsDB searchplayers — which lets us power the
// player-detail page.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../constants/api_keys.dart';

class SportsDbTeam {
  final String? teamId;
  final String name;
  final String? country;
  final String? badgeUrl;
  final String? logoUrl;
  final String? stadiumName;
  final String? stadiumImage;
  final String? anthemUrl;
  final String? description;
  final int? founded;
  final String? jerseyUrl;

  const SportsDbTeam({
    this.teamId,
    required this.name,
    this.country,
    this.badgeUrl,
    this.logoUrl,
    this.stadiumName,
    this.stadiumImage,
    this.anthemUrl,
    this.description,
    this.founded,
    this.jerseyUrl,
  });

  factory SportsDbTeam.fromJson(Map<String, dynamic> j) => SportsDbTeam(
        teamId: j['idTeam'] as String?,
        name: (j['strTeam'] ?? '') as String,
        country: j['strCountry'] as String?,
        badgeUrl: j['strBadge'] as String?,
        logoUrl: j['strLogo'] as String?,
        stadiumName: j['strStadium'] as String?,
        stadiumImage: j['strStadiumThumb'] as String?,
        anthemUrl: j['strTeamAnthem'] as String?,
        description: j['strDescriptionEN'] as String?,
        founded: int.tryParse((j['intFormedYear'] ?? '') as String),
        jerseyUrl:
            j['strEquipment'] as String? ?? j['strKitColour1'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'idTeam': teamId,
        'strTeam': name,
        'strCountry': country,
        'strBadge': badgeUrl,
        'strLogo': logoUrl,
        'strStadium': stadiumName,
        'strStadiumThumb': stadiumImage,
        'strTeamAnthem': anthemUrl,
        'strDescriptionEN': description,
        'intFormedYear': founded?.toString(),
        'strEquipment': jerseyUrl,
      };
}

class SportsDbPlayer {
  final String? playerId;
  final String name;
  final String? position;
  final String? nationality;
  final String? team;
  final String? photoUrl;
  final String? thumbUrl;
  final String? description;
  final int? birthYear;
  final String? height;
  final String? weight;
  final String? wage;

  const SportsDbPlayer({
    this.playerId,
    required this.name,
    this.position,
    this.nationality,
    this.team,
    this.photoUrl,
    this.thumbUrl,
    this.description,
    this.birthYear,
    this.height,
    this.weight,
    this.wage,
  });

  factory SportsDbPlayer.fromJson(Map<String, dynamic> j) {
    int? year;
    final dob = j['dateBorn'] as String?;
    if (dob != null && dob.length >= 4) {
      year = int.tryParse(dob.substring(0, 4));
    }
    return SportsDbPlayer(
      playerId: j['idPlayer'] as String?,
      name: (j['strPlayer'] ?? '') as String,
      position: j['strPosition'] as String?,
      nationality: j['strNationality'] as String?,
      team: j['strTeam'] as String?,
      photoUrl: j['strCutout'] as String?,
      thumbUrl: j['strThumb'] as String?,
      description: j['strDescriptionEN'] as String?,
      birthYear: year,
      height: j['strHeight'] as String?,
      weight: j['strWeight'] as String?,
      wage: j['strWage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'idPlayer': playerId,
        'strPlayer': name,
        'strPosition': position,
        'strNationality': nationality,
        'strTeam': team,
        'strCutout': photoUrl,
        'strThumb': thumbUrl,
        'strDescriptionEN': description,
        'dateBorn': birthYear?.toString(),
        'strHeight': height,
        'strWeight': weight,
        'strWage': wage,
      };
}

// ─── National team aliases & TLA maps ───────────────────────────────────────

const Map<String, String> _nationalTeamAliases = {
  'czechia': 'Czech Republic',
  'usa': 'United States',
  'us': 'United States',
  'united states': 'United States',
  'south korea': 'Korea Republic',
  'korea republic': 'Korea Republic',
  'korea': 'Korea Republic',
  'north korea': 'Korea DPR',
  'iran': 'Iran',
  'ivory coast': 'Ivory Coast',
  "côte d'ivoire": 'Ivory Coast',
  'cote d ivoire': 'Ivory Coast',
  'cape verde': 'Cape Verde',
  'cabo verde': 'Cape Verde',
  'curaçao': 'Curacao',
  'curacao': 'Curacao',
  'dr congo': 'DR Congo',
  'congo dr': 'DR Congo',
  'bosnia': 'Bosnia and Herzegovina',
  'bosnia and herzegovina': 'Bosnia and Herzegovina',
  'england': 'England',
  'wales': 'Wales',
  'scotland': 'Scotland',
  'north macedonia': 'North Macedonia',
  'macedonia': 'North Macedonia',
  'españa': 'Spain',
  'brasil': 'Brazil',
};

const Map<String, String> _tlaToNationalName = {
  'BRA': 'Brazil',
  'ARG': 'Argentina',
  'FRA': 'France',
  'GER': 'Germany',
  'ENG': 'England',
  'ESP': 'Spain',
  'POR': 'Portugal',
  'NED': 'Netherlands',
  'BEL': 'Belgium',
  'ITA': 'Italy',
  'CRO': 'Croatia',
  'URU': 'Uruguay',
  'MEX': 'Mexico',
  'USA': 'United States',
  'CAN': 'Canada',
  'JPN': 'Japan',
  'KOR': 'Korea Republic',
  'AUS': 'Australia',
  'SEN': 'Senegal',
  'MAR': 'Morocco',
  'GHA': 'Ghana',
  'NGA': 'Nigeria',
  'EGY': 'Egypt',
  'TUN': 'Tunisia',
  'CMR': 'Cameroon',
  'CIV': 'Ivory Coast',
  'SUI': 'Switzerland',
  'DEN': 'Denmark',
  'POL': 'Poland',
  'SRB': 'Serbia',
  'WAL': 'Wales',
  'SCO': 'Scotland',
  'IRL': 'Ireland',
  'NIR': 'Northern Ireland',
  'ECU': 'Ecuador',
  'COL': 'Colombia',
  'PER': 'Peru',
  'CHI': 'Chile',
  'PAR': 'Paraguay',
  'VEN': 'Venezuela',
  'BOL': 'Bolivia',
  'CRC': 'Costa Rica',
  'PAN': 'Panama',
  'JAM': 'Jamaica',
  'HON': 'Honduras',
  'IRN': 'Iran',
  'KSA': 'Saudi Arabia',
  'QAT': 'Qatar',
  'UAE': 'United Arab Emirates',
  'JOR': 'Jordan',
  'UZB': 'Uzbekistan',
  'CPV': 'Cape Verde',
  'CUW': 'Curacao',
  'NZL': 'New Zealand',
  'TUR': 'Turkey',
  'AUT': 'Austria',
  'CZE': 'Czech Republic',
  'HUN': 'Hungary',
  'SWE': 'Sweden',
  'NOR': 'Norway',
  'FIN': 'Finland',
  'GRE': 'Greece',
  'RUS': 'Russia',
  'UKR': 'Ukraine',
  'RSA': 'South Africa',
  'ALG': 'Algeria',
};

class SportsDbService {
  static const _ttlMs = 24 * 60 * 60 * 1000;
  static const _photoTtlMs = 7 * 24 * 60 * 60 * 1000;
  static const _negativeTtlMs = 6 * 60 * 60 * 1000;

  static Uri _uri(String path) =>
      Uri.parse('${ApiKeys.sportsDbBase}/${ApiKeys.sportsDbKey}/$path');

  // ─── Team search ───────────────────────────────────────────────────────

  static Future<SportsDbTeam?> searchTeam(
    String name, {
    String? tla,
    bool forceRefresh = false,
  }) async {
    if (name.isEmpty && (tla == null || tla.isEmpty)) return null;
    final box = Hive.box('matches_cache');
    final cleanName = name.trim();
    final cacheKey =
        'sportsdb_team_${_norm(cleanName)}_${tla?.toUpperCase() ?? ''}';
    final cacheKeyAt = '${cacheKey}_at';
    final cached = box.get(cacheKey);
    final cachedAt = box.get(cacheKeyAt);
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _ttlMs) {
        if (cached == '__NULL__') return null;
        return SportsDbTeam.fromJson(
            jsonDecode(cached as String) as Map<String, dynamic>);
      }
    }

    final queries = <String>[];
    final alias = _nationalTeamAliases[cleanName.toLowerCase()];
    if (alias != null) queries.add(alias);
    if (tla != null) {
      final tlaName = _tlaToNationalName[tla.toUpperCase()];
      if (tlaName != null && !queries.contains(tlaName)) queries.add(tlaName);
    }
    if (!queries.contains(cleanName)) queries.add(cleanName);

    SportsDbTeam? best;
    for (final q in queries) {
      try {
        final teams = await _queryTeams(q);
        final picked =
            _pickBestMatch(teams, cleanName, alias ?? cleanName, tla);
        if (picked != null) {
          best = picked;
          break;
        }
      } catch (_) {}
    }

    if (best != null) {
      await box.put(cacheKey, jsonEncode(best.toJson()));
    } else {
      await box.put(cacheKey, '__NULL__');
    }
    await box.put(
        cacheKeyAt,
        DateTime.now().millisecondsSinceEpoch -
            (best == null ? (_ttlMs - _negativeTtlMs) : 0));
    return best;
  }

  static Future<List<Map<String, dynamic>>> _queryTeams(String q) async {
    final res = await http
        .get(_uri('searchteams.php?t=${Uri.encodeQueryComponent(q)}'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final teams = (data['teams'] as List?) ?? [];
    return teams.cast<Map<String, dynamic>>();
  }

  static SportsDbTeam? _pickBestMatch(
    List<Map<String, dynamic>> teams,
    String originalName,
    String resolvedQuery,
    String? tla,
  ) {
    if (teams.isEmpty) return null;
    final original = _norm(originalName);
    final resolved = _norm(resolvedQuery);

    final soccer = teams.where((t) {
      final sport = ((t['strSport'] ?? '') as String).toLowerCase();
      return sport == 'soccer';
    }).toList();
    if (soccer.isEmpty) return null;

    int scoreOf(Map<String, dynamic> t) {
      final teamName = _norm((t['strTeam'] ?? '') as String);
      final altName = _norm((t['strTeamAlternate'] ?? '') as String);
      final country = _norm((t['strCountry'] ?? '') as String);
      int s = 0;
      if (teamName == resolved) s += 100;
      if (teamName == original) s += 100;
      if (teamName.contains(resolved) || resolved.contains(teamName)) s += 40;
      if (teamName.contains(original) || original.contains(teamName)) s += 40;
      if (altName.contains(resolved)) s += 20;
      if (tla != null && _tlaToNationalName.containsKey(tla.toUpperCase())) {
        final natName = _norm(_tlaToNationalName[tla.toUpperCase()]!);
        if (teamName == natName) s += 200;
        if (country == natName) s += 30;
      }
      return s;
    }

    soccer.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
    final top = soccer.first;
    if (scoreOf(top) < 40) return null;
    return SportsDbTeam.fromJson(top);
  }

  // ─── Bulk squad ────────────────────────────────────────────────────────

  static Future<List<SportsDbPlayer>> fetchSquad(String teamId,
      {bool forceRefresh = false}) async {
    final box = Hive.box('matches_cache');
    final key = 'sportsdb_squad_$teamId';
    final keyAt = '${key}_at';
    final cached = box.get(key);
    final cachedAt = box.get(keyAt);
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _ttlMs) {
        return ((jsonDecode(cached as String)) as List)
            .map((e) => SportsDbPlayer.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final res = await http
          .get(_uri('lookup_all_players.php?id=$teamId'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return _cachedSquad(box, key);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final players = (data['player'] as List?) ?? [];
      final list = players
          .map((e) => SportsDbPlayer.fromJson(e as Map<String, dynamic>))
          .where((p) => p.name.isNotEmpty)
          .toList();
      await box.put(key, jsonEncode(list.map((p) => p.toJson()).toList()));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
      return list;
    } catch (_) {
      return _cachedSquad(box, key);
    }
  }

  // ─── Per-player search (returns full player record incl. bio) ───────────

  static Future<SportsDbPlayer?> searchPlayer(
    String playerName, {
    String? teamHint,
  }) async {
    if (playerName.isEmpty) return null;
    final box = Hive.box('matches_cache');
    final cacheKey = 'sportsdb_player_${_norm(playerName)}';
    final cacheKeyAt = '${cacheKey}_at';
    final cached = box.get(cacheKey);
    final cachedAt = box.get(cacheKeyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _photoTtlMs) {
        if (cached == '__NULL__') return null;
        try {
          return SportsDbPlayer.fromJson(
              jsonDecode(cached as String) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }
    }

    Map<String, dynamic>? pick;
    try {
      final res = await http
          .get(_uri(
              'searchplayers.php?p=${Uri.encodeQueryComponent(playerName)}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final players = (data['player'] as List?) ?? [];
        final wantTeam = teamHint?.toLowerCase();
        for (final raw in players) {
          if (raw is! Map) continue;
          final p = raw.cast<String, dynamic>();
          final sport = ((p['strSport'] ?? '') as String).toLowerCase();
          if (sport != 'soccer') continue;
          if (wantTeam != null) {
            final team = ((p['strTeam'] ?? '') as String).toLowerCase();
            final nat = ((p['strNationality'] ?? '') as String).toLowerCase();
            if (team.contains(wantTeam) || nat.contains(wantTeam)) {
              pick = p;
              break;
            }
          }
          pick ??= p;
        }
      }
    } catch (_) {}

    if (pick == null) {
      await box.put(cacheKey, '__NULL__');
      await box.put(cacheKeyAt, DateTime.now().millisecondsSinceEpoch);
      return null;
    }

    final player = SportsDbPlayer.fromJson(pick);
    await box.put(cacheKey, jsonEncode(player.toJson()));
    await box.put(cacheKeyAt, DateTime.now().millisecondsSinceEpoch);
    return player;
  }

  /// Convenience: just the photo URL.
  /// Tries: TheSportsDB → Wikipedia thumbnail fallback.
  static Future<String?> searchPlayerPhoto(
    String playerName, {
    String? teamHint,
  }) async {
    if (playerName.isEmpty) return null;
    final box = Hive.box('matches_cache');
    final cacheKey = 'sportsdb_pp_${_norm(playerName)}';
    final cacheKeyAt = '${cacheKey}_at';
    final cached = box.get(cacheKey);
    final cachedAt = box.get(cacheKeyAt);
    if (cached != null && cachedAt != null) {
      final age = DateTime.now().millisecondsSinceEpoch - (cachedAt as int);
      if (age < _photoTtlMs) {
        return cached == '__NULL__' ? null : (cached as String);
      }
    }

    // Tier 1 — TheSportsDB
    String? best;
    try {
      final p = await searchPlayer(playerName, teamHint: teamHint);
      best = p?.photoUrl ?? p?.thumbUrl;
    } catch (_) {}

    // Tier 2 — Wikipedia thumbnail (catches ~95% of pros)
    if (best == null) {
      try {
        best = await _wikipediaThumb(playerName, teamHint: teamHint);
      } catch (_) {}
    }

    await box.put(cacheKey, best ?? '__NULL__');
    await box.put(cacheKeyAt, DateTime.now().millisecondsSinceEpoch);
    return best;
  }

  /// Wikipedia REST API page summary endpoint returns a thumbnail URL.
  /// Free, no key. Returns 200x200+ thumbnail PNG/JPG.
  static Future<String?> _wikipediaThumb(String name,
      {String? teamHint}) async {
    // First, search Wikipedia to find the most likely article title.
    final searchTerm = teamHint != null && teamHint.isNotEmpty
        ? '$name footballer'
        : '$name footballer';
    final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'list': 'search',
      'srsearch': searchTerm,
      'srlimit': '3',
      'srnamespace': '0',
    });
    final searchRes =
        await http.get(searchUri).timeout(const Duration(seconds: 8));
    if (searchRes.statusCode != 200) return null;
    final searchData = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final results = (searchData['query']?['search'] as List?) ?? [];
    if (results.isEmpty) return null;

    // Look for the best title — prefer one mentioning footballer / soccer.
    String? title;
    for (final r in results) {
      final t = ((r['title'] ?? '') as String);
      final snippet = ((r['snippet'] ?? '') as String).toLowerCase();
      if (snippet.contains('footballer') ||
          snippet.contains('football') ||
          snippet.contains('soccer')) {
        title = t;
        break;
      }
    }
    title ??= results.first['title'] as String?;
    if (title == null) return null;

    // Fetch page summary which contains the thumbnail.
    final summaryUri = Uri.https(
      'en.wikipedia.org',
      '/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
    );
    final summaryRes =
        await http.get(summaryUri).timeout(const Duration(seconds: 8));
    if (summaryRes.statusCode != 200) return null;
    final summary = jsonDecode(summaryRes.body) as Map<String, dynamic>;
    final thumb = summary['thumbnail']?['source'] as String?;
    final original = summary['originalimage']?['source'] as String?;
    // Prefer original (sharper) but it can be very large; thumb is safer.
    return thumb ?? original;
  }

  // ─── helpers ───────────────────────────────────────────────────────────

  static String _norm(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '');

  static List<SportsDbPlayer> _cachedSquad(Box box, String key) {
    final raw = box.get(key);
    if (raw == null) return <SportsDbPlayer>[];
    try {
      return ((jsonDecode(raw as String)) as List)
          .map((e) => SportsDbPlayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <SportsDbPlayer>[];
    }
  }
}
