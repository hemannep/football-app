// lib/core/services/match_details_resolver.dart
//
// Single entry point the match-details screen calls. It pulls rich match
// detail (lineups, incidents, stats) from BSD (sports.bzzoiro.com) — the
// free source that football-data.org's free tier lacks.
//
// Resolution: our Match.id is a football-data.org id, so BsdService first
// resolves a BSD event id by (date, home, away), then fetches sub-resources.
//
// Graceful degradation:
//   - No BSD token set -> lineups/stats return null/empty; incidents fall back
//     to football-data.org goals (so scorers still show on finished matches).
//   - BSD has no data for the match -> same fallback.

import '../../shared/models/match.dart';
import 'api_service.dart';
import 'bsd_service.dart';
import 'extras_service.dart';

class MatchDetailsResolver {
  // Resolve + cache the BSD event id once per Match per app session.
  static final Map<int, Future<int?>> _idCache = {};

  static Future<int?> _bsdId(Match m) {
    return _idCache.putIfAbsent(
      m.id,
      () => BsdService.resolveEventId(
        utcDate: m.utcDate.toUtc(),
        homeName: m.homeTeam.name,
        awayName: m.awayTeam.name,
      ),
    );
  }

  // --- LINEUPS --------------------------------------------------------------
  static Future<MatchLineups?> lineups(Match m) async {
    final id = await _bsdId(m);
    if (id == null) return null;
    return BsdService.fetchLineups(id, isLive: m.isLive);
  }

  // --- INCIDENTS ------------------------------------------------------------
  static Future<List<MatchIncident>> incidents(Match m) async {
    final id = await _bsdId(m);
    if (id != null) {
      final bsd = await BsdService.fetchIncidents(id, isLive: m.isLive);
      if (bsd.isNotEmpty) return bsd;
    }
    // Fallback: football-data.org goals (free) so scorers still appear.
    return _fdGoalsAsIncidents(m);
  }

  static Future<List<MatchIncident>> _fdGoalsAsIncidents(Match m) async {
    final raw =
        await ApiService.fetchMatchDetailsRaw(m.id, isFinished: m.isFinished);
    if (raw == null) return const [];
    final homeId = (raw['homeTeam'] as Map?)?['id'] as int?;
    final out = <MatchIncident>[];
    for (final g in (raw['goals'] as List?) ?? const []) {
      final j = Map<String, dynamic>.from(g as Map);
      final teamId = (j['team'] as Map?)?['id'] as int?;
      final type = (j['type'] ?? 'REGULAR') as String;
      out.add(MatchIncident(
        minute: (j['minute'] ?? 0) as int,
        type: 'goal',
        player: (j['scorer'] as Map?)?['name'] as String?,
        assistOrOff: (j['assist'] as Map?)?['name'] as String?,
        isHome: teamId != null && teamId == homeId,
        subtype:
            type == 'OWN' ? 'ownGoal' : (type == 'PENALTY' ? 'penalty' : null),
      ));
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
  }

  // --- STATS ----------------------------------------------------------------
  static Future<List<MatchStat>> stats(Match m) async {
    final id = await _bsdId(m);
    if (id == null) return const [];
    return BsdService.fetchStats(id, isLive: m.isLive);
  }
}
