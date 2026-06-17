// lib/core/services/match_details_resolver.dart
//
// Single entry point the match-details screen calls. Pulls rich match detail
// (lineups, incidents, stats) from BSD then TheSportsDB, writing successful
// results back to Firestore so the relay's lineups/{matchId} collection gets
// populated even before the relay runs — shared crowd-cache benefit.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../shared/models/match.dart';
import 'api_service.dart';
import 'bsd_service.dart';
import 'extras_service.dart';
import 'sportsdb_match_service.dart';

void _log(String m) {
  const enabled = bool.fromEnvironment('DEBUG_SPORTS_API');
  if (kDebugMode && enabled) debugPrint('[Resolver] $m');
}

class MatchDetailsResolver {
  // Per-session BSD event-id cache (avoids duplicate resolveEventId calls).
  static final Map<int, Future<int?>> _bsdIdCache = {};

  static Future<int?> _bsdId(Match m) {
    // Short-circuit: enricher already resolved and wrote bzzoiroId to Firestore.
    if (m.bzzoiroId != null) {
      return _bsdIdCache.putIfAbsent(m.id, () => Future.value(m.bzzoiroId));
    }
    return _bsdIdCache.putIfAbsent(
      m.id,
      () => BsdService.resolveEventId(
        utcDate: m.utcDate.toUtc(),
        homeName: m.homeTeam.name,
        awayName: m.awayTeam.name,
      ),
    );
  }

  // ── Hive write-back key ───────────────────────────────────────────────────
  // We track whether we've already written this match to Firestore this session
  // so we don't repeat the write on every tab switch.
  static final Set<int> _firestoreWritten = {};

  // ── Convert BSD MatchLineups → flat bzzLineups list ───────────────────────
  static List<Map<String, dynamic>>? _bsdToFlat(MatchLineups ml) {
    final out = <Map<String, dynamic>>[];
    void add(TeamLineup? side, bool isHome) {
      if (side == null) return;
      for (final p in side.starters) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': true,
        });
      }
      for (final p in side.bench) {
        out.add({
          'name': p.name,
          'player_name': p.name,
          'jersey_number': p.shirtNumber,
          'position': p.position,
          'is_home': isHome,
          'is_starter': false,
        });
      }
    }

    add(ml.home, true);
    add(ml.away, false);
    return out.isEmpty ? null : out;
  }

// ── Write lineup to Firestore + Hive (finished matches only, once/session) ─
  // This populates the lineups/{matchId} collection so other users and the
  // Flutter lineupProvider benefit from the data without a relay run.
  static Future<void> _persistLineup(
    Match m,
    List<Map<String, dynamic>> flat, {
    String? homeFormation,
    String? awayFormation,
    String? homeCoach,
    String? awayCoach,
    String source = 'client',
  }) async {
    if (_firestoreWritten.contains(m.id)) return;
    _firestoreWritten.add(m.id);

    // Hive crowd-cache (so same device doesn't re-fetch for 12 h).
    try {
      final key = 'crowd_lineup_${m.id}';
      final keyAt = '${key}_at';
      final box = Hive.box('matches_cache');
      await box.put(key, jsonEncode(flat));
      await box.put(keyAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _log('Hive persist error: $e');
    }

    // Firestore write — only for finished matches (lineup is final).
    // We only write to lineups/{matchId} (client has write permission).
    // We do NOT write to matches/{matchId} — that collection is relay-only.
    if (!m.isFinished) return;
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('lineups').doc(m.id.toString()).set({
        'flatLineups': flat,
        if (homeFormation != null) 'homeFormation': homeFormation,
        if (awayFormation != null) 'awayFormation': awayFormation,
        if (homeCoach != null) 'homeCoach': homeCoach,
        if (awayCoach != null) 'awayCoach': awayCoach,
        'fetchedAt': FieldValue.serverTimestamp(),
        'source': source,
      }, SetOptions(merge: true));
      _log('Wrote ${flat.length} players to lineups/${m.id} (source=$source)');
    } catch (e) {
      _log('Firestore lineup write failed: $e');
    }
  }

  // ── LINEUPS ───────────────────────────────────────────────────────────────
  // Priority: BSD → TheSportsDB
  // On success, writes back to Firestore (finished matches) + Hive (always).
  static Future<MatchLineups?> lineups(Match m) async {
    // ── 1. BSD ───────────────────────────────────────────────────────────────
    final bsdId = await _bsdId(m);
    if (bsdId != null) {
      final ml = await BsdService.fetchLineups(bsdId, isLive: m.isLive);
      if (ml != null) {
        final flat = _bsdToFlat(ml);
        if (flat != null && flat.isNotEmpty) {
          unawaited(_persistLineup(
            m,
            flat,
            homeFormation: ml.home?.formation,
            awayFormation: ml.away?.formation,
            source: 'bsd_v2',
          ));
        }
        return ml;
      }
    }

    // Note: TheSportsDB fallback is handled by the separate _sdbLineupsProvider
    // in match_details_screen.dart.  We don't call SDB here to avoid duplicate
    // API requests that trigger 429 rate-limit responses.
    return null;
  }

  // ── INCIDENTS ─────────────────────────────────────────────────────────────
  // BSD → SDB timeline → FD goals (each tried in parallel where possible).
  static Future<List<MatchIncident>> incidents(Match m) async {
    final svc = SportsDbMatchService();

    // Kick off both event-ID lookups at the same time.
    final bsdIdFuture = _bsdId(m);
    final sdbIdFuture = svc.resolveEventId(
      dateUtc: m.utcDate.toUtc(),
      homeTeam: m.homeTeam.name,
      awayTeam: m.awayTeam.name,
    );

    final bsdId = await bsdIdFuture;
    final sdbId = await sdbIdFuture;

    // Kick off both fetches at the same time.
    final bsdFuture = bsdId != null
        ? BsdService.fetchIncidents(bsdId, isLive: m.isLive)
        : Future.value(<MatchIncident>[]);
    final sdbFuture = sdbId != null
        ? svc
            .fetchTimeline(sdbId,
                homeName: m.homeTeam.name, isFinished: m.isFinished)
            .then(_sdbEventsToIncidents)
        : Future.value(<MatchIncident>[]);

    final bsdIncs = await bsdFuture;
    final sdbIncs = await sdbFuture;

    if (bsdIncs.isNotEmpty) return bsdIncs;
    if (sdbIncs.isNotEmpty) return sdbIncs;
    return _fdGoalsAsIncidents(m);
  }

  static List<MatchIncident> _sdbEventsToIncidents(
      List<SdbTimelineEvent> events) {
    final out = <MatchIncident>[];
    for (final e in events) {
      final t = e.type.toLowerCase();
      String type;
      String? subtype;
      if (t.contains('goal')) {
        type = 'goal';
        final d = (e.detail ?? '').toLowerCase();
        if (d.contains('own')) {
          subtype = 'ownGoal';
        } else if (d.contains('pen')) {
          subtype = 'penalty';
        }
      } else if (t.contains('red')) {
        type = 'redCard';
      } else if (t.contains('yellow')) {
        type = 'yellowCard';
      } else if (t.contains('sub')) {
        type = 'substitution';
      } else {
        continue;
      }
      out.add(MatchIncident(
        minute: e.minute,
        type: type,
        player: e.player,
        assistOrOff: e.assistOrOff,
        isHome: e.isHome,
        subtype: subtype,
      ));
    }
    return out;
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

  // ── PLAYER STATS ─────────────────────────────────────────────────────────────
  // BSD /events/{id}/player-stats/ — ratings, goals, assists, passes, etc.
  // 60s TTL live / 12h finished. Returns empty list if BSD event not resolved.
  static Future<List<PlayerMatchStat>> playerStats(Match m) async {
    final bsdId = await _bsdId(m);
    if (bsdId == null) return const [];
    return BsdService.fetchPlayerStats(bsdId, isLive: m.isLive);
  }

  // ── MATCH METADATA ────────────────────────────────────────────────────────────
  // BSD /events/{id}/metadata/ — fun facts, jersey colours, AI preview text.
  // 6h TTL (pre-match editorial content; null if BSD event not resolved).
  static Future<MatchMetadata?> metadata(Match m) async {
    final bsdId = await _bsdId(m);
    if (bsdId == null) return null;
    return BsdService.fetchMetadata(bsdId);
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  // BSD → SDB (parallel lookups, BSD wins if both have data).
  static Future<List<MatchStat>> stats(Match m) async {
    final svc = SportsDbMatchService();

    final bsdIdFuture = _bsdId(m);
    final sdbIdFuture = svc.resolveEventId(
      dateUtc: m.utcDate.toUtc(),
      homeTeam: m.homeTeam.name,
      awayTeam: m.awayTeam.name,
    );

    final bsdId = await bsdIdFuture;
    final sdbId = await sdbIdFuture;

    final bsdFuture = bsdId != null
        ? BsdService.fetchStats(bsdId, isLive: m.isLive)
        : Future.value(<MatchStat>[]);
    final sdbFuture = sdbId != null
        ? svc.fetchStats(sdbId, isFinished: m.isFinished).then((ss) => ss
            .map((s) =>
                MatchStat(name: s.name, homeValue: s.home, awayValue: s.away))
            .toList())
        : Future.value(<MatchStat>[]);

    final bsdStats = await bsdFuture;
    if (bsdStats.isNotEmpty) return bsdStats;
    return await sdbFuture;
  }
}

// Silence the unawaited warning for fire-and-forget Firestore writes.
void unawaited(Future<void> f) {}
