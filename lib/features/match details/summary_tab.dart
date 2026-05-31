// tabs/summary_tab.dart  (renders as the "Detail" tab)
//
// Detail tab: match info, goal scorers, xG bar, referee, H2H snippet,
// live ticker, AI insights, fan poll.
// Part of the match_details library — see match_details_screen.dart.

part of 'match_details_screen.dart';

class _SummaryTab extends ConsumerWidget {
  final Match match;
  const _SummaryTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Raw doc gives us scorers with names, xG, referee, H2H.
    final rawAsync = (match.isFinished || match.isLive)
        ? ref.watch(_rawMatchProvider(match.id))
        : null;
    final rawDoc = rawAsync?.value;

    // Goal scorers: prefer Firestore raw goals (have names), fall back to
    // the rich per-match API fetch.
    final richAsync = (match.isFinished || match.isLive)
        ? ref.watch(matchGoalsProvider(match.id))
        : null;
    final goalsSource = richAsync?.value ?? match;
    final richLoading = richAsync != null && richAsync.isLoading;

    final homeGoals = goalsSource.goals
        .where((g) => g.teamId == match.homeTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));
    final awayGoals = goalsSource.goals
        .where((g) => g.teamId == match.awayTeam.id)
        .toList()
      ..sort((a, b) => a.minute.compareTo(b.minute));

    // xG
    final xgDoc = rawDoc?['xg'] as Map?;
    final xgHome = (xgDoc?['homeLive'] as num?)?.toDouble();
    final xgAway = (xgDoc?['awayLive'] as num?)?.toDouble();

    // Ball possession from liveStats
    final liveStats = rawDoc?['liveStats'];
    final rawHome = liveStats is Map ? liveStats['home'] as Map? : null;
    final rawAway = liveStats is Map ? liveStats['away'] as Map? : null;
    final possHome = (rawHome?['possession'] as num?)?.toDouble();
    final possAway = (rawAway?['possession'] as num?)?.toDouble();

    // Referee & venue from raw doc
    final referee = rawDoc?['referee'] as Map?;
    final refName = referee?['name'] as String?;
    final refNat = referee?['nationality'] as String?;

    // Incidents for the live ticker
    final fsIncidents =
        rawDoc != null ? _incidentsFromRaw(rawDoc) : null;

    // H2H from raw doc
    final h2hDoc = rawDoc?['head_to_head'] as Map?;
    final h2hMatches = h2hDoc?['matches'] as List? ?? const [];

    // Man of the Match / Highest Rated — derived from bzzLineups ratings
    final bzzList = rawDoc?['bzzLineups'];
    final allRatedPlayers = (bzzList is List)
        ? bzzList
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((pl) => pl['rating'] != null && pl['is_starter'] != false)
            .toList()
        : <Map<String, dynamic>>[];
    allRatedPlayers
        .sort((a, b) => ((b['rating'] as num?) ?? 0)
            .compareTo((a['rating'] as num?) ?? 0));
    final motm = allRatedPlayers.isNotEmpty ? allRatedPlayers.first : null;
    final highestRated = allRatedPlayers.take(6).toList();

    // Last 5 Matches / Next Match — from the live score cache
    final allMatches = ref.watch(liveScoreProvider).matches;
    List<Match> teamLast5(String tla) => allMatches
        .where((m) =>
            m.isFinished &&
            (m.homeTeam.tla == tla || m.awayTeam.tla == tla))
        .toList()
      ..sort((a, b) => b.utcDate.compareTo(a.utcDate));
    List<Match> teamNext(String tla) => allMatches
        .where((m) =>
            m.isScheduled &&
            (m.homeTeam.tla == tla || m.awayTeam.tla == tla))
        .toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));
    final homeLast5 = teamLast5(match.homeTeam.tla).take(5).toList();
    final awayLast5 = teamLast5(match.awayTeam.tla).take(5).toList();
    final homeNext = teamNext(match.homeTeam.tla).take(2).toList();
    final awayNext = teamNext(match.awayTeam.tla).take(2).toList();
    final nextMatches = {...homeNext, ...awayNext}.toList()
      ..sort((a, b) => a.utcDate.compareTo(b.utcDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // ── Ball Possession ──────────────────────────────────────────────
        if (possHome != null && possAway != null &&
            (match.isFinished || match.isLive)) ...[
          const _SectionLabel('Ball Possession'),
          _DetailCard(
            child: _PossessionBar(
              homeTeam: match.homeTeam.tla,
              awayTeam: match.awayTeam.tla,
              homePct: possHome,
              awayPct: possAway,
              p: p,
            ),
          ),
        ],

        // ── Scorers section ─────────────────────────────────────────────
        if (match.isFinished || match.isLive) ...[
          if (richLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (goalsSource.goals.isNotEmpty) ...[
            const _SectionLabel('Goals'),
            _DetailCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GoalColumn(p: p, team: match.homeTeam,
                      goals: homeGoals, isRight: false)),
                  Container(width: 1, color: p.stroke),
                  Expanded(child: _GoalColumn(p: p, team: match.awayTeam,
                      goals: awayGoals, isRight: true)),
                ],
              ),
            ),
          ],
        ],

        // ── Match Heat Meter ────────────────────────────────────────────
        if (match.isFinished || match.isLive)
          MatchHeatMeter(match: goalsSource),

        // ── Match Events (live ticker / timeline) ────────────────────────
        if (match.isFinished || match.isLive) ...[
          const _SectionLabel('Match Events'),
          _LiveTicker(
            match: match,
            fsIncidents: fsIncidents,
            ref: ref,
            rawScore: rawDoc?['score'] as Map?,
          ),
        ],

        // ── xG bar ──────────────────────────────────────────────────────
        if (xgHome != null && xgAway != null) ...[
          const _SectionLabel('Expected Goals'),
          _DetailCard(
            child: _XgBar(
                homeTeam: match.homeTeam.tla,
                awayTeam: match.awayTeam.tla,
                homeXg: xgHome,
                awayXg: xgAway,
                p: p),
          ),
        ],

        // ── Man of the Match ─────────────────────────────────────────────
        if (motm != null && match.isFinished) ...[
          const _SectionLabel('Man of the Match'),
          _DetailCard(child: _MotmCard(player: motm, p: p)),
        ],

        // ── Highest Rated ────────────────────────────────────────────────
        if (highestRated.length > 1 && match.isFinished) ...[
          const _SectionLabel('Highest Rated'),
          _DetailCard(child: _HighestRatedGrid(players: highestRated, p: p)),
        ],

        // ── Next Match ───────────────────────────────────────────────────
        if (nextMatches.isNotEmpty) ...[
          const _SectionLabel('Next Match'),
          _DetailCard(child: _NextMatchList(matches: nextMatches, p: p)),
        ],

        // ── Last 5 Matches ───────────────────────────────────────────────
        if (homeLast5.isNotEmpty || awayLast5.isNotEmpty) ...[
          const _SectionLabel('Last 5 Matches'),
          _DetailCard(
            child: _Last5Grid(
              homeTeam: match.homeTeam,
              awayTeam: match.awayTeam,
              homeMatches: homeLast5,
              awayMatches: awayLast5,
              p: p,
            ),
          ),
        ],

        // ── Match info (Referee and Stadium) ────────────────────────────
        const _SectionLabel('Match Info'),
        _InfoRow(p: p, icon: Icons.calendar_today_rounded, label: 'Date',
            value: DateFormat('EEEE, d MMM yyyy').format(match.utcDate)),
        _InfoRow(p: p, icon: Icons.schedule_rounded,
            label: match.isFinished ? 'Kicked off' : 'Kick-off',
            value: '${DateFormat('HH:mm').format(match.utcDate)} local'),
        if (match.venue != null)
          _InfoRow(p: p, icon: Icons.stadium_rounded, label: 'Stadium',
              value: match.venue!),
        if (refName != null && refName.isNotEmpty)
          _InfoRow(p: p, icon: Icons.sports_rounded, label: 'Referee',
              value: refNat != null ? '$refName · $refNat' : refName),
        _InfoRow(p: p, icon: Icons.emoji_events_rounded, label: 'Competition',
            value: match.competitionName ?? '—'),
        _InfoRow(p: p, icon: Icons.flag_rounded, label: 'Stage',
            value: _stageLabel(match.stage)),
        if (match.group != null)
          _InfoRow(p: p, icon: Icons.groups_2_rounded, label: 'Group',
              value: match.group!.replaceAll('GROUP_', 'Group ')),

        // ── H2H snippet ─────────────────────────────────────────────────
        if (h2hMatches.isNotEmpty) ...[
          const _SectionLabel('Head to Head'),
          _DetailCard(
            child: Column(
              children: h2hMatches.take(5).map<Widget>((raw) {
                if (raw is! Map) return const SizedBox.shrink();
                final rm = raw.cast<String, dynamic>();
                final htMap = rm['homeTeam'] as Map?;
                final atMap = rm['awayTeam'] as Map?;
                final ht = htMap?['name'] as String? ?? '—';
                final at = atMap?['name'] as String? ?? '—';
                final htTla = htMap?['tla'] as String? ??
                    ht.substring(0, ht.length.clamp(0, 3)).toUpperCase();
                final atTla = atMap?['tla'] as String? ??
                    at.substring(0, at.length.clamp(0, 3)).toUpperCase();
                final htCrest = htMap?['crest'] as String?;
                final atCrest = atMap?['crest'] as String?;
                final sc = rm['score'] as Map?;
                final ft = sc?['fullTime'] as Map?;
                final hg = ft?['home'];
                final ag = ft?['away'];
                final scoreStr =
                    hg != null && ag != null ? '$hg – $ag' : 'vs';
                final dateStr = rm['utcDate'] as String?;
                DateTime? dt;
                if (dateStr != null) {
                  dt = DateTime.tryParse(dateStr)?.toLocal();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      if (dt != null)
                        Text(DateFormat('d MMM yy').format(dt),
                            style: TextStyle(
                                fontSize: 11,
                                color: p.textLow,
                                fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TeamCrestWidget(
                          crestUrl: htCrest, tla: htTla, size: 18),
                      const SizedBox(width: 5),
                      Text(ht,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textHi)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.surfaceHi,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(scoreStr,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: p.textHi)),
                      ),
                      const SizedBox(width: 8),
                      Text(at,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.textHi)),
                      const SizedBox(width: 5),
                      TeamCrestWidget(
                          crestUrl: atCrest, tla: atTla, size: 18),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Rivalry + AI insights + fan poll ────────────────────────────
        RivalryCardWidget(
            homeTla: match.homeTeam.tla, awayTla: match.awayTeam.tla),
        AiInsightsWidget(match: match),
        FanPollWidget(match: match),
      ],
    );
  }

  String _stageLabel(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

}

// ─── Ball possession bar ──────────────────────────────────────────────────────

class _PossessionBar extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final double homePct;
  final double awayPct;
  final Palette p;
  const _PossessionBar({
    required this.homeTeam,
    required this.awayTeam,
    required this.homePct,
    required this.awayPct,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final total = homePct + awayPct;
    final hRatio = total > 0 ? homePct / total : 0.5;
    final hLabel = '${homePct.toStringAsFixed(0)}%';
    final aLabel = '${awayPct.toStringAsFixed(0)}%';

    return Column(
      children: [
        Row(
          children: [
            Text(hLabel,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brand)),
            const Spacer(),
            Text('Possession',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.textLow)),
            const Spacer(),
            Text(aLabel,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: p.textHi)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (hRatio * 100).round().clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.brand),
                ),
                Expanded(
                  flex: ((1 - hRatio) * 100).round().clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.live),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(homeTeam,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.textMid)),
            const Spacer(),
            Text(awayTeam,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.textMid)),
          ],
        ),
      ],
    );
  }
}

// ─── Man of the Match card ────────────────────────────────────────────────────

class _MotmCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final Palette p;
  const _MotmCard({required this.player, required this.p});

  @override
  Widget build(BuildContext context) {
    final name = (player['player_name'] ?? player['name'] ?? '') as String;
    final rating = (player['rating'] as num?)?.toDouble();
    final photoUrl = player['photo_url'] as String?;
    final goals = player['goals'] as int?;
    final assists = player['assists'] as int?;
    final rColor = _ratingColor(rating);

    return Row(
      children: [
        ClipOval(
          child: Container(
            width: 56,
            height: 56,
            color: AppTheme.brand.withValues(alpha: 0.15),
            child: (photoUrl != null && photoUrl.isNotEmpty)
                ? Image.network(photoUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded, size: 30, color: AppTheme.brand))
                : const Icon(Icons.person_rounded,
                    size: 30, color: AppTheme.brand),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.textHi)),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (goals != null && goals > 0) ...[
                    const Icon(Icons.sports_soccer_rounded,
                        size: 13, color: AppTheme.brand),
                    const SizedBox(width: 3),
                    Text('$goals',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.textMid)),
                    const SizedBox(width: 8),
                  ],
                  if (assists != null && assists > 0) ...[
                    const Icon(Icons.assistant_rounded,
                        size: 13, color: AppTheme.accent),
                    const SizedBox(width: 3),
                    Text('$assists',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.textMid)),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (rating != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: rColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

// ─── Highest Rated grid ───────────────────────────────────────────────────────

class _HighestRatedGrid extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Palette p;
  const _HighestRatedGrid({required this.players, required this.p});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: players.take(6).map((pl) {
        final name = (pl['player_name'] ?? pl['name'] ?? '') as String;
        final rating = (pl['rating'] as num?)?.toDouble();
        final photoUrl = pl['photo_url'] as String?;
        final goals = pl['goals'] as int?;
        final assists = pl['assists'] as int?;
        final rColor = _ratingColor(rating);
        final parts = name.trim().split(' ');
        final shortName =
            parts.length > 1 ? '${parts.first[0]}. ${parts.last}' : name;

        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 80) / 2,
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 38,
                  height: 38,
                  color: AppTheme.brand.withValues(alpha: 0.12),
                  child: (photoUrl != null && photoUrl.isNotEmpty)
                      ? Image.network(photoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: AppTheme.brand))
                      : const Icon(Icons.person_rounded,
                          size: 20, color: AppTheme.brand),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.textHi)),
                    if (goals != null && goals > 0 ||
                        assists != null && assists > 0)
                      Row(children: [
                        if (goals != null && goals > 0) ...[
                          const Icon(Icons.sports_soccer_rounded,
                              size: 10, color: AppTheme.brand),
                          Text(' $goals ',
                              style: TextStyle(
                                  fontSize: 10, color: p.textLow)),
                        ],
                        if (assists != null && assists > 0) ...[
                          const Icon(Icons.assistant_rounded,
                              size: 10, color: AppTheme.accent),
                          Text(' $assists',
                              style: TextStyle(
                                  fontSize: 10, color: p.textLow)),
                        ],
                      ]),
                  ],
                ),
              ),
              if (rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: rColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Next Match list ──────────────────────────────────────────────────────────

class _NextMatchList extends StatelessWidget {
  final List<Match> matches;
  final Palette p;
  const _NextMatchList({required this.matches, required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: matches.map((m) {
        final dateStr = DateFormat('dd/MM').format(m.utcDate.toLocal());
        final timeStr = DateFormat('HH:mm').format(m.utcDate.toLocal());
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.textHi)),
                  Text(timeStr,
                      style: TextStyle(fontSize: 10, color: p.textLow)),
                ],
              ),
              const SizedBox(width: 12),
              TeamCrestWidget(
                  crestUrl: m.homeTeam.crest, tla: m.homeTeam.tla, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(m.homeTeam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textHi)),
              ),
              TeamCrestWidget(
                  crestUrl: m.awayTeam.crest, tla: m.awayTeam.tla, size: 22),
              const SizedBox(width: 6),
              Text(m.awayTeam.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.textHi)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Last 5 Matches grid ──────────────────────────────────────────────────────

class _Last5Grid extends StatelessWidget {
  final TeamRef homeTeam;
  final TeamRef awayTeam;
  final List<Match> homeMatches;
  final List<Match> awayMatches;
  final Palette p;
  const _Last5Grid({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeMatches,
    required this.awayMatches,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _teamRow(context, homeTeam, homeMatches),
        const SizedBox(height: 10),
        _teamRow(context, awayTeam, awayMatches),
      ],
    );
  }

  Widget _teamRow(
      BuildContext context, TeamRef team, List<Match> matches) {
    return Row(
      children: [
        TeamCrestWidget(crestUrl: team.crest, tla: team.tla, size: 22),
        const SizedBox(width: 8),
        ...matches.map((m) {
          final isHome = m.homeTeam.tla == team.tla;
          final hg = m.score.homeGoals ?? 0;
          final ag = m.score.awayGoals ?? 0;
          final teamGoals = isHome ? hg : ag;
          final oppGoals = isHome ? ag : hg;
          final String result;
          final Color bg;
          if (teamGoals > oppGoals) {
            result = 'W';
            bg = AppTheme.good;
          } else if (teamGoals < oppGoals) {
            result = 'L';
            bg = AppTheme.bad;
          } else {
            result = 'D';
            bg = AppTheme.warn;
          }
          return Container(
            margin: const EdgeInsets.only(right: 5),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(result,
                    style: TextStyle(
                        color: bg.computeLuminance() > 0.3
                            ? Colors.black
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
                Text('$teamGoals-$oppGoals',
                    style: TextStyle(
                        color: bg.computeLuminance() > 0.3
                            ? Colors.black
                            : Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── xG horizontal bar ────────────────────────────────────────────────────────

class _XgBar extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final double homeXg;
  final double awayXg;
  final Palette p;
  const _XgBar({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeXg,
    required this.awayXg,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final total = homeXg + awayXg;
    final hRatio = total > 0 ? homeXg / total : 0.5;
    return Column(
      children: [
        Row(
          children: [
            Text(homeXg.toStringAsFixed(2),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brand)),
            const Spacer(),
            Text('xG',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.textLow,
                    letterSpacing: 1)),
            const Spacer(),
            Text(awayXg.toStringAsFixed(2),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.live)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (hRatio * 100).round().clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.brand),
                ),
                Expanded(
                  flex: ((1 - hRatio) * 100).round().clamp(1, 99),
                  child: const ColoredBox(color: AppTheme.live),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(homeTeam,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: p.textMid)),
            const Spacer(),
            Text(awayTeam,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: p.textMid)),
          ],
        ),
      ],
    );
  }
}

// ─── Goal column (one side) ───────────────────────────────────────────────────

class _GoalColumn extends StatelessWidget {
  final Palette p;
  final TeamRef team;
  final List<MatchGoal> goals;
  final bool isRight;
  const _GoalColumn(
      {required this.p,
      required this.team,
      required this.goals,
      required this.isRight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: isRight ? 12 : 0, right: isRight ? 0 : 12),
      child: Column(
        crossAxisAlignment:
            isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isRight) ...[
                TeamCrestWidget(crestUrl: team.crest, tla: team.tla, size: 16),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(team.tla,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.textMid)),
              ),
              if (isRight) ...[
                const SizedBox(width: 5),
                TeamCrestWidget(crestUrl: team.crest, tla: team.tla, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (goals.isEmpty)
            Text('—',
                style: TextStyle(
                    fontSize: 12,
                    color: p.textLow,
                    fontStyle: FontStyle.italic))
          else
            ...goals.map((g) {
              final extra = g.isPenalty
                  ? ' (P)'
                  : g.isOwnGoal
                      ? ' (OG)'
                      : '';
              final text = "${g.minute}' ${g.scorerName ?? '—'}$extra";
              final iconColor = g.isOwnGoal ? Colors.grey : AppTheme.brand;
              final hasAssist = g.assistName != null && g.assistName!.isNotEmpty && !g.isPenalty && !g.isOwnGoal;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: isRight
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isRight) ...[
                          Icon(Icons.sports_soccer_rounded,
                              size: 12, color: iconColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(text,
                                style: TextStyle(fontSize: 12, color: p.textHi)),
                          ),
                        ] else ...[
                          Flexible(
                            child: Text(text,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, color: p.textHi)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.sports_soccer_rounded,
                              size: 12, color: iconColor),
                        ],
                      ],
                    ),
                    if (hasAssist)
                      Text(
                        'Assist: ${g.assistName}',
                        textAlign: isRight ? TextAlign.right : TextAlign.left,
                        style: TextStyle(fontSize: 10, color: p.textLow, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final Palette p;
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.p,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppTheme.brand),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: p.textLow,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textHi)),
          ),
        ],
      ),
    );
  }
}

// ─── Live ticker ──────────────────────────────────────────────────────────────

class _LiveTicker extends ConsumerWidget {
  final Match match;
  final List<MatchIncident>? fsIncidents;
  final WidgetRef ref;
  final Map? rawScore;
  const _LiveTicker({
    required this.match,
    required this.fsIncidents,
    required this.ref,
    this.rawScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Prefer Firestore incidents; fall back to BSD resolver.
    if (fsIncidents != null && fsIncidents!.isNotEmpty) {
      return _buildTicker(p, fsIncidents!);
    }

    final async = ref.watch(_incidentsProvider(match));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => _buildTicker(p, list),
    );
  }

  Widget _buildTicker(Palette p, List<MatchIncident> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    // Half-time and full-time scores from the raw Firestore score map.
    final htMap = rawScore?['halfTime'] as Map?;
    final htHome = htMap?['home'] as int?;
    final htAway = htMap?['away'] as int?;
    final ftMap = rawScore?['fullTime'] as Map?;
    final ftHome = ftMap?['home'] as int? ?? match.score.homeGoals;
    final ftAway = ftMap?['away'] as int? ?? match.score.awayGoals;

    // Sort newest-first — the most recent events appear at the top, which is
    // more natural for a live ticker and matches the reference app.
    final sorted = [...list]..sort((a, b) => b.minute.compareTo(a.minute));

    // Is the match past half-time? Used to decide whether to show the HT marker
    // when all stored events are from 1st half (no event > 45 in our list).
    final elapsed = DateTime.now().difference(match.utcDate).inMinutes;
    final pastHalfTime = match.isFinished ||
        match.status == 'PAUSED' ||
        (match.status == 'IN_PLAY' && elapsed > 55);

    // Build rows (newest at top).
    // HT marker is inserted just before the first event with minute ≤ 45
    // (i.e., between 2nd-half events above and 1st-half events below).
    final rows = <Widget>[];
    bool htInserted = false;
    for (final inc in sorted) {
      if (!htInserted && inc.minute <= 45) {
        if (pastHalfTime) {
          rows.add(_HtMarker(p: p, htHome: htHome, htAway: htAway));
        }
        htInserted = true;
      }
      rows.add(_IncidentRow(incident: inc, p: p));
    }
    // If all events were > 45 (all 2nd half), place HT below them.
    if (!htInserted && pastHalfTime) {
      rows.add(_HtMarker(p: p, htHome: htHome, htAway: htAway));
    }

    // FT marker sits at the very top for finished matches (newest event).
    if (match.isFinished && ftHome != null && ftAway != null) {
      rows.insert(0, _FtMarker(p: p, ftHome: ftHome, ftAway: ftAway));
    }

    return _DetailCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                match.isLive ? 'LIVE TICKER' : 'MATCH EVENTS',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w800,
                    color: p.textLow),
              ),
              const Spacer(),
              if (match.isLive) _PulsingDot(),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: AppTheme.live, shape: BoxShape.circle)),
      );
}

// HT divider shown between halves, optionally with the half-time score.
class _HtMarker extends StatelessWidget {
  final Palette p;
  final int? htHome;
  final int? htAway;
  const _HtMarker({required this.p, this.htHome, this.htAway});

  @override
  Widget build(BuildContext context) {
    final hasScore = htHome != null && htAway != null;
    final label = hasScore ? 'HT  $htHome – $htAway' : 'HT';
    return _MatchMarker(p: p, label: label);
  }
}

// FT divider shown after all events for finished matches.
class _FtMarker extends StatelessWidget {
  final Palette p;
  final int ftHome;
  final int ftAway;
  const _FtMarker({required this.p, required this.ftHome, required this.ftAway});

  @override
  Widget build(BuildContext context) =>
      _MatchMarker(p: p, label: 'FT  $ftHome – $ftAway');
}

class _MatchMarker extends StatelessWidget {
  final Palette p;
  final String label;
  const _MatchMarker({required this.p, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.stroke, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: p.surfaceHi,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.stroke),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: p.textMid)),
            ),
          ),
          Expanded(child: Divider(color: p.stroke, thickness: 1)),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  final MatchIncident incident;
  final Palette p;
  const _IncidentRow({required this.incident, required this.p});

  @override
  Widget build(BuildContext context) {
    final isGoal = incident.type == 'goal';
    final isOG = isGoal && incident.subtype == 'ownGoal';
    final isPen = isGoal && incident.subtype == 'penalty';
    final isYellow = incident.type == 'yellowCard';
    final isRed = incident.type == 'redCard';
    final isSub = incident.type == 'substitution';

    final IconData icon = isGoal
        ? Icons.sports_soccer_rounded
        : isSub
            ? Icons.swap_horiz_rounded
            : Icons.square_rounded;

    final Color iconColor = isGoal
        ? (isOG ? Colors.grey : isPen ? const Color(0xFFF5A623) : AppTheme.brand)
        : isYellow
            ? const Color(0xFFF5A623)
            : isRed
                ? AppTheme.live
                : p.textMid;

    final Color chipBg = isGoal
        ? (isOG
            ? Colors.grey.withValues(alpha: 0.12)
            : isPen
                ? const Color(0xFFFFF3CD)
                : AppTheme.brand.withValues(alpha: 0.12))
        : isYellow
            ? const Color(0xFFFFF3CD)
            : isRed
                ? const Color(0xFFFFEBEE)
                : p.surfaceHi;

    final String playerLabel;
    final String? subLabel;
    if (isSub) {
      // Show "PlayerIn / PlayerOut" on one line — matches reference app style.
      final inName = incident.player;
      final outName = incident.assistOrOff;
      if (inName != null && outName != null) {
        playerLabel = '$inName  /  $outName';
        subLabel = null;
      } else {
        playerLabel = inName ?? outName ?? '—';
        subLabel = null;
      }
    } else if (isGoal) {
      playerLabel = incident.player ?? '—';
      subLabel = isOG ? 'Own Goal' : isPen ? 'Penalty' : incident.assistOrOff != null ? 'Assist: ${incident.assistOrOff}' : null;
    } else {
      playerLabel = incident.player ?? '—';
      subLabel = null;
    }

    final minuteBox = Container(
      width: 38,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isGoal
              ? (isOG ? Colors.grey.withValues(alpha: 0.2) : AppTheme.brand.withValues(alpha: 0.15))
              : isRed
                  ? AppTheme.live.withValues(alpha: 0.12)
                  : isYellow
                      ? const Color(0xFFF5A623).withValues(alpha: 0.12)
                      : p.surfaceHi,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "${incident.minute}'",
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isGoal
                  ? (isOG ? Colors.grey : AppTheme.brand)
                  : isRed
                      ? AppTheme.live
                      : isYellow
                          ? const Color(0xFFF5A623)
                          : p.textMid),
        ),
      ),
    );

    final eventIcon = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 13, color: iconColor),
    );

    Widget nameCol(bool alignRight) => Expanded(
          child: Column(
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(playerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignRight ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isGoal ? FontWeight.w800 : FontWeight.w600,
                      color: isGoal ? p.textHi : p.textHi)),
              if (subLabel != null)
                Text(subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                        alignRight ? TextAlign.right : TextAlign.left,
                    style: TextStyle(fontSize: 10, color: p.textLow)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: incident.isHome
            ? [
                nameCol(false),
                const SizedBox(width: 6),
                eventIcon,
                const SizedBox(width: 4),
                minuteBox,
                const SizedBox(width: 4),
                const Expanded(child: SizedBox()),
              ]
            : [
                const Expanded(child: SizedBox()),
                minuteBox,
                const SizedBox(width: 4),
                eventIcon,
                const SizedBox(width: 6),
                nameCol(true),
              ],
      ),
    );
  }
}
