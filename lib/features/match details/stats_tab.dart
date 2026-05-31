// tabs/stats_tab.dart
//
// Stats tab: possession bar + per-stat dual-value rows with proportional bar.
// Prefers liveStats from the Firestore raw doc; falls back to BSD resolver.
// Part of the match_details library — see match_details_screen.dart.

part of 'match_details_screen.dart';

class _StatsTab extends ConsumerWidget {
  final Match match;
  const _StatsTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final rawAsync = ref.watch(_rawMatchProvider(match.id));
    final rawDoc = rawAsync.value;

    // ── Build stats from Firestore liveStats ────────────────────────────────
    final liveStats = rawDoc?['liveStats'];
    final fsStats = liveStats is Map ? _statsFromRaw(rawDoc!) : null;

    // ── xG ─────────────────────────────────────────────────────────────────
    final xgDoc = rawDoc?['xg'] as Map?;
    final xgHome = (xgDoc?['homeLive'] as num?)?.toDouble();
    final xgAway = (xgDoc?['awayLive'] as num?)?.toDouble();
    final showXg = xgHome != null && xgAway != null;

    // ── Possession from raw or from BSD stats ───────────────────────────────
    final rawHomeMap = liveStats is Map ? liveStats['home'] as Map? : null;
    final rawAwayMap = liveStats is Map ? liveStats['away'] as Map? : null;
    double? parsePct(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll('%', '').trim());
      return null;
    }
    final possHome = parsePct(rawHomeMap?['possession'] ?? rawHomeMap?['ballPossession']);
    final possAway = parsePct(rawAwayMap?['possession'] ?? rawAwayMap?['ballPossession']);

    // Always watch incidents — needed for momentum chart regardless of stats source.
    final incsAsync = ref.watch(_incidentsProvider(match));
    List<MomentumPoint>? momentumFromIncs;
    incsAsync.whenData((incs) {
      if (incs.length >= 2) momentumFromIncs = Momentum.fromIncidents(incs);
    });

    if (fsStats != null && fsStats.isNotEmpty) {
      return _buildBody(p, ref, fsStats, possHome, possAway, xgHome, xgAway,
          showXg, fromFirestore: true, momentumPoints: momentumFromIncs);
    }

    // Fall back to BSD resolver
    final statsAsync = ref.watch(_statsProvider(match));

    return statsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Unavailable(
          icon: Icons.bar_chart_rounded, message: 'Stats unavailable.'),
      data: (bsdStats) {
        final allStats = bsdStats;
        // Try extracting possession from BSD stats list
        double? bsdPossHome, bsdPossAway;
        for (final s in bsdStats) {
          if (s.name.toLowerCase().contains('possession')) {
            bsdPossHome = double.tryParse(
                s.homeValue.replaceAll('%', '').trim());
            bsdPossAway = double.tryParse(
                s.awayValue.replaceAll('%', '').trim());
            break;
          }
        }
        return _buildBody(p, ref, allStats,
            bsdPossHome, bsdPossAway, xgHome, xgAway, showXg,
            momentumPoints: momentumFromIncs);
      },
    );
  }

  Widget _buildBody(
    Palette p,
    WidgetRef ref,
    List<MatchStat> stats,
    double? possHome,
    double? possAway,
    double? xgHome,
    double? xgAway,
    bool showXg, {
    List<MomentumPoint>? momentumPoints,
    bool fromFirestore = false,
  }) {
    final allEmpty = stats.isEmpty && !showXg && possHome == null && possAway == null;

    if (allEmpty) {
      return _Unavailable(
          icon: Icons.bar_chart_rounded,
          message: match.isFinished
              ? 'Detailed stats not available for this match.'
              : match.isLive
                  ? 'Stats are warming up — check back shortly.'
                  : 'Statistics appear once the match starts.');
    }

    // Remove possession from the stat list if we're rendering it separately
    final filteredStats = stats
        .where((s) => !s.name.toLowerCase().contains('possession'))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // ── Possession bar ────────────────────────────────────────────
        if (possHome != null && possAway != null)
          _PossessionCard(
              homeTeam: match.homeTeam.tla,
              awayTeam: match.awayTeam.tla,
              homePct: possHome,
              awayPct: possAway,
              p: p),

        // ── xG card ───────────────────────────────────────────────────
        if (showXg)
          _XgCard(
              homeTeam: match.homeTeam.tla,
              awayTeam: match.awayTeam.tla,
              homeXg: xgHome!,
              awayXg: xgAway!,
              p: p),

        // ── Momentum graph ────────────────────────────────────────────
        if (momentumPoints != null && momentumPoints.length >= 2)
          _DetailCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('MOMENTUM',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: p.textLow)),
                  const Spacer(),
                  Text('estimated',
                      style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: p.textLow)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                    height: 80,
                    child: CustomPaint(
                        painter: _MomentumPainter(momentumPoints, p),
                        size: Size.infinite)),
                const SizedBox(height: 10),
                Row(children: [
                  const _LegendDot(color: AppTheme.brand),
                  const SizedBox(width: 5),
                  Text(match.homeTeam.tla,
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textMid,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 14),
                  const _LegendDot(color: AppTheme.live),
                  const SizedBox(width: 5),
                  Text(match.awayTeam.tla,
                      style: TextStyle(
                          fontSize: 11,
                          color: p.textMid,
                          fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),

        // ── Stat rows ─────────────────────────────────────────────────
        if (filteredStats.isNotEmpty)
          _DetailCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Text('STATISTICS',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800,
                            color: p.textLow)),
                    if (fromFirestore) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.good.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Live',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.good)),
                      ),
                    ],
                  ]),
                ),
                ...filteredStats.map((s) => _StatRow(stat: s, p: p)),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Possession card ──────────────────────────────────────────────────────────

class _PossessionCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final double homePct;
  final double awayPct;
  final Palette p;
  const _PossessionCard({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(homeTeam,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
              const Spacer(),
              Text('Possession',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textLow)),
              const Spacer(),
              Text(awayTeam,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.live)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${homePct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: p.textHi)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
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
                ),
              ),
              Text('${awayPct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: p.textHi)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── xG card ─────────────────────────────────────────────────────────────────

class _XgCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final double homeXg;
  final double awayXg;
  final Palette p;
  const _XgCard({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppTheme.r),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(homeTeam,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand)),
              const Spacer(),
              Text('Expected Goals (xG)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textLow)),
              const Spacer(),
              Text(awayTeam,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.live)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(homeXg.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.brand)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
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
                ),
              ),
              Text(awayXg.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.live)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Single stat row ──────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final MatchStat stat;
  final Palette p;
  const _StatRow({required this.stat, required this.p});

  @override
  Widget build(BuildContext context) {
    final h = double.tryParse(stat.homeValue.replaceAll('%', '')) ?? 0;
    final a = double.tryParse(stat.awayValue.replaceAll('%', '')) ?? 0;
    final total = (h + a) <= 0 ? 1.0 : (h + a);
    final hRatio = h / total;
    final homeWins = h > a;
    final awayWins = a > h;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        children: [
          Row(children: [
            SizedBox(
              width: 48,
              child: Text(stat.homeValue,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: homeWins ? AppTheme.brand : p.textHi)),
            ),
            Expanded(
              child: Text(stat.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textLow)),
            ),
            SizedBox(
              width: 48,
              child: Text(stat.awayValue,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: awayWins ? AppTheme.live : p.textHi)),
            ),
          ]),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(
                  flex: (hRatio * 100).round().clamp(1, 99),
                  child: ColoredBox(
                      color: homeWins
                          ? AppTheme.brand
                          : AppTheme.brand.withValues(alpha: 0.4)),
                ),
                Expanded(
                  flex: ((1 - hRatio) * 100).round().clamp(1, 99),
                  child: ColoredBox(
                      color: awayWins
                          ? AppTheme.live
                          : AppTheme.live.withValues(alpha: 0.4)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );
}

class _MomentumPainter extends CustomPainter {
  final List<MomentumPoint> points;
  final Palette palette;
  _MomentumPainter(this.points, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final w = size.width;
    final h = size.height;
    final maxMin =
        points.map((p) => p.minute).reduce((a, b) => a > b ? a : b);
    final span = (math.max(maxMin, 90)).toDouble();

    final gridPaint = Paint()
      ..color = palette.stroke
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
          Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2),
        Paint()
          ..color = palette.textLow.withValues(alpha: 0.35)
          ..strokeWidth = 1);

    Offset toOff(MomentumPoint pt, bool isHome) {
      final x = (pt.minute / span) * w;
      final score = isHome ? pt.homeScore : pt.awayScore;
      final y = h - (score / 100) * h;
      return Offset(x, y);
    }

    void drawPath(List<Offset> pts, Color color) {
      if (pts.length < 2) return;
      final path = Path();
      path.moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final curr = pts[i];
        final cpX = (prev.dx + curr.dx) / 2;
        path.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    drawPath(points.map((pt) => toOff(pt, true)).toList(), AppTheme.brand);
    drawPath(points.map((pt) => toOff(pt, false)).toList(), AppTheme.live);
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) =>
      old.points != points || old.palette.isDark != palette.isDark;
}
