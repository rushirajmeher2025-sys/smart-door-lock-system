import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_state.dart';
import '../models/security_event.dart';
import '../repositories/mock_lock_repository.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/lock_status_card.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;

  const DashboardScreen({
    super.key,
    this.onNavigateToHistory,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = MockLockRepository.instance;
  late DoorLockState _lockState;
  late List<SecurityEvent> _recentEvents;
  StreamSubscription<DoorLockState>? _stateSub;
  StreamSubscription<List<SecurityEvent>>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _lockState = _repository.currentState;
    _recentEvents = _repository.currentEvents.take(3).toList();

    _stateSub = _repository.stateStream.listen((state) {
      if (mounted) setState(() => _lockState = state);
    });

    _eventsSub = _repository.eventsStream.listen((events) {
      if (mounted) setState(() => _recentEvents = events.take(3).toList());
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _handleLockAction() async {
    if (_lockState.isActionPending) return;

    // Safety confirmation dialog
    final confirmed = await LockConfirmationDialog.show(
      context,
      isLockingAction: true,
      isDoorClosed: _lockState.doorClosed,
    );

    if (confirmed != true) return;

    final success = await _repository.sendLockCommand();
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lock failed: Door must be closed first!'),
          backgroundColor: AppColors.alarm,
        ),
      );
    }
  }

  Future<void> _handleUnlockAction() async {
    if (_lockState.isActionPending) return;

    // Safety confirmation dialog
    final confirmed = await LockConfirmationDialog.show(
      context,
      isLockingAction: false,
      isDoorClosed: _lockState.doorClosed,
    );

    if (confirmed != true) return;

    await _repository.sendUnlockCommand();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        actions: [
          // Simulated connection toggle icon
          IconButton(
            tooltip: _lockState.isOnline ? 'Simulate Disconnect' : 'Simulate Connect',
            icon: Icon(
              _lockState.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: _lockState.isOnline ? AppColors.unlocked : AppColors.alarm,
            ),
            onPressed: () {
              _repository.toggleConnection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_lockState.isOnline ? 'ESP32 connected' : 'ESP32 disconnected (Offline simulation)'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          // Simulated Door Sensor toggle icon
          IconButton(
            tooltip: _lockState.doorClosed ? 'Simulate Door Opened' : 'Simulate Door Closed',
            icon: Icon(
              _lockState.doorClosed ? Icons.door_front_door_rounded : Icons.meeting_room_outlined,
              color: _lockState.doorClosed ? AppColors.primaryLight : AppColors.warning,
            ),
            onPressed: () {
              _repository.toggleDoorSensor();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Lock Status Card
              LockStatusCard(lockState: _lockState),
              const SizedBox(height: 24),

              // Action Controls (Large Dual Buttons)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_lockState.isActionPending || !_lockState.isOnline)
                          ? null
                          : _handleUnlockAction,
                      icon: const Icon(Icons.lock_open_rounded, size: 22),
                      label: const Text('UNLOCK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.unlocked,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_lockState.isActionPending || !_lockState.isOnline)
                          ? null
                          : _handleLockAction,
                      icon: const Icon(Icons.lock_rounded, size: 22),
                      label: const Text('LOCK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.locked,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Hardware Quick Telemetry Grid
              Row(
                children: [
                  Expanded(
                    child: _buildTelemetryTile(
                      title: 'Door Status',
                      value: _lockState.doorClosed ? 'Closed' : 'OPEN / AJAR',
                      icon: Icons.sensor_door_outlined,
                      color: _lockState.doorClosed ? AppColors.primaryLight : AppColors.warning,
                      actionLabel: 'Toggle',
                      onAction: () => _repository.toggleDoorSensor(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTelemetryTile(
                      title: 'Connection',
                      value: _lockState.isOnline ? 'Online (WiFi)' : 'Offline',
                      icon: Icons.router_outlined,
                      color: _lockState.isOnline ? AppColors.unlocked : AppColors.alarm,
                      actionLabel: 'Toggle',
                      onAction: () => _repository.toggleConnection(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Events Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToHistory ??
                        () => Navigator.of(context).pushNamed(AppConstants.routeHistory),
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Events List Preview
              if (_recentEvents.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No recent security events recorded.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentEvents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = _recentEvents[index];
                    return _buildEventItem(event);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(SecurityEvent event) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: event.isWarningOrAlarm ? event.color.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(event.icon, color: event.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  event.method,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatEventTime(event.timestamp),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatEventTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
