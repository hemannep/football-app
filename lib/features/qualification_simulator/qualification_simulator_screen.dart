// lib/features/qualification_simulator/qualification_simulator_screen.dart
//
// Spec feature #16 — Qualification Simulator.
//
// Lets the user pick a team and toggle hypothetical results for their
// remaining group matches to see if they advance (top 2 + 8 best 3rds).
//
// Uses fd.org standings + remaining fixtures via existing providers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart';
import '../../shared/models/standing.dart';
import '../../shared/widgets/ad_banner_widget.dart';
import '../../shared/widgets/team_crest_widget.dart';

class QualificationSimulatorScreen extends ConsumerStatefulWidget {
  const QualificationSimulatorScreen({super.key});

  @override
  ConsumerState<QualificationSimulatorScreen> createState() =>
      _QualificationSimulatorScreenState();
}

class _QualificationSimulatorScreenState
    extends ConsumerState<QualificationSimulatorScreen> {
  String? _selectedTla;
  // Result selections for each remaining match: key=matchKey, value='W'/'D'/'L'
  final Map<String, String> _hypothetical = {};

  /// Public so descendants located via `findAncestorStateOfType` can update
  /// the hypothetical map without triggering an `invalid_use_of_protected_member`
  /// warning (calling `setState` directly on someone else's State is the
  /// protected-member violation analyzer flags).
  void setHypothetical(String matchKey, String result) {
    setState(() {
      _hypothetical[matchKey] = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final scoreState = ref.watch(liveScoreProvider);
    final standingsAsync = ref.watch(standingsStreamProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('Qualification Simulator',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                  if (_hypothetical.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => setState(() {
                        _hypothetical.clear();
                      }),
                      tooltip: 'Reset',
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
                'Pick your team and toggle hypothetical results for their remaining matches. The simulator shows if they\'d advance.',
                style: TextStyle(fontSize: 12, color: p.textMid)),
          ),
          Expanded(
            child: standingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Couldn't load standings.",
                    style: TextStyle(color: p.textMid)),
              )),
              data: (groups) => _buildContent(scoreState, groups, p),
            ),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }

  Widget _buildContent(
      LiveScoreState scoreState, List<GroupTable> groups, Palette p) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No group-stage data for this competition yet.',
              style: TextStyle(color: p.textMid)),
        ),
      );
    }

    // Find the group containing the selected team
    GroupTable? selectedGroup;
    TeamStanding? me;
    if (_selectedTla != null) {
      for (final g in groups) {
        for (final t in g.teams) {
          if (t.tla == _selectedTla) {
            selectedGroup = g;
            me = t;
            break;
          }
        }
        if (selectedGroup != null) break;
      }
    }

    final remainingMatches = _selectedTla == null
        ? <Match>[]
        : scoreState.matches
            .where((m) =>
                !m.isFinished &&
                (m.homeTeam.tla == _selectedTla ||
                    m.awayTeam.tla == _selectedTla))
            .toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    final hypotheticalTable = _computeProjection(
      scoreState: scoreState,
      groups: groups,
      selectedTla: _selectedTla,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        // Team picker
        _TeamPickerCard(
          groups: groups,
          selected: _selectedTla,
          onPicked: (t) => setState(() {
            _selectedTla = t;
            _hypothetical.clear();
          }),
        ),
        if (_selectedTla != null && me != null && selectedGroup != null) ...[
          const SizedBox(height: 12),
          _CurrentPositionCard(
              team: me, groupName: selectedGroup.groupName, p: p),
          const SizedBox(height: 12),
          if (remainingMatches.isEmpty)
            _NoMoreMatchesCard(p: p)
          else ...[
            const _SectionHeader(text: 'REMAINING MATCHES'),
            ...remainingMatches.map(
                (m) => _RemainingMatchTile(match: m, myTla: _selectedTla!)),
          ],
          const SizedBox(height: 12),
          _ProjectionCard(
            projection: hypotheticalTable,
            myTla: _selectedTla!,
            p: p,
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Simulates the final standings given the user's hypothetical results.
  /// Returns the sorted projected group table.
  List<_ProjectedTeam> _computeProjection({
    required LiveScoreState scoreState,
    required List<GroupTable> groups,
    required String? selectedTla,
  }) {
    if (selectedTla == null) return const [];

    // Find the user's group
    GroupTable? group;
    for (final g in groups) {
      if (g.teams.any((t) => t.tla == selectedTla)) {
        group = g;
        break;
      }
    }
    if (group == null) return const [];

    // Map of TLA → projected stats
    final projected = <String, _ProjectedTeam>{};
    for (final t in group.teams) {
      projected[t.tla] = _ProjectedTeam(
        tla: t.tla,
        name: t.teamName,
        crest: t.crest,
        played: t.playedGames,
        wins: t.won,
        draws: t.draw,
        losses: t.lost,
        goalsFor: t.goalsFor,
        goalsAgainst: t.goalsAgainst,
        points: t.points,
      );
    }

    // Apply hypothetical results
    for (final entry in _hypothetical.entries) {
      final match = scoreState.matches
          .firstWhere((m) => m.matchKey == entry.key, orElse: () => _empty);
      if (match.id == 0) continue;
      final outcome = entry.value;
      _applyMatchOutcome(projected, match, outcome);
    }

    // Sort by points → GD → GF
    final list = projected.values.toList()
      ..sort((a, b) {
        final byPts = b.points.compareTo(a.points);
        if (byPts != 0) return byPts;
        final byGd = b.goalDiff.compareTo(a.goalDiff);
        if (byGd != 0) return byGd;
        return b.goalsFor.compareTo(a.goalsFor);
      });
    return list;
  }

  static final _empty = Match(
    id: 0,
    status: 'SCHEDULED',
    utcDate: DateTime(2026),
    homeTeam: const TeamRef(id: 0, name: '', tla: '', crest: null),
    awayTeam: const TeamRef(id: 0, name: '', tla: '', crest: null),
    score: const Score(
        homeGoals: null, awayGoals: null, winner: null, duration: null),
    stage: '',
    group: null,
    competitionName: null,
    competitionCode: null,
    venue: null,
    goals: const [],
  );

  void _applyMatchOutcome(
      Map<String, _ProjectedTeam> projected, Match match, String outcome) {
    final home = projected[match.homeTeam.tla];
    final away = projected[match.awayTeam.tla];
    if (home == null || away == null) return;

    // Assume a 1-0 / 0-0 / 0-1 score for simplicity (doesn't affect points).
    final (hg, ag) = switch (outcome) {
      'W' => (1, 0),
      'L' => (0, 1),
      _ => (0, 0),
    };

    home.played += 1;
    away.played += 1;
    home.goalsFor += hg;
    home.goalsAgainst += ag;
    away.goalsFor += ag;
    away.goalsAgainst += hg;
    if (hg > ag) {
      home.wins += 1;
      away.losses += 1;
      home.points += 3;
    } else if (hg < ag) {
      away.wins += 1;
      home.losses += 1;
      away.points += 3;
    } else {
      home.draws += 1;
      away.draws += 1;
      home.points += 1;
      away.points += 1;
    }
  }
}

class _ProjectedTeam {
  final String tla;
  final String name;
  final String? crest;
  int played, wins, draws, losses, goalsFor, goalsAgainst, points;
  _ProjectedTeam({
    required this.tla,
    required this.name,
    this.crest,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });
  int get goalDiff => goalsFor - goalsAgainst;
}

// ─── UI parts ───────────────────────────────────────────────────────────────

class _TeamPickerCard extends StatelessWidget {
  final List<GroupTable> groups;
  final String? selected;
  final ValueChanged<String?> onPicked;
  const _TeamPickerCard({
    required this.groups,
    required this.selected,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final teams = <TeamStanding>[];
    for (final g in groups) {
      teams.addAll(g.teams);
    }
    teams.sort((a, b) => a.teamName.compareTo(b.teamName));

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.r),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: p.bg,
          builder: (_) => _PickerSheet(teams: teams, selected: selected),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: AppTheme.brand, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR TEAM',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: p.textLow)),
                  const SizedBox(height: 2),
                  Text(
                      selected == null
                          ? 'Tap to pick'
                          : teams
                              .firstWhere((t) => t.tla == selected,
                                  orElse: () => teams.first)
                              .teamName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: p.textHi)),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: p.textLow),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final List<TeamStanding> teams;
  final String? selected;
  const _PickerSheet({required this.teams, required this.selected});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final filtered = widget.teams
        .where((t) =>
            _q.isEmpty || t.teamName.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: p.stroke, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search teams',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final t = filtered[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, t.tla),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: p.stroke.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          TeamCrestWidget(
                              crestUrl: t.crest, tla: t.tla, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(t.teamName,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: p.textHi))),
                          Text('${t.points} pts',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brand)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPositionCard extends StatelessWidget {
  final TeamStanding team;
  final String groupName;
  final Palette p;
  const _CurrentPositionCard(
      {required this.team, required this.groupName, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text('${team.position}',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: p.textHi,
                      height: 1.0)),
              Text(_ordinal(team.position),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: p.textLow)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.teamName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: p.textHi)),
                Text(groupName,
                    style: TextStyle(
                        fontSize: 11,
                        color: p.textLow,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stat('${team.points} pts', AppTheme.brand),
                    const SizedBox(width: 8),
                    _stat(
                        '${team.goalDifference > 0 ? '+' : ''}${team.goalDifference} GD',
                        team.goalDifference >= 0
                            ? AppTheme.good
                            : AppTheme.bad),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'PLACE';
    return switch (n % 10) {
      1 => 'st PLACE',
      2 => 'nd PLACE',
      3 => 'rd PLACE',
      _ => 'th PLACE',
    };
  }
}

class _NoMoreMatchesCard extends StatelessWidget {
  final Palette p;
  const _NoMoreMatchesCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.good, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Group stage complete for this team.',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textMid)),
          ),
        ],
      ),
    );
  }
}

class _RemainingMatchTile extends ConsumerWidget {
  final Match match;
  final String myTla;
  const _RemainingMatchTile({required this.match, required this.myTla});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final state =
        context.findAncestorStateOfType<_QualificationSimulatorScreenState>();
    final chosen = state?._hypothetical[match.matchKey];

    final isHome = match.homeTeam.tla == myTla;
    final opponent = isHome ? match.awayTeam : match.homeTeam;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(isHome ? 'vs' : '@',
                  style: TextStyle(
                      fontSize: 11,
                      color: p.textLow,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              TeamCrestWidget(
                  crestUrl: opponent.crest, tla: opponent.tla, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(opponent.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.textHi)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _OutcomeButton(
                      label: 'Win',
                      isSelected: chosen == 'W',
                      color: AppTheme.good,
                      onTap: () =>
                          state?.setHypothetical(match.matchKey, 'W'))),
              const SizedBox(width: 6),
              Expanded(
                  child: _OutcomeButton(
                      label: 'Draw',
                      isSelected: chosen == 'D',
                      color: AppTheme.warn,
                      onTap: () =>
                          state?.setHypothetical(match.matchKey, 'D'))),
              const SizedBox(width: 6),
              Expanded(
                  child: _OutcomeButton(
                      label: 'Lose',
                      isSelected: chosen == 'L',
                      color: AppTheme.bad,
                      onTap: () =>
                          state?.setHypothetical(match.matchKey, 'L'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _OutcomeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : p.surfaceHi,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (color.computeLuminance() > 0.3
                        ? Colors.black
                        : Colors.white)
                    : p.textMid)),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final List<_ProjectedTeam> projection;
  final String myTla;
  final Palette p;
  const _ProjectionCard({
    required this.projection,
    required this.myTla,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    if (projection.isEmpty) return const SizedBox.shrink();

    final myIndex = projection.indexWhere((t) => t.tla == myTla);
    final myFinal = projection[myIndex];
    final qualifies = myIndex < 2;
    final thirdPlace = myIndex == 2;

    final headlineColor = qualifies
        ? AppTheme.good
        : thirdPlace
            ? AppTheme.warn
            : AppTheme.bad;
    final headline = qualifies
        ? 'AUTOMATIC QUALIFICATION'
        : thirdPlace
            ? 'BEST-3RD-PLACE RACE'
            : 'ELIMINATED';
    final subtext = qualifies
        ? '${myFinal.tla} would finish ${_ord(myIndex + 1)} and advance directly to the Round of 32.'
        : thirdPlace
            ? '${myFinal.tla} would finish 3rd with ${myFinal.points} pts. Qualification depends on the other 11 groups\' 3rd-placed teams (8 best advance).'
            : '${myFinal.tla} would finish ${_ord(myIndex + 1)} with ${myFinal.points} pts and exit the tournament.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: headlineColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  qualifies
                      ? Icons.check_circle_rounded
                      : thirdPlace
                          ? Icons.hourglass_bottom_rounded
                          : Icons.cancel_rounded,
                  color: headlineColor,
                  size: 18),
              const SizedBox(width: 6),
              Text(headline,
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: headlineColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtext,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: p.textMid,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('PROJECTED FINAL TABLE',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: p.textLow)),
          const SizedBox(height: 6),
          ...projection.asMap().entries.map((e) {
            final pos = e.key + 1;
            final t = e.value;
            final isMe = t.tla == myTla;
            final color = pos <= 2
                ? AppTheme.good
                : pos == 3
                    ? AppTheme.warn
                    : AppTheme.bad;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.brand.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 16,
                      child: Text('$pos',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: p.textMid))),
                  TeamCrestWidget(crestUrl: t.crest, tla: t.tla, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isMe ? FontWeight.w900 : FontWeight.w700,
                            color: p.textHi)),
                  ),
                  Text('${t.points}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: p.textHi)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _ord(int n) => switch (n) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        _ => '${n}th',
      };
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: p.textLow)),
    );
  }
}
