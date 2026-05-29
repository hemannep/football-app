// lib/features/onboarding/splash_screen.dart
//
// Animated splash with an ARTICULATED stick figure (real jointed limbs).
//
// Timeline (≈3.4s total):
//   0.00–0.12  pitch + goal fade in
//   0.12–0.42  run-up: figure runs in from the left, full leg/arm run cycle
//   0.42–0.55  plant + wind-up: kicking leg cocks back, arms counter-balance
//   0.55–0.68  strike: leg snaps through, ball launches
//   0.55–0.86  ball flies in an arc, spinning, then squashes into the net
//   0.68–0.90  net ripples, "GOAL!" pops with a bounce
//   0.80–1.00  app name + "2026" rise into place
//
// Pure Flutter Canvas — no images, no packages beyond flutter + dart:math.
// The figure is drawn from a small skeleton: hip, knee, foot / shoulder,
// elbow, hand. Each joint angle is animated, so the motion reads as real
// running and kicking rather than a sliding sprite.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
      duration: const Duration(milliseconds: 3400),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 250), () {
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
      backgroundColor: AppTheme.bg,
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
  _SplashPainter(this.t);

  // Phase boundaries (normalized).
  static const _pitchEnd = 0.12;
  static const _runStart = 0.12;
  static const _runEnd = 0.42;
  static const _strike = 0.55; // contact moment
  static const _kickEnd = 0.68; // leg follow-through done
  static const _ballEnd = 0.86; // ball reaches net
  static const _goalEnd = 0.90;
  static const _nameStart = 0.80;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pitch = _c01(t / _pitchEnd);

    _drawPitch(canvas, w, h, pitch);
    final goalRect = Rect.fromLTWH(w * 0.72, h * 0.30, w * 0.20, h * 0.30);
    _drawGoal(canvas, goalRect, pitch);

    // Ball
    final groundY = h * 0.66;
    final ballR = w * 0.035;
    final ballPos = _ballPos(w, h, groundY, goalRect);
    final squash = _ballSquash();

    // Net ripple after contact
    if (t >= _ballEnd - 0.02) {
      _drawNetRipple(canvas, goalRect,
          _c01((t - (_ballEnd - 0.02)) / (_goalEnd - (_ballEnd - 0.02))));
    }

    _drawBall(canvas, ballPos, ballR, _ballRot(), squash, groundY);

    // Figure (hidden once the kick is fully done and ball is mid-flight)
    if (t < _kickEnd + 0.06) {
      _drawFigure(canvas, w, h, groundY);
    }

    // GOAL! + name
    if (t >= _strike) {
      _drawGoalText(canvas, w, h, _c01((t - _strike) / (_goalEnd - _strike)));
    }
    if (t >= _nameStart) {
      _drawName(canvas, w, h, _c01((t - _nameStart) / (1.0 - _nameStart)));
    }
  }

  // ─── Pitch ───────────────────────────────────────────────────────────────
  void _drawPitch(Canvas canvas, double w, double h, double a) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF123A22), Color(0xFF071A0E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // Mowed stripes
    final stripe = Paint()..color = const Color(0x10FFFFFF);
    const n = 7;
    for (var i = 0; i < n; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(0, h * i / n, w, h / n), stripe);
      }
    }
    // Halfway arc near the figure's start
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.10 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, h * 0.66), Offset(w, h * 0.66), line);
  }

  // ─── Goal ──────────────────────────────────────────────────────────────────
  void _drawGoal(Canvas canvas, Rect g, double a) {
    final frame = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Perspective: top narrower than bottom
    final topL = Offset(g.left + g.width * 0.10, g.top);
    final topR = Offset(g.right - g.width * 0.02, g.top);
    final botL = g.bottomLeft;
    final botR = g.bottomRight;
    canvas.drawLine(topL, topR, frame);
    canvas.drawLine(topL, botL, frame);
    canvas.drawLine(topR, botR, frame);

    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var i = 1; i < 9; i++) {
      final x = g.left + g.width * i / 9;
      canvas.drawLine(Offset(x, g.top + 2), Offset(x, g.bottom), net);
    }
    for (var i = 1; i < 7; i++) {
      final y = g.top + g.height * i / 7;
      canvas.drawLine(Offset(g.left, y), Offset(g.right, y), net);
    }
  }

  void _drawNetRipple(Canvas canvas, Rect g, double t01) {
    final impact = Offset(g.center.dx, g.center.dy);
    final fade = (1 - t01).clamp(0.0, 1.0);
    canvas.drawCircle(
        impact,
        g.width * 0.5 * _easeOut(t01),
        Paint()
          ..color = AppTheme.brand.withValues(alpha: 0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(impact, g.width * 0.28 * _easeOut(t01),
        Paint()..color = AppTheme.brand.withValues(alpha: 0.18 * fade));
  }

  // ─── Ball ────────────────────────────────────────────────────────────────
  Offset _ballPos(double w, double h, double groundY, Rect goal) {
    final startX = w * 0.30; // at the figure's kicking foot
    if (t < _strike) return Offset(startX, groundY - 2);
    if (t > _ballEnd) {
      return Offset(goal.center.dx, goal.center.dy);
    }
    final p = (t - _strike) / (_ballEnd - _strike);
    final endX = goal.center.dx, endY = goal.center.dy;
    final x = startX + (endX - startX) * p;
    final arc = -math.sin(p * math.pi) * h * 0.16;
    final y = (groundY - 2) + ((endY - (groundY - 2)) * p) + arc;
    return Offset(x, y);
  }

  double _ballRot() {
    if (t < _strike) return 0;
    final p = ((t - _strike) / (_ballEnd - _strike)).clamp(0.0, 1.0);
    return p * math.pi * 9;
  }

  // Returns (sx, sy) scale for squash on impact with the net.
  Offset _ballSquash() {
    if (t < _ballEnd - 0.03 || t > _ballEnd + 0.05) return const Offset(1, 1);
    final p = ((t - (_ballEnd - 0.03)) / 0.08).clamp(0.0, 1.0);
    final s = math.sin(p * math.pi); // 0→1→0
    return Offset(1 - 0.35 * s, 1 + 0.35 * s);
  }

  void _drawBall(Canvas canvas, Offset c, double r, double rot, Offset squash,
      double groundY) {
    // Ground shadow before launch
    if (t < _strike) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx, groundY + r * 0.6),
            width: r * 1.8,
            height: r * 0.5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(squash.dx, squash.dy);
    canvas.rotate(rot);
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    final pent = Paint()..color = const Color(0xFF12161C);
    canvas.drawCircle(Offset.zero, r * 0.24, pent);
    for (var i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(
          Offset(math.cos(ang) * r * 0.5, math.sin(ang) * r * 0.5),
          r * 0.13,
          pent);
    }
    canvas.restore();
  }

  // ─── Articulated stick figure ──────────────────────────────────────────────
  //
  // We build a skeleton each frame: pelvis at (px, py). From it we compute
  // hip→knee→foot for both legs and shoulder→elbow→hand for both arms, plus a
  // head. Joint angles are driven by the current phase so the figure runs,
  // plants, winds up and kicks with a follow-through.
  void _drawFigure(Canvas canvas, double w, double h, double groundY) {
    // Horizontal travel: runs in from the left to the plant spot.
    final plantX = w * 0.255;
    double px;
    if (t < _runStart) {
      px = -w * 0.1;
    } else if (t < _runEnd) {
      px = (-w * 0.1) +
          (plantX - (-w * 0.1)) *
              _easeOut(_c01((t - _runStart) / (_runEnd - _runStart)));
    } else {
      px = plantX;
    }

    // Vertical bob during the run.
    final unit = w * 0.052; // limb segment length unit
    double bob = 0;
    if (t >= _runStart && t < _runEnd) {
      final rp = (t - _runStart) / (_runEnd - _runStart);
      bob = -(math.sin(rp * math.pi * 8).abs()) * unit * 0.18;
    }
    final pelvis = Offset(px, groundY - unit * 2.1 + bob);

    // Run cycle phase (for limbs) — only while running.
    final running = t >= _runStart && t < _runEnd;
    final runPhase =
        running ? (t - _runStart) / (_runEnd - _runStart) * 8 : 0.0;

    // Kick progression 0..1 across wind-up→follow-through.
    double kick = 0;
    if (t >= _runEnd && t <= _kickEnd) {
      kick = (t - _runEnd) / (_kickEnd - _runEnd);
    } else if (t > _kickEnd) {
      kick = 1;
    }

    final stroke = Paint()
      ..color = AppTheme.brand
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dark = Paint()
      ..color = AppTheme.brandDark
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // ── Torso + head ──
    final neck = pelvis + Offset(unit * 0.15, -unit * 1.5);
    // Lean forward during run/kick
    final lean = running ? unit * 0.25 : unit * 0.4;
    final neckLeaned = Offset(neck.dx + lean, neck.dy);
    canvas.drawLine(pelvis, neckLeaned, stroke);
    final headC = neckLeaned + Offset(unit * 0.12, -unit * 0.62);
    canvas.drawCircle(headC, unit * 0.5, Paint()..color = AppTheme.brand);

    // ── Legs ──
    // Right (far) leg drawn first (darker), then left (near) leg.
    // Each leg: hip → knee → foot using two segments.
    final hip = pelvis;
    final thigh = unit * 1.05, shin = unit * 1.05;

    // Run cycle angles
    double rThighA, rKneeBend, lThighA, lKneeBend;
    if (running) {
      rThighA = math.sin(runPhase) * 0.7; // swing
      lThighA = math.sin(runPhase + math.pi) * 0.7;
      rKneeBend = (math.sin(runPhase + 0.6).clamp(0.0, 1.0)) * 1.1 + 0.2;
      lKneeBend =
          (math.sin(runPhase + math.pi + 0.6).clamp(0.0, 1.0)) * 1.1 + 0.2;
    } else {
      // Plant + kick. Support (left/near) leg stays planted, slightly bent.
      lThighA = 0.15;
      lKneeBend = 0.35;
      // Kicking (right/far) leg: cocks back then snaps forward.
      // kick 0→0.45 = wind back (negative), 0.45→1 = swing through (positive)
      if (kick < 0.45) {
        final wp = kick / 0.45;
        rThighA = -0.9 * _easeOut(wp);
        rKneeBend = 1.3 * _easeOut(wp); // heel to butt
      } else {
        final sp = (kick - 0.45) / 0.55;
        rThighA = -0.9 + (1.7 * _easeIn(sp)); // sweep forward past vertical
        rKneeBend = 1.3 * (1 - _easeOut(sp)); // extend straight on contact
      }
    }

    // Draw far leg (right) darker for depth
    _drawLeg(canvas, hip, thigh, shin, rThighA, rKneeBend, dark, groundY,
        planted: false);
    // Draw near leg (left) — planted during kick
    _drawLeg(canvas, hip + Offset(unit * 0.12, 0), thigh, shin, lThighA,
        lKneeBend, stroke, groundY,
        planted: !running);

    // ── Arms ── (counter-swing to legs / balance during kick)
    final shoulder = neckLeaned + Offset(0, unit * 0.18);
    final upper = unit * 0.8, fore = unit * 0.75;
    double rArmA, rElbow, lArmA, lElbow;
    if (running) {
      rArmA = math.sin(runPhase + math.pi) * 0.8 + 1.2;
      lArmA = math.sin(runPhase) * 0.8 + 1.2;
      rElbow = 1.1;
      lElbow = 1.1;
    } else {
      // Arms fling out for balance on the kick.
      final b = _easeOut(kick);
      rArmA = 1.2 - b * 1.4; // forward arm rises
      lArmA = 1.2 + b * 1.0; // back arm extends
      rElbow = 0.7;
      lElbow = 0.6;
    }
    _drawArm(canvas, shoulder, upper, fore, rArmA, rElbow, dark);
    _drawArm(canvas, shoulder + Offset(unit * 0.1, 0), upper, fore, lArmA,
        lElbow, stroke);
  }

  // Leg: hip → knee → foot. thighA is the thigh angle from vertical (rad),
  // kneeBend is how much the shin folds back behind the thigh.
  void _drawLeg(Canvas canvas, Offset hip, double thigh, double shin,
      double thighA, double kneeBend, Paint paint, double groundY,
      {required bool planted}) {
    // Thigh points down + forward by thighA.
    final knee =
        hip + Offset(math.sin(thighA) * thigh, math.cos(thighA) * thigh);
    // Shin continues, folded by kneeBend.
    final shinA = thighA - kneeBend; // bend backwards
    var foot = knee + Offset(math.sin(shinA) * shin, math.cos(shinA) * shin);
    // Keep planted foot on the ground line.
    if (planted) foot = Offset(foot.dx, groundY);
    canvas.drawLine(hip, knee, paint);
    canvas.drawLine(knee, foot, paint);
    // Foot (short forward stub)
    canvas.drawLine(foot, foot + Offset(thigh * 0.28, 0), paint);
  }

  void _drawArm(Canvas canvas, Offset shoulder, double upper, double fore,
      double armA, double elbowBend, Paint paint) {
    final elbow =
        shoulder + Offset(math.sin(armA) * upper, math.cos(armA) * upper);
    final handA = armA + elbowBend;
    final hand = elbow + Offset(math.sin(handA) * fore, math.cos(handA) * fore);
    canvas.drawLine(shoulder, elbow, paint);
    canvas.drawLine(elbow, hand, paint);
  }

  // ─── Text ──────────────────────────────────────────────────────────────────
  void _drawGoalText(Canvas canvas, double w, double h, double t01) {
    final scale = 0.5 + _bounce(t01) * 0.7;
    final op = t01.clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'GOAL!',
        style: TextStyle(
          color: AppTheme.brand.withValues(alpha: op),
          fontSize: w * 0.14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
                color: AppTheme.brand.withValues(alpha: 0.6 * op),
                blurRadius: 24),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(w * 0.5, h * 0.2);
    canvas.scale(scale, scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _drawName(Canvas canvas, double w, double h, double t01) {
    final op = t01.clamp(0.0, 1.0);
    final rise = (1 - _easeOut(t01)) * 24;
    final title = TextPainter(
      text: TextSpan(
        text: 'Football Fan Hub',
        style: TextStyle(
            color: Colors.white.withValues(alpha: op),
            fontSize: w * 0.072,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final sub = TextPainter(
      text: TextSpan(
        text: '2026',
        style: TextStyle(
            color: AppTheme.brand.withValues(alpha: op),
            fontSize: w * 0.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(w / 2 - title.width / 2, h * 0.80 + rise));
    sub.paint(canvas, Offset(w / 2 - sub.width / 2, h * 0.88 + rise));
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t;

  // ─── easing ──────────────────────────────────────────────────────────────
  static double _c01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  static double _easeIn(double t) => t * t;
  static double _bounce(double t) =>
      t < 0.5 ? _easeOut(t * 2) * 1.15 : 1.15 - (t - 0.5) * 0.3;
}
