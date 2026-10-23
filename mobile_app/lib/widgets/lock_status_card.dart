import 'package:flutter/material.dart';
import '../models/lock_state.dart';
import '../models/security_event.dart';
import '../theme/app_colors.dart';
import 'status_badge.dart';

class LockStatusCard extends StatelessWidget {
  final DoorLockState lockState;

  const LockStatusCard({
    super.key,
    required this.lockState,
  });

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final status = lockState.lockStatus;
    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    switch (status) {
      case LockStatus.locked:
        statusColor = AppColors.locked;
        statusTitle = 'LOCKED';
        statusIcon = Icons.lock_rounded;
        break;
      case LockStatus.unlocked:
        statusColor = AppColors.unlocked;
        statusTitle = 'UNLOCKED';
        statusIcon = Icons.lock_open_rounded;
        break;
      case LockStatus.unknown:
        statusColor = AppColors.warning;
        statusTitle = 'UNKNOWN';
        statusIcon = Icons.help_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Badges Row: Online Status & Door Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(
                label: lockState.isOnline ? 'ESP32 Online' : 'ESP32 Offline',
                icon: lockState.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: lockState.isOnline ? AppColors.unlocked : AppColors.alarm,
              ),
              StatusBadge(
                label: lockState.doorClosed ? 'Door Closed' : 'Door Ajar',
                icon: lockState.doorClosed ? Icons.door_front_door_rounded : Icons.meeting_room_outlined,
                color: lockState.doorClosed ? AppColors.primaryLight : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Central Icon with Pending State or Status Icon
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.12),
              border: Border.all(color: statusColor, width: 2.5),
            ),
            child: Center(
              child: lockState.isActionPending
                  ? const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      statusIcon,
                      size: 60,
                      color: statusColor,
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Status Heading
          Text(
            lockState.isActionPending ? 'TRANSMITTING...' : statusTitle,
            style: TextStyle(
              color: lockState.isActionPending ? AppColors.accent : statusColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle / Pending message / Last sync info
          Text(
            lockState.isActionPending
                ? (lockState.pendingActionMessage ?? 'Awaiting hardware confirmation...')
                : 'Last update: ${_formatTime(lockState.lastUpdated)} via ${lockState.lastMethod}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: lockState.isActionPending ? AppColors.accent : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Burglar Warning Banner (if triggered)
          if (lockState.burglarAlarmActive) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alarm.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alarm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, color: AppColors.alarm, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ALARM ACTIVE: Unauthorized door opening while locked!',
                      style: TextStyle(color: AppColors.alarm, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
