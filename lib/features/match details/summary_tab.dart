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

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // ── Live ticker ─────────────────────────────────────────────────
        if (match.isFinished || match.isLive)
          _LiveTicker(
            match: match,
            fsIncidents: fsIncidents,
            ref: ref,
          ),

        // ── Match Heat Meter ────────────────────────────────────────────
        if (match.isFinished || match.isLive)
          MatchHeatMeter(match: goalsSource),

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

        // ── Match info ───────────────────────────────────────────────────
        const _SectionLabel('Match info'),
        _InfoRow(p: p, icon: Icons.calendar_today_rounded, label: 'Date',
            value: DateFormat('EEEE, d MMM yyyy').format(match.utcDate)),
        _InfoRow(p: p, icon: Icons.schedule_rounded,
            label: match.isFinished ? 'Kicked off' : 'Kick-off',
            value: '${DateFormat('HH:mm').format(match.utcDate)} local'),
        _InfoRow(p: p, icon: Icons.emoji_events_rounded, label: 'Competition',
            value: match.competitionName ?? '—'),
        _InfoRow(p: p, icon: Icons.flag_rounded, label: 'Stage',
            value: _stageLabel(match.stage)),
        if (match.group != null)
          _InfoRow(p: p, icon: Icons.groups_2_rounded, label: 'Group',
              value: match.group!.replaceAll('GROUP_', 'Group ')),
        if (match.venue != null)
          _InfoRow(p: p, icon: Icons.stadium_rounded, label: 'Venue',
              value: match.venue!),
        if (refName != null && refName.isNotEmpty)
          _InfoRow(p: p, icon: Icons.sports_rounded, label: 'Referee',
              value: refNat != null ? '$refName · $refNat' : refName),
        _InfoRow(p: p, icon: Icons.info_rounded, label: 'Status',
            value: _statusLabel(match.status),
            valueColor: match.isLive
                ? AppTheme.live
                : match.isFinished
                    ? AppTheme.good
                    : null),

        // ── H2H snippet ─────────────────────────────────────────────────
        if (h2hMatches.isNotEmpty) ...[
          const _SectionLabel('Head to Head'),
          _DetailCard(
            child: Column(
              children: h2hMatches.take(5).map<Widget>((raw) {
                if (raw is! Map) return const SizedBox.shrink();
                final rm = raw.cast<String, dynamic>();
                final ht = (rm['homeTeam'] as Map?)?['name'] as String? ?? '—';
                final at = (rm['awayTeam'] as Map?)?['name'] as String? ?? '—';
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

  String _statusLabel(String s) => switch (s) {
        'SCHEDULED' || 'TIMED' => 'Upcoming',
        'IN_PLAY' => 'Live',
        'PAUSED' => 'Half-time',
        'FINISHED' => switch (null) {
            _ => 'Finished',
          },
        _ => s,
      };
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
                FlagWidget(tla: team.tla, size: 14),
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
                FlagWidget(tla: team.tla, size: 14),
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: isRight
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!isRight) ...[
                      const Icon(Icons.sports_soccer_rounded,
                          size: 12, color: AppTheme.brand),
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
                      const Icon(Icons.sports_soccer_rounded,
                          size: 12, color: AppTheme.brand),
                    ],
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
  final Color? valueColor;
  const _InfoRow(
      {required this.p,
      required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

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
                    color: valueColor ?? p.textHi)),
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
  const _LiveTicker(
      {required this.match, required this.fsIncidents, required this.ref});

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
    final shown = list.reversed.take(12).toList();
    return _DetailCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                match.isLive ? 'LIVE TICKER' : 'MATCH TIMELINE',
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
          ...shown.map((i) => _IncidentRow(incident: i, p: p)),
          if (list.length > 12)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('+ ${list.length - 12} more',
                  style: TextStyle(fontSize: 11, color: p.textLow)),
            ),
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
                color: Colors.red, shape: BoxShape.circle)),
      );
}

class _IncidentRow extends StatelessWidget {
  final MatchIncident incident;
  final Palette p;
  const _IncidentRow({required this.incident, required this.p});

  @override
  Widget build(BuildContext context) {
    final (chipColor, icon) = switch (incident.type) {
      'goal' => (AppTheme.brand.withValues(alpha: 0.12),
          Icons.sports_soccer_rounded),
      'yellowCard' => (const Color(0xFFFFF3CD), Icons.square_rounded),
      'redCard' => (const Color(0xFFFFEBEE), Icons.square_rounded),
      'substitution' => (p.surfaceHi, Icons.swap_horiz_rounded),
      _ => (p.surfaceHi, Icons.circle_outlined),
    };
    final iconColor = switch (incident.type) {
      'goal' => AppTheme.brand,
      'yellowCard' => const Color(0xFFF5A623),
      'redCard' => AppTheme.live,
      _ => p.textMid,
    };
    final label = switch (incident.type) {
      'substitution' =>
        '${incident.player ?? '—'}${incident.assistOrOff != null ? ' → ${incident.assistOrOff}' : ''}',
      _ => incident.player ?? '—',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text("${incident.minute}'",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.textMid)),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign:
                    incident.isHome ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textHi)),
          ),
        ],
      ),
    );
  }
}
