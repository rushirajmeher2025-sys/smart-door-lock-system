import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  static const _items = [
    (Icons.lock_outline_rounded, Icons.lock_rounded, 'Door'),
    (Icons.history_rounded, Icons.history_rounded, 'Activity'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  void _select(int i) {
    if (i == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToHistory: () => _select(1)),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Center(
          heightFactor: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 300,
                height: 60,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth / _items.length;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutBack,
                          left: w * _currentIndex,
                          top: 0,
                          bottom: 0,
                          width: w,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: i == _currentIndex,
                                  label: _items[i].$3,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _select(i),
                                    child: _NavItem(
                                      icon: i == _currentIndex ? _items[i].$2 : _items[i].$1,
                                      label: _items[i].$3,
                                      active: i == _currentIndex,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textMuted;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 250),
            child: Icon(icon, size: 19, color: color),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: active
                ? Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(
                      label,
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.1),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
