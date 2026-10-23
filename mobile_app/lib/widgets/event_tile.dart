import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../theme/app_colors.dart';

class EventTile extends StatelessWidget {
  final SecurityEvent event;
  final String trailing;
  final bool showLine;
  final bool detailed;

  const EventTile({
    super.key,
    required this.event,
    required this.trailing,
    this.showLine = true,
    this.detailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    final alert = event.isWarningOrAlarm;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: alert ? 0.16 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, color: color, size: 18),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            event.title,
                            style: TextStyle(
                              color: alert ? color : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          trailing,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailed ? event.description : event.method,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (detailed) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.method,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    if (event.gsmAlertSent == true) ...[
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sms_outlined, size: 14, color: AppColors.primaryLight),
                          SizedBox(width: 6),
                          Text(
                            'SMS alert sent',
                            style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
