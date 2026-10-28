import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class InAppNotificationBanner extends StatefulWidget {
  final Widget child;
  final VoidCallback? onNotificationTap;

  const InAppNotificationBanner({
    super.key,
    required this.child,
    this.onNotificationTap,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  StreamSubscription<SecurityEvent>? _subscription;
  SecurityEvent? _currentEvent;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _subscription = NotificationService.instance.inAppEventStream.listen(_showBanner);
  }

  void _showBanner(SecurityEvent event) {
    if (!mounted) return;

    _dismissTimer?.cancel();
    setState(() {
      _currentEvent = event;
    });

    _animController.forward(from: 0.0);

    // Auto dismiss after 4 seconds
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentEvent = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentEvent != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Dismissible(
                      key: ValueKey(_currentEvent!.id + DateTime.now().millisecondsSinceEpoch.toString()),
                      direction: DismissDirection.up,
                      onDismissed: (_) => _dismiss(),
                      child: GestureDetector(
                        onTap: () {
                          _dismiss();
                          widget.onNotificationTap?.call();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _currentEvent!.color.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _currentEvent!.color.withValues(alpha: 0.2),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _currentEvent!.color.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _currentEvent!.color.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Icon(
                                      _currentEvent!.icon,
                                      color: _currentEvent!.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _currentEvent!.title,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              'Just now',
                                              style: AppTheme.mono(
                                                fontSize: 10.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _currentEvent!.description.isNotEmpty
                                              ? _currentEvent!.description
                                              : 'Method: ${_currentEvent!.method}',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _dismiss,
                                    tooltip: 'Dismiss',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
