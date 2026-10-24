import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Card surface used across LocKify: solid, hairline border, optional
/// coloured edge glow for state (alarm, success).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final Color? borderColor;
  final Color? color;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.glow,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.hairline),
        boxShadow: [
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.16), blurRadius: 28, spreadRadius: -4),
        ],
      ),
      child: child,
    );
  }
}

/// Fades and lifts its child into place, [delay] after first build.
/// Used to stagger cards and list rows as a screen appears.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;

  const Reveal({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Small rounded label, e.g. "Online" or "Owner".
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;

  const Pill({super.key, required this.label, required this.color, this.icon, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ] else ...[
            PulseDot(color: color, active: pulse),
            const SizedBox(width: 7),
          ],
          Text(label, style: AppTheme.mono(fontSize: 11.5, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// A status dot that breathes while [active].
class PulseDot extends StatefulWidget {
  final Color color;
  final bool active;
  final double size;

  const PulseDot({super.key, required this.color, this.active = true, this.size = 7});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.active)
              Transform.scale(
                scale: 1 + _c.value * 1.8,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1 - _c.value) * 0.5),
                  ),
                ),
              ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}
