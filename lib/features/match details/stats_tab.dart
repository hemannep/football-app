// tabs/stats_tab.dart
//
// Stats tab — rich data-visualisation layer.
//
// Improvements over the original:
//   • Animated stat bars sweep in with TweenAnimationBuilder
//   • Shot Accuracy gauge: two half-circle arcs (home = brand, away = live)
//     showing on-target % with a TweenAnimationBuilder fill animation
//   • Momentum chart upgraded: gradient fill under each line, vertical
//     half-time marker, minute labels (0 / 45 / 90), thicker strokes
//   • Stats grouped into ATTACK / PASSING / DISCIPLINE with labelled dividers
//   • Possession card: bigger numbers + round-end bar caps
//
// Part of the match_details library — see match_details_screen.dart.

part of 'match_details_screen.dart';

// ─── Stat category sets ───────────────────────────────────────────────────────
const _kAttackStats = {
  'Shots on Goal',
  'Shots off Goal',
  'Total Shots',
  'Blocked Shots',
  'Shots inside Box',
  'Shots outside Box',
};
const _kPassingStats = {
  'Passes',
  'Pass Accuracy',
  'Corner Kicks',
};
const _kDisciplineStats = {
  'Fouls',
  'Yellow Cards',
  'Red Cards',
  'Offsides',
  'Saves',
  'Tackles',
};

class _StatsTab extends ConsumerWidget {
  final Match match;
  const _StatsTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final rawAsync = ref.watch(_rawMatchProvider(match));
    final rawDoc = rawAsync.value;

    final liveStats = rawDoc?['liveStats'];
    final fsStats = liveStats is Map ? _statsFromRaw(rawDoc!) : null;

    final xgDoc = rawDoc?['xg'] as Map?;
    final xgHome = (xgDoc?['homeLive'] as num?)?.toDouble();
    final xgAway = (xgDoc?['awayLive'] as num?)?.toDouble();
    final showXg = xgHome != null && xgAway != null;

    final rawHomeMap = liveStats is Map ? liveStats['home'] as Map? : null;
    final rawAwayMap = liveStats is Map ? liveStats['away'] as Map? : null;
    double? parsePct(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll('%', '').trim());
      return null;
    }

    final possHome =
        parsePct(rawHomeMap?['possession'] ?? rawHomeMap?['ballPossession']);
    final possAway =
        parsePct(rawAwayMap?['possession'] ?? rawAwayMap?['ballPossession']);

    final incsAsync = ref.watch(_incidentsProvider(match));
    List<MomentumPoint>? momentumFromIncs;
    List<MatchIncident> incidentList = const [];
    incsAsync.whenData((incs) {
      incidentList = incs;
      if (incs.length >= 2) momentumFromIncs = Momentum.fromIncidents(incs);
    });

    if (fsStats != null && fsStats.isNotEmpty) {
      return _buildBody(
          p, ref, fsStats, possHome, possAway, xgHome, xgAway, showXg,
          fromFirestore: true,
          momentumPoints: momentumFromIncs,
          incidents: incidentList);
    }

    final statsAsync = ref.watch(_statsProvider(match));
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Unavailable(
          icon: Icons.bar_chart_rounded, message: 'Stats unavailable.'),
      data: (bsdStats) {
        double? bsdPossHome, bsdPossAway;
        for (final s in bsdStats) {
          if (s.name.toLowerCase().contains('possession')) {
            bsdPossHome =
                double.tryParse(s.homeValue.replaceAll('%', '').trim());
            bsdPossAway =
                double.tryParse(s.awayValue.replaceAll('%', '').trim());
            break;
          }
        }
        return _buildBody(
            p, ref, bsdStats, bsdPossHome, bsdPossAway, xgHome, xgAway, showXg,
            momentumPoints: momentumFromIncs, incidents: incidentList);
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
    List<MatchIncident> incidents = const [],
    bool fromFirestore = false,
  }) {
    final allEmpty =
        stats.isEmpty && !showXg && possHome == null && possAway == null;

    if (allEmpty) {
      return _Unavailable(
          icon: Icons.bar_chart_rounded,
          message: match.isFinished
              ? 'Detailed stats not available for this match.'
              : match.isLive
                  ? 'Stats are warming up — check back shortly.'
                  : 'Statistics appear once the match starts.');
    }

    // Strip possession from the main list — rendered separately.
    final filteredStats = stats
        .where((s) => !s.name.toLowerCase().contains('possession'))
        .toList();

    // Extract shot stats for the accuracy gauge.
    MatchStat? findStat(List<String> names) {
      for (final s in filteredStats) {
        if (names.any((n) => s.name == n)) return s;
      }
      return null;
    }

    final totalShots = findStat(['Total Shots']);
    final shotsOnGoal = findStat(['Shots on Goal']);
    final showAccuracy = totalShots != null && shotsOnGoal != null;

    // Group the remaining stats by category.
    List<MatchStat> cat(Set<String> keys) =>
        filteredStats.where((s) => keys.contains(s.name)).toList();
    List<MatchStat> other() => filteredStats
        .where((s) =>
            !_kAttackStats.contains(s.name) &&
            !_kPassingStats.contains(s.name) &&
            !_kDisciplineStats.contains(s.name))
        .toList();

    final attackStats = cat(_kAttackStats);
    final passingStats = cat(_kPassingStats);
    final disciplineStats = cat(_kDisciplineStats);
    final otherStats = other();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // ── Possession ───────────────────────────────────────────────
        if (possHome != null && possAway != null)
          _PossessionCard(
              homeTeam: match.homeTeam.tla,
              awayTeam: match.awayTeam.tla,
              homePct: possHome,
              awayPct: possAway,
              p: p),

        // ── xG card ──────────────────────────────────────────────────
        if (showXg)
          _XgCard(
              homeTeam: match.homeTeam.tla,
              awayTeam: match.awayTeam.tla,
              homeXg: xgHome ?? 0,
              awayXg: xgAway ?? 0,
              p: p),

        // ── Shot accuracy gauge ───────────────────────────────────────
        if (showAccuracy)
          _ShotAccuracyCard(
            homeTeam: match.homeTeam.tla,
            awayTeam: match.awayTeam.tla,
            totalShots: totalShots,
            shotsOnGoal: shotsOnGoal,
            p: p,
          ),

        // ── Momentum chart ────────────────────────────────────────────
        if (momentumPoints != null && momentumPoints.length >= 2)
          _MomentumCard(
            points: momentumPoints,
            incidents: incidents,
            homeTeam: match.homeTeam.tla,
            awayTeam: match.awayTeam.tla,
            p: p,
          ),

        // ── Grouped stat rows ─────────────────────────────────────────
        if (attackStats.isNotEmpty ||
            passingStats.isNotEmpty ||
            disciplineStats.isNotEmpty ||
            otherStats.isNotEmpty) ...[
          _StatsCard(
            title: 'STATISTICS',
            fromFirestore: fromFirestore,
            groups: [
              if (attackStats.isNotEmpty) _StatGroup('ATTACK', attackStats),
              if (passingStats.isNotEmpty) _StatGroup('PASSING', passingStats),
              if (disciplineStats.isNotEmpty)
                _StatGroup('DISCIPLINE', disciplineStats),
              if (otherStats.isNotEmpty) _StatGroup('', otherStats),
            ],
            p: p,
          ),
        ],
      ],
    );
  }
}

// ─── Possession card ──────────────────────────────────────────────────────────

class _PossessionCard extends StatelessWidget {
  final String homeTeam, awayTeam;
  final double homePct, awayPct;
  final Palette p;
  const _PossessionCard(
      {required this.homeTeam,
      required this.awayTeam,
      required this.homePct,
      required this.awayPct,
      required this.p});

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
          border: Border.all(color: p.stroke)),
      child: Column(children: [
        Row(children: [
          Text(homeTeam,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brand)),
          const Spacer(),
          Text('Possession',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: p.textLow)),
          const Spacer(),
          Text(awayTeam,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.live)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('${homePct.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: p.textHi)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: hRatio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, ratio, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(children: [
                      Expanded(
                          flex: (ratio * 100).round().clamp(1, 99),
                          child: const ColoredBox(color: AppTheme.brand)),
                      Expanded(
                          flex: ((1 - ratio) * 100).round().clamp(1, 99),
                          child: const ColoredBox(color: AppTheme.live)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Text('${awayPct.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: p.textHi)),
        ]),
      ]),
    );
  }
}

// ─── xG card ─────────────────────────────────────────────────────────────────

class _XgCard extends StatelessWidget {
  final String homeTeam, awayTeam;
  final double homeXg, awayXg;
  final Palette p;
  const _XgCard(
      {required this.homeTeam,
      required this.awayTeam,
      required this.homeXg,
      required this.awayXg,
      required this.p});

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
          border: Border.all(color: p.stroke)),
      child: Column(children: [
        Row(children: [
          Text(homeTeam,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brand)),
          const Spacer(),
          Text('Expected Goals (xG)',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: p.textLow)),
          const Spacer(),
          Text(awayTeam,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.live)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(homeXg.toStringAsFixed(2),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brand)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: hRatio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, ratio, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(children: [
                      Expanded(
                          flex: (ratio * 100).round().clamp(1, 99),
                          child: const ColoredBox(color: AppTheme.brand)),
                      Expanded(
                          flex: ((1 - ratio) * 100).round().clamp(1, 99),
                          child: const ColoredBox(color: AppTheme.live)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Text(awayXg.toStringAsFixed(2),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.live)),
        ]),
      ]),
    );
  }
}

// ─── Shot accuracy gauge ──────────────────────────────────────────────────────
// Two animated half-circle arcs showing on-target shot accuracy per team.

class _ShotAccuracyCard extends StatelessWidget {
  final String homeTeam, awayTeam;
  final MatchStat totalShots;
  final MatchStat shotsOnGoal;
  final Palette p;
  const _ShotAccuracyCard(
      {required this.homeTeam,
      required this.awayTeam,
      required this.totalShots,
      required this.shotsOnGoal,
      required this.p});

  @override
  Widget build(BuildContext context) {
    double parse(String v) =>
        double.tryParse(v.replaceAll('—', '').trim()) ?? 0;

    final homeTot = parse(totalShots.homeValue);
    final awayTot = parse(totalShots.awayValue);
    final homeOn = parse(shotsOnGoal.homeValue);
    final awayOn = parse(shotsOnGoal.awayValue);
    final homeAcc = homeTot > 0 ? (homeOn / homeTot).clamp(0.0, 1.0) : 0.0;
    final awayAcc = awayTot > 0 ? (awayOn / awayTot).clamp(0.0, 1.0) : 0.0;

    if (homeTot == 0 && awayTot == 0) return const SizedBox.shrink();

    Widget gauge(double accuracy, Color color, String teamTla, double total,
        double onTarget) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 70,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: accuracy),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => CustomPaint(
              painter: _ShotArcPainter(
                accuracy: val,
                activeColor: color,
                trackColor: p.surfaceHi,
              ),
              size: const Size(double.infinity, 70),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(accuracy * 100).toInt()}%',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(
          '${onTarget.toInt()} of ${total.toInt()} on target',
          style: TextStyle(fontSize: 10, color: p.textLow),
        ),
        Text(teamTla,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: p.textMid)),
      ]);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke)),
      child: Column(children: [
        Row(children: [
          Text('SHOT ACCURACY',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: p.textLow)),
          const Spacer(),
          Text('on-target %', style: TextStyle(fontSize: 10, color: p.textLow)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: gauge(homeAcc, AppTheme.brand, homeTeam, homeTot, homeOn)),
          Container(width: 1, height: 80, color: p.stroke),
          Expanded(
              child: gauge(awayAcc, AppTheme.live, awayTeam, awayTot, awayOn)),
        ]),
      ]),
    );
  }
}

/// Half-circle arc gauge painter.
/// Draws a semi-circle (bottom half) as track, then overlays the filled arc.
class _ShotArcPainter extends CustomPainter {
  final double accuracy; // 0.0 → 1.0
  final Color activeColor;
  final Color trackColor;
  const _ShotArcPainter(
      {required this.accuracy,
      required this.activeColor,
      required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 4;
    final radius = math.min(size.width * 0.42, cy - 4);
    const sw = 12.0;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track arc (full half-circle, left to right)
    canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);

    // Active arc
    if (accuracy > 0.01) {
      canvas.drawArc(
          rect,
          math.pi,
          accuracy * math.pi,
          false,
          Paint()
            ..color = activeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round);
    }

    // Centre percentage text is rendered by the parent widget, not here.
  }

  @override
  bool shouldRepaint(_ShotArcPainter old) =>
      old.accuracy != accuracy || old.activeColor != activeColor;
}

// ─── Momentum card ────────────────────────────────────────────────────────────

class _MomentumCard extends StatelessWidget {
  final List<MomentumPoint> points;
  final List<MatchIncident> incidents;
  final String homeTeam, awayTeam;
  final Palette p;
  const _MomentumCard(
      {required this.points,
      required this.incidents,
      required this.homeTeam,
      required this.awayTeam,
      required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('MOMENTUM',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: p.textLow)),
          const Spacer(),
          Text('estimated from events',
              style: TextStyle(
                  fontSize: 10, fontStyle: FontStyle.italic, color: p.textLow)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: CustomPaint(
            painter: _MomentumPainter(points, incidents, p),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const _LegendDot(color: AppTheme.brand),
          const SizedBox(width: 5),
          Text(homeTeam,
              style: TextStyle(
                  fontSize: 11, color: p.textMid, fontWeight: FontWeight.w700)),
          const SizedBox(width: 14),
          const _LegendDot(color: AppTheme.live),
          const SizedBox(width: 5),
          Text(awayTeam,
              style: TextStyle(
                  fontSize: 11, color: p.textMid, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ─── Enhanced momentum painter ────────────────────────────────────────────────

class _MomentumPainter extends CustomPainter {
  final List<MomentumPoint> points;
  final List<MatchIncident> incidents;
  final Palette palette;
  _MomentumPainter(this.points, this.incidents, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final w = size.width;
    // Leave 16px at bottom for minute labels
    final chartH = size.height - 16;
    final maxMin = points.map((p) => p.minute).reduce((a, b) => a > b ? a : b);
    final span = (math.max(maxMin, 90)).toDouble();

    // ── Grid ────────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = palette.stroke
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(
          Offset(0, chartH * i / 4), Offset(w, chartH * i / 4), gridPaint);
    }
    // Centre line (50%)
    canvas.drawLine(
        Offset(0, chartH / 2),
        Offset(w, chartH / 2),
        Paint()
          ..color = palette.textLow.withValues(alpha: 0.35)
          ..strokeWidth = 1);

    // ── Half-time vertical marker at 45' ────────────────────────────────────
    final htX = (45 / span) * w;
    canvas.drawLine(
        Offset(htX, 0),
        Offset(htX, chartH),
        Paint()
          ..color = palette.textLow.withValues(alpha: 0.45)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);

    Offset toOff(MomentumPoint pt, bool isHome) {
      final x = (pt.minute / span) * w;
      final score = isHome ? pt.homeScore : pt.awayScore;
      final y = chartH - (score / 100) * chartH;
      return Offset(x, y);
    }

    List<Offset> homeOffsets = points.map((pt) => toOff(pt, true)).toList();
    List<Offset> awayOffsets = points.map((pt) => toOff(pt, false)).toList();

    // ── Gradient fill under each line ───────────────────────────────────────
    void drawFill(List<Offset> pts, Color color) {
      if (pts.length < 2) return;
      final path = Path();
      path.moveTo(pts[0].dx, chartH / 2);
      path.lineTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final curr = pts[i];
        final cpX = (prev.dx + curr.dx) / 2;
        path.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      }
      path.lineTo(pts.last.dx, chartH / 2);
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.03),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(0, 0, w, chartH))
            ..style = PaintingStyle.fill);
    }

    drawFill(homeOffsets, AppTheme.brand);
    drawFill(awayOffsets, AppTheme.live);

    // ── Lines ────────────────────────────────────────────────────────────────
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
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    drawPath(homeOffsets, AppTheme.brand);
    drawPath(awayOffsets, AppTheme.live);

    // ── Goal event dots ──────────────────────────────────────────────────────
    final goalIncs = incidents.where((i) => i.type == 'goal').toList();
    for (final inc in goalIncs) {
      final x = (inc.minute / span) * w;
      final color = inc.isHome ? AppTheme.brand : AppTheme.live;
      canvas.drawCircle(Offset(x, chartH / 2), 4, Paint()..color = color);
      canvas.drawCircle(
          Offset(x, chartH / 2),
          4,
          Paint()
            ..color = palette.surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // ── Minute labels ────────────────────────────────────────────────────────
    void drawMinuteLabel(String text, double x) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: 9, color: palette.textLow, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
    }

    drawMinuteLabel("0'", 0);
    drawMinuteLabel("45'", htX);
    drawMinuteLabel("90'", (90 / span) * w);
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) =>
      old.points != points ||
      old.incidents != incidents ||
      old.palette.isDark != palette.isDark;
}

// ─── Stats card with grouped sections ────────────────────────────────────────

class _StatGroup {
  final String label;
  final List<MatchStat> stats;
  const _StatGroup(this.label, this.stats);
}

class _StatsCard extends StatelessWidget {
  final String title;
  final bool fromFirestore;
  final List<_StatGroup> groups;
  final Palette p;
  const _StatsCard(
      {required this.title,
      required this.fromFirestore,
      required this.groups,
      required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppTheme.r),
          border: Border.all(color: p.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Text(title,
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w800,
                    color: p.textLow)),
            if (fromFirestore) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        // Groups
        ...groups.asMap().entries.map((entry) {
          final i = entry.key;
          final g = entry.value;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) Divider(height: 16, color: p.stroke),
                if (g.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(g.label,
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            color: p.textLow.withValues(alpha: 0.6))),
                  ),
                ...g.stats.map((s) => _StatRow(stat: s, p: p)),
              ]);
        }),
      ]),
    );
  }
}

// ─── Single stat row with animated bar ───────────────────────────────────────

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
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 48,
            child: Text(stat.homeValue,
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
        const SizedBox(height: 6),
        // Animated bar sweeps in left→right on first render
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: hRatio),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, ratio, __) => ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                Expanded(
                  flex: (ratio * 100).round().clamp(1, 99),
                  child: ColoredBox(
                      color: homeWins
                          ? AppTheme.brand
                          : AppTheme.brand.withValues(alpha: 0.35)),
                ),
                Expanded(
                  flex: ((1 - ratio) * 100).round().clamp(1, 99),
                  child: ColoredBox(
                      color: awayWins
                          ? AppTheme.live
                          : AppTheme.live.withValues(alpha: 0.35)),
                ),
              ]),
            ),
          ),
        ),
      ]),
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
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));
}
