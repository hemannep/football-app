// lib/shared/widgets/match_card.dart
//
// Complete drop-in replacement.
//
// Renders a compact match card with:
//   • Group / stage chip on top
//   • Optional date stamp (when showDate is true)
//   • Two team rows with flag + name
//   • Score box that adapts: live (with pulse), finished (FT), or upcoming
//     (time + date).
//
// Goal scorers are NOT shown on the card itself (that would require an API
// call per visible card). They show on the match details page instead.

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

    final accentColor = _competitionColor(match.competitionCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(
          color: isLive ? AppTheme.live.withValues(alpha: 0.5) : p.stroke,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.r),
          child: IntrinsicHeight(
            child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: isLive ? AppTheme.live : accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.r),
                    bottomLeft: Radius.circular(AppTheme.r),
                  ),
                ),
              ),
              Expanded(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 12, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    if (match.group != null)
                      _Chip(
                          text: _prettyGroup(match.group!),
                          color: accentColor)
                    else
                      _Chip(
                          text: _prettyStage(match.stage),
                          color: accentColor),
                    const Spacer(),
                    if (_hasRecentGoal(match)) const _GoalBadge(),
                    if (showDate)
                      Text(DateFormat('d MMM').format(match.utcDate),
                          style: TextStyle(
                              fontSize: 11,
                              color: p.textLow,
                              fontWeight: FontWeight.w600)),
                    if (onTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 16, color: p.textLow),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _TeamRow(
                            name: match.homeTeam.name,
                            tla: match.homeTeam.tla,
                            crest: match.homeTeam.crest,
                            reverse: false)),
                    _ScoreBox(match: match),
                    Expanded(
                        child: _TeamRow(
                            name: match.awayTeam.name,
                            tla: match.awayTeam.tla,
                            crest: match.awayTeam.crest,
                            reverse: true)),
                  ],
                ),
                if (match.isFinished && match.goals.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _CardScorers(match: match, p: p),
                ],
              ],
            ),
          ),
          ),           // Expanded
          ],           // Row children
        ),             // Row
        ),             // IntrinsicHeight
        ),             // InkWell
      ),               // Material
    );                 // Container
  }

  String _prettyStage(String s) {
    return s
        .split('_')
        .map((p) => p.isEmpty ? p : p[0] + p.substring(1).toLowerCase())
        .join(' ');
  }

  String _prettyGroup(String g) {
    if (g.startsWith('GROUP_')) return 'Group ${g.substring(6)}';
    return g;
  }

  // Returns true when a goal was scored within the last 5 estimated minutes.
  bool _hasRecentGoal(Match m) {
    if (!m.isLive || m.goals.isEmpty) return false;
    final elapsed = DateTime.now().difference(m.utcDate).inMinutes.clamp(1, 120);
    final lastMin = m.goals.fold(0, (max, g) => g.minute > max ? g.minute : max);
    return lastMin > 0 && (elapsed - lastMin) <= 5;
  }

  // Deterministic accent color from competition code.
  static const _competitionColors = <String, Color>{
    'WC':  Color(0xFF8B0000),
    'CL':  Color(0xFF1A237E),
    'EL':  Color(0xFFE65100),
    'ECL': Color(0xFF1B5E20),
    'EC':  Color(0xFF004D40),
    'PL':  Color(0xFF38003C),
    'BL1': Color(0xFFD32F2F),
    'PD':  Color(0xFFFF6F00),
    'SA':  Color(0xFF0D47A1),
    'FL1': Color(0xFF1565C0),
    'PPL': Color(0xFF006400),
  };

  Color _competitionColor(String? code) {
    if (code != null && _competitionColors.containsKey(code)) {
      return _competitionColors[code]!;
    }
    return AppTheme.brand;
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          )),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final String tla;
  final String? crest;
  final bool reverse;
  const _TeamRow(
      {required this.name, required this.tla, this.crest, required this.reverse});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final flag = TeamCrestWidget(crestUrl: crest, tla: tla, size: 30);
    final label = Flexible(
      child: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: reverse ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: p.textHi)),
    );
    return Row(
      mainAxisAlignment:
          reverse ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: reverse
          ? [label, const SizedBox(width: 10), flag]
          : [flag, const SizedBox(width: 10), label],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final Match match;
  const _ScoreBox({required this.match});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    if (match.isLive) {
      final isHt = match.status == 'PAUSED';
      final elapsed = DateTime.now().difference(match.utcDate).inMinutes;
      // Use relay-stored minute when available; otherwise estimate from wall clock.
      final liveMin = match.minute ??
          (elapsed < 55 ? elapsed : elapsed < 105 ? elapsed - 15 : elapsed - 30)
              .clamp(1, 120);
      final minute = isHt ? 45 : liveMin;
      final minuteStr = isHt ? 'HT' : "$minute'";
      return Container(
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppTheme.liveGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(minuteStr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(match.score.display,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
            if (!isHt) const _PulseDot(),
          ],
        ),
      );
    }

    if (match.isFinished) {
      final hg = match.score.homeGoals;
      final ag = match.score.awayGoals;
      final winner = match.score.winner;
      Color homeColor = p.textHi;
      Color awayColor = p.textHi;
      if (winner == 'HOME_TEAM') {
        homeColor = AppTheme.good;
        awayColor = p.textLow;
      } else if (winner == 'AWAY_TEAM') {
        homeColor = p.textLow;
        awayColor = AppTheme.good;
      }
      return Container(
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: p.surfaceHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hg != null ? '$hg' : '-',
                    style: TextStyle(
                        color: homeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.0)),
                Text(' – ',
                    style: TextStyle(
                        color: p.textLow,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.0)),
                Text(ag != null ? '$ag' : '-',
                    style: TextStyle(
                        color: awayColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.0)),
              ],
            ),
            const SizedBox(height: 2),
            Text('FT',
                style: TextStyle(
                    color: p.textLow,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final diff = match.utcDate.toLocal().difference(DateTime.now());
    final isSoon = diff.inMinutes > 0 && diff.inMinutes <= 60;
    final countdownStr = diff.inMinutes <= 0
        ? null
        : diff.inMinutes < 60
            ? 'in ${diff.inMinutes}m'
            : diff.inHours < 24
                ? 'in ${diff.inHours}h'
                : null;

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSoon ? AppTheme.brand.withValues(alpha: 0.08) : p.surfaceHi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSoon ? AppTheme.brand.withValues(alpha: 0.3) : p.stroke,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(DateFormat('HH:mm').format(match.utcDate),
              style: TextStyle(
                  color: isSoon ? AppTheme.brand : p.textHi,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(
            countdownStr ?? DateFormat('d MMM').format(match.utcDate),
            style: TextStyle(
                color: isSoon ? AppTheme.brand.withValues(alpha: 0.7) : p.textLow,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

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

class _GoalBadge extends StatefulWidget {
  const _GoalBadge();
  @override
  State<_GoalBadge> createState() => _GoalBadgeState();
}

class _GoalBadgeState extends State<_GoalBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.6, end: 1.0).animate(_c),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: AppTheme.liveGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '⚽ GOAL!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _CardScorers extends StatelessWidget {
  final Match match;
  final Palette p;
  const _CardScorers({required this.match, required this.p});

  String _short(String name) {
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return '${parts.first[0]}. ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final home = match.goals
        .where((g) => g.teamId == match.homeTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));
    final away = match.goals
        .where((g) => g.teamId == match.awayTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));

    Widget col(List<MatchGoal> goals, bool alignRight) => Column(
          crossAxisAlignment: alignRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: goals
              .map((g) {
                final name = g.scorerName?.isNotEmpty == true
                    ? _short(g.scorerName!)
                    : '—';
                final suffix =
                    g.isPenalty ? ' (P)' : g.isOwnGoal ? ' (OG)' : '';
                final label = alignRight
                    ? "${g.minute}' $name$suffix"
                    : "$name$suffix ${g.minute}'";
                return Text(
                  label,
                  style: TextStyle(
                      fontSize: 10,
                      color: p.textLow,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              })
              .toList(),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(home, false)),
        const SizedBox(width: 80),
        Expanded(child: col(away, true)),
      ],
    );
  }
}
