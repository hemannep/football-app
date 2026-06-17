// lib/features/standings/standings_screen.dart
//
// Shows live group tables while Firestore has data.
// Pre-tournament fallback: when the standings collection is empty (all stats 0
// before 11 Jun), derives group membership directly from the matches stream so
// users still see the 12 groups A–L with their 4 teams.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/providers/selected_leagues_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/leagues.dart';
import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/inline_banner_ad.dart';
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
    final standingsAsync = ref.watch(standingsByLeagueProvider(league.code));
    final liveState = ref.watch(liveScoreProvider);
    final metaAsync = ref.watch(relayMetaProvider);

    final freshnessLabel = metaAsync.asData?.value.freshnessLabel ?? '';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 4),
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
                    onPressed: () {
                      LiveDataService.instance
                          .evict('standings_${league.code}');
                      LiveDataService.instance.evict('matches_all');
                      ref.invalidate(standingsByLeagueProvider(league.code));
                      ref.invalidate(matchesStreamProvider);
                    },
                  ),
                ],
              ),
            ),
            if (freshnessLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(freshnessLabel,
                      style: TextStyle(fontSize: 11, color: p.textLow)),
                ),
              ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: standingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _err(p, ref),
                data: (groups) {
                  if (groups.isNotEmpty) {
                    // ── Live standings ──────────────────────────────────
                    // Inject ad after every 2nd group table.
                    final liveItems = <Widget>[
                      if (league.code == Leagues.wc.code)
                        _ThirdPlaceCard(groups: groups),
                    ];
                    for (var gi = 0; gi < groups.length; gi++) {
                      liveItems
                          .add(_GroupCard(group: groups[gi], league: league));
                      if ((gi + 1) % 2 == 0 && gi < groups.length - 1) {
                        liveItems.add(const InlineBannerAd());
                      }
                    }
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 30, top: 4),
                      children: liveItems,
                    );
                  }

                  // ── Pre-tournament fallback ─────────────────────────
                  // Use liveScoreProvider (already loaded by home screen)
                  // so this never shows an infinite spinner.
                  if (liveState.isLoading && liveState.matches.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final fallbackMatches = liveState.matches
                      .where((m) =>
                          m.competitionCode == null ||
                          m.competitionCode == league.code)
                      .toList();
                  final preview = _buildPreview(fallbackMatches);
                  if (preview.isEmpty) return _empty(p);
                  // Inject ad after every 2nd preview group card.
                  final previewItems = <Widget>[
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warn.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.r),
                        border: Border.all(
                            color: AppTheme.warn.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 16, color: AppTheme.warn),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              league.code == 'WC'
                                  ? 'Tables update once the tournament begins (June 11)'
                                  : 'Tables will appear once the season is underway',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: p.textMid,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                  for (var pi = 0; pi < preview.length; pi++) {
                    previewItems.add(
                        _PreviewGroupCard(group: preview[pi], league: league));
                    if ((pi + 1) % 2 == 0 && pi < preview.length - 1) {
                      previewItems.add(const InlineBannerAd());
                    }
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 30, top: 4),
                    children: previewItems,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build fake group tables from match fixture data (all stats = 0).
  List<GroupTable> _buildPreview(List<Match> matches) {
    final grouped = <String, Map<int, TeamRef>>{};
    for (final m in matches) {
      final g = m.group;
      if (g == null || g.isEmpty) continue;
      grouped.putIfAbsent(g, () => {});
      if (m.homeTeam.id != null) {
        grouped[g]![m.homeTeam.id!] = m.homeTeam;
      }
      if (m.awayTeam.id != null) {
        grouped[g]![m.awayTeam.id!] = m.awayTeam;
      }
    }
    if (grouped.isEmpty) return const [];

    final keys = grouped.keys.toList()..sort();
    return keys.map((groupKey) {
      final teamRefs = grouped[groupKey]!.values.toList();
      teamRefs.sort((a, b) => a.name.compareTo(b.name));
      return GroupTable.fromJson({
        'group': groupKey,
        'table': teamRefs
            .asMap()
            .entries
            .map((e) => {
                  'position': e.key + 1,
                  'team': {
                    'id': e.value.id,
                    'name': e.value.name,
                    'tla': e.value.tla,
                    'crest': e.value.crest,
                  },
                  'playedGames': 0,
                  'won': 0,
                  'draw': 0,
                  'lost': 0,
                  'points': 0,
                  'goalsFor': 0,
                  'goalsAgainst': 0,
                  'goalDifference': 0,
                })
            .toList(),
      });
    }).toList();
  }

  Widget _empty(Palette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard_outlined, size: 56, color: p.textLow),
              const SizedBox(height: 14),
              Text('Groups not yet available',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.textMid)),
              const SizedBox(height: 4),
              Text('Check back once fixtures are published.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textLow, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _err(Palette p, WidgetRef ref) => Center(
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  LiveDataService.instance.evict('standings_all');
                  ref.invalidate(standingsStreamProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

// ─── Pre-tournament preview card ────────────────────────────────────────────

class _PreviewGroupCard extends StatelessWidget {
  final GroupTable group;
  final League league;
  const _PreviewGroupCard({required this.group, required this.league});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final prettyName = group.groupName.startsWith('GROUP_')
        ? 'Group ${group.groupName.substring(6)} · Teams'
        : '${group.groupName} · Teams';

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
                Text(prettyName,
                    style: TextStyle(
                        fontSize: 13,
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
                    child: Text('MP',
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
          ...group.teams.map((t) => InkWell(
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
                      TeamCrestWidget(
                        crestUrl: t.crest,
                        tla: t.tla,
                        name: t.teamName,
                        size: 22,
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
                          child: Text('0',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 12, color: p.textLow))),
                      SizedBox(
                        width: 34,
                        child: Text('–',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: p.textLow)),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
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

// ─── Live group card ─────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final GroupTable group;
  final League league;
  const _GroupCard({required this.group, required this.league});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final prettyName = group.groupName.startsWith('GROUP_')
        ? 'Group ${group.groupName.substring(6)} · Standings'
        : '${group.groupName} · Standings';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(AppTheme.r)),
            ),
            child: Row(
              children: [
                Text(prettyName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: p.textHi)),
              ],
            ),
          ),
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
                const SizedBox(
                    width: 22,
                    child: Text('W',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.good))),
                const SizedBox(
                    width: 22,
                    child: Text('D',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.warn))),
                const SizedBox(
                    width: 22,
                    child: Text('L',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.bad))),
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
                        width: 22,
                        child: Text('${t.won}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: t.won > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: t.won > 0 ? AppTheme.good : p.textLow))),
                    SizedBox(
                        width: 22,
                        child: Text('${t.draw}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: p.textMid))),
                    SizedBox(
                        width: 22,
                        child: Text('${t.lost}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: t.lost > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: t.lost > 0 ? AppTheme.bad : p.textLow))),
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
