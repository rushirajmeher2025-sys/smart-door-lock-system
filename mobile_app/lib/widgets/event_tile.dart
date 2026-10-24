import 'package:flutter/material.dart';
import '../models/security_event.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
    final alert = event.isWarningOrAlarm;
    final color = alert ? event.color : AppColors.textSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: alert ? color.withValues(alpha: 0.10) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: alert ? color.withValues(alpha: 0.30) : AppColors.hairline),
                  ),
                  child: Icon(event.icon, color: color, size: 17),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 18 : 0, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: event.severity == EventSeverity.alarm ? AppColors.alarm : AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(trailing, style: AppTheme.mono(fontSize: 11.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detailed ? event.description : event.method,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                  ),
                  if (detailed) ...[
                    const SizedBox(height: 6),
                    Text(event.method.toUpperCase(), style: AppTheme.label()),
                    if (event.gsmAlertSent == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sms_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('SMS handed to the modem', style: AppTheme.mono(fontSize: 11.5)),
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
