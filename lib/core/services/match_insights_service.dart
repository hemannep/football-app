// lib/core/services/match_insights_service.dart
//
// Lightweight, locally-computed match analytics. No paid analytics APIs.
//
//   • Match Heat Meter (0-100) — how "exciting" a match is, derived from
//     goals, cards, late drama, and density of incidents.
//
//   • AI-style insights — short, factual sentences derived from the team's
//     recent match list (e.g. "Argentina are unbeaten in 7 matches").

import '../../shared/models/match.dart';
import 'extras_service.dart';

class MatchHeat {
  final int heat; // 0..100
  final String emoji; // 🥶 / 😐 / 🔥 / 🔥🔥🔥
  final String label;
  const MatchHeat(
      {required this.heat, required this.emoji, required this.label});
}

class MatchInsightsService {
  /// Heat meter for a finished/live match.
  ///
  /// Inputs:
  ///   • match → for score, status
  ///   • incidents (optional) → for cards, subs, late goals
  static MatchHeat heatFor(Match match, {List<MatchIncident>? incidents}) {
    if (match.isScheduled) {
      return const MatchHeat(heat: 0, emoji: '⏳', label: 'Not started');
    }

    final hg = match.score.homeGoals ?? 0;
    final ag = match.score.awayGoals ?? 0;
    final totalGoals = hg + ag;
    final goalDiff = (hg - ag).abs();

    int score = 0;

    // Goals are the biggest factor.
    score += totalGoals * 15; // 0g→0, 5g→75
    // Tight matches add tension.
    if (totalGoals >= 2 && goalDiff <= 1) score += 12;
    // Goal-fest bonus.
    if (totalGoals >= 5) score += 8;
    // Comeback bonus (both teams scored 2+).
    if (hg >= 2 && ag >= 2) score += 10;

    // Card and substitution drama.
    if (incidents != null) {
      final yellow = incidents.where((i) => i.type == 'yellowCard').length;
      final red = incidents.where((i) => i.type == 'redCard').length;
      final subs = incidents.where((i) => i.type == 'substitution').length;
      score += yellow * 2; // mild drama
      score += red * 15; // big drama
      // Late goals (after 80')
      final lateGoals =
          incidents.where((i) => i.type == 'goal' && i.minute >= 80).length;
      score += lateGoals * 10;
      // Stoppage-time goals
      final stoppageGoals =
          incidents.where((i) => i.type == 'goal' && i.minute >= 90).length;
      score += stoppageGoals * 5;
      // Sub density
      if (subs >= 8) score += 3;
    }

    final heat = score.clamp(0, 100);
    final (emoji, label) = switch (heat) {
      < 25 => ('🥶', 'Cold'),
      < 50 => ('😐', 'Average'),
      < 75 => ('🔥', 'Hot'),
      _ => ('🔥🔥🔥', 'Blockbuster'),
    };
    return MatchHeat(heat: heat, emoji: emoji, label: label);
  }

  /// Returns 0..N AI-style insight lines for [team] from its recent matches.
  /// Caller can join with " · " or render as bullets.
  static List<String> insightsForTeam({
    required String tla,
    required List<Match> recentMatches,
  }) {
    if (recentMatches.isEmpty) return const [];
    final finished = recentMatches.where((m) => m.isFinished).toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    if (finished.isEmpty) return const [];

    final insights = <String>[];

    // Unbeaten run
    int unbeaten = 0;
    for (final m in finished) {
      final us = m.homeTeam.tla == tla
          ? m.score.homeGoals ?? 0
          : m.score.awayGoals ?? 0;
      final them = m.homeTeam.tla == tla
          ? m.score.awayGoals ?? 0
          : m.score.homeGoals ?? 0;
      if (us >= them) {
        unbeaten++;
      } else {
        break;
      }
    }
    if (unbeaten >= 3) {
      insights.add('Unbeaten in $unbeaten matches');
    }

    // Winning streak
    int winStreak = 0;
    for (final m in finished) {
      final us = m.homeTeam.tla == tla
          ? m.score.homeGoals ?? 0
          : m.score.awayGoals ?? 0;
      final them = m.homeTeam.tla == tla
          ? m.score.awayGoals ?? 0
          : m.score.homeGoals ?? 0;
      if (us > them) {
        winStreak++;
      } else {
        break;
      }
    }
    if (winStreak >= 2) {
      insights.add('$winStreak consecutive wins');
    }

    // Losing streak
    int lossStreak = 0;
    for (final m in finished) {
      final us = m.homeTeam.tla == tla
          ? m.score.homeGoals ?? 0
          : m.score.awayGoals ?? 0;
      final them = m.homeTeam.tla == tla
          ? m.score.awayGoals ?? 0
          : m.score.homeGoals ?? 0;
      if (us < them) {
        lossStreak++;
      } else {
        break;
      }
    }
    if (lossStreak >= 2) {
      insights.add('$lossStreak consecutive defeats');
    }

    // Scoring form (last 5)
    final last5 = finished.take(5).toList();
    if (last5.length >= 3) {
      int scored = 0;
      int conceded = 0;
      for (final m in last5) {
        scored += m.homeTeam.tla == tla
            ? m.score.homeGoals ?? 0
            : m.score.awayGoals ?? 0;
        conceded += m.homeTeam.tla == tla
            ? m.score.awayGoals ?? 0
            : m.score.homeGoals ?? 0;
      }
      final n = last5.length;
      final scoredAvg = (scored / n).toStringAsFixed(1);
      final concededAvg = (conceded / n).toStringAsFixed(1);
      insights.add(
          'Scoring $scoredAvg • conceding $concededAvg per game (last $n)');

      // Clean sheets
      final cleanSheets = last5.where((m) {
        final them = m.homeTeam.tla == tla
            ? m.score.awayGoals ?? 0
            : m.score.homeGoals ?? 0;
        return them == 0;
      }).length;
      if (cleanSheets >= 2) {
        insights.add('$cleanSheets clean sheets in last $n');
      }
    }

    return insights;
  }

  /// Pre-match insight comparing two teams.
  static List<String> insightsForMatchup({
    required String homeTla,
    required String awayTla,
    required List<Match> recentForHome,
    required List<Match> recentForAway,
  }) {
    final out = <String>[];
    final homeIns = insightsForTeam(tla: homeTla, recentMatches: recentForHome);
    final awayIns = insightsForTeam(tla: awayTla, recentMatches: recentForAway);
    if (homeIns.isNotEmpty) out.add('$homeTla: ${homeIns.first}');
    if (awayIns.isNotEmpty) out.add('$awayTla: ${awayIns.first}');
    return out;
  }
}
