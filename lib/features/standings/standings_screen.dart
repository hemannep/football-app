// lib/features/standings/standings_screen.dart
//
// Updated:
//   • Uses TeamCrestWidget instead of FlagWidget in every team row, so club
//     teams in PL / La Liga / Bundesliga / Serie A / Ligue 1 show their
//     proper crests (PNG or SVG via fd.org), while national teams still get
//     country flags. Falls back to a styled initials badge when needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/leagues.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/team_crest_widget.dart';
import '../league picker/league_picker.dart';
import '../team details/team_details_screen.dart';

class StandingsScreen extends ConsumerStatefulWidget {
  const StandingsScreen({super.key});
  @override
  ConsumerState<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends ConsumerState<StandingsScreen> {
  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final league = ref.watch(selectedLeagueProvider);
    final async = ref.watch(standingsStreamProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Standings',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: p.textHi)),
                  ),
                  const LeaguePickerChip(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () =>
                        ref.invalidate(standingsStreamProvider),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _err(p),
                data: (groups) {
                  if (groups.isEmpty) return _empty(p);
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24, top: 4),
                    children: [
                      if (league.code == Leagues.wc.code) ...[
                        _ThirdPlaceCard(groups: groups),
                      ],
                      ...groups
                          .map((g) => _GroupCard(group: g, league: league)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(Palette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard_outlined, size: 56, color: p.textLow),
              const SizedBox(height: 14),
              Text('Tables not available',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.textMid)),
              const SizedBox(height: 4),
              Text('Try another competition or check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textLow, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _err(Palette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.warn),
              const SizedBox(height: 12),
              Text("Couldn't load standings",
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: p.textMid)),
            ],
          ),
        ),
      );
}

// ─── 3rd-Place race card (WC only) ──────────────────────────────────────────

class _ThirdPlaceCard extends StatelessWidget {
  final List<GroupTable> groups;
  const _ThirdPlaceCard({required this.groups});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final thirds = <_TR>[];
    for (final g in groups) {
      if (g.teams.length >= 3) thirds.add(_TR(g.groupName, g.teams[2]));
    }
    thirds.sort((a, b) {
      if (b.team.points != a.team.points) {
        return b.team.points.compareTo(a.team.points);
      }
      if (b.team.goalDifference != a.team.goalDifference) {
        return b.team.goalDifference.compareTo(a.team.goalDifference);
      }
      return b.team.goalsFor.compareTo(a.team.goalsFor);
    });
    if (thirds.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  color: AppTheme.brand, size: 18),
              const SizedBox(width: 8),
              Text('3rd-Place Race',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.textHi)),
            ],
          ),
          const SizedBox(height: 10),
          ...thirds.asMap().entries.map((e) {
            final pos = e.key + 1;
            final r = e.value;
            final qual = pos <= 8;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: qual ? AppTheme.good : AppTheme.bad,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('$pos',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  TeamCrestWidget(
                    crestUrl: r.team.crest,
                    tla: r.team.tla,
                    name: r.team.teamName,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${r.team.teamName} (${r.group})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.textHi)),
                  ),
                  Text('${r.team.points}p',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: p.textHi)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Group card with full table ─────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final GroupTable group;
  final League league;
  const _GroupCard({required this.group, required this.league});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppTheme.r)),
            ),
            child: Row(
              children: [
                Text(group.groupName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: p.textHi)),
              ],
            ),
          ),
          // Column labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 22),
                const SizedBox(width: 30),
                Expanded(
                  child: Text('Team',
                      style: TextStyle(
                          fontSize: 10,
                          color: p.textLow,
                          fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                    width: 26,
                    child: Text('P',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: p.textLow))),
                SizedBox(
                    width: 26,
                    child: Text('GD',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: p.textLow))),
                SizedBox(
                    width: 34,
                    child: Text('Pts',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: p.textLow))),
              ],
            ),
          ),
          // Rows
          ...group.teams.asMap().entries.map((e) {
            final idx = e.key;
            final t = e.value;
            final qualifies = league.isKnockout ? idx < 2 : false;
            final thirdPlace = league.isKnockout && idx == 2;
            return InkWell(
              onTap: t.teamId != null
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => TeamDetailScreen(
                                teamId: t.teamId!,
                                fallbackName: t.teamName,
                                fallbackTla: t.tla)),
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: qualifies
                            ? AppTheme.good
                            : thirdPlace
                                ? AppTheme.warn
                                : (league.isKnockout ? AppTheme.bad : p.stroke),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 22,
                      child: Text('${t.position}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: p.textMid,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 2),
                    TeamCrestWidget(
                      crestUrl: t.crest,
                      tla: t.tla,
                      name: t.teamName,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: p.textHi)),
                    ),
                    SizedBox(
                        width: 26,
                        child: Text('${t.playedGames}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: p.textMid))),
                    SizedBox(
                      width: 26,
                      child: Text(
                        t.goalDifference > 0
                            ? '+${t.goalDifference}'
                            : '${t.goalDifference}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.goalDifference > 0
                              ? AppTheme.good
                              : t.goalDifference < 0
                                  ? AppTheme.bad
                                  : p.textMid,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('${t.points}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: p.textHi)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _TR {
  final String group;
  final TeamStanding team;
  _TR(this.group, this.team);
}
