import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Slide-to-act control. A deliberate gesture so a stray tap in a pocket can
/// never unlock the door. Springs back if released before the end.
class SwipeToConfirm extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onConfirmed;

  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirmed,
    this.enabled = true,
  });

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> with TickerProviderStateMixin {
  static const double _height = 64;
  static const double _pad = 5;

  late final AnimationController _pos = AnimationController(vsync: this, lowerBound: 0, upperBound: 1);
  late final AnimationController _sheen =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  double _travel = 1;
  bool _fired = false;

  @override
  void didUpdateWidget(SwipeToConfirm old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _pos.value > 0) _springBack();
    if (old.label != widget.label) _fired = false;
  }

  @override
  void dispose() {
    _pos.dispose();
    _sheen.dispose();
    super.dispose();
  }

  void _springBack() {
    _pos.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 420, damping: 26),
      _pos.value,
      0,
      0,
    ));
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled || _fired) return;
    _pos.value = (_pos.value + d.delta.dx / _travel).clamp(0.0, 1.0);
  }

  void _onEnd(DragEndDetails d) {
    if (!widget.enabled || _fired) return;
    final fling = d.primaryVelocity != null && d.primaryVelocity! > 900 && _pos.value > 0.5;
    if (_pos.value > 0.88 || fling) {
      _confirm();
    } else {
      _springBack();
    }
  }

  Future<void> _confirm() async {
    _fired = true;
    HapticFeedback.mediumImpact();
    await _pos.animateTo(1, duration: const Duration(milliseconds: 140), curve: Curves.easeOut);
    widget.onConfirmed();
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _springBack();
    _fired = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final color = enabled ? widget.color : AppColors.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onConfirmed : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            const knob = _height - _pad * 2;
            _travel = (box.maxWidth - knob - _pad * 2).clamp(1, double.infinity);
            return AnimatedBuilder(
              animation: Listenable.merge([_pos, _sheen]),
              builder: (context, _) {
                final p = _pos.value;
                return Container(
                  height: _height,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(_height / 2),
                    border: Border.all(color: enabled ? color.withValues(alpha: 0.28) : AppColors.hairline),
                  ),
                  child: Stack(
                    children: [
                      // Fill that follows the knob
                      Positioned(
                        left: _pad,
                        top: _pad,
                        bottom: _pad,
                        width: knob + _travel * p,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(knob / 2),
                            color: color.withValues(alpha: 0.10 + 0.14 * p),
                          ),
                        ),
                      ),
                      // Label with a passing sheen; fades as you slide
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(left: knob + 12, right: 18),
                          child: Center(
                            child: Opacity(
                              opacity: (1 - p * 1.6).clamp(0.0, 1.0),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (rect) => LinearGradient(
                                  colors: enabled
                                      ? [AppColors.textSecondary, Colors.white, AppColors.textSecondary]
                                      : [AppColors.textMuted, AppColors.textMuted, AppColors.textMuted],
                                  stops: const [0.35, 0.5, 0.65],
                                  begin: Alignment(-2.2 + 4.4 * _sheen.value, 0),
                                  end: Alignment(-1.2 + 4.4 * _sheen.value, 0),
                                ).createShader(rect),
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Knob
                      Positioned(
                        left: _pad + _travel * p,
                        top: _pad,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: _onUpdate,
                          onHorizontalDragEnd: _onEnd,
                          child: Container(
                            width: knob,
                            height: knob,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: enabled ? color : AppColors.surfaceLight,
                              boxShadow: [
                                if (enabled) BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2),
                              ],
                            ),
                            child: Icon(
                              p > 0.88 ? Icons.check_rounded : widget.icon,
                              color: enabled ? AppColors.background : AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
