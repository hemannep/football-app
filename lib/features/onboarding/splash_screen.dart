// lib/features/onboarding/splash_screen.dart

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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020805),
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _SplashPainter(_controller.value),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  final double t;

  const _SplashPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final short = math.min(w, h);
    final long = math.max(w, h);
    final intro = _easeOut(_sat(t / 0.22));
    final reveal = _easeOut(_sat((t - 0.16) / 0.44));
    final titleIn = _easeOutBack(_sat((t - 0.54) / 0.24));
    final pulse = math.sin(t * math.pi * 8);

    _drawSky(canvas, size, intro);
    _drawStadium(canvas, w, h, intro);
    _drawLightBeams(canvas, w, h, intro);
    _drawPitch(canvas, w, h, reveal);
    _drawEnergyRings(canvas, w, h, short, reveal, pulse);
    _drawCrest(canvas, w, h, short, reveal, pulse);
    _drawFlyingBall(canvas, w, h, short);
    _drawTitle(canvas, w, h, short, long, titleIn);
    _drawProgress(canvas, w, h, reveal);
  }

  void _drawSky(Canvas canvas, Size size, double a) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF020805),
            Color(0xFF061811),
            Color(0xFF0B2817),
            Color(0xFF06100B),
          ],
          stops: [0.0, 0.36, 0.72, 1.0],
        ).createShader(rect),
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.38),
      size.shortestSide * (0.48 + 0.05 * a),
      Paint()
        ..color = AppTheme.brand.withValues(alpha: 0.15 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 56),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.10),
          radius: 1.16,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.60),
          ],
        ).createShader(rect),
    );
  }

  void _drawStadium(Canvas canvas, double w, double h, double a) {
    final crowdTop = h * 0.15;
    final crowdBottom = h * 0.41;
    final bowl = Path()
      ..moveTo(-w * 0.18, crowdTop)
      ..quadraticBezierTo(w * 0.5, crowdBottom, w * 1.18, crowdTop)
      ..lineTo(w * 1.18, crowdBottom + h * 0.04)
      ..quadraticBezierTo(
          w * 0.5, crowdBottom + h * 0.12, -w * 0.18, crowdBottom + h * 0.04)
      ..close();

    canvas.drawPath(
      bowl,
      Paint()..color = const Color(0xFF05110B).withValues(alpha: 0.78 * a),
    );

    final seatPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var row = 0; row < 7; row++) {
      final y = crowdTop + row * h * 0.033;
      for (var i = 0; i < 34; i++) {
        final x = w * (i / 33);
        final wave = math.sin(i * 0.9 + row * 1.7) * h * 0.008;
        final color = i % 5 == 0
            ? AppTheme.accent
            : i % 4 == 0
                ? AppTheme.live
                : i % 3 == 0
                    ? const Color(0xFF44B9FF)
                    : Colors.white;
        seatPaint.color = color.withValues(alpha: 0.18 * a);
        canvas.drawCircle(Offset(x, y + wave), 1.8 + row * 0.12, seatPaint);
      }
    }

    final rail = Paint()
      ..color = Colors.white.withValues(alpha: 0.10 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 4; i++) {
      final y = crowdBottom - h * (0.025 + i * 0.037);
      canvas.drawArc(
        Rect.fromLTWH(-w * 0.12, y - h * 0.12, w * 1.24, h * 0.23),
        math.pi * 0.08,
        math.pi * 0.84,
        false,
        rail,
      );
    }
  }

  void _drawLightBeams(Canvas canvas, double w, double h, double a) {
    for (final side in [-1, 1]) {
      final origin = Offset(side < 0 ? w * 0.10 : w * 0.90, h * 0.02);
      final beam = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(w * 0.5 + side * w * 0.18, h * 0.73)
        ..lineTo(w * 0.5 + side * w * 0.53, h * 0.77)
        ..close();

      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.20 * a),
              AppTheme.brand.withValues(alpha: 0.05 * a),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          origin + Offset(side * i * 7, i.isEven ? 0 : 5),
          3.4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  void _drawPitch(Canvas canvas, double w, double h, double a) {
    final top = h * 0.55;
    final pitch = Path()
      ..moveTo(w * 0.06, top)
      ..lineTo(w * 0.94, top)
      ..lineTo(w * 1.18, h)
      ..lineTo(-w * 0.18, h)
      ..close();

    canvas.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF164C27), Color(0xFF0D351C), Color(0xFF092311)],
        ).createShader(Rect.fromLTWH(0, top, w, h - top)),
    );

    for (var i = 0; i < 9; i++) {
      final bandTop = top + (h - top) * i / 9;
      final band = Path()
        ..moveTo(w * (0.06 - i * 0.025), bandTop)
        ..lineTo(w * (0.94 + i * 0.025), bandTop)
        ..lineTo(w * (0.97 + i * 0.035), bandTop + (h - top) / 9 + 2)
        ..lineTo(w * (0.03 - i * 0.035), bandTop + (h - top) / 9 + 2)
        ..close();
      canvas.drawPath(
        band,
        Paint()
          ..color = (i.isEven ? Colors.white : Colors.black)
              .withValues(alpha: i.isEven ? 0.035 * a : 0.055 * a),
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.24 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerY = h * 0.79;
    canvas.drawLine(Offset(w * 0.5, top), Offset(w * 0.5, h), line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, centerY),
        width: w * 0.48,
        height: h * 0.13,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(w * 0.5, centerY),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.36 * a),
    );

    for (var i = 0; i < 6; i++) {
      final x1 = w * (0.10 + i * 0.11);
      final x2 = w * (0.90 - i * 0.11);
      canvas.drawLine(
        Offset(x1, h),
        Offset(w * 0.5, top),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055 * a)
          ..strokeWidth = 0.9,
      );
      canvas.drawLine(
        Offset(x2, h),
        Offset(w * 0.5, top),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.055 * a)
          ..strokeWidth = 0.9,
      );
    }
  }

  void _drawEnergyRings(
    Canvas canvas,
    double w,
    double h,
    double short,
    double a,
    double pulse,
  ) {
    final center = Offset(w * 0.5, h * 0.43);
    for (var i = 0; i < 4; i++) {
      final p = _sat((t + i * 0.18) % 1.0);
      final r = short * (0.16 + p * 0.34);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = (i.isEven ? AppTheme.brand : const Color(0xFF35B8FF))
              .withValues(alpha: 0.20 * (1 - p) * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - p,
      );
    }

    canvas.drawCircle(
      center,
      short * (0.21 + pulse.abs() * 0.012),
      Paint()
        ..color = AppTheme.brand.withValues(alpha: 0.22 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
  }

  void _drawCrest(
    Canvas canvas,
    double w,
    double h,
    double short,
    double a,
    double pulse,
  ) {
    final center = Offset(w * 0.5, h * 0.43);
    final radius = short * (0.19 + pulse * 0.004);

    canvas.drawCircle(
      center + Offset(0, short * 0.018),
      radius * 1.06,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.36 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08150F), Color(0xFF0F3520), Color(0xFF08120C)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      center,
      radius * 0.80,
      Paint()
        ..color = AppTheme.brand.withValues(alpha: 0.38 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    _drawTrophy(canvas, center, radius, a);
    _drawMiniBall(canvas, center + Offset(radius * 0.62, -radius * 0.54),
        radius * 0.19, t * math.pi * 7, a);
    _drawMiniBall(canvas, center + Offset(-radius * 0.72, radius * 0.42),
        radius * 0.12, -t * math.pi * 5, a * 0.7);
  }

  void _drawTrophy(Canvas canvas, Offset c, double r, double a) {
    final gold = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFE082).withValues(alpha: a),
          AppTheme.accent.withValues(alpha: a),
          const Color(0xFFFFF3C2).withValues(alpha: a),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.72));

    final cup = Path()
      ..moveTo(c.dx - r * 0.30, c.dy - r * 0.38)
      ..quadraticBezierTo(
          c.dx - r * 0.25, c.dy + r * 0.05, c.dx, c.dy + r * 0.12)
      ..quadraticBezierTo(
          c.dx + r * 0.25, c.dy + r * 0.05, c.dx + r * 0.30, c.dy - r * 0.38)
      ..close();
    canvas.drawPath(cup, gold);

    final handle = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.80 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(-r * 0.33, -r * 0.18),
        width: r * 0.34,
        height: r * 0.36,
      ),
      math.pi * 0.62,
      math.pi * 0.86,
      false,
      handle,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: c + Offset(r * 0.33, -r * 0.18),
        width: r * 0.34,
        height: r * 0.36,
      ),
      math.pi * 1.52,
      math.pi * 0.86,
      false,
      handle,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, r * 0.42),
          width: r * 0.52,
          height: r * 0.15,
        ),
        Radius.circular(r * 0.04),
      ),
      gold,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: c + Offset(0, r * 0.25),
        width: r * 0.17,
        height: r * 0.36,
      ),
      gold,
    );
    canvas.drawCircle(
      c + Offset(-r * 0.10, -r * 0.16),
      r * 0.055,
      Paint()..color = Colors.white.withValues(alpha: 0.62 * a),
    );
  }

  void _drawFlyingBall(Canvas canvas, double w, double h, double short) {
    final p = _easeInOut(_sat((t - 0.16) / 0.54));
    if (p <= 0 || p >= 1) return;

    final start = Offset(w * 0.12, h * 0.66);
    final end = Offset(w * 0.86, h * 0.31);
    final lift = math.sin(p * math.pi) * h * 0.24;
    final pos = Offset(
      start.dx + (end.dx - start.dx) * p,
      start.dy + (end.dy - start.dy) * p - lift,
    );
    final r = short * (0.030 + 0.018 * math.sin(p * math.pi));

    for (var i = 6; i >= 1; i--) {
      final tp = _sat(p - i * 0.030);
      final trailPos = Offset(
        start.dx + (end.dx - start.dx) * tp,
        start.dy + (end.dy - start.dy) * tp - math.sin(tp * math.pi) * h * 0.24,
      );
      canvas.drawCircle(
        trailPos,
        r * (0.34 + i * 0.08),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.045 * (7 - i))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    _drawMiniBall(canvas, pos, r, p * math.pi * 10, 1);
  }

  void _drawMiniBall(Canvas canvas, Offset c, double r, double rot, double a) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.42),
          colors: [
            Colors.white.withValues(alpha: a),
            const Color(0xFFD8DEE5).withValues(alpha: a),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );

    final panel = Paint()..color = const Color(0xFF0B1218).withValues(alpha: a);
    _drawPentagon(canvas, Offset.zero, r * 0.28, panel);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      _drawPentagon(
        canvas,
        Offset(math.cos(angle) * r * 0.60, math.sin(angle) * r * 0.60),
        r * 0.17,
        panel,
      );
    }
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _drawPentagon(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTitle(
    Canvas canvas,
    double w,
    double h,
    double short,
    double long,
    double a,
  ) {
    final y = h * 0.69 + (1 - a) * short * 0.08;

    final title = TextPainter(
      text: TextSpan(
        text: 'Football Fan Hub',
        style: TextStyle(
          color: Colors.white.withValues(alpha: a.clamp(0, 1)),
          fontSize: (short * 0.086).clamp(29.0, 42.0),
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          height: 0.96,
          shadows: [
            Shadow(
              color: AppTheme.brand.withValues(alpha: 0.50 * a),
              blurRadius: 26,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.88);

    final sub = TextPainter(
      text: TextSpan(
        text: 'WORLD CUP 2026',
        style: TextStyle(
          color: AppTheme.accent.withValues(alpha: a.clamp(0, 1)),
          fontSize: (short * 0.036).clamp(13.0, 17.0),
          fontWeight: FontWeight.w800,
          letterSpacing: 2.1,
          shadows: [
            Shadow(
              color: AppTheme.accent.withValues(alpha: 0.45 * a),
              blurRadius: 18,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.86);

    final badge = TextPainter(
      text: TextSpan(
        text: 'LIVE FIXTURES  |  TRIVIA  |  PREDICTIONS',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62 * a),
          fontSize: (short * 0.025).clamp(10.0, 12.0),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.90);

    title.paint(canvas, Offset((w - title.width) / 2, y));
    sub.paint(canvas, Offset((w - sub.width) / 2, y + title.height + 12));
    badge.paint(
      canvas,
      Offset((w - badge.width) / 2, y + title.height + sub.height + 28),
    );

    canvas.drawLine(
      Offset(w * 0.20, y - short * 0.035),
      Offset(w * 0.80, y - short * 0.035),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppTheme.brand.withValues(alpha: 0.70 * a),
            const Color(0xFF35B8FF).withValues(alpha: 0.70 * a),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w * 0.20, 0, w * 0.60, long))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawProgress(Canvas canvas, double w, double h, double a) {
    final width = w * 0.42;
    final left = (w - width) / 2;
    final top = h * 0.92;
    final progress = _easeOut(_sat((t - 0.08) / 0.82));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, 3.5),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.13 * a),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width * progress, 3.5),
        const Radius.circular(8),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.brand.withValues(alpha: a),
            AppTheme.accent.withValues(alpha: a),
          ],
        ).createShader(Rect.fromLTWH(left, top, width, 4)),
    );
  }

  @override
  bool shouldRepaint(_SplashPainter oldDelegate) => oldDelegate.t != t;

  static double _sat(double value) => value.clamp(0.0, 1.0);

  static double _easeOut(double value) {
    final t = _sat(value);
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  static double _easeInOut(double value) {
    final t = _sat(value);
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  static double _easeOutBack(double value) {
    final t = _sat(value);
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }
}
