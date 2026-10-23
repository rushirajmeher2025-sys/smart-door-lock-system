import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Modal dialog providing safety confirmation before issuing remote commands.
class LockConfirmationDialog extends StatelessWidget {
  final bool isLockingAction;
  final bool isDoorClosed;
  final VoidCallback onConfirm;

  const LockConfirmationDialog({
    super.key,
    required this.isLockingAction,
    required this.isDoorClosed,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required bool isLockingAction,
    required bool isDoorClosed,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => LockConfirmationDialog(
        isLockingAction: isLockingAction,
        isDoorClosed: isDoorClosed,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: Cannot lock if door is open
    final isBlockedByDoor = isLockingAction && !isDoorClosed;
    final actionColor = isBlockedByDoor
        ? AppColors.warning
        : (isLockingAction ? AppColors.locked : AppColors.unlocked);

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: actionColor.withValues(alpha: 0.5), width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBlockedByDoor
                  ? Icons.warning_rounded
                  : (isLockingAction ? Icons.lock_outline_rounded : Icons.lock_open_rounded),
              color: actionColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isBlockedByDoor
                  ? 'Cannot Lock Door'
                  : (isLockingAction ? 'Confirm Lock Command' : 'Confirm Remote Unlock'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBlockedByDoor) ...[
            const Text(
              'The door sensor indicates the door is currently OPEN. The deadbolt servo cannot be locked until the door is physically closed.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.door_front_door_outlined, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text('Safety Rule: Firmware blocks open locking', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                ],
              ),
            ),
          ] else ...[
            Text(
              isLockingAction
                  ? 'Are you sure you want to engage the deadbolt remotely?'
                  : 'Are you sure you want to remotely UNLOCK the door? Anyone with physical access will be able to enter.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Notice: Commands require online ESP32 confirmation before status updates.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        if (!isBlockedByDoor)
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isLockingAction ? 'Lock Now' : 'Unlock Now'),
          ),
      ],
    );
  }
}
