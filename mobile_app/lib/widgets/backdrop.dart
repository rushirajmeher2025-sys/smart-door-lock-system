import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Screen background: a faint dot grid and a soft spotlight from the top
/// that takes on the lock-state colour and breathes very slowly.
class Backdrop extends StatefulWidget {
  final Widget child;
  final Color? tint;

  const Backdrop({super.key, required this.child, this.tint});

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final fallbackTint = isDark ? AppColors.darkTextPrimary : AppColors.brand;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.tint ?? fallbackTint),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, tint, child) => Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: AppColors.backgroundOf(context)),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _BackdropPainter(
                  Curves.easeInOut.transform(_c.value),
                  tint ?? fallbackTint,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final double t;
  final Color tint;
  final bool isDark;

  _BackdropPainter(this.t, this.tint, {required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final focus = Offset(w / 2, size.height * 0.22);
    final reach = max(w, 420.0) * (0.95 + 0.08 * t);

    canvas.drawCircle(
      focus,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: isDark ? (0.11 + 0.03 * t) : (0.06 + 0.02 * t)),
            tint.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: focus, radius: reach)),
    );

    // Dot grid that fades out away from the spotlight
    const gap = 22.0;
    final dot = Paint();
    final baseDotColor = isDark ? Colors.white : Colors.black;
    for (double y = gap / 2; y < size.height * 0.75; y += gap) {
      for (double x = gap / 2; x < w; x += gap) {
        final d = (Offset(x, y) - focus).distance / reach;
        final a = (1 - d).clamp(0.0, 1.0) * (isDark ? 0.07 : 0.04);
        if (a < 0.004) continue;
        dot.color = baseDotColor.withValues(alpha: a);
        canvas.drawCircle(Offset(x, y), 0.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.t != t || old.tint != tint || old.isDark != isDark;
}
