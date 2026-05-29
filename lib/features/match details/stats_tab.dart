// tabs/stats_tab.dart
//
// Stats tab: momentum graph + dual-bar statistics.
// Part of the match_details library — see match_details_screen.dart.
// Do not add imports here; they live in the library root.

part of 'match_details_screen.dart';

// ─── Stats tab ────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  final Match match;
  const _StatsTab({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    // Prefer liveStats from the Firestore raw doc; fall back to BSD resolver.
    final rawAsync = ref.watch(_rawMatchProvider(match.id));
    final rawDoc = rawAsync.value;
    final fsStats = rawDoc != null ? _statsFromRaw(rawDoc) : null;

    final statsAsync = fsStats != null
        ? AsyncValue.data(fsStats)
        : ref.watch(_statsProvider(match));
    final incsAsync = ref.watch(_incidentsProvider(match));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 30),
      children: [
        // Momentum graph
        incsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (incs) {
            final pts = Momentum.fromIncidents(incs);
            if (pts.length < 2) return const SizedBox.shrink();
            return _DetailCard(
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
                          painter: _MomentumPainter(pts, p),
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
            );
          },
        ),

        // Stats bars
        statsAsync.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
          error: (_, __) => const _Unavailable(
              icon: Icons.bar_chart_rounded, message: 'Stats unavailable.'),
          data: (stats) {
            if (stats.isEmpty) {
              return _Unavailable(
                  icon: Icons.bar_chart_rounded,
                  message: match.isFinished
                      ? 'Detailed stats not available for this match.'
                      : match.isLive
                          ? 'Stats are warming up — check back in a few minutes.'
                          : 'Statistics appear once the match starts.',
                  hint: match.isFinished
                      ? 'Some competitions don\'t expose full match statistics.'
                      : null);
            }
            return _DetailCard(
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
                              color: AppTheme.of(context).textLow)),
                    ]),
                  ),
                  ...stats.map((s) => _StatBar(stat: s)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }
}

class _StatBar extends StatelessWidget {
  final MatchStat stat;
  const _StatBar({required this.stat});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final h = double.tryParse(stat.homeValue.replaceAll('%', '')) ?? 0;
    final a = double.tryParse(stat.awayValue.replaceAll('%', '')) ?? 0;
    final total = (h + a) <= 0 ? 1.0 : (h + a);
    final hRatio = h / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(children: [
            Text(stat.homeValue,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.textHi)),
            const Spacer(),
            Text(stat.name,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.textMid)),
            const Spacer(),
            Text(stat.awayValue,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.textHi)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Row(children: [
                Expanded(
                  flex: (hRatio * 100).round().clamp(1, 99),
                  child: Container(color: AppTheme.brand),
                ),
                Expanded(
                  flex: ((1 - hRatio) * 100).round().clamp(1, 99),
                  child: Container(color: AppTheme.live),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentumPainter extends CustomPainter {
  final List<MomentumPoint> points;
  final Palette palette;
  _MomentumPainter(this.points, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final w = size.width, h = size.height;
    final maxMin = points.map((p) => p.minute).reduce((a, b) => a > b ? a : b);
    final span = (math.max(maxMin, 90)).toDouble();

    // Grid lines
    final gridPaint = Paint()
      ..color = palette.stroke
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    // Centre line
    canvas.drawLine(
      Offset(0, h / 2),
      Offset(w, h / 2),
      Paint()
        ..color = palette.textLow.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    Offset toOffset(MomentumPoint pt, bool isHome) {
      final x = (pt.minute / span) * w;
      final score = isHome ? pt.homeScore : pt.awayScore;
      final y = h - (score / 100) * h;
      return Offset(x, y);
    }

    void drawSmoothedPath(List<Offset> pts, Color color) {
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
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final homeOffsets = points.map((pt) => toOffset(pt, true)).toList();
    final awayOffsets = points.map((pt) => toOffset(pt, false)).toList();
    drawSmoothedPath(homeOffsets, AppTheme.brand);
    drawSmoothedPath(awayOffsets, AppTheme.live);
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) =>
      old.points != points || old.palette.isDark != palette.isDark;
}
