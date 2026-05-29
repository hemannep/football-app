// lib/core/services/extras_service.dart
//
// This file used to wrap a SofaScore RapidAPI mirror for match-detail
// enrichment. That endpoint went over its free-tier monthly quota and stays
// in 429 state until it resets, so it's been removed from the data path.
//
// All match-detail data (lineups, goals, cards, substitutions) now comes
// directly from football-data.org via `MatchDetailsResolver`. See that file.
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
