import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// LocKify logo: a keyhole on a hardware-style tile with a status LED.
class LockifyLogo extends StatefulWidget {
  final double size;
  final bool live;

  const LockifyLogo({super.key, this.size = 36, this.live = true});

  @override
  State<LockifyLogo> createState() => _LockifyLogoState();
}

class _LockifyLogoState extends State<LockifyLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.live) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(_c.value),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double t;

  _LogoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(s * 0.26));

    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232327), Color(0xFF111114)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.04)],
        ).createShader(rect),
    );

    // Keyhole
    final ink = Paint()..color = AppColors.textPrimary;
    final c = Offset(s * 0.5, s * 0.44);
    canvas.drawCircle(c, s * 0.12, ink);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.055, c.dy + s * 0.05)
        ..lineTo(c.dx + s * 0.055, c.dy + s * 0.05)
        ..lineTo(c.dx + s * 0.085, s * 0.74)
        ..lineTo(c.dx - s * 0.085, s * 0.74)
        ..close(),
      ink,
    );

    // Status LED: a short double blink, like real hardware
    final blink = (t < 0.06 || (t > 0.12 && t < 0.18)) ? 1.0 : 0.35;
    final led = Offset(s * 0.79, s * 0.21);
    canvas.drawCircle(
      led,
      s * 0.14,
      Paint()
        ..shader = RadialGradient(colors: [AppColors.brand.withValues(alpha: 0.5 * blink), AppColors.brand.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: led, radius: s * 0.14)),
    );
    canvas.drawCircle(led, s * 0.045, Paint()..color = Color.lerp(const Color(0xFF1E5E44), AppColors.brand, blink)!);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.t != t;
}

/// "LocKify" wordmark; the K carries the brand colour.
class LockifyWordmark extends StatelessWidget {
  final double fontSize;

  const LockifyWordmark({super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.display(fontSize: fontSize, fontWeight: FontWeight.w600, letterSpacing: -fontSize * 0.04);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Loc'),
          TextSpan(text: 'K', style: style.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
          const TextSpan(text: 'ify'),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LockifyLogo(size: size),
        SizedBox(width: size * 0.36),
        LockifyWordmark(fontSize: size * 0.6),
      ],
    );
  }
}
