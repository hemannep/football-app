// tabs/h2h_tab.dart
//
// Head-to-head tab: win/draw/loss summary + recent meetings.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── H2H tab ──────────────────────────────────────────────────────────────────

class _H2HTab extends ConsumerWidget {
  final Match match;
  const _H2HTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Historical H2H records from the Firestore relay (if available).
    final rawDoc = ref.watch(_rawMatchProvider(match)).value;
    final relayH2H = rawDoc?['head_to_head'];
    final relayMeetings = relayH2H is Map
        ? (relayH2H['matches'] as List?)?.cast<Map>() ?? const []
        : const <Map>[];

    final allMatches = ref.watch(liveScoreProvider).matches;
    final h2h = allMatches.where((m) {
      if (!m.isFinished) return false;
      final tlas = {m.homeTeam.tla, m.awayTeam.tla};
      return tlas.containsAll({match.homeTeam.tla, match.awayTeam.tla});
    }).toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));

    int homeWins = 0, awayWins = 0, draws = 0;

    // Prefer relay H2H (cross-competition history); fall back to in-memory.
    if (relayMeetings.isNotEmpty) {
      for (final rm in relayMeetings) {
        final sc = rm['score'] as Map?;
        final ft = sc?['fullTime'] as Map?;
        if (ft == null) continue;
        final hg = (ft['home'] as num?)?.toInt() ?? 0;
        final ag = (ft['away'] as num?)?.toInt() ?? 0;
        if (hg == ag) {
          draws++;
          continue;
        }
        // Determine if this relay meeting's home team is our match's home team.
        final rmHomeId = (rm['homeTeam'] as Map?)?['id'];
        bool rmIsCurrentHome;
        if (rmHomeId != null && match.homeTeam.id != null) {
          rmIsCurrentHome = rmHomeId == match.homeTeam.id;
        } else {
          final rmHomeTla = (rm['homeTeam'] as Map?)?['tla'] as String?;
          final rmHomeName = (rm['homeTeam'] as Map?)?['name'] as String? ?? '';
          rmIsCurrentHome = rmHomeTla == match.homeTeam.tla ||
              rmHomeName.toLowerCase().contains(match.homeTeam.tla.toLowerCase());
        }
        if (rmIsCurrentHome ? hg > ag : ag > hg) {
          homeWins++;
        } else {
          awayWins++;
        }
      }
    } else {
      for (final m in h2h) {
        final hg = m.score.homeGoals ?? 0;
        final ag = m.score.awayGoals ?? 0;
        if (hg == ag) {
          draws++;
        } else if (m.homeTeam.tla == match.homeTeam.tla) {
          hg > ag ? homeWins++ : awayWins++;
        } else {
          ag > hg ? homeWins++ : awayWins++;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // W/D/L summary
        _DetailCard(
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: _H2HCell(
                        value: '$homeWins',
                        label: '${match.homeTeam.tla} wins',
                        color: AppTheme.brand)),
                Container(width: 1, height: 50, color: p.stroke),
                Expanded(
                    child: _H2HCell(
                        value: '$draws', label: 'Draws', color: p.textMid)),
                Container(width: 1, height: 50, color: p.stroke),
                Expanded(
                    child: _H2HCell(
                        value: '$awayWins',
                        label: '${match.awayTeam.tla} wins',
                        color: AppTheme.live)),
              ]),
              if (homeWins + draws + awayWins > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 8,
                    child: Row(children: [
                      Expanded(
                        flex: homeWins.clamp(1, 999),
                        child: const ColoredBox(color: AppTheme.brand),
                      ),
                      Expanded(
                        flex: draws.clamp(1, 999),
                        child: ColoredBox(color: p.textLow),
                      ),
                      Expanded(
                        flex: awayWins.clamp(1, 999),
                        child: const ColoredBox(color: AppTheme.live),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${(homeWins / (homeWins + draws + awayWins) * 100).round()}%',
                      style: const TextStyle(fontSize: 10, color: AppTheme.brand, fontWeight: FontWeight.w700),
                    ),
                    Expanded(
                      child: Text(
                        '${homeWins + draws + awayWins} meetings',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: p.textLow),
                      ),
                    ),
                    Text(
                      '${(awayWins / (homeWins + draws + awayWins) * 100).round()}%',
                      style: const TextStyle(fontSize: 10, color: AppTheme.live, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── H2H Analytics (computed from relay meetings) ────────────────────
        if (relayMeetings.isNotEmpty) ...[
          const _SectionLabel('H2H Analytics'),
          _H2HAnalyticsCard(meetings: relayMeetings, p: p),
          const SizedBox(height: 10),
        ],

        if (relayMeetings.isNotEmpty) ...[
          const _SectionLabel('Historical Meetings'),
          ...relayMeetings.take(10).map((rm) {
            final htMap = (rm['homeTeam'] as Map?);
            final atMap = (rm['awayTeam'] as Map?);
            final homeTeamName = htMap?['name'] as String? ?? htMap?['tla'] as String? ?? '—';
            final awayTeamName = atMap?['name'] as String? ?? atMap?['tla'] as String? ?? '—';
            final homeCrest   = htMap?['crest'] as String?;
            final awayCrest   = atMap?['crest'] as String?;
            final sc = rm['score'] as Map?;
            final ft = sc?['fullTime'] as Map?;
            final hg = (ft?['home'] as num?)?.toInt();
            final ag = (ft?['away'] as num?)?.toInt();
            final scoreStr = hg != null && ag != null ? '$hg – $ag' : 'vs';
            final compName = (rm['competition'] as Map?)?['name'] as String?;
            final dateStr = rm['utcDate'] as String?;
            DateTime? dt;
            if (dateStr != null) dt = DateTime.tryParse(dateStr)?.toLocal();

            // Score pill color from current home team's perspective.
            Color pillBg = p.surfaceHi;
            Color pillText = p.textHi;
            if (hg != null && ag != null) {
              final rmHomeId = htMap?['id'];
              final bool rmIsCurrentHome = (rmHomeId != null && match.homeTeam.id != null)
                  ? rmHomeId == match.homeTeam.id
                  : (htMap?['tla'] as String?) == match.homeTeam.tla;
              final currentTeamGoals = rmIsCurrentHome ? hg : ag;
              final opponentGoals    = rmIsCurrentHome ? ag : hg;
              if (currentTeamGoals > opponentGoals) {
                pillBg = AppTheme.good.withValues(alpha: 0.15);
                pillText = AppTheme.good;
              } else if (currentTeamGoals < opponentGoals) {
                pillBg = AppTheme.bad.withValues(alpha: 0.12);
                pillText = AppTheme.bad;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compName != null) ...[
                    Text(compName,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: p.textLow,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 6),
                  ],
                  Row(children: [
                    if (dt != null)
                      SizedBox(
                        width: 44,
                        child: Text(DateFormat('d MMM').format(dt),
                            style: TextStyle(
                                fontSize: 11,
                                color: p.textLow,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(width: 6),
                    TeamCrestWidget(crestUrl: homeCrest, tla: htMap?['tla'] as String? ?? '?', size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(homeTeamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textHi)),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(scoreStr,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: pillText)),
                    ),
                    Expanded(
                      child: Text(awayTeamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textHi)),
                    ),
                    const SizedBox(width: 6),
                    TeamCrestWidget(crestUrl: awayCrest, tla: atMap?['tla'] as String? ?? '?', size: 18),
                  ]),
                ],
              ),
            );
          }),
        ],
        if (h2h.isEmpty && relayMeetings.isEmpty)
          const _Unavailable(
              icon: Icons.history_rounded,
              message: 'No previous meetings found.')
        else if (h2h.isNotEmpty) ...[
          const _SectionLabel('Recent Meetings'),
          ...h2h.take(10).map((m) {
            final hg = m.score.homeGoals ?? 0;
            final ag = m.score.awayGoals ?? 0;
            final isCurrentHome = m.homeTeam.tla == match.homeTeam.tla;
            final myGoals  = isCurrentHome ? hg : ag;
            final oppGoals = isCurrentHome ? ag : hg;
            Color pillBg   = p.surfaceHi;
            Color pillText = p.textHi;
            if (m.score.homeGoals != null) {
              if (myGoals > oppGoals) {
                pillBg = AppTheme.good.withValues(alpha: 0.15);
                pillText = AppTheme.good;
              } else if (myGoals < oppGoals) {
                pillBg = AppTheme.bad.withValues(alpha: 0.12);
                pillText = AppTheme.bad;
              }
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.stroke),
              ),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: Text(DateFormat('d MMM').format(m.utcDate),
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textLow,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                TeamCrestWidget(crestUrl: m.homeTeam.crest, tla: m.homeTeam.tla, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(m.homeTeam.tla,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(m.score.display,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: pillText)),
                ),
                Expanded(
                  child: Text(m.awayTeam.tla,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                ),
                const SizedBox(width: 6),
                TeamCrestWidget(crestUrl: m.awayTeam.crest, tla: m.awayTeam.tla, size: 18),
              ]),
            );
          }),
        ],
      ],
    );
  }
}

class _H2HCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _H2HCell(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.of(context).textLow,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─── H2H Analytics card ───────────────────────────────────────────────────────

class _H2HAnalyticsCard extends StatelessWidget {
  final List<Map> meetings;
  final Palette p;
  const _H2HAnalyticsCard({required this.meetings, required this.p});

  @override
  Widget build(BuildContext context) {
    int counted = 0, over25 = 0, over15 = 0, btts = 0, cleanSheet = 0;
    double totalGoals = 0;

    for (final rm in meetings) {
      final sc = rm['score'] as Map?;
      final ft = sc?['fullTime'] as Map?;
      final hg = (ft?['home'] as num?)?.toInt();
      final ag = (ft?['away'] as num?)?.toInt();
      if (hg == null || ag == null) continue;
      counted++;
      final total = hg + ag;
      totalGoals += total;
      if (total >= 3) over25++;
      if (total >= 2) over15++;
      if (hg > 0 && ag > 0) btts++;
      if (hg == 0 || ag == 0) cleanSheet++;
    }

    if (counted == 0) return const SizedBox.shrink();

    final gpm = totalGoals / counted;
    final pOver25 = (over25 * 100 / counted).round();
    final pOver15 = (over15 * 100 / counted).round();
    final pBtts   = (btts * 100 / counted).round();
    final pCs     = (cleanSheet * 100 / counted).round();

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
          Row(children: [
            Text('Based on $counted matches',
                style: TextStyle(fontSize: 10, color: p.textLow, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          // 2×2 stat grid
          Row(children: [
            Expanded(child: _AnalyticTile(
              label: 'Over 2.5', pct: pOver25,
              sub: pOver25 < 50 ? 'Unlikely' : pOver25 < 70 ? 'Possible' : 'Likely',
              color: _pctColor(pOver25),
            )),
            const SizedBox(width: 8),
            Expanded(child: _AnalyticTile(
              label: 'Over 1.5', pct: pOver15,
              sub: pOver15 < 50 ? 'Unlikely' : pOver15 < 70 ? 'Possible' : 'Likely',
              color: _pctColor(pOver15),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _AnalyticTile(
              label: 'BTTS', pct: pBtts,
              sub: 'Both teams score',
              color: _pctColor(pBtts),
            )),
            const SizedBox(width: 8),
            Expanded(child: _AnalyticTile(
              label: 'Goals/Match',
              valueStr: gpm.toStringAsFixed(1),
              sub: 'Avg total goals',
              color: AppTheme.brand,
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _AnalyticTile(
              label: 'Clean Sheet', pct: pCs,
              sub: 'At least one team',
              color: _pctColor(pCs),
            )),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }

  Color _pctColor(int pct) {
    if (pct >= 70) return AppTheme.good;
    if (pct >= 40) return AppTheme.warn;
    return AppTheme.bad;
  }
}

class _AnalyticTile extends StatelessWidget {
  final String label;
  final int? pct;
  final String? valueStr;
  final String sub;
  final Color color;
  const _AnalyticTile({
    required this.label,
    this.pct,
    this.valueStr,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final display = valueStr ?? (pct != null ? '$pct%' : '—');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.textLow)),
          const SizedBox(height: 4),
          Text(display,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(sub,
              style: TextStyle(fontSize: 9, color: p.textLow)),
        ],
      ),
    );
  }
}
