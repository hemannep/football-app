// lib/features/team_comparison/team_comparison_screen.dart
//
// Spec feature #19 — Team Comparison Tool.
// Side-by-side stats for any two teams. Uses existing fd.org team-matches
// data via ApiService.fetchTeamMatches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/live_score_provider.dart';
import '../../core/services/live_data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/match.dart';
import '../../shared/widgets/ad_banner_widget.dart';
import '../../shared/widgets/team_crest_widget.dart';

final _teamMatchesProvider =
    FutureProvider.family<List<Match>, int>((ref, teamId) async {
  final all = await LiveDataService.instance.getMatches();
  return all
      .where((m) =>
          (m.homeTeam.id != null && m.homeTeam.id == teamId) ||
          (m.awayTeam.id != null && m.awayTeam.id == teamId))
      .toList();
});

class _TeamSummary {
  final int? teamId;
  final String name;
  final String tla;
  final String? crest;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final List<String> last5; // W/D/L
  const _TeamSummary({
    this.teamId,
    required this.name,
    required this.tla,
    this.crest,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.last5,
  });

  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
  double get winRate => played == 0 ? 0 : wins / played;
}

class TeamComparisonScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected teams (e.g. when launched from a match details
  /// screen). Either or both can be null — user picks from a dropdown.
  final TeamRef? initialA;
  final TeamRef? initialB;
  const TeamComparisonScreen({super.key, this.initialA, this.initialB});

  @override
  ConsumerState<TeamComparisonScreen> createState() =>
      _TeamComparisonScreenState();
}

class _TeamComparisonScreenState extends ConsumerState<TeamComparisonScreen> {
  TeamRef? _a;
  TeamRef? _b;

  @override
  void initState() {
    super.initState();
    _a = widget.initialA;
    _b = widget.initialB;
  }

  _TeamSummary _summary(TeamRef ref, List<Match> matches) {
    final played = matches.where((m) => m.isFinished).toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    int w = 0, d = 0, l = 0, gf = 0, ga = 0;
    final last5 = <String>[];
    for (final m in played) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final us = m.homeTeam.tla == ref.tla ? hg : ag;
      final them = m.homeTeam.tla == ref.tla ? ag : hg;
      gf += us;
      ga += them;
      String code;
      if (us > them) {
        w++;
        code = 'W';
      } else if (us < them) {
        l++;
        code = 'L';
      } else {
        d++;
        code = 'D';
      }
      if (last5.length < 5) last5.add(code);
    }
    return _TeamSummary(
      teamId: ref.id,
      name: ref.name,
      tla: ref.tla,
      crest: ref.crest,
      played: played.length,
      wins: w,
      draws: d,
      losses: l,
      goalsFor: gf,
      goalsAgainst: ga,
      last5: last5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final allTeams = _allTeams(ref);

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
                    child: Text('Compare Teams',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: _TeamPicker(
                    label: 'Team A',
                    selected: _a,
                    teams: allTeams,
                    onChanged: (t) => setState(() => _a = t),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.compare_arrows_rounded,
                      size: 18, color: AppTheme.brand),
                ),
                Expanded(
                  child: _TeamPicker(
                    label: 'Team B',
                    selected: _b,
                    teams: allTeams,
                    onChanged: (t) => setState(() => _b = t),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: (_a == null || _b == null)
                ? _emptyPicker(p)
                : _buildComparison(p),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }

  Widget _buildComparison(Palette p) {
    final aId = _a!.id;
    final bId = _b!.id;
    if (aId == null || bId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('One of the teams has no match data yet.',
              textAlign: TextAlign.center, style: TextStyle(color: p.textMid)),
        ),
      );
    }

    final aA = ref.watch(_teamMatchesProvider(aId));
    final aB = ref.watch(_teamMatchesProvider(bId));

    return aA.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _err(p, '$e'),
      data: (matchesA) => aB.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(p, '$e'),
        data: (matchesB) {
          final sa = _summary(_a!, matchesA);
          final sb = _summary(_b!, matchesB);
          final h2h = _h2hSummary(matchesA, _a!.tla, _b!.tla);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              _CompareHeader(a: sa, b: sb),
              const SizedBox(height: 12),
              _StatRow(label: 'Played', a: sa.played, b: sb.played),
              _StatRow(
                  label: 'Wins', a: sa.wins, b: sb.wins, color: AppTheme.good),
              _StatRow(
                  label: 'Draws',
                  a: sa.draws,
                  b: sb.draws,
                  color: AppTheme.warn),
              _StatRow(
                  label: 'Losses',
                  a: sa.losses,
                  b: sb.losses,
                  color: AppTheme.bad),
              _StatRow(label: 'Goals for', a: sa.goalsFor, b: sb.goalsFor),
              _StatRow(
                  label: 'Goals against',
                  a: sa.goalsAgainst,
                  b: sb.goalsAgainst),
              _StatRow(
                  label: 'Goal diff',
                  a: sa.goalDiff,
                  b: sb.goalDiff,
                  highlightBetter: true),
              _StatRow(
                  label: 'Points',
                  a: sa.points,
                  b: sb.points,
                  highlightBetter: true,
                  color: AppTheme.brand),
              const SizedBox(height: 12),
              _FormRow(label: '${sa.tla} form', codes: sa.last5),
              _FormRow(label: '${sb.tla} form', codes: sb.last5),
              const SizedBox(height: 16),
              _H2HCard(aTla: sa.tla, bTla: sb.tla, h2h: h2h),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyPicker(Palette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows_rounded, size: 56, color: p.textLow),
              const SizedBox(height: 12),
              Text('Pick two teams to compare',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textMid)),
              const SizedBox(height: 4),
              Text('Stats, recent form, head-to-head.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textLow, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _err(Palette p, String e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text("Couldn't load comparison data.",
              style: TextStyle(color: p.textMid)),
        ),
      );

  /// Head-to-head summary derived from team A's matches.
  ({int wins, int draws, int losses, List<Match> matches}) _h2hSummary(
      List<Match> matches, String aTla, String bTla) {
    final h2h = matches
        .where((m) =>
            m.isFinished &&
            {m.homeTeam.tla, m.awayTeam.tla}.containsAll({aTla, bTla}))
        .toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    int w = 0, d = 0, l = 0;
    for (final m in h2h) {
      final hg = m.score.homeGoals ?? 0;
      final ag = m.score.awayGoals ?? 0;
      final us = m.homeTeam.tla == aTla ? hg : ag;
      final them = m.homeTeam.tla == aTla ? ag : hg;
      if (us > them) {
        w++;
      } else if (us < them) {
        l++;
      } else {
        d++;
      }
    }
    return (wins: w, draws: d, losses: l, matches: h2h);
  }

  List<TeamRef> _allTeams(WidgetRef ref) {
    final matches = ref.watch(liveScoreProvider).matches;
    final seen = <String, TeamRef>{};
    for (final m in matches) {
      seen[m.homeTeam.tla] = m.homeTeam;
      seen[m.awayTeam.tla] = m.awayTeam;
    }
    final list = seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}

class _TeamPicker extends StatelessWidget {
  final String label;
  final TeamRef? selected;
  final List<TeamRef> teams;
  final ValueChanged<TeamRef?> onChanged;
  const _TeamPicker({
    required this.label,
    required this.selected,
    required this.teams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showModalBottomSheet<TeamRef>(
          context: context,
          backgroundColor: p.bg,
          builder: (_) => _PickerSheet(teams: teams, selected: selected),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.stroke),
        ),
        child: Row(
          children: [
            if (selected == null)
              Icon(Icons.add_rounded, color: p.textLow, size: 18)
            else
              TeamCrestWidget(
                crestUrl: selected!.crest,
                tla: selected!.tla,
                name: selected!.name,
                size: 22,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: p.textLow)),
                  Text(selected?.name ?? 'Pick a team',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: p.textHi)),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: p.textLow, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final List<TeamRef> teams;
  final TeamRef? selected;
  const _PickerSheet({required this.teams, required this.selected});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final filtered = widget.teams
        .where((t) =>
            _query.isEmpty ||
            t.name.toLowerCase().contains(_query.toLowerCase()) ||
            t.tla.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
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
                    color: p.stroke, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
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
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final t = filtered[i];
                    final isSelected = widget.selected?.tla == t.tla;
                    return InkWell(
                      onTap: () => Navigator.pop(context, t),
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
                              crestUrl: t.crest,
                              tla: t.tla,
                              name: t.name,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(t.name,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: p.textHi))),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  color: AppTheme.brand),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompareHeader extends StatelessWidget {
  final _TeamSummary a;
  final _TeamSummary b;
  const _CompareHeader({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(child: _teamCol(a, p)),
          const Text('vs',
              style: TextStyle(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          Expanded(child: _teamCol(b, p)),
        ],
      ),
    );
  }

  Widget _teamCol(_TeamSummary t, Palette p) => Column(
        children: [
          TeamCrestWidget(
              crestUrl: t.crest, tla: t.tla, name: t.name, size: 48),
          const SizedBox(height: 6),
          Text(t.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: p.textHi)),
        ],
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final int a;
  final int b;
  final Color? color;
  final bool highlightBetter;
  const _StatRow({
    required this.label,
    required this.a,
    required this.b,
    this.color,
    this.highlightBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final aBetter = (highlightBetter || color != null) && a > b;
    final bBetter = (highlightBetter || color != null) && b > a;
    final total = a + b;
    final aRatio = total > 0 ? a / total : 0.5;
    final aColor = aBetter ? (color ?? AppTheme.brand) : p.textMid;
    final bColor = bBetter ? (color ?? AppTheme.brand) : p.textMid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$a',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: aColor)),
                ),
              ),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      color: p.textLow)),
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$b',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: bColor)),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                child: Row(children: [
                  Expanded(
                    flex: (aRatio * 100).round().clamp(1, 99),
                    child: ColoredBox(
                        color: (color ?? AppTheme.brand)
                            .withValues(alpha: aBetter ? 1.0 : 0.35)),
                  ),
                  Expanded(
                    flex: ((1 - aRatio) * 100).round().clamp(1, 99),
                    child: ColoredBox(
                        color: (color ?? AppTheme.live)
                            .withValues(alpha: bBetter ? 1.0 : 0.35)),
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final List<String> codes;
  const _FormRow({required this.label, required this.codes});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: p.textLow,
                      fontWeight: FontWeight.w700))),
          Expanded(
            child: codes.isEmpty
                ? Text('No matches played',
                    style: TextStyle(
                        fontSize: 11,
                        color: p.textLow,
                        fontStyle: FontStyle.italic))
                : Wrap(
                    spacing: 4,
                    children: codes.map((c) {
                      final col = c == 'W'
                          ? AppTheme.good
                          : c == 'L'
                              ? AppTheme.bad
                              : AppTheme.warn;
                      return Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration:
                            BoxDecoration(color: col, shape: BoxShape.circle),
                        child: Text(c,
                            style: TextStyle(
                                color: col.computeLuminance() > 0.3
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _H2HCard extends StatelessWidget {
  final String aTla;
  final String bTla;
  final ({int wins, int draws, int losses, List<Match> matches}) h2h;
  const _H2HCard({required this.aTla, required this.bTla, required this.h2h});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HEAD-TO-HEAD',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brand)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _hstat(p, '${h2h.wins}', '$aTla wins', AppTheme.good)),
              Expanded(
                  child: _hstat(p, '${h2h.draws}', 'Draws', AppTheme.warn)),
              Expanded(
                  child:
                      _hstat(p, '${h2h.losses}', '$bTla wins', AppTheme.bad)),
            ],
          ),
          if (h2h.matches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Recent meetings',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: p.textLow)),
            const SizedBox(height: 6),
            ...h2h.matches.take(5).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                      '${m.homeTeam.tla}  ${m.score.display}  ${m.awayTeam.tla}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.textMid)),
                )),
          ]
        ],
      ),
    );
  }

  Widget _hstat(Palette p, String v, String l, Color c) => Column(
        children: [
          Text(v,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: c)),
          Text(l,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: p.textLow)),
        ],
      );
}
