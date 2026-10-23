import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BoltDial extends StatefulWidget {
  final bool locked;
  final bool pending;
  final bool dim;
  final Color color;
  final double size;

  const BoltDial({
    super.key,
    required this.locked,
    required this.color,
    this.pending = false,
    this.dim = false,
    this.size = 240,
  });

  @override
  State<BoltDial> createState() => _BoltDialState();
}

class _BoltDialState extends State<BoltDial> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.pending) _spin.repeat();
  }

  @override
  void didUpdateWidget(BoltDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pending && !_spin.isAnimating) _spin.repeat();
    if (!widget.pending && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.locked ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: widget.color),
          duration: const Duration(milliseconds: 400),
          builder: (context, color, _) {
            return AnimatedBuilder(
              animation: _spin,
              builder: (context, _) {
                return SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _BoltPainter(
                      t: t,
                      color: color ?? widget.color,
                      spin: widget.pending ? _spin.value : null,
                      dim: widget.dim,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BoltPainter extends CustomPainter {
  final double t;
  final Color color;
  final double? spin;
  final bool dim;

  _BoltPainter({
    required this.t,
    required this.color,
    required this.spin,
    required this.dim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final col = dim ? AppColors.textMuted : color;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [col.withValues(alpha: 0.22), col.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final plate = r * 0.8;
    canvas.drawCircle(c, plate, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      c,
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = col.withValues(alpha: 0.55),
    );

    if (spin != null) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: plate),
        spin! * 2 * pi - pi / 2,
        pi / 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = col,
      );
    }

    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx + r * 0.46, c.dy), width: r * 0.14, height: r * 0.7),
      Radius.circular(r * 0.04),
    );
    canvas.drawRRect(frame, Paint()..color = AppColors.surfaceLight);
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.border,
    );

    final left = c.dx - r * 0.4;
    final right = c.dx + r * (0.08 + 0.42 * t);
    final bolt = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, c.dy - r * 0.09, right, c.dy + r * 0.09),
      Radius.circular(r * 0.05),
    );
    canvas.drawRRect(bolt, Paint()..color = col);

    final knob = Offset(left, c.dy);
    canvas.drawCircle(knob, r * 0.17, Paint()..color = AppColors.surfaceLight);
    canvas.drawCircle(
      knob,
      r * 0.17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = col.withValues(alpha: 0.85),
    );
    final a = t * pi / 2;
    final v = Offset(cos(a), sin(a)) * (r * 0.11);
    canvas.drawLine(
      knob - v,
      knob + v,
      Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = col,
    );
  }

  @override
  bool shouldRepaint(covariant _BoltPainter old) {
    return old.t != t || old.color != color || old.spin != spin || old.dim != dim;
  }
}
