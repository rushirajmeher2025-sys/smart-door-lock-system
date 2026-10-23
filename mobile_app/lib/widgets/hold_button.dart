import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class HoldButton extends StatefulWidget {
  final String label;
  final String activeLabel;
  final IconData icon;
  final Color color;
  final bool enabled;
  final Duration duration;
  final VoidCallback onConfirmed;

  const HoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirmed,
    this.activeLabel = 'Keep holding',
    this.enabled = true,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        widget.onConfirmed();
        _c.value = 0;
      }
    });
  }

  @override
  void didUpdateWidget(HoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _c.duration = widget.duration;
    if (!widget.enabled && _c.value > 0) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _c.forward();
  }

  void _up() {
    if (_c.status != AnimationStatus.completed) _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? widget.onConfirmed : null,
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final holding = enabled && _c.value > 0;
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: enabled ? widget.color.withValues(alpha: 0.12) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: enabled ? widget.color.withValues(alpha: 0.6) : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: enabled ? _c.value : 0,
                            heightFactor: 1,
                            child: ColoredBox(color: widget.color.withValues(alpha: 0.45)),
                          ),
                        ),
                      ),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (enabled) ...[
                              Icon(widget.icon, size: 20, color: AppColors.textPrimary),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              holding ? widget.activeLabel : widget.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
