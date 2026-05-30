// lib/shared/widgets/pitch_painter.dart
//
// Football pitch background used by the Match Detail Lineup tab.
//
// Usage:
//   Stack(
//     children: [
//       const PitchBackground(),
//       // overlay player chips using Positioned with fractional coords
//     ],
//   )

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stateless widget that paints a regulation football pitch.
/// Aspect ratio is left to the parent — wrap in AspectRatio(0.62) for a
/// portrait-phone full-pitch view.
class PitchBackground extends StatelessWidget {
  const PitchBackground({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PitchPainter(),
        child: const SizedBox.expand(),
      );
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background gradient ─────────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A3A20),
          Color(0xFF1D4A23),
          Color(0xFF1A3A20),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Subtle alternating stripes (lighter/darker) to simulate real turf.
    final stripeW = w / 8;
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03);
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(
          Rect.fromLTWH(i * stripeW, 0, stripeW, h), stripePaint);
    }

    // ── Line paint ─────────────────────────────────────────────────────────
    final lp = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;

    // Margins (5% horizontal, 3% vertical)
    final mx = w * 0.05;
    final my = h * 0.03;
    final fieldW = w - 2 * mx;
    final fieldH = h - 2 * my;

    // ── Outer boundary ──────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTRB(mx, my, w - mx, h - my), lp);

    // ── Halfway line ────────────────────────────────────────────────────────
    canvas.drawLine(Offset(mx, h * 0.5), Offset(w - mx, h * 0.5), lp);

    // ── Centre circle ───────────────────────────────────────────────────────
    final cR = fieldW * 0.135;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), cR, lp);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 2.5, dotPaint);

    // ── Penalty areas (top + bottom) ────────────────────────────────────────
    // Real proportions: PA width = 40.32m / 68m ≈ 59%  height = 16.5m / 105m ≈ 16%
    final paW = fieldW * 0.59;
    final paH = fieldH * 0.155;
    final paX = (w - paW) / 2;
    canvas.drawRect(Rect.fromLTRB(paX, my, paX + paW, my + paH), lp);           // top
    canvas.drawRect(Rect.fromLTRB(paX, h - my - paH, paX + paW, h - my), lp);  // bottom

    // ── 6-yard boxes ────────────────────────────────────────────────────────
    // Real proportions: 18.32m / 68m ≈ 27%  depth = 5.5m / 105m ≈ 5%
    final sbW = fieldW * 0.27;
    final sbH = fieldH * 0.055;
    final sbX = (w - sbW) / 2;
    canvas.drawRect(Rect.fromLTRB(sbX, my, sbX + sbW, my + sbH), lp);           // top
    canvas.drawRect(Rect.fromLTRB(sbX, h - my - sbH, sbX + sbW, h - my), lp);  // bottom

    // ── Penalty spots ───────────────────────────────────────────────────────
    // Real: 11m / 105m ≈ 10.5% from goal line
    final psY = fieldH * 0.105;
    canvas.drawCircle(Offset(w * 0.5, my + psY), 2.5, dotPaint);            // top
    canvas.drawCircle(Offset(w * 0.5, h - my - psY), 2.5, dotPaint);       // bottom

    // ── Penalty arcs (the "D") ──────────────────────────────────────────────
    // Only the arc outside the penalty box is visible.
    final arcR = cR; // same radius as centre circle
    final topSpot = Offset(w * 0.5, my + psY);
    final botSpot = Offset(w * 0.5, h - my - psY);
    final topPaBottom = my + paH;
    final botPaTop = h - my - paH;

    // Top arc (arc below the top penalty area)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, topPaBottom, w, h));
    canvas.drawCircle(topSpot, arcR, lp);
    canvas.restore();

    // Bottom arc (arc above the bottom penalty area)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, botPaTop));
    canvas.drawCircle(botSpot, arcR, lp);
    canvas.restore();

    // ── Corner arcs ─────────────────────────────────────────────────────────
    final cArcR = fieldW * 0.038;
    for (final cfg in [
      (Offset(mx, my), 0.0),
      (Offset(w - mx, my), math.pi / 2),
      (Offset(mx, h - my), -math.pi / 2),
      (Offset(w - mx, h - my), math.pi),
    ]) {
      canvas.drawArc(
          Rect.fromCircle(center: cfg.$1, radius: cArcR),
          cfg.$2, math.pi / 2, false, lp);
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => false;
}

// ─── Formation layout helpers ─────────────────────────────────────────────────

/// Parses a formation string like "4-3-3" into a row count list [4, 3, 3].
/// Always prepends a GK row of 1, giving [1, 4, 3, 3] total.
List<int> parseFormation(String? formation) {
  if (formation == null || formation.isEmpty) return [1, 4, 3, 3];
  final parts = formation
      .split('-')
      .map(int.tryParse)
      .whereType<int>()
      .toList();
  if (parts.isEmpty) return [1, 4, 3, 3];
  return [1, ...parts];
}

/// Returns normalized (0..1) pitch positions for [players] arranged by
/// [formation] for either the home (top half) or away (bottom half) team.
///
/// Home: GK at top (y ≈ 0.07), forwards near halfway (y ≈ 0.46).
/// Away: GK at bottom (y ≈ 0.93), forwards near halfway (y ≈ 0.54).
List<Offset> formationPositions({
  required String? formation,
  required bool isHome,
  required int playerCount,
}) {
  final rows = parseFormation(formation);

  // Trim or pad rows so they account for exactly playerCount players.
  var total = rows.fold(0, (s, r) => s + r);
  final adjustedRows = List<int>.from(rows);
  if (total < playerCount) {
    adjustedRows[adjustedRows.length - 1] += playerCount - total;
  } else if (total > playerCount) {
    var excess = total - playerCount;
    for (int i = adjustedRows.length - 1; i >= 0 && excess > 0; i--) {
      final remove = math.min(adjustedRows[i] - 1, excess);
      adjustedRows[i] -= remove;
      excess -= remove;
    }
  }

  final positions = <Offset>[];
  final numRows = adjustedRows.length;

  // y range within which this team's players are placed (normalized to full pitch)
  const homeYStart = 0.06;
  const homeYEnd = 0.46;
  const awayYStart = 0.94;
  const awayYEnd = 0.54;

  for (int ri = 0; ri < numRows; ri++) {
    final count = adjustedRows[ri];
    if (count <= 0) continue;

    final progress = numRows == 1 ? 0.5 : ri / (numRows - 1);
    final y = isHome
        ? homeYStart + progress * (homeYEnd - homeYStart)
        : awayYStart - progress * (awayYStart - awayYEnd);

    for (int ci = 0; ci < count; ci++) {
      final x = (ci + 1) / (count + 1);
      positions.add(Offset(x, y));
    }
  }

  return positions;
}
