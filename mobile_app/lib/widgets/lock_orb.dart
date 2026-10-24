import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The hero padlock. The shackle springs shut or swings open, the dial scans
/// while a command is in flight, red ripples pulse during an alarm, and
/// bumping [celebrate] plays a single confirmation pulse.
class LockOrb extends StatefulWidget {
  final bool locked;
  final bool pending;
  final bool dim;
  final bool alarm;
  final Color color;
  final double size;
  final int celebrate;

  const LockOrb({
    super.key,
    required this.locked,
    required this.color,
    this.pending = false,
    this.dim = false,
    this.alarm = false,
    this.size = 260,
    this.celebrate = 0,
  });

  @override
  State<LockOrb> createState() => _LockOrbState();
}

class _LockOrbState extends State<LockOrb> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat(reverse: true);
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _applyModes();
  }

  @override
  void didUpdateWidget(LockOrb old) {
    super.didUpdateWidget(old);
    if (old.pending != widget.pending || old.alarm != widget.alarm || old.dim != widget.dim) _applyModes();
    if (old.celebrate != widget.celebrate) _burst.forward(from: 0);
  }

  void _applyModes() {
    if (widget.pending) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
    if (widget.alarm) {
      _ripple.repeat();
    } else {
      _ripple.stop();
      _ripple.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _breath.dispose();
    _ripple.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.dim ? AppColors.offline : widget.color;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.locked ? 1.0 : 0.0),
      duration: Duration(milliseconds: widget.locked ? 900 : 700),
      curve: widget.locked ? Curves.elasticOut : Curves.easeOutBack,
      builder: (context, t, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 600),
        builder: (context, c, _) => RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_spin, _breath, _ripple, _burst]),
            builder: (context, _) => SizedBox.square(
              dimension: widget.size,
              child: CustomPaint(
                painter: _OrbPainter(
                  t: t,
                  color: c ?? color,
                  spin: _spin.value,
                  breath: _breath.value,
                  ripple: widget.alarm ? _ripple.value : null,
                  burst: _burst.isAnimating ? _burst.value : null,
                  pending: widget.pending,
                  dim: widget.dim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t; // 1 = locked, 0 = open (overshoots with the spring)
  final Color color;
  final double spin;
  final double breath;
  final double? ripple;
  final double? burst;
  final bool pending;
  final bool dim;

  _OrbPainter({
    required this.t,
    required this.color,
    required this.spin,
    required this.breath,
    required this.ripple,
    required this.burst,
    required this.pending,
    required this.dim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    final breathe = Curves.easeInOut.transform(breath);

    // Soft state glow
    final glowR = r * (0.92 + 0.04 * breathe);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: dim ? 0.05 : 0.16), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // Alarm ripples
    if (ripple != null) {
      for (var i = 0; i < 3; i++) {
        final p = (ripple! + i / 3) % 1.0;
        canvas.drawCircle(
          c,
          r * (0.64 + 0.36 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppColors.alarm.withValues(alpha: (1 - p) * 0.7),
        );
      }
    }

    // Outer ring: a fine full circle in the state colour
    final ringR = r * 0.94;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: dim ? 0.15 : 0.35),
    );

    // While a command is in flight, a comet runs around the ring
    final angle = spin * 2 * pi - pi / 2;
    if (pending) {
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [color.withValues(alpha: 0), color],
            stops: const [0.65, 1.0],
            transform: GradientRotation(angle),
          ).createShader(Rect.fromCircle(center: c, radius: ringR)),
      );
      canvas.drawCircle(c + Offset(cos(angle), sin(angle)) * ringR, 3, Paint()..color = Colors.white);
    }

    // Dial ticks; they light up behind the comet while pending
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      final a = i / ticks * 2 * pi - pi / 2;
      var lit = 0.0;
      if (pending) {
        var d = (angle - a) % (2 * pi);
        if (d < 0) d += 2 * pi;
        lit = max(0.0, 1 - d / 1.6);
      }
      final major = i % 5 == 0;
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(
        c + dir * r * (major ? 0.78 : 0.80),
        c + dir * r * 0.84,
        Paint()
          ..strokeWidth = major ? 1.6 : 1
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(Colors.white.withValues(alpha: major ? 0.16 : 0.08), color, lit)!,
      );
    }

    // Inner disc: matte, with a hairline and a faint top highlight
    final discR = r * 0.70;
    final disc = Rect.fromCircle(center: c, radius: discR);
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1E), Color(0xFF0E0E11)],
        ).createShader(disc),
    );
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.03)],
        ).createShader(disc),
    );

    _paintPadlock(canvas, c.translate(0, r * 0.07), r);

    // Confirmation pulse
    if (burst != null) {
      final b = Curves.easeOutCubic.transform(burst!);
      canvas.drawCircle(
        c,
        r * (0.70 + 0.30 * b),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - b) + 0.5
          ..color = color.withValues(alpha: (1 - b) * 0.9),
      );
    }
  }

  void _paintPadlock(Canvas canvas, Offset c, double r) {
    final bodyW = r * 0.56;
    final bodyH = r * 0.44;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c.translate(0, r * 0.08), width: bodyW, height: bodyH),
      Radius.circular(r * 0.1),
    );
    final bodyTop = body.top;

    // Shackle: lifts, then tilts open around its left leg
    final open = (1 - t);
    final lift = open.clamp(-0.2, 1.0) * r * 0.13;
    final tilt = open.clamp(0.0, 1.0) * -0.42;
    final legX = r * 0.17;
    final legTop = bodyTop - r * 0.16;
    final shackle = Path()
      ..moveTo(c.dx - legX, bodyTop + r * 0.04)
      ..lineTo(c.dx - legX, legTop)
      ..arcToPoint(Offset(c.dx + legX, legTop), radius: Radius.circular(legX))
      ..lineTo(c.dx + legX, bodyTop + r * 0.04);

    canvas.save();
    final pivot = Offset(c.dx - legX, bodyTop);
    canvas.translate(0, -lift);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(tilt);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [const Color(0xFFF4F4F5), const Color(0xFF9A9AA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(c.dx - legX, legTop - legX, legX * 2, r * 0.4)),
    );
    canvas.restore();

    // Body with a soft colour glow
    canvas.drawRRect(
      body.shift(Offset(0, r * 0.03)),
      Paint()
        ..color = color.withValues(alpha: dim ? 0.06 : 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.18)!, Color.lerp(color, Colors.black, 0.12)!],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // Keyhole
    final k = body.center.translate(0, -r * 0.03);
    final hole = Paint()..color = AppColors.background.withValues(alpha: 0.85);
    canvas.drawCircle(k, r * 0.045, hole);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: k.translate(0, r * 0.06), width: r * 0.035, height: r * 0.1),
        Radius.circular(r * 0.02),
      ),
      hole,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter o) =>
      o.t != t ||
      o.color != color ||
      o.spin != spin ||
      o.breath != breath ||
      o.ripple != ripple ||
      o.burst != burst ||
      o.pending != pending ||
      o.dim != dim;
}
