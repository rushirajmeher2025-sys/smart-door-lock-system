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
  final bool? gsmAlertSent;

  const SecurityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.method,
    required this.timestamp,
    required this.severity,
    required this.icon,
    this.gsmAlertSent,
  });

  Color get color {
    switch (severity) {
      case EventSeverity.alarm:
        return AppColors.alarm;
      case EventSeverity.warning:
        return AppColors.warning;
      case EventSeverity.normal:
        return AppColors.textSecondary;
    }
  }

  bool get isWarningOrAlarm => severity == EventSeverity.warning || severity == EventSeverity.alarm;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'method': method,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'severity': severity.name,
      'gsmAlertSent': gsmAlertSent,
    };
  }

  factory SecurityEvent.fromJson(Map<dynamic, dynamic> json, {String? fallbackId}) {
    final severityStr = (json['severity'] as String?)?.toLowerCase();
    EventSeverity severity;
    IconData icon;

    if (severityStr == 'alarm') {
      severity = EventSeverity.alarm;
      icon = Icons.crisis_alert_rounded;
    } else if (severityStr == 'warning') {
      severity = EventSeverity.warning;
      icon = Icons.warning_amber_rounded;
    } else {
      severity = EventSeverity.normal;
      icon = Icons.lock_outline_rounded;
    }

    return SecurityEvent(
      id: (json['id'] as String?) ?? fallbackId ?? '',
      title: (json['title'] as String?) ?? 'Security Event',
      description: (json['description'] as String?) ?? '',
      method: (json['method'] as String?) ?? 'system',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      severity: severity,
      icon: icon,
      gsmAlertSent: json['gsmAlertSent'] as bool?,
    );
  }
}
