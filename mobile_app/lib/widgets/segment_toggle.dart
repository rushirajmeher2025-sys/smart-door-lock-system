import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pill-shaped segmented control with a sliding thumb.
class SegmentToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentToggle({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / labels.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: DefaultTextStyle.of(context).style.copyWith(
                                color: i == index ? AppColors.textPrimary : AppColors.textMuted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
