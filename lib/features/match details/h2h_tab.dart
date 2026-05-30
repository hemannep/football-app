// tabs/h2h_tab.dart
//
// Head-to-head tab: win/draw/loss summary + recent meetings.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── H2H tab ──────────────────────────────────────────────────────────────────

// ignore: unused_element
class _H2HTab extends ConsumerWidget {
  final Match match;
  const _H2HTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Historical H2H records from the Firestore relay (if available).
    final rawDoc = ref.watch(_rawMatchProvider(match.id)).value;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // W/D/L summary
        _DetailCard(
          child: Column(
            children: [
              Text('${h2h.length} meetings',
                  style: TextStyle(
                      fontSize: 12,
                      color: p.textMid,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
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
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (relayMeetings.isNotEmpty) ...[
          const _SectionLabel('Historical meetings'),
          ...relayMeetings.take(10).map((rm) {
            final homeTeam =
                (rm['homeTeam'] as Map?)?['name'] as String? ?? '—';
            final awayTeam =
                (rm['awayTeam'] as Map?)?['name'] as String? ?? '—';
            final score = rm['score'] as Map?;
            final ft = score?['fullTime'] as Map?;
            final hg = ft?['home'];
            final ag = ft?['away'];
            final scoreStr =
                hg != null && ag != null ? '$hg – $ag' : 'vs';
            final dateStr = rm['utcDate'] as String?;
            DateTime? dt;
            if (dateStr != null) { dt = DateTime.tryParse(dateStr)?.toLocal(); }
            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.stroke),
              ),
              child: Row(children: [
                if (dt != null)
                  Text(DateFormat('d MMM yy').format(dt),
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textLow,
                          fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(homeTeam,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textHi)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.surfaceHi,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(scoreStr,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: p.textHi)),
                ),
                const SizedBox(width: 8),
                Text(awayTeam,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textHi)),
              ]),
            );
          }),
        ],
        if (h2h.isEmpty && relayMeetings.isEmpty)
          const _Unavailable(
              icon: Icons.history_rounded,
              message: 'No previous meetings found.',
              hint: 'Only matches within this competition are shown.')
        else if (h2h.isNotEmpty) ...[
          const _SectionLabel('Recent meetings'),
          ...h2h.take(10).map((m) => Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.stroke),
                ),
                child: Row(children: [
                  Text(DateFormat('d MMM yy').format(m.utcDate),
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textLow,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(m.homeTeam.tla,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.surfaceHi,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(m.score.display,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                  const SizedBox(width: 10),
                  Text(m.awayTeam.tla,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                ]),
              )),
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
