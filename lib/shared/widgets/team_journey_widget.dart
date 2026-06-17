// lib/shared/widgets/team_journey_widget.dart
//
// Spec feature #14 — Team Journey Timeline.
//
// Renders a visual timeline of a team's tournament journey:
//   Qualified → Group Stage → R32 → R16 → QF → SF → Final
//
// Each stage is marked as completed, current, upcoming, or eliminated based
// on the team's results in this competition. Designed to live inside the
// team details screen.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/match.dart';

class TeamJourneyWidget extends StatelessWidget {
  final String tla;
  final List<Match> competitionMatches;
  const TeamJourneyWidget({
    super.key,
    required this.tla,
    required this.competitionMatches,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    if (competitionMatches.isEmpty) return const SizedBox.shrink();

    final stages = _computeJourney();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16, color: AppTheme.brand),
              SizedBox(width: 6),
              Text('TOURNAMENT JOURNEY',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
            ],
          ),
          const SizedBox(height: 14),
          // Horizontal scroll for narrow screens
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < stages.length; i++) ...[
                  _StageDot(stage: stages[i]),
                  if (i < stages.length - 1)
                    _Connector(
                        active: stages[i].status == _StageStatus.completed),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._buildResultLines(stages, p),
        ],
      ),
    );
  }

  List<Widget> _buildResultLines(List<_Stage> stages, Palette p) {
    final lines = <Widget>[];
    for (final s in stages) {
      if (s.results.isEmpty) continue;
      lines.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(s.label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: p.textLow)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: s.results
                    .map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(r,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.textMid)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ));
    }
    return lines;
  }

  List<_Stage> _computeJourney() {
    // Order: qualification → group → R32 → R16 → QF → SF → final
    final stageOrder = [
      _StageKey.qualification,
      _StageKey.group,
      _StageKey.r32,
      _StageKey.r16,
      _StageKey.qf,
      _StageKey.sf,
      _StageKey.finalStage,
    ];
    final labels = {
      _StageKey.qualification: 'Qualified',
      _StageKey.group: 'Group',
      _StageKey.r32: 'R32',
      _StageKey.r16: 'R16',
      _StageKey.qf: 'QF',
      _StageKey.sf: 'SF',
      _StageKey.finalStage: 'Final',
    };

    // Group matches by stage
    final byStage = <_StageKey, List<Match>>{};
    for (final m in competitionMatches) {
      if (m.homeTeam.tla != tla && m.awayTeam.tla != tla) continue;
      final key = _classifyStage(m.stage);
      byStage.putIfAbsent(key, () => []).add(m);
    }

    final stages = <_Stage>[];
    bool eliminated = false;
    for (final key in stageOrder) {
      final matches = byStage[key] ?? const <Match>[];
      final results = <String>[];
      _StageStatus status;

      if (key == _StageKey.qualification) {
        // We assume the team is in the competition, so they're qualified.
        status = _StageStatus.completed;
      } else if (matches.isEmpty) {
        // If we've already detected elimination, mark as not reached.
        if (eliminated) {
          status = _StageStatus.eliminated;
        } else {
          status = _StageStatus.upcoming;
        }
      } else {
        final played = matches.where((m) => m.isFinished).toList()
          ..sort((a, b) => a.utcDate.compareTo(b.utcDate));
        final unplayed = matches.where((m) => !m.isFinished).toList();

        for (final m in played) {
          final hg = m.score.homeGoals ?? 0;
          final ag = m.score.awayGoals ?? 0;
          final usH = m.homeTeam.tla == tla;
          final usScore = usH ? hg : ag;
          final themScore = usH ? ag : hg;
          final opp = usH ? m.awayTeam.tla : m.homeTeam.tla;
          final outcome = usScore > themScore
              ? 'W'
              : usScore < themScore
                  ? 'L'
                  : 'D';
          results.add('$outcome  $usScore-$themScore  vs $opp');
        }

        // Determine outcome of this stage
        if (key == _StageKey.group) {
          if (played.length < matches.length) {
            status = _StageStatus.current;
          } else {
            // Determine if team progressed (simplified: at least one win or two draws)
            final wins = played.where((m) {
              final us = m.homeTeam.tla == tla
                  ? m.score.homeGoals ?? 0
                  : m.score.awayGoals ?? 0;
              final them = m.homeTeam.tla == tla
                  ? m.score.awayGoals ?? 0
                  : m.score.homeGoals ?? 0;
              return us > them;
            }).length;
            final draws = played.where((m) {
              final hg = m.score.homeGoals ?? 0;
              final ag = m.score.awayGoals ?? 0;
              return hg == ag;
            }).length;
            // 7+ pts almost certainly through. 4 pts often is. Below 4 likely out.
            final points = wins * 3 + draws;
            if (points >= 4) {
              status = _StageStatus.completed;
            } else {
              status = _StageStatus.eliminated;
              eliminated = true;
            }
          }
        } else {
          // Knockout: single elimination match
          if (unplayed.isNotEmpty) {
            status = _StageStatus.current;
          } else {
            final m = played.last;
            final hg = m.score.homeGoals ?? 0;
            final ag = m.score.awayGoals ?? 0;
            final us = m.homeTeam.tla == tla ? hg : ag;
            final them = m.homeTeam.tla == tla ? ag : hg;
            if (us > them) {
              status = _StageStatus.completed;
            } else if (us < them) {
              status = _StageStatus.eliminated;
              eliminated = true;
            } else {
              // tied → assume penalties / leave as completed (no penalty data)
              status = _StageStatus.completed;
            }
          }
        }
      }

      stages.add(_Stage(
        key: key,
        label: labels[key]!,
        status: status,
        results: results,
      ));
    }
    return stages;
  }

  _StageKey _classifyStage(String stage) {
    final s = stage.toUpperCase();
    if (s.contains('GROUP')) return _StageKey.group;
    if (s.contains('ROUND_OF_32') || s == 'R32') return _StageKey.r32;
    if (s.contains('ROUND_OF_16') || s == 'R16' || s.contains('LAST_16')) {
      return _StageKey.r16;
    }
    if (s.contains('QUARTER')) return _StageKey.qf;
    if (s.contains('SEMI')) return _StageKey.sf;
    if (s.contains('FINAL') && !s.contains('SEMI') && !s.contains('QUARTER')) {
      return _StageKey.finalStage;
    }
    return _StageKey.group; // default
  }
}

// ─── Internal types ─────────────────────────────────────────────────────────

enum _StageKey { qualification, group, r32, r16, qf, sf, finalStage }

enum _StageStatus { completed, current, upcoming, eliminated }

class _Stage {
  final _StageKey key;
  final String label;
  final _StageStatus status;
  final List<String> results;
  const _Stage({
    required this.key,
    required this.label,
    required this.status,
    this.results = const [],
  });
}

// ─── UI parts ───────────────────────────────────────────────────────────────

class _StageDot extends StatelessWidget {
  final _Stage stage;
  const _StageDot({required this.stage});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final (color, icon) = switch (stage.status) {
      _StageStatus.completed => (AppTheme.good, Icons.check_rounded),
      _StageStatus.current => (AppTheme.brand, Icons.play_arrow_rounded),
      _StageStatus.upcoming => (p.surfaceHi, Icons.circle_outlined),
      _StageStatus.eliminated => (AppTheme.bad, Icons.close_rounded),
    };
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: stage.status == _StageStatus.upcoming
                ? Border.all(color: p.stroke, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(icon,
              size: 14,
              color: stage.status == _StageStatus.upcoming
                  ? p.textLow
                  : Colors.black),
        ),
        const SizedBox(height: 4),
        Text(stage.label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: stage.status == _StageStatus.eliminated
                    ? AppTheme.bad
                    : stage.status == _StageStatus.current
                        ? AppTheme.brand
                        : stage.status == _StageStatus.upcoming
                            ? p.textLow
                            : p.textHi)),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  final bool active;
  const _Connector({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        width: 18,
        height: 2,
        decoration: BoxDecoration(
          color: active ? AppTheme.good : p.stroke,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
