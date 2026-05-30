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
import 'flag_widget.dart';

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    if (match.group != null)
                      _Chip(
                          text: _prettyGroup(match.group!),
                          color: AppTheme.brand)
                    else
                      _Chip(
                          text: _prettyStage(match.stage),
                          color: AppTheme.accent),
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
                            reverse: false)),
                    _ScoreBox(match: match),
                    Expanded(
                        child: _TeamRow(
                            name: match.awayTeam.name,
                            tla: match.awayTeam.tla,
                            reverse: true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
  final bool reverse;
  const _TeamRow(
      {required this.name, required this.tla, required this.reverse});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final flag = FlagWidget(tla: tla, size: 30);
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
            const _PulseDot(),
            const SizedBox(height: 2),
            Text(match.score.display,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1)),
            const Text('LIVE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ],
        ),
      );
    }

    if (match.isFinished) {
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
            Text(match.score.display,
                style: TextStyle(
                    color: p.textHi,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.0)),
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
          Text(DateFormat('HH:mm').format(match.utcDate),
              style: TextStyle(
                  color: p.textHi,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(DateFormat('d MMM').format(match.utcDate),
              style: TextStyle(
                  color: p.textLow, fontSize: 10, fontWeight: FontWeight.w600)),
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

class _GoalBadge extends StatelessWidget {
  const _GoalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppTheme.liveGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'GOAL!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
