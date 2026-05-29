// tabs/summary_tab.dart
//
// Summary tab: live ticker, goals, match-info rows, fan poll, insights.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── Summary tab ─────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  final Match match;
  const _SummaryTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Raw Firestore doc — contains Bzzoiro incidents and xG when available.
    final rawAsync = (match.isFinished || match.isLive)
        ? ref.watch(_rawMatchProvider(match.id))
        : null;
    final rawDoc = rawAsync?.value;

    // Goal scorers: prefer Firestore raw doc goals, fall back to per-match API.
    final richMatchAsync = (match.isFinished || match.isLive)
        ? ref.watch(matchGoalsProvider(match.id))
        : null;
    final goalsSource = richMatchAsync?.value ?? match;
    final homeGoals =
        goalsSource.goals.where((g) => g.teamId == match.homeTeam.id).toList();
    final awayGoals =
        goalsSource.goals.where((g) => g.teamId == match.awayTeam.id).toList();
    final richLoading = richMatchAsync != null && richMatchAsync.isLoading;

    // xG from raw Firestore doc (null → hide the row entirely).
    final xgDoc = rawDoc?['xg'];
    final xgHome = xgDoc is Map ? xgDoc['homeLive'] : null;
    final xgAway = xgDoc is Map ? xgDoc['awayLive'] : null;
    final showXg = xgHome != null && xgAway != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // Live ticker — only meaningful once the match has started.
        if (match.isFinished || match.isLive) _LiveTicker(match: match),

        // ── Match Heat Meter (at-a-glance excitement) ─────────────────────
        if (match.isFinished || match.isLive)
          MatchHeatMeter(match: goalsSource),

        // ── Goals (per-match fetch shows scorers) ─────────────────────────
        if (match.isFinished || match.isLive) ...[
          if (richLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (goalsSource.goals.isNotEmpty) ...[
            const _SectionLabel('Goals'),
            _DetailCard(
              child: Row(
                children: [
                  Expanded(
                      child: _GoalSide(
                          p: p,
                          team: match.homeTeam,
                          goals: homeGoals,
                          isRight: false)),
                  Container(width: 1, height: 70, color: p.stroke),
                  Expanded(
                      child: _GoalSide(
                          p: p,
                          team: match.awayTeam,
                          goals: awayGoals,
                          isRight: true)),
                ],
              ),
            ),
          ],
        ],

        // ── Match info (core facts: date, competition, stage, venue) ──────
        const _SectionLabel('Match info'),
        _InfoRow(
            p: p,
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: DateFormat('EEEE, d MMM yyyy').format(match.utcDate)),
        _InfoRow(
            p: p,
            icon: Icons.schedule_rounded,
            label: match.isFinished ? 'Kicked off' : 'Kick-off',
            value: '${DateFormat('HH:mm').format(match.utcDate)} local'),
        _InfoRow(
            p: p,
            icon: Icons.emoji_events_rounded,
            label: 'Competition',
            value: match.competitionName ?? '—'),
        _InfoRow(
            p: p,
            icon: Icons.flag_rounded,
            label: 'Stage',
            value: _stageLabel(match.stage)),
        if (match.group != null)
          _InfoRow(
              p: p,
              icon: Icons.groups_2_rounded,
              label: 'Group',
              value: match.group!.replaceAll('GROUP_', 'Group ')),
        if (match.venue != null)
          _InfoRow(
              p: p,
              icon: Icons.stadium_rounded,
              label: 'Venue',
              value: match.venue!),
        _InfoRow(
            p: p,
            icon: Icons.info_rounded,
            label: 'Status',
            value: _statusLabel(match.status),
            valueColor: match.isLive
                ? AppTheme.live
                : match.isFinished
                    ? AppTheme.good
                    : null),
        if (showXg)
          _InfoRow(
            p: p,
            icon: Icons.analytics_outlined,
            label: 'xG',
            value:
                '${(xgHome as num).toStringAsFixed(2)} – ${(xgAway as num).toStringAsFixed(2)}',
          ),

        // ── Rivalry card — only renders for recognised rivalries ──────────
        RivalryCardWidget(
          homeTla: match.homeTeam.tla,
          awayTla: match.awayTeam.tla,
        ),

        // ── AI insights — team form bullets ───────────────────────────────
        AiInsightsWidget(match: match),

        // ── Fan poll — interactive, encourages engagement ─────────────────
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
        'FINISHED' => 'Finished',
        _ => s,
      };
}

class _GoalSide extends StatelessWidget {
  final Palette p;
  final TeamRef team;
  final List<MatchGoal> goals;
  final bool isRight;
  const _GoalSide(
      {required this.p,
      required this.team,
      required this.goals,
      required this.isRight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isRight ? 12 : 0, right: isRight ? 0 : 12),
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
            ...goals.map((g) => Padding(
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
                          child: Text("${g.minute}'  ${g.scorerName ?? '—'}",
                              style: TextStyle(fontSize: 12, color: p.textHi)),
                        ),
                      ] else ...[
                        Flexible(
                          child: Text("${g.scorerName ?? '—'}  ${g.minute}'",
                              style: TextStyle(fontSize: 12, color: p.textHi),
                              textAlign: TextAlign.right),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.sports_soccer_rounded,
                            size: 12, color: AppTheme.brand),
                      ],
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

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
          // Icon chip — fixed width, never shrinks
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
          // Label — fixed, does not grow
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: p.textLow, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          // Value — takes all remaining width, right-aligned, single line
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? p.textHi),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live ticker ──────────────────────────────────────────────────────────────

class _LiveTicker extends ConsumerWidget {
  final Match match;
  const _LiveTicker({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Prefer Firestore incidents (Bzzoiro-enriched); fall back to BSD resolver.
    final rawAsync = ref.watch(_rawMatchProvider(match.id));
    final rawDoc = rawAsync.value;
    final fsIncidents =
        rawDoc != null ? _incidentsFromRaw(rawDoc) : null;

    if (fsIncidents != null && fsIncidents.isNotEmpty) {
      return _buildTicker(context, fsIncidents, p);
    }

    final async = ref.watch(_incidentsProvider(match));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => _buildTicker(context, list, p),
    );
  }

  Widget _buildTicker(
      BuildContext context, List<MatchIncident> list, Palette p) {
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
          width: 7,
          height: 7,
          decoration:
              const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  final MatchIncident incident;
  final Palette p;
  const _IncidentRow({required this.incident, required this.p});

  @override
  Widget build(BuildContext context) {
    final (chipColor, icon) = switch (incident.type) {
      'goal' => (
          AppTheme.brand.withValues(alpha: 0.12),
          Icons.sports_soccer_rounded
        ),
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
                textAlign: incident.isHome ? TextAlign.left : TextAlign.right,
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
