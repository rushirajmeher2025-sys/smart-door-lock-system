import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum EventSeverity {
  normal,
  warning,
  alarm,
}

enum LockStatus {
  locked,
  unlocked,
  unknown,
}

class SecurityEvent {
  final String id;
  final String title;
  final String description;
  final String method; // 'Keypad PIN', 'Mobile App', 'Auto-Lock', 'Inside Button', 'Door Sensor'
  final DateTime timestamp;
  final EventSeverity severity;
  final IconData icon;

  const SecurityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.method,
    required this.timestamp,
    required this.severity,
    required this.icon,
  });

  Color get color {
    switch (severity) {
      case EventSeverity.alarm:
        return AppColors.alarm;
      case EventSeverity.warning:
        return AppColors.warning;
      case EventSeverity.normal:
        return AppColors.unlocked;
    }
  }

  bool get isWarningOrAlarm => severity == EventSeverity.warning || severity == EventSeverity.alarm;
}
