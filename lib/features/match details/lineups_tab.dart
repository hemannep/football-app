// tabs/lineups_tab.dart
//
// Lineups tab: pitch view, formation headers, two-column starter/bench lists.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── Lineups tab ──────────────────────────────────────────────────────────────

class _LineupsTab extends ConsumerWidget {
  final Match match;
  const _LineupsTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Prefer bzzLineups from the Firestore raw doc; fall back to BSD resolver.
    final rawAsync = ref.watch(_rawMatchProvider(match.id));
    final rawDoc = rawAsync.value;
    final bzzLineups = rawDoc != null ? _lineupsFromRaw(rawDoc) : null;

    if (bzzLineups != null) {
      return _buildLineupsView(context, bzzLineups, p);
    }

    final lineupsAsync = ref.watch(_lineupsProvider(match));
    return lineupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Unavailable(
          icon: Icons.groups_outlined,
          message: 'Could not load lineups.',
          hint: 'Detailed lineup data isn\'t available for every match.'),
      data: (data) => _buildLineupsView(context, data, p),
    );
  }

  Widget _buildLineupsView(
      BuildContext context, MatchLineups? data, Palette p) {
    if (data == null || (data.home == null && data.away == null)) {
      return _Unavailable(
          icon: Icons.groups_outlined,
          message: match.isFinished
              ? 'Lineups not available for this match.'
              : 'Lineups not published yet.',
          hint: match.isFinished
              ? 'Detailed lineup data isn\'t available for every competition.'
              : 'Lineups usually appear ~1 hour before kick-off.');
    }
    final home = data.home;
    final away = data.away;
    final hasStarters = (home?.starters.isNotEmpty ?? false) ||
        (away?.starters.isNotEmpty ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        if (hasStarters) ...[
          _FormationHeader(
              team: match.homeTeam, formation: home?.formation, p: p),
          _PitchView(
              starters: home?.starters ?? const [],
              color: AppTheme.brand,
              topDown: true,
              p: p),
          const SizedBox(height: 2),
          _PitchView(
              starters: away?.starters ?? const [],
              color: AppTheme.live,
              topDown: false,
              p: p),
          _FormationHeader(
              team: match.awayTeam,
              formation: away?.formation,
              p: p,
              alignRight: true),
          const SizedBox(height: 14),
        ],
        _DetailCard(
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LineupColumn(
                      team: match.homeTeam,
                      lineup: home,
                      isRight: false,
                      p: p),
                ),
                VerticalDivider(width: 1, thickness: 1, color: p.stroke),
                Expanded(
                  child: _LineupColumn(
                      team: match.awayTeam,
                      lineup: away,
                      isRight: true,
                      p: p),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Formation header strip: crest + team name + formation badge.
class _FormationHeader extends StatelessWidget {
  final TeamRef team;
  final String? formation;
  final Palette p;
  final bool alignRight;
  const _FormationHeader({
    required this.team,
    required this.formation,
    required this.p,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text(team.tla,
          style: TextStyle(
              color: p.textHi, fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(width: 8),
      if (formation != null && formation!.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: p.stroke),
          ),
          child: Text(formation!,
              style: TextStyle(
                  color: p.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5)),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignRight ? children.reversed.toList() : children,
      ),
    );
  }
}

// A half-pitch that arranges a starting XI into rows by position.
// Players are grouped G / D / M / F and spread evenly across each row.
class _PitchView extends StatelessWidget {
  final List<LineupPlayer> starters;
  final Color color;
  final bool topDown; // true: GK at top (home), false: GK at bottom (away)
  final Palette p;
  const _PitchView({
    required this.starters,
    required this.color,
    required this.topDown,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    if (starters.isEmpty) return const SizedBox.shrink();

    // Group by position bucket.
    final gk = starters.where((s) => s.position == 'G').toList();
    final def = starters.where((s) => s.position == 'D').toList();
    final mid = starters.where((s) => s.position == 'M').toList();
    final fwd = starters.where((s) => s.position == 'F').toList();
    final unknown = starters
        .where((s) => s.position == null || !'GDMF'.contains(s.position!))
        .toList();

    // If positions are missing entirely, fall back to a simple even spread.
    final rows = <List<LineupPlayer>>[];
    if (gk.isEmpty && def.isEmpty && mid.isEmpty && fwd.isEmpty) {
      // chunk into rows of ~4
      for (var i = 0; i < unknown.length; i += 4) {
        rows.add(unknown.sublist(i, (i + 4).clamp(0, unknown.length)));
      }
    } else {
      rows.addAll([gk, def, mid + unknown, fwd]);
    }
    if (!topDown) {
      // Away team mirrors: forwards near the halfway line.
      final r = rows.reversed.toList();
      rows
        ..clear()
        ..addAll(r);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: topDown
              ? [const Color(0xFF12351F), const Color(0xFF0C2417)]
              : [const Color(0xFF0C2417), const Color(0xFF12351F)],
        ),
        borderRadius: BorderRadius.vertical(
          top: topDown ? const Radius.circular(14) : Radius.zero,
          bottom: topDown ? Radius.zero : const Radius.circular(14),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          for (final row in rows)
            if (row.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row
                      .map((pl) => _PitchPlayer(player: pl, color: color))
                      .toList(),
                ),
              ),
        ],
      ),
    );
  }
}

class _PitchPlayer extends StatelessWidget {
  final LineupPlayer player;
  final Color color;
  const _PitchPlayer({required this.player, required this.color});

  @override
  Widget build(BuildContext context) {
    // Surname only, to keep tokens small on the pitch.
    final parts = player.name.trim().split(' ');
    final short = parts.isEmpty ? '' : parts.last;
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              player.shirtNumber?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 64,
            child: Text(
              short,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupColumn extends StatelessWidget {
  final TeamRef team;
  final TeamLineup? lineup;
  final bool isRight;
  final Palette p;
  const _LineupColumn(
      {required this.team,
      required this.lineup,
      required this.isRight,
      required this.p});

  @override
  Widget build(BuildContext context) {
    if (lineup == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment:
            isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Team header — tappable, opens TeamDetailScreen if id available
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: team.id == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TeamDetailScreen(
                        teamId: team.id!,
                        fallbackName: team.name,
                        fallbackTla: team.tla,
                      ),
                    )),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisAlignment:
                    isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isRight) ...[
                    FlagWidget(tla: team.tla, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(team.tla,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.textHi)),
                  ),
                  if (team.id != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 14, color: p.textLow),
                  ],
                  if (isRight) ...[
                    const SizedBox(width: 6),
                    FlagWidget(tla: team.tla, size: 18),
                  ],
                ],
              ),
            ),
          ),
          if (lineup!.formation != null) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(lineup!.formation!,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
            ),
          ],
          const SizedBox(height: 12),
          _lineupSection('Starting XI', lineup!.starters, p, team.name),
          if (lineup!.bench.isNotEmpty) ...[
            const SizedBox(height: 10),
            _lineupSection('Bench', lineup!.bench, p, team.name),
          ],
        ],
      ),
    );
  }

  Widget _lineupSection(
      String title, List<LineupPlayer> players, Palette p, String teamHint) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: p.textLow)),
        const SizedBox(height: 6),
        ...players.map((pl) => _PlayerRow(
              player: pl,
              p: p,
              isRight: isRight,
              teamHint: teamHint,
            )),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final LineupPlayer player;
  final Palette p;
  final bool isRight;
  final String teamHint;
  const _PlayerRow({
    required this.player,
    required this.p,
    required this.isRight,
    required this.teamHint,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerDetailScreen(
            name: player.name,
            teamHint: teamHint,
            shirtNumber: player.shirtNumber,
            position: player.position,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          children: [
            if (!isRight) ...[
              _ShirtChip(number: player.shirtNumber, p: p),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment:
                    isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                  if (player.position != null)
                    Text(player.position!,
                        style: TextStyle(
                            fontSize: 9,
                            color: p.textLow,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (isRight) ...[
              const SizedBox(width: 6),
              _ShirtChip(number: player.shirtNumber, p: p),
            ],
            if (player.isCaptain)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('C',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brand)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShirtChip extends StatelessWidget {
  final int? number;
  final Palette p;
  const _ShirtChip({required this.number, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceHi,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        number?.toString() ?? '—',
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: p.textMid),
      ),
    );
  }
}
