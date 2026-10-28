import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/access_request.dart';
import '../repositories/lock_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/in_app_notification_banner.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'lock_selection_screen.dart';
import 'members_screen.dart';
import 'settings_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final LockRepository _repository = lockRepository();
  int _currentIndex = 0;
  VoidCallback? _accessListener;
  StreamSubscription<List<AccessRequest>>? _requestsSub;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.attachLockRepository(_repository);
    _pendingCount = _repository.currentPendingRequests.length;
    _requestsSub = _repository.pendingRequestsStream.listen((reqs) {
      if (mounted) setState(() => _pendingCount = reqs.length);
    });

    _accessListener = () {
      if (!mounted) return;
      final access = _repository.access.value;
      if (access.status == AccessStatus.denied) {
        final lockName = _repository.activeDeviceName;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LockSelectionScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.alarm,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.block_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Access to "$lockName" has been revoked by the owner.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    };
    _repository.access.addListener(_accessListener!);
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    if (_accessListener != null) {
      _repository.access.removeListener(_accessListener!);
    }
    super.dispose();
  }

  void _select(int i) {
    if (i == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LockAccess>(
      valueListenable: _repository.access,
      builder: (context, access, _) {
        final isOwner = access.isOwner;

        // Dynamic tabs and screens based on role portal
        final List<(IconData, IconData, String, int)> items;
        final List<Widget> screens;

        if (isOwner) {
          items = [
            (Icons.lock_outline_rounded, Icons.lock_rounded, 'Door', 0),
            (Icons.group_outlined, Icons.group_rounded, 'Members', _pendingCount),
            (Icons.history_rounded, Icons.history_rounded, 'Activity', 0),
            (Icons.tune_outlined, Icons.tune_rounded, 'Settings', 0),
          ];
          screens = [
            DashboardScreen(
              onNavigateToHistory: () => _select(2),
              onNavigateToMembers: () => _select(1),
            ),
            const MembersScreen(),
            const HistoryScreen(),
            const SettingsScreen(),
          ];
        } else {
          items = [
            (Icons.lock_outline_rounded, Icons.lock_rounded, 'Door', 0),
            (Icons.history_rounded, Icons.history_rounded, 'Activity', 0),
            (Icons.tune_outlined, Icons.tune_rounded, 'Settings', 0),
          ];
          screens = [
            DashboardScreen(onNavigateToHistory: () => _select(1)),
            const HistoryScreen(),
            const SettingsScreen(),
          ];
        }

        // Clamp index if switching between roles
        final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

        return InAppNotificationBanner(
          onNotificationTap: () => _select(isOwner ? 2 : 1),
          child: Scaffold(
            backgroundColor: AppColors.background,
            extendBody: true,
            body: IndexedStack(index: safeIndex, children: screens),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: Center(
                heightFactor: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: isOwner ? 350 : 300,
                      height: 60,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final w = box.maxWidth / items.length;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutBack,
                                left: w * safeIndex,
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
                                  for (var i = 0; i < items.length; i++)
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        selected: i == safeIndex,
                                        label: items[i].$3,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _select(i),
                                          child: _NavItem(
                                            icon: i == safeIndex ? items[i].$2 : items[i].$1,
                                            label: items[i].$3,
                                            active: i == safeIndex,
                                            badgeCount: items[i].$4,
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
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.textPrimary : AppColors.textMuted;
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
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
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          label,
                          style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (badgeCount > 0)
            Positioned(
              top: 4,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.alarm,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }
}
