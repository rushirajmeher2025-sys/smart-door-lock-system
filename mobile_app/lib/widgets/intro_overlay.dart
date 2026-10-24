import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

/// Launch sequence played over the app while it boots underneath:
/// a ring draws itself, the shackle drops and clicks shut (green flash),
/// the wordmark rises in letter by letter, then everything dissolves into
/// the app. Tap anywhere to skip.
class IntroOverlay extends StatefulWidget {
  final Widget child;

  const IntroOverlay({super.key, required this.child});

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2900);

  late final AnimationController _c = AnimationController(vsync: this, duration: _total);
  bool _done = false;
  bool _clicked = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_clicked && _c.value >= 0.42) {
        _clicked = true;
        HapticFeedback.lightImpact();
      }
    });
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    if (_c.value < 0.82) _c.animateTo(1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  // Maps the controller onto a sub-interval with a curve.
  double _seg(double from, double to, [Curve curve = Curves.easeOutCubic]) {
    final v = ((_c.value - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final exit = _seg(0.82, 1.0, Curves.easeInCubic);
              return Opacity(
                opacity: 1 - exit,
                child: Transform.scale(
                  scale: 1 + 0.06 * exit,
                  // Material gives the text a proper style (no debug underlines above the navigator)
                  child: Material(
                    color: AppColors.background,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 148,
                            child: CustomPaint(
                              painter: _IntroLockPainter(
                                ring: _seg(0.0, 0.34, Curves.easeInOutCubic),
                                body: _seg(0.10, 0.30, Curves.easeOutBack),
                                drop: _seg(0.26, 0.46, Curves.bounceOut),
                                flash: _c.value < 0.42 ? 0 : 1 - _seg(0.42, 0.70),
                                settle: _seg(0.42, 0.60),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          _Wordmark(progress: _seg(0.44, 0.74, Curves.linear), kGlow: _seg(0.66, 0.80)),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _seg(0.62, 0.80),
                            child: Transform.translate(
                              offset: Offset(0, 6 * (1 - _seg(0.62, 0.80))),
                              child: Text(AppConstants.appTagline, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  final double progress;
  final double kGlow;

  const _Wordmark({required this.progress, required this.kGlow});

  @override
  Widget build(BuildContext context) {
    const letters = ['L', 'o', 'c', 'K', 'i', 'f', 'y'];
    final base = AppTheme.display(fontSize: 38, fontWeight: FontWeight.w600, letterSpacing: -1.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          Builder(builder: (context) {
            // Each letter gets its own slice of the reveal
            final start = i / letters.length * 0.6;
            final t = Curves.easeOutCubic.transform(((progress - start) / 0.4).clamp(0.0, 1.0));
            final isK = letters[i] == 'K';
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - t)),
                child: Text(
                  letters[i],
                  style: isK
                      ? base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Color.lerp(AppColors.textPrimary, AppColors.brand, kGlow),
                          shadows: [Shadow(color: AppColors.brand.withValues(alpha: 0.6 * kGlow), blurRadius: 18)],
                        )
                      : base,
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _IntroLockPainter extends CustomPainter {
  final double ring;
  final double body;
  final double drop;
  final double flash;
  final double settle;

  _IntroLockPainter({
    required this.ring,
    required this.body,
    required this.drop,
    required this.flash,
    required this.settle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final green = AppColors.brand;

    // Glow that blooms on the click
    if (flash > 0) {
      canvas.drawCircle(
        c,
        r * 1.6,
        Paint()
          ..shader = RadialGradient(colors: [green.withValues(alpha: 0.35 * flash), green.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
      );
    }

    // Ring draws itself, then turns green on the click
    final ringColor = Color.lerp(Colors.white.withValues(alpha: 0.5), green, settle)!;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 2),
      -pi / 2,
      2 * pi * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + flash * 1.5
        ..strokeCap = StrokeCap.round
        ..color = ringColor,
    );
    if (ring > 0 && ring < 1) {
      final a = -pi / 2 + 2 * pi * ring;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * (r - 2), 3, Paint()..color = Colors.white);
    }

    if (body <= 0) return;

    // Padlock body scales in
    final s = r * 0.9;
    final bodyRect = Rect.fromCenter(center: c.translate(0, s * 0.18), width: s * 0.78 * body, height: s * 0.6 * body);
    final rr = RRect.fromRectAndRadius(bodyRect, Radius.circular(s * 0.14 * body));

    // Shackle drops from above and lands in the body
    final legX = s * 0.24;
    final bodyTop = c.dy + s * 0.18 - s * 0.3;
    final lift = (1 - drop) * s * 0.55;
    final legTop = bodyTop - s * 0.22 - lift;
    final shackle = Path()
      ..moveTo(c.dx - legX, bodyTop + s * 0.06 - lift)
      ..lineTo(c.dx - legX, legTop)
      ..arcToPoint(Offset(c.dx + legX, legTop), radius: Radius.circular(legX))
      ..lineTo(c.dx + legX, bodyTop + s * 0.06 - lift);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.1
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(const Color(0xFF8D8D96), const Color(0xFFF4F4F5), drop)!.withValues(alpha: drop.clamp(0.0, 1.0)),
    );

    final bodyColor = Color.lerp(const Color(0xFF2A2A30), green, settle)!;
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(bodyColor, Colors.white, 0.15)!, bodyColor],
        ).createShader(bodyRect),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.2),
    );

    // Keyhole
    final k = bodyRect.center.translate(0, -s * 0.04);
    final hole = Paint()..color = AppColors.background.withValues(alpha: 0.85 * body);
    canvas.drawCircle(k, s * 0.06 * body, hole);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: k.translate(0, s * 0.08), width: s * 0.045 * body, height: s * 0.13 * body),
        Radius.circular(s * 0.02),
      ),
      hole,
    );
  }

  @override
  bool shouldRepaint(covariant _IntroLockPainter o) =>
      o.ring != ring || o.body != body || o.drop != drop || o.flash != flash || o.settle != settle;
}
