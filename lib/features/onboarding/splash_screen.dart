// lib/features/onboarding/splash_screen.dart
//
// Cinematic splash — stadium atmosphere, fully articulated player, real ball.
//
// Timeline (4 400 ms):
//   0.00–0.10  pitch, crowd silhouette, floodlights + goal materialise
//   0.10–0.40  player runs in (filled jersey, proper run cycle)
//   0.40–0.54  plant & wind-up; ball rolls to boot
//   0.54–0.57  IMPACT flash + 8-spoke sparks
//   0.54–0.82  ball arcs with pentagon-spin, motion trail, aerial shadow
//   0.82–0.92  net deforms, three concentric ripple rings
//   0.82–1.00  confetti burst + "GOAL!" glow-bounce + title rises

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─── Confetti piece data ─────────────────────────────────────────────────────

class _CP {
  final double angle, speed, rotSpeed, size;
  final Color color;
  const _CP(this.angle, this.speed, this.rotSpeed, this.size, this.color);
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060F09),
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Center(
          child: AspectRatio(
            aspectRatio: 0.82,
            child: CustomPaint(painter: _SplashPainter(_c.value)),
          ),
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _SplashPainter extends CustomPainter {
  final double t;
  final List<_CP> _conf;

  // Phase boundaries (0–1 normalised)
  static const _tEnvEnd    = 0.10;
  static const _tRunEnd    = 0.40;
  static const _tStrike    = 0.54; // ball launches
  static const _tFlashEnd  = 0.59;
  static const _tKickEnd   = 0.68;
  static const _tBallEnd   = 0.82; // ball in net
  static const _tNetEnd    = 0.92;
  static const _tNameStart = 0.82;

  _SplashPainter(this.t) : _conf = _makeConfetti();

  static List<_CP> _makeConfetti() {
    final r = math.Random(7);
    const cols = [
      Color(0xFFFFD700), Color(0xFFFF4444), Color(0xFF44AAFF),
      Color(0xFF44EE66), Colors.white,      Color(0xFFFF88CC),
      Color(0xFFFF9900), Color(0xFFCC55FF),
    ];
    return List.generate(64, (i) => _CP(
      r.nextDouble() * math.pi * 2,
      0.30 + r.nextDouble() * 0.70,
      (r.nextDouble() - 0.5) * 14,
      0.007 + r.nextDouble() * 0.016,
      cols[i % cols.length],
    ));
  }

  // ─── Main paint ───────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final envA = _sat(t / _tEnvEnd); // environment alpha 0→1

    final goalRect = Rect.fromLTWH(w * 0.72, h * 0.25, w * 0.24, h * 0.41);
    final groundY  = goalRect.bottom; // h * 0.66

    _drawAtmosphere(canvas, w, h, envA);
    _drawPitch(canvas, w, h, groundY, envA);
    _drawGoal(canvas, goalRect, envA);

    // Net ripple after ball lands
    if (t >= _tBallEnd - 0.01 && t <= _tNetEnd + 0.04) {
      _drawNetEffect(canvas, goalRect,
          _sat((t - (_tBallEnd - 0.01)) / (_tNetEnd - (_tBallEnd - 0.01))));
    }

    final ballR = w * 0.038;
    final bPos  = _ballPos(w, h, groundY, goalRect);

    _drawBallShadow(canvas, bPos, ballR, groundY);

    if (t >= _tStrike && t < _tBallEnd) {
      _drawMotionTrail(canvas, w, h, groundY, goalRect, ballR);
    }

    _drawBall(canvas, bPos, ballR, _ballRot());

    if (t < _tKickEnd + 0.12) {
      _drawPlayer(canvas, w, h, groundY);
    }

    if (t >= _tStrike && t < _tFlashEnd) {
      _drawImpactFlash(canvas, w, groundY,
          _sat((t - _tStrike) / (_tFlashEnd - _tStrike)));
    }

    if (t >= _tBallEnd) {
      _drawConfetti(canvas, w, h,
          _sat((t - _tBallEnd) / (1.0 - _tBallEnd)));
    }

    if (t >= _tStrike) {
      _drawGoalBurst(canvas, w, h,
          _sat((t - _tStrike) / (_tNetEnd - _tStrike)));
    }

    if (t >= _tNameStart) {
      _drawAppName(canvas, w, h,
          _sat((t - _tNameStart) / (1.0 - _tNameStart)));
    }
  }

  // ─── Atmosphere ───────────────────────────────────────────────────────────

  void _drawAtmosphere(Canvas canvas, double w, double h, double a) {
    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071510), Color(0xFF0C1F10), Color(0xFF081508)],
          stops: [0, 0.45, 1],
        ).createShader(bg),
    );

    _drawFloodlight(canvas, w, h, Offset(w * 0.04, 0), a);
    _drawFloodlight(canvas, w, h, Offset(w * 0.96, 0), a);
    _drawCrowd(canvas, w, h, a);
  }

  void _drawFloodlight(
      Canvas canvas, double w, double h, Offset origin, double a) {
    final isLeft = origin.dx < w / 2;
    final fanEndX = isLeft ? w * 0.65 : w * 0.35;
    final fanH = h * 0.68;
    final halfW = w * 0.28;
    final path = Path()
      ..moveTo(origin.dx, 0)
      ..lineTo(origin.dx + (isLeft ? 2 : -2), 0)
      ..lineTo(fanEndX + halfW, fanH)
      ..lineTo(fanEndX - halfW, fanH)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.07 * a),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Bright source dot
    canvas.drawCircle(
      origin + const Offset(0, 2),
      4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawCrowd(Canvas canvas, double w, double h, double a) {
    final bandH = h * 0.11;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, bandH + 2),
      Paint()..color = const Color(0xFF040905).withValues(alpha: a),
    );
    final rng = math.Random(99);
    final crowdDark = Paint()
      ..color = const Color(0xFF0E1C10).withValues(alpha: a);
    for (var i = 0; i < 42; i++) {
      final x = w * i / 42 + (rng.nextDouble() - 0.5) * (w / 38);
      final bodyH = bandH * (0.48 + rng.nextDouble() * 0.40);
      final hw = w * 0.022;
      // Head
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, bandH - bodyH - hw * 0.65),
          width: hw * 1.1, height: hw * 1.3,
        ),
        crowdDark,
      );
      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - hw * 0.55, bandH - bodyH, hw * 1.1, bodyH),
          const Radius.circular(3),
        ),
        crowdDark,
      );
    }
    // Glow band at crowd/pitch boundary
    canvas.drawRect(
      Rect.fromLTWH(0, bandH - 3, w, 8),
      Paint()
        ..color = const Color(0xFF1A5A25).withValues(alpha: 0.4 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  // ─── Pitch ────────────────────────────────────────────────────────────────

  void _drawPitch(
      Canvas canvas, double w, double h, double groundY, double a) {
    final pitchTop = h * 0.10;

    // Mowed stripes
    for (var i = 0; i < 9; i++) {
      final col = i.isEven
          ? const Color(0xFF1C5228)
          : const Color(0xFF184422);
      canvas.drawRect(
        Rect.fromLTWH(0, pitchTop + (groundY - pitchTop) * i / 9,
            w, (groundY - pitchTop) / 9 + 1),
        Paint()..color = col.withValues(alpha: a),
      );
    }

    // Ground plane below the action (slightly darker)
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, h - groundY),
      Paint()..color = const Color(0xFF122E18).withValues(alpha: a),
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Ground/horizon line
    canvas.drawLine(Offset(0, groundY), Offset(w, groundY), line);

    // Centre circle (elliptical from camera angle)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.42, groundY),
        width: w * 0.26, height: w * 0.07,
      ),
      line..color = Colors.white.withValues(alpha: 0.15 * a),
    );

    // Centre spot
    canvas.drawCircle(
      Offset(w * 0.42, groundY), 2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.28 * a),
    );

    // Penalty box (right side)
    canvas.drawRect(
      Rect.fromLTRB(w * 0.62, h * 0.19, w, groundY + 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 6-yard box
    canvas.drawRect(
      Rect.fromLTRB(w * 0.765, h * 0.275, w, groundY + 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85,
    );

    // Penalty spot
    canvas.drawCircle(
      Offset(w * 0.67, groundY - (groundY - h * 0.19) * 0.28),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.20 * a),
    );

    // Arc at top of penalty area
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.67, groundY - (groundY - h * 0.19) * 0.28),
        width: w * 0.14, height: h * 0.11,
      ),
      math.pi, math.pi, false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85,
    );

    // Corner arc (top-right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w, h * 0.19), radius: w * 0.055),
      math.pi * 0.5, math.pi * 0.5, false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85,
    );

    // Halfway line (left half)
    canvas.drawLine(
      Offset(w * 0.42, h * 0.10), Offset(w * 0.42, groundY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * a)
        ..strokeWidth = 0.9,
    );
  }

  // ─── Goal ────────────────────────────────────────────────────────────────

  void _drawGoal(Canvas canvas, Rect g, double a) {
    const dX = 7.0, dY = -5.0; // depth offset for back posts

    // Net background fill
    final netFill = Path()
      ..moveTo(g.left + g.width * 0.07, g.top)
      ..lineTo(g.right, g.top)
      ..lineTo(g.right, g.bottom)
      ..lineTo(g.left, g.bottom)
      ..close();
    canvas.drawPath(
      netFill,
      Paint()..color = const Color(0xFF0F2A16).withValues(alpha: 0.7 * a),
    );

    // Net grid lines
    final netLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55;
    for (var i = 1; i < 11; i++) {
      final x = g.left + g.width * i / 11;
      canvas.drawLine(Offset(x, g.top + 1), Offset(x, g.bottom), netLine);
    }
    for (var i = 1; i < 9; i++) {
      final y = g.top + g.height * i / 9;
      canvas.drawLine(Offset(g.left, y), Offset(g.right, y), netLine);
    }

    // Depth lines (back frame, drawn before front)
    final depthPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final backL = Offset(g.left + g.width * 0.07 + dX, g.top + dY);
    final backR = Offset(g.right + dX, g.top + dY);
    final backBR = Offset(g.right + dX, g.bottom + dY);
    canvas.drawLine(backL, backR, depthPaint);
    canvas.drawLine(backR, backBR, depthPaint);
    canvas.drawLine(Offset(g.left + g.width * 0.07, g.top), backL, depthPaint);
    canvas.drawLine(Offset(g.right, g.top), backR, depthPaint);

    // Front frame
    final post = Paint()
      ..color = Colors.white.withValues(alpha: 0.92 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
        Offset(g.left + g.width * 0.07, g.top), Offset(g.right, g.top), post);
    canvas.drawLine(
        Offset(g.left + g.width * 0.07, g.top), Offset(g.left, g.bottom), post);
    canvas.drawLine(
        Offset(g.right, g.top), Offset(g.right, g.bottom), post);

    // Post glow
    for (final x in [g.left + g.width * 0.07, g.right]) {
      canvas.drawLine(
        Offset(x, g.top), Offset(x, g.bottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10 * a)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  void _drawNetEffect(Canvas canvas, Rect g, double t01) {
    // 3 expanding rings with staggered delay
    for (var i = 0; i < 3; i++) {
      final tp = _sat((t01 - i * 0.18) / 0.65);
      if (tp <= 0) continue;
      final fade = (1 - tp).clamp(0.0, 1.0);
      canvas.drawCircle(
        g.center,
        g.shortestSide * 0.55 * _easeOut(tp),
        Paint()
          ..color = AppTheme.brand.withValues(alpha: 0.50 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - tp * 0.5),
      );
    }
    // Net bulge glow
    final bulge = _sat(t01 / 0.35);
    if (bulge > 0.01) {
      canvas.drawOval(
        Rect.fromCenter(
          center: g.center + Offset(g.width * 0.08 * bulge, 0),
          width: g.width * 0.55 * bulge,
          height: g.height * 0.45 * bulge,
        ),
        Paint()
          ..color = AppTheme.brand.withValues(alpha: 0.14 * (1 - bulge))
          ..style = PaintingStyle.fill,
      );
    }
  }

  // ─── Ball ────────────────────────────────────────────────────────────────

  Offset _ballPos(double w, double h, double groundY, Rect goal) {
    final startX = w * 0.295;
    final startY = groundY - w * 0.038;
    if (t < _tStrike) return Offset(startX, startY);
    if (t >= _tBallEnd) return goal.center + const Offset(3, 5);
    final p = _easeOut(_sat((t - _tStrike) / (_tBallEnd - _tStrike)));
    final arc = -math.sin(_sat((t - _tStrike) / (_tBallEnd - _tStrike)) * math.pi) * h * 0.18;
    return Offset(
      startX + (goal.center.dx - startX) * p,
      startY + (goal.center.dy - startY) * p + arc,
    );
  }

  double _ballRot() {
    if (t < _tStrike) return 0;
    final p = _sat((t - _tStrike) / (_tBallEnd - _tStrike));
    return p * math.pi * 11;
  }

  void _drawBallShadow(Canvas canvas, Offset pos, double r, double groundY) {
    final heightAbove = (groundY - pos.dy - r).clamp(0.0, groundY);
    final scale = 1.0 - (heightAbove / groundY) * 0.72;
    final alpha = 0.32 * scale;
    if (alpha < 0.01) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, groundY + r * 0.45),
        width: r * 2.4 * scale, height: r * 0.55 * scale,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _drawMotionTrail(
      Canvas canvas, double w, double h, double groundY, Rect goal, double r) {
    final startX = w * 0.295;
    final startY = groundY - r;
    for (var i = 5; i >= 1; i--) {
      final tp = t - i * 0.013;
      if (tp < _tStrike) continue;
      final pRaw = _sat((tp - _tStrike) / (_tBallEnd - _tStrike));
      final p = _easeOut(pRaw);
      final arc = -math.sin(pRaw * math.pi) * h * 0.18;
      final pos = Offset(
        startX + (goal.center.dx - startX) * p,
        startY + (goal.center.dy - startY) * p + arc,
      );
      canvas.drawCircle(
        pos, r * (1 - i * 0.12),
        Paint()..color = Colors.white.withValues(alpha: 0.07 * (6 - i) / 5),
      );
    }
  }

  void _drawBall(Canvas canvas, Offset c, double r, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);

    // Squash on net impact
    if (t >= _tBallEnd - 0.02 && t < _tBallEnd + 0.07) {
      final sp = _sat((t - (_tBallEnd - 0.02)) / 0.09);
      final s = math.sin(sp * math.pi);
      canvas.scale(1 - 0.32 * s, 1 + 0.32 * s);
    }

    canvas.rotate(rot);

    // White base with radial shading (lighter highlight off-centre)
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.38),
          radius: 0.85,
          colors: [Colors.white, Color(0xFFD0D0D0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );

    // Outer ring
    canvas.drawCircle(
      Offset.zero, r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // Pentagon panels (Telstar/Jabulani style)
    final pent = Paint()..color = const Color(0xFF0D1218);
    _drawPentagon(canvas, Offset.zero, r * 0.29, pent); // centre
    for (var i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 - math.pi / 2;
      _drawPentagon(
        canvas,
        Offset(math.cos(ang) * r * 0.56, math.sin(ang) * r * 0.56),
        r * 0.21, pent,
      );
    }

    // Specular highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.28, -r * 0.30),
        width: r * 0.34, height: r * 0.20,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.60),
    );

    canvas.restore();
  }

  void _drawPentagon(Canvas canvas, Offset ctr, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      final pt = ctr + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ─── Impact flash ─────────────────────────────────────────────────────────

  void _drawImpactFlash(
      Canvas canvas, double w, double groundY, double t01) {
    final fade = 1 - t01;
    final kx = w * 0.296;
    final ky = groundY - w * 0.038;

    // White burst circle
    canvas.drawCircle(
      Offset(kx, ky),
      w * 0.13 * _easeOut(t01),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 8 spark lines radiating outward
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + 0.18;
      final len = w * 0.10 * _easeOut(t01);
      final gapR = w * 0.025;
      canvas.drawLine(
        Offset(kx + math.cos(ang) * gapR, ky + math.sin(ang) * gapR),
        Offset(kx + math.cos(ang) * len, ky + math.sin(ang) * len),
        Paint()
          ..color = AppTheme.brand.withValues(alpha: 0.95 * fade)
          ..strokeWidth = 2.8 * (1 - t01 * 0.5)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Core bright dot
    canvas.drawCircle(
      Offset(kx, ky), w * 0.022 * (1 - t01),
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
  }

  // ─── Player ───────────────────────────────────────────────────────────────

  void _drawPlayer(Canvas canvas, double w, double h, double groundY) {
    // Horizontal travel
    final plantX = w * 0.255;
    double px;
    if (t <= _tEnvEnd) {
      px = -w * 0.12;
    } else if (t < _tRunEnd) {
      final rp = _easeOut(_sat((t - _tEnvEnd) / (_tRunEnd - _tEnvEnd)));
      px = -w * 0.12 + (plantX - (-w * 0.12)) * rp;
    } else {
      px = plantX;
    }

    final unit = w * 0.054;
    final running = t < _tRunEnd;
    double bob = 0;
    if (running && t > _tEnvEnd) {
      final rp = (t - _tEnvEnd) / (_tRunEnd - _tEnvEnd);
      bob = -(math.sin(rp * math.pi * 8).abs()) * unit * 0.24;
    }

    // Kick progress 0→1
    double kick = 0;
    if (t >= _tRunEnd && t <= _tKickEnd) {
      kick = (t - _tRunEnd) / (_tKickEnd - _tRunEnd);
    } else if (t > _tKickEnd) {
      kick = 1.0;
    }

    final runPhase = (running && t > _tEnvEnd)
        ? (t - _tEnvEnd) / (_tRunEnd - _tEnvEnd) * 8.5
        : 0.0;

    final lean   = running ? unit * 0.30 : unit * 0.48;
    final pelvis = Offset(px, groundY - unit * 2.05 + bob);
    final neck   = Offset(pelvis.dx + lean, pelvis.dy - unit * 1.50);
    final headC  = neck + Offset(unit * 0.14, -unit * 0.60);

    // ── Limb angles ──
    final thigh = unit * 1.06, shin = unit * 1.05;
    final upperArm = unit * 0.80, foreArm = unit * 0.72;

    double rThighA, rKnee, lThighA, lKnee;
    double rArmA, lArmA;

    if (running) {
      rThighA = math.sin(runPhase) * 0.78;
      lThighA = math.sin(runPhase + math.pi) * 0.78;
      rKnee   = (math.sin(runPhase + 0.55).clamp(0.0, 1.0)) * 1.20 + 0.18;
      lKnee   = (math.sin(runPhase + math.pi + 0.55).clamp(0.0, 1.0)) * 1.20 + 0.18;
      rArmA   = math.sin(runPhase + math.pi) * 0.88 + 1.30;
      lArmA   = math.sin(runPhase) * 0.88 + 1.30;
    } else {
      lThighA = 0.16; lKnee = 0.36;
      if (kick < 0.45) {
        final wp = kick / 0.45;
        rThighA = -1.00 * _easeOut(wp);
        rKnee   = 1.45 * _easeOut(wp);
      } else {
        final sp = (kick - 0.45) / 0.55;
        rThighA = -1.00 + 1.90 * _easeIn(sp);
        rKnee   = 1.45 * (1 - _easeOut(sp));
      }
      final b = _easeOut(kick);
      rArmA = 1.30 - b * 1.55;
      lArmA = 1.30 + b * 1.10;
    }

    final elbowBendRun = 1.12;
    final rElbow = running ? elbowBendRun : 0.68;
    final lElbow = running ? elbowBendRun : 0.62;

    // ── Draw: far-side (darker) objects first ──

    // Far arm (dark)
    _drawArm(canvas, neck + Offset(0, unit * 0.22),
        upperArm, foreArm, rArmA, rElbow,
        _lp(AppTheme.brandDark.withValues(alpha: 0.85), w));

    // Far leg (dark)
    _drawLeg(canvas, pelvis, thigh, shin, rThighA, rKnee,
        _lp(AppTheme.brandDark.withValues(alpha: 0.85), w),
        groundY, planted: false);

    // ── Torso (filled jersey shape) ──
    final torsoW = unit * 0.74;
    final torsoPath = Path()
      ..moveTo(neck.dx - torsoW * 0.4, neck.dy + unit * 0.08)
      ..lineTo(neck.dx + torsoW * 0.9, neck.dy + unit * 0.08)
      ..lineTo(pelvis.dx + torsoW * 1.0, pelvis.dy - unit * 0.05)
      ..lineTo(pelvis.dx - torsoW * 0.35, pelvis.dy - unit * 0.05)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = AppTheme.brand);

    // Shorts (small darker block at waist)
    final shortsPath = Path()
      ..moveTo(pelvis.dx - torsoW * 0.35, pelvis.dy - unit * 0.05)
      ..lineTo(pelvis.dx + torsoW * 1.0, pelvis.dy - unit * 0.05)
      ..lineTo(pelvis.dx + torsoW * 0.9, pelvis.dy + unit * 0.48)
      ..lineTo(pelvis.dx - torsoW * 0.25, pelvis.dy + unit * 0.48)
      ..close();
    canvas.drawPath(
        shortsPath, Paint()..color = const Color(0xFF1A3080));

    // ── Near leg ──
    _drawLeg(canvas, pelvis + Offset(unit * 0.10, 0), thigh, shin,
        lThighA, lKnee, _lp(AppTheme.brand, w), groundY, planted: !running);

    // ── Near arm ──
    _drawArm(canvas, neck + Offset(unit * 0.10, unit * 0.22),
        upperArm, foreArm, lArmA, lElbow, _lp(AppTheme.brand, w));

    // ── Player ground shadow ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px + lean * 0.4, groundY + 4),
        width: unit * 1.9, height: unit * 0.38,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Head ──
    // Neck
    canvas.drawLine(neck, headC + Offset(0, unit * 0.50),
        _lp(const Color(0xFFD4906A), w * 0.75));

    // Head circle (skin)
    canvas.drawCircle(headC, unit * 0.50, Paint()..color = const Color(0xFFE8B080));

    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: headC, radius: unit * 0.50),
      -math.pi * 0.15, -math.pi * 0.70, false,
      Paint()
        ..color = const Color(0xFF2A1400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.35
        ..strokeCap = StrokeCap.round,
    );

    // Eye
    canvas.drawCircle(
      headC + Offset(unit * 0.18, -unit * 0.04),
      unit * 0.065,
      Paint()..color = const Color(0xFF1A0A00),
    );
  }

  Paint _lp(Color c, double wOrStroke) => Paint()
    ..color = c
    ..strokeWidth = wOrStroke * 0.021
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _drawLeg(Canvas canvas, Offset hip, double thigh, double shin,
      double thighA, double kneeBend, Paint paint, double groundY,
      {required bool planted}) {
    final knee = hip + Offset(
        math.sin(thighA) * thigh, math.cos(thighA) * thigh);
    final shinA = thighA - kneeBend;
    var foot = knee + Offset(
        math.sin(shinA) * shin, math.cos(shinA) * shin);
    if (planted) foot = Offset(foot.dx, groundY);

    // Socks (white) over leg
    canvas.drawLine(
      knee + Offset(math.sin(shinA) * shin * 0.1, math.cos(shinA) * shin * 0.1),
      foot,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = paint.strokeWidth * 1.05
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(hip, knee, paint);
    canvas.drawLine(knee,
      knee + Offset(math.sin(shinA) * shin * 0.12, math.cos(shinA) * shin * 0.12),
      paint);

    // Boot
    canvas.drawLine(
      foot, foot + Offset(thigh * 0.32, 0),
      Paint()
        ..color = const Color(0xFF101820)
        ..strokeWidth = paint.strokeWidth * 1.15
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawArm(Canvas canvas, Offset shoulder, double upper, double fore,
      double armA, double elbowBend, Paint paint) {
    final elbow = shoulder + Offset(
        math.sin(armA) * upper, math.cos(armA) * upper);
    final handA = armA + elbowBend;
    final hand = elbow + Offset(
        math.sin(handA) * fore, math.cos(handA) * fore);
    canvas.drawLine(shoulder, elbow, paint);
    canvas.drawLine(elbow, hand, paint);
  }

  // ─── Confetti ─────────────────────────────────────────────────────────────

  void _drawConfetti(Canvas canvas, double w, double h, double t01) {
    final ox = w * 0.82, oy = h * 0.44;
    for (var idx = 0; idx < _conf.length; idx++) {
      final cp = _conf[idx];
      final prog = t01 * cp.speed;
      final x = ox + math.cos(cp.angle) * w * 0.58 * prog;
      final y = oy + math.sin(cp.angle) * h * 0.42 * prog
               + h * 0.10 * prog * prog; // gravity drop
      final rot = cp.rotSpeed * t01;
      final fade = (1 - t01 * 0.72).clamp(0.0, 1.0);
      final sz = w * cp.size;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      if (idx % 3 == 0) {
        // Rectangle ribbon
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 0.40),
          Paint()..color = cp.color.withValues(alpha: fade),
        );
      } else {
        // Diamond
        final path = Path()
          ..moveTo(0, -sz * 0.52)
          ..lineTo(sz * 0.36, 0)
          ..lineTo(0, sz * 0.52)
          ..lineTo(-sz * 0.36, 0)
          ..close();
        canvas.drawPath(path, Paint()..color = cp.color.withValues(alpha: fade));
      }
      canvas.restore();
    }
  }

  // ─── GOAL! burst ──────────────────────────────────────────────────────────

  void _drawGoalBurst(Canvas canvas, double w, double h, double t01) {
    final cx = w * 0.50, cy = h * 0.195;

    // Background glow
    final glowA = (t01 < 0.35
        ? t01 / 0.35
        : 1.0 - (t01 - 0.35) / 0.65)
        .clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(cx, cy), w * 0.42 * _easeOut(t01),
      Paint()
        ..color = AppTheme.brand.withValues(alpha: 0.14 * glowA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // 8 radial lines that rotate slowly
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4 + t01 * 0.55;
      final len = w * 0.28 * _easeOut(t01) * glowA;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(ang) * len, cy + math.sin(ang) * len),
        Paint()
          ..color = AppTheme.brand.withValues(alpha: 0.38 * glowA)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // "GOAL!" text
    final textT = _sat(t01 / 0.28);
    final scale = 0.35 + _bounce(textT) * 0.78;
    final op = textT.clamp(0.0, 1.0);

    final tp = TextPainter(
      text: TextSpan(
        text: 'GOAL!',
        style: TextStyle(
          color: AppTheme.brand.withValues(alpha: op),
          fontSize: w * 0.152,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          shadows: [
            Shadow(
              color: AppTheme.brand.withValues(alpha: 0.85 * op),
              blurRadius: 32,
            ),
            Shadow(
              color: Colors.white.withValues(alpha: 0.25 * op),
              blurRadius: 8,
              offset: const Offset(1.5, 1.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    // 12 star/dot particles orbiting outward
    final rng = math.Random(12);
    for (var i = 0; i < 12; i++) {
      final ang = i * math.pi * 2 / 12 + rng.nextDouble() * 0.25;
      final dist = w * 0.32 * _easeOut(t01);
      final pFade = (1 - t01 * 0.85).clamp(0.0, 1.0);
      final px = cx + math.cos(ang) * dist;
      final py = cy + math.sin(ang) * dist * 0.58;
      if (i % 2 == 0) {
        _drawStar(canvas, Offset(px, py), w * 0.013,
            AppTheme.brand.withValues(alpha: pFade));
      } else {
        canvas.drawCircle(Offset(px, py), w * 0.008,
            Paint()..color = Colors.white.withValues(alpha: pFade * 0.75));
      }
    }
  }

  void _drawStar(Canvas canvas, Offset ctr, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final isOuter = i.isEven;
      final ang = i * math.pi / 5 - math.pi / 2;
      final rad = isOuter ? r : r * 0.44;
      final pt = ctr + Offset(math.cos(ang) * rad, math.sin(ang) * rad);
      if (i == 0) { path.moveTo(pt.dx, pt.dy); } else { path.lineTo(pt.dx, pt.dy); }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // ─── App name ────────────────────────────────────────────────────────────

  void _drawAppName(Canvas canvas, double w, double h, double t01) {
    final op = _easeOut(t01).clamp(0.0, 1.0);
    final rise = (1 - _easeOut(t01)) * 30;

    // Frosted pill behind text
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.845 + rise),
          width: w * 0.80, height: h * 0.145,
        ),
        const Radius.circular(18),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.045 * op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final title = TextPainter(
      text: TextSpan(
        text: 'Football Fan Hub',
        style: TextStyle(
          color: Colors.white.withValues(alpha: op),
          fontSize: w * 0.076,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.22 * op),
              blurRadius: 14,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final sub = TextPainter(
      text: TextSpan(
        text: 'W O R L D  C U P  2 0 2 6',
        style: TextStyle(
          color: AppTheme.brand.withValues(alpha: op),
          fontSize: w * 0.046,
          fontWeight: FontWeight.w700,
          letterSpacing: 3.2,
          shadows: [
            Shadow(
              color: AppTheme.brand.withValues(alpha: 0.55 * op),
              blurRadius: 18,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    title.paint(canvas, Offset(w / 2 - title.width / 2, h * 0.790 + rise));
    sub.paint(canvas, Offset(w / 2 - sub.width / 2, h * 0.876 + rise));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t;

  static double _sat(double v) => v.clamp(0.0, 1.0);
  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  static double _easeIn(double t) => t * t;
  static double _bounce(double t) =>
      t < 0.52 ? _easeOut(t / 0.52) * 1.22 : 1.22 - (t - 0.52) * 0.46;
}
