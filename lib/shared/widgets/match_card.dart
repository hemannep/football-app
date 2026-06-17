// lib/shared/widgets/match_card.dart
//
// Livescore-inspired vertical layout:
//   [Status col] | [Stacked team rows + scorers] [Score col]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../models/match.dart';
import 'team_crest_widget.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;
  final bool showDate;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final isLive = match.isLive;
    final isFinished = match.isFinished;
    final isHt = match.status == 'PAUSED';
    final accent = _accentColor(match.competitionCode);

    // Live minute
    int? liveMin;
    if (isLive) {
      final elapsed = DateTime.now().difference(match.utcDate).inMinutes;
      liveMin = match.minute ??
          (elapsed < 55
                  ? elapsed
                  : elapsed < 105
                      ? elapsed - 15
                      : elapsed - 30)
              .clamp(1, 120);
    }

    // Goal scorers split by team
    final homeGoals = match.goals
        .where((g) => g.teamId == match.homeTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));
    final awayGoals = match.goals
        .where((g) => g.teamId == match.awayTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));

    // Score winner colors
    Color homeScoreColor = p.textHi;
    Color awayScoreColor = p.textHi;
    final winner = match.score.winner;
    if (isFinished) {
      if (winner == 'HOME_TEAM') {
        homeScoreColor = AppTheme.good;
        awayScoreColor = p.textLow;
      } else if (winner == 'AWAY_TEAM') {
        homeScoreColor = p.textLow;
        awayScoreColor = AppTheme.good;
      }
    }
    if (isLive) {
      homeScoreColor = Colors.white;
      awayScoreColor = Colors.white;
    }

    // Upcoming time soon?
    final diff = match.utcDate.toLocal().difference(DateTime.now());
    final isSoon =
        !isLive && !isFinished && diff.inMinutes > 0 && diff.inMinutes <= 60;

    return Material(
      color: isLive ? p.surface.withValues(alpha: 0.0) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.brand.withValues(alpha: 0.06),
        highlightColor: AppTheme.brand.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            color: isLive ? AppTheme.live.withValues(alpha: 0.04) : p.surface,
            border: Border(
              bottom: BorderSide(
                  color: p.stroke.withValues(alpha: 0.6), width: 0.5),
              left: isLive
                  ? const BorderSide(color: AppTheme.live, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status column (time / minute / FT) ─────────────────
                SizedBox(
                  width: 58,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLive) ...[
                          _LiveMinBadge(
                              minute: isHt ? null : liveMin, isHt: isHt),
                        ] else if (isFinished) ...[
                          Text(
                            'FT',
                            style: TextStyle(
                              color: p.textLow,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (showDate) ...[
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d MMM')
                                  .format(match.utcDate.toLocal()),
                              style: TextStyle(
                                color: p.textLow,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            DateFormat('HH:mm').format(match.utcDate.toLocal()),
                            style: TextStyle(
                              color: isSoon ? AppTheme.brand : p.textMid,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (showDate) ...[
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d MMM')
                                  .format(match.utcDate.toLocal()),
                              style: TextStyle(
                                color: p.textLow,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else if (isSoon) ...[
                            const SizedBox(height: 2),
                            Text(
                              'in ${diff.inMinutes}m',
                              style: const TextStyle(
                                color: AppTheme.brand,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                // ── Vertical separator ──────────────────────────────────
                Container(
                  width: 1,
                  color: isLive
                      ? AppTheme.live.withValues(alpha: 0.3)
                      : p.stroke.withValues(alpha: 0.6),
                ),
                // ── Teams + scorers ─────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Small stage/group chip
                        if (match.group != null || match.stage.isNotEmpty) ...[
                          Text(
                            _stageLabel(match),
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],
                        // Home row
                        _TeamLine(
                          team: match.homeTeam,
                          goals: homeGoals,
                          palette: p,
                          isWinner: winner == 'HOME_TEAM',
                          isLoser: winner == 'AWAY_TEAM',
                          isFinished: isFinished,
                          hasRecentGoal:
                              _hasRecentGoal(match, match.homeTeam.id),
                        ),
                        const SizedBox(height: 7),
                        // Away row
                        _TeamLine(
                          team: match.awayTeam,
                          goals: awayGoals,
                          palette: p,
                          isWinner: winner == 'AWAY_TEAM',
                          isLoser: winner == 'HOME_TEAM',
                          isFinished: isFinished,
                          hasRecentGoal:
                              _hasRecentGoal(match, match.awayTeam.id),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Score ───────────────────────────────────────────────
                if (isLive || isFinished)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${match.score.homeGoals ?? 0}',
                          style: TextStyle(
                            color: homeScoreColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${match.score.awayGoals ?? 0}',
                          style: TextStyle(
                            color: awayScoreColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: p.textLow.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _hasRecentGoal(Match m, int? teamId) {
    if (!m.isLive || m.goals.isEmpty || teamId == null) return false;
    final elapsed =
        DateTime.now().difference(m.utcDate).inMinutes.clamp(1, 120);
    final teamGoals = m.goals.where((g) => g.teamId == teamId).toList();
    if (teamGoals.isEmpty) return false;
    final lastMin = teamGoals.fold(0, (mx, g) => g.minute > mx ? g.minute : mx);
    return lastMin > 0 && (elapsed - lastMin) <= 5;
  }

  String _stageLabel(Match m) {
    if (m.group != null) {
      return m.group!.startsWith('GROUP_')
          ? 'Group ${m.group!.substring(6)}'
          : m.group!;
    }
    return m.stage
        .split('_')
        .map((s) => s.isEmpty ? s : s[0] + s.substring(1).toLowerCase())
        .join(' ');
  }

  static const _competitionColors = <String, Color>{
    'WC': Color(0xFF8B0000),
    'CL': Color(0xFF1A237E),
    'EL': Color(0xFFE65100),
    'ECL': Color(0xFF1B5E20),
    'EC': Color(0xFF004D40),
    'PL': Color(0xFF38003C),
    'BL1': Color(0xFFD32F2F),
    'PD': Color(0xFFFF6F00),
    'SA': Color(0xFF0D47A1),
    'FL1': Color(0xFF1565C0),
    'PPL': Color(0xFF006400),
  };

  static Color _accentColor(String? code) =>
      code != null && _competitionColors.containsKey(code)
          ? _competitionColors[code]!
          : AppTheme.brand;
}

// ─── Live minute badge ────────────────────────────────────────────────────────

class _LiveMinBadge extends StatefulWidget {
  final int? minute;
  final bool isHt;
  const _LiveMinBadge({this.minute, required this.isHt});

  @override
  State<_LiveMinBadge> createState() => _LiveMinBadgeState();
}

class _LiveMinBadgeState extends State<_LiveMinBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isHt
        ? 'HT'
        : widget.minute != null
            ? "${widget.minute}'"
            : '●';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _c,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppTheme.live, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.live,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ─── Single team line ────────────────────────────────────────────────────────

class _TeamLine extends StatelessWidget {
  final TeamRef team;
  final List<MatchGoal> goals;
  final Palette palette;
  final bool isWinner;
  final bool isLoser;
  final bool isFinished;
  final bool hasRecentGoal;

  const _TeamLine({
    required this.team,
    required this.goals,
    required this.palette,
    this.isWinner = false,
    this.isLoser = false,
    this.isFinished = false,
    this.hasRecentGoal = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = isLoser
        ? palette.textLow
        : isWinner
            ? palette.textHi
            : palette.textHi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TeamCrestWidget(
              crestUrl: team.crest,
              tla: team.tla,
              name: team.name,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                team.name,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 14,
                  fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasRecentGoal) ...[
              const SizedBox(width: 6),
              const _GoalFlash(),
            ],
          ],
        ),
        // Goal scorers (shown below team name when available)
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            goals.map((g) {
              final name = _short(g.scorerName);
              final suffix = g.isPenalty
                  ? ' (P)'
                  : g.isOwnGoal
                      ? ' (OG)'
                      : '';
              return "$name$suffix ${g.minute}'";
            }).join('  '),
            style: TextStyle(
              color: palette.textLow,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _short(String? name) {
    if (name == null || name.isEmpty) return '—';
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return '${parts.first[0]}. ${parts.last}';
  }
}

// ─── Goal flash badge ────────────────────────────────────────────────────────

class _GoalFlash extends StatefulWidget {
  const _GoalFlash();
  @override
  State<_GoalFlash> createState() => _GoalFlashState();
}

class _GoalFlashState extends State<_GoalFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            gradient: AppTheme.liveGradient,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            '⚽ GOAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

// ─── Pulse dot (kept for any callers that still use it) ───────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(
          width: 6,
          height: 6,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      );
}
