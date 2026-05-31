// tabs/standings_tab.dart
//
// Standings tab: group/league table with both teams highlighted.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── Standings tab ────────────────────────────────────────────────────────────

class _StandingsTab extends ConsumerWidget {
  final Match match;
  const _StandingsTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code =
        match.competitionCode ?? ref.watch(liveScoreProvider).competitionCode;
    final async = ref.watch(_matchStandingsProvider(code));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Unavailable(
          icon: Icons.table_chart_outlined, message: 'Standings unavailable.'),
      data: (groups) {
        if (groups.isEmpty) {
          return const _Unavailable(
              icon: Icons.table_chart_outlined,
              message: 'No standings for this competition.');
        }
        final relevant = groups.where((g) {
          return g.teams.any((t) =>
              t.tla == match.homeTeam.tla || t.tla == match.awayTeam.tla);
        }).toList();
        final list = relevant.isEmpty ? groups : relevant;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
          itemCount: list.length,
          itemBuilder: (_, i) => _StandingsTable(
            group: list[i],
            highlight: {match.homeTeam.tla, match.awayTeam.tla},
          ),
        );
      },
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final GroupTable group;
  final Set<String> highlight;
  const _StandingsTable({required this.group, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(
                group.groupName.replaceAll('_', ' '),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: p.textHi),
              ),
            ),
            ..._headerCell('W', color: AppTheme.good),
            ..._headerCell('D', color: AppTheme.warn),
            ..._headerCell('L', color: AppTheme.bad),
            ..._headerCell('GD'),
            ..._headerCell('Pts', bold: true),
          ]),
        ),
        Divider(height: 1, thickness: 1, color: p.stroke),
        ...group.teams.map((t) {
          final isHl = highlight.contains(t.tla);
          return Container(
            color: isHl
                ? AppTheme.brand.withValues(alpha: 0.07)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: Text('${t.position}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.textLow)),
                ),
                const SizedBox(width: 8),
                TeamCrestWidget(crestUrl: t.crest, tla: t.tla, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isHl ? FontWeight.w800 : FontWeight.w600,
                          color: p.textHi)),
                ),
                ..._wdlCell('${t.won}', t.won > 0 ? AppTheme.good : p.textLow, t.won > 0),
                ..._wdlCell('${t.draw}', p.textMid, false),
                ..._wdlCell('${t.lost}', t.lost > 0 ? AppTheme.bad : p.textLow, t.lost > 0),
                ..._gdCell(t.goalDifference, p),
                ..._valueCell('${t.points}', p, bold: true),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  List<Widget> _headerCell(String s, {bool bold = false, Color? color}) => [
        SizedBox(
          width: 28,
          child: Text(s,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: color ?? const Color(0xFF9E9E9E))),
        ),
      ];

  List<Widget> _wdlCell(String v, Color color, bool bold) => [
        SizedBox(
          width: 28,
          child: Text(v,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ),
      ];

  List<Widget> _valueCell(String v, Palette p, {bool bold = false}) => [
        SizedBox(
          width: 34,
          child: Text(v,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? p.textHi : p.textMid)),
        ),
      ];

  List<Widget> _gdCell(int gd, Palette p) {
    final color = gd > 0
        ? AppTheme.good
        : gd < 0
            ? AppTheme.live
            : p.textMid;
    return [
      SizedBox(
        width: 34,
        child: Text(gd > 0 ? '+$gd' : '$gd',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    ];
  }
}
