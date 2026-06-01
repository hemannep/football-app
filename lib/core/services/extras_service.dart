// lib/core/services/extras_service.dart
//
// This file only holds shared match-detail models. Older provider-specific
// enrichment code was removed so the app can stay on the BSD-first free stack.
//
// Match-detail data now comes through `MatchDetailsResolver`, which prefers
// BSD for rich live data and falls back to TheSportsDB / football-data.org
// where those sources are useful.
//
// What stays here: just the shared model classes that the UI binds to —
// MatchLineups, TeamLineup, LineupPlayer, MatchIncident, MatchStat. Multiple
// widgets and services import these (match_details_screen, match_heat_meter,
// match_insights_service), so the model layer must remain stable even if
// the network layer is replaced.

// ─── Lineup models ──────────────────────────────────────────────────────────

class LineupPlayer {
  final String name;
  final int? shirtNumber;
  final String? position; // G, D, M, F
  final bool isStarting;
  final bool isCaptain;
  const LineupPlayer({
    required this.name,
    this.shirtNumber,
    this.position,
    required this.isStarting,
    this.isCaptain = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'shirtNumber': shirtNumber,
        'position': position,
        'isStarting': isStarting,
        'isCaptain': isCaptain,
      };
  factory LineupPlayer.fromJson(Map<String, dynamic> j) => LineupPlayer(
        name: j['name'] ?? '',
        shirtNumber: j['shirtNumber'],
        position: j['position'],
        isStarting: j['isStarting'] ?? false,
        isCaptain: j['isCaptain'] ?? false,
      );
}

class TeamLineup {
  final String? formation;
  final List<LineupPlayer> starters;
  final List<LineupPlayer> bench;
  const TeamLineup({
    this.formation,
    required this.starters,
    required this.bench,
  });

  Map<String, dynamic> toJson() => {
        'formation': formation,
        'starters': starters.map((p) => p.toJson()).toList(),
        'bench': bench.map((p) => p.toJson()).toList(),
      };
  factory TeamLineup.fromJson(Map<String, dynamic> j) => TeamLineup(
        formation: j['formation'],
        starters: ((j['starters'] ?? []) as List)
            .map((e) => LineupPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        bench: ((j['bench'] ?? []) as List)
            .map((e) => LineupPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MatchLineups {
  final TeamLineup? home;
  final TeamLineup? away;
  const MatchLineups({this.home, this.away});

  Map<String, dynamic> toJson() =>
      {'home': home?.toJson(), 'away': away?.toJson()};
  factory MatchLineups.fromJson(Map<String, dynamic> j) => MatchLineups(
        home: j['home'] == null
            ? null
            : TeamLineup.fromJson(j['home'] as Map<String, dynamic>),
        away: j['away'] == null
            ? null
            : TeamLineup.fromJson(j['away'] as Map<String, dynamic>),
      );
}

// ─── Incident models ────────────────────────────────────────────────────────

class MatchIncident {
  final int minute;
  final String type; // goal, yellowCard, redCard, substitution
  final String? player;
  final String? assistOrOff;
  final bool isHome;
  final String? subtype; // penalty, ownGoal, etc.

  const MatchIncident({
    required this.minute,
    required this.type,
    this.player,
    this.assistOrOff,
    required this.isHome,
    this.subtype,
  });

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'type': type,
        'player': player,
        'assistOrOff': assistOrOff,
        'isHome': isHome,
        'subtype': subtype,
      };
  factory MatchIncident.fromJson(Map<String, dynamic> j) => MatchIncident(
        minute: j['minute'] ?? 0,
        type: j['type'] ?? 'unknown',
        player: j['player'],
        assistOrOff: j['assistOrOff'],
        isHome: j['isHome'] ?? false,
        subtype: j['subtype'],
      );
}

// ─── Statistics models ──────────────────────────────────────────────────────

class MatchStat {
  final String name;
  final String homeValue;
  final String awayValue;
  const MatchStat({
    required this.name,
    required this.homeValue,
    required this.awayValue,
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'homeValue': homeValue, 'awayValue': awayValue};
  factory MatchStat.fromJson(Map<String, dynamic> j) => MatchStat(
        name: j['name'] ?? '',
        homeValue: j['homeValue'] ?? '0',
        awayValue: j['awayValue'] ?? '0',
      );
}

// ─── Momentum (live momentum chart, used by match_details_screen) ──────────
//
// Computes a relative-momentum score from incidents (goal +30, red -25,
// yellow -5, sub +4). The graph in the Stats tab plots these points.
// Kept here because _MomentumPainter imports MomentumPoint from this file.

class MomentumPoint {
  final int minute;
  final double homeScore; // 0..100
  final double awayScore;
  const MomentumPoint(this.minute, this.homeScore, this.awayScore);
}

class Momentum {
  static List<MomentumPoint> fromIncidents(List<MatchIncident> incs) {
    if (incs.isEmpty) return const [];
    double h = 50, a = 50;
    final pts = <MomentumPoint>[const MomentumPoint(0, 50, 50)];
    for (final i in incs) {
      double delta = 0;
      switch (i.type) {
        case 'goal':
          delta = 30;
          break;
        case 'redCard':
          delta = -25;
          break;
        case 'yellowCard':
          delta = -5;
          break;
        case 'substitution':
          delta = 4;
          break;
      }
      if (i.isHome) {
        h = (h + delta).clamp(0, 100);
        a = (a - delta * 0.5).clamp(0, 100);
      } else {
        a = (a + delta).clamp(0, 100);
        h = (h - delta * 0.5).clamp(0, 100);
      }
      // Normalise so the two sides sum to 100 (relative momentum).
      final sum = h + a;
      if (sum > 0) {
        h = (h / sum) * 100;
        a = (a / sum) * 100;
      }
      pts.add(MomentumPoint(i.minute, h, a));
    }
    return pts;
  }
}

// ─── Player match statistics (BSD /events/{id}/player-stats/) ───────────────
//
// Per-player ratings and performance metrics for a single match.
// BSD documents updates every minute during live play.

class PlayerMatchStat {
  final int? playerId;
  final int? teamId;
  final bool isHome;
  final String name;
  final String? position; // G, D, M, F
  final int minutesPlayed;
  final double? rating;
  final bool isSubstitute;
  final int goals;
  final int assists;
  final double? expectedGoals;
  final double? expectedAssists;
  final int totalShots;
  final int shotsOnTarget;
  final int totalPasses;
  final int accuratePasses;
  final int? keyPasses;
  final int totalTackles;
  final int interceptions;
  final int yellowCards;
  final int redCards;
  final int? saves;

  const PlayerMatchStat({
    this.playerId,
    this.teamId,
    required this.isHome,
    required this.name,
    this.position,
    required this.minutesPlayed,
    this.rating,
    this.isSubstitute = false,
    this.goals = 0,
    this.assists = 0,
    this.expectedGoals,
    this.expectedAssists,
    this.totalShots = 0,
    this.shotsOnTarget = 0,
    this.totalPasses = 0,
    this.accuratePasses = 0,
    this.keyPasses,
    this.totalTackles = 0,
    this.interceptions = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.saves,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'teamId': teamId,
        'isHome': isHome,
        'name': name,
        'position': position,
        'minutesPlayed': minutesPlayed,
        'rating': rating,
        'isSubstitute': isSubstitute,
        'goals': goals,
        'assists': assists,
        'expectedGoals': expectedGoals,
        'expectedAssists': expectedAssists,
        'totalShots': totalShots,
        'shotsOnTarget': shotsOnTarget,
        'totalPasses': totalPasses,
        'accuratePasses': accuratePasses,
        'keyPasses': keyPasses,
        'totalTackles': totalTackles,
        'interceptions': interceptions,
        'yellowCards': yellowCards,
        'redCards': redCards,
        'saves': saves,
      };

  factory PlayerMatchStat.fromJson(Map<String, dynamic> j) => PlayerMatchStat(
        playerId: j['playerId'] as int?,
        teamId: j['teamId'] as int?,
        isHome: (j['isHome'] as bool?) ?? false,
        name: (j['name'] as String?) ?? '',
        position: j['position'] as String?,
        minutesPlayed: (j['minutesPlayed'] as int?) ?? 0,
        rating: j['rating'] != null ? (j['rating'] as num).toDouble() : null,
        isSubstitute: (j['isSubstitute'] as bool?) ?? false,
        goals: (j['goals'] as int?) ?? 0,
        assists: (j['assists'] as int?) ?? 0,
        expectedGoals: j['expectedGoals'] != null
            ? (j['expectedGoals'] as num).toDouble()
            : null,
        expectedAssists: j['expectedAssists'] != null
            ? (j['expectedAssists'] as num).toDouble()
            : null,
        totalShots: (j['totalShots'] as int?) ?? 0,
        shotsOnTarget: (j['shotsOnTarget'] as int?) ?? 0,
        totalPasses: (j['totalPasses'] as int?) ?? 0,
        accuratePasses: (j['accuratePasses'] as int?) ?? 0,
        keyPasses: j['keyPasses'] as int?,
        totalTackles: (j['totalTackles'] as int?) ?? 0,
        interceptions: (j['interceptions'] as int?) ?? 0,
        yellowCards: (j['yellowCards'] as int?) ?? 0,
        redCards: (j['redCards'] as int?) ?? 0,
        saves: j['saves'] as int?,
      );
}

// ─── Match metadata (BSD /events/{id}/metadata/) ────────────────────────────
//
// Pre-match fun facts, AI preview text, and jersey colours.
// Cached 6h — this content is editorial and doesn't change during a match.

class JerseyColors {
  final String? primary;
  final String? secondary;
  const JerseyColors({this.primary, this.secondary});

  Map<String, dynamic> toJson() =>
      {'primary': primary, 'secondary': secondary};

  factory JerseyColors.fromJson(Map<String, dynamic> j) => JerseyColors(
        primary: j['primary'] as String?,
        secondary: j['secondary'] as String?,
      );
}

class MatchJerseys {
  final JerseyColors? home;
  final JerseyColors? away;
  const MatchJerseys({this.home, this.away});

  Map<String, dynamic> toJson() => {
        'home': home?.toJson(),
        'away': away?.toJson(),
      };

  factory MatchJerseys.fromJson(Map<String, dynamic> j) => MatchJerseys(
        home: j['home'] == null
            ? null
            : JerseyColors.fromJson(j['home'] as Map<String, dynamic>),
        away: j['away'] == null
            ? null
            : JerseyColors.fromJson(j['away'] as Map<String, dynamic>),
      );
}

class MatchFunFact {
  final int typeId;
  final String sentence;
  const MatchFunFact({required this.typeId, required this.sentence});

  Map<String, dynamic> toJson() =>
      {'typeId': typeId, 'sentence': sentence};

  factory MatchFunFact.fromJson(Map<String, dynamic> j) => MatchFunFact(
        typeId: (j['typeId'] ?? j['type_id'] ?? 0) as int,
        sentence: (j['sentence'] ?? '') as String,
      );
}

class MatchMetadata {
  final List<MatchFunFact> funfacts;
  final String? aiPreview;
  final MatchJerseys? jerseys;

  const MatchMetadata({
    this.funfacts = const [],
    this.aiPreview,
    this.jerseys,
  });

  bool get isEmpty =>
      funfacts.isEmpty && aiPreview == null && jerseys == null;

  Map<String, dynamic> toJson() => {
        'funfacts': funfacts.map((f) => f.toJson()).toList(),
        'aiPreview': aiPreview,
        'jerseys': jerseys?.toJson(),
      };

  factory MatchMetadata.fromJson(Map<String, dynamic> j) => MatchMetadata(
        funfacts: ((j['funfacts'] ?? const []) as List)
            .map((e) => MatchFunFact.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiPreview: j['aiPreview'] as String?,
        jerseys: j['jerseys'] == null
            ? null
            : MatchJerseys.fromJson(j['jerseys'] as Map<String, dynamic>),
      );
}
