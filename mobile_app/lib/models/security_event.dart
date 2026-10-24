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
  final String type; // firmware event name, e.g. 'unlock', 'burglar_alarm'
  final String title;
  final String description;
  final String method; // 'Keypad PIN', 'Mobile App', 'Auto-Lock', 'Inside Button', 'Door Sensor'
  final DateTime timestamp;
  final EventSeverity severity;
  final IconData icon;
  final bool? gsmAlertSent;

  const SecurityEvent({
    required this.id,
    this.type = '',
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
      'type': type,
      'title': title,
      'description': description,
      'method': method,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'severity': severity.name,
      'gsmAlertSent': gsmAlertSent,
    };
  }

  /// Icon for a firmware event type, falling back to one per severity.
  static IconData iconFor(String type, EventSeverity severity) {
    switch (type) {
      case 'unlock':
        return Icons.lock_open_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'failed_attempt':
        return Icons.pin_outlined;
      case 'lockout':
        return Icons.lock_clock_rounded;
      case 'door_opened':
      case 'door_closed':
        return Icons.door_front_door_outlined;
      case 'burglar_alarm':
        return Icons.crisis_alert_rounded;
      case 'alarm_cleared':
        return Icons.notifications_off_outlined;
      case 'door_warning':
        return Icons.sensor_door_outlined;
      case 'pin_changed':
        return Icons.password_rounded;
      case 'lock_online':
      case 'lock_reconnected':
        return Icons.wifi_rounded;
    }
    if (type.startsWith('rej_')) return Icons.block_rounded;
    switch (severity) {
      case EventSeverity.alarm:
        return Icons.crisis_alert_rounded;
      case EventSeverity.warning:
        return Icons.warning_amber_rounded;
      case EventSeverity.normal:
        return Icons.lock_outline_rounded;
    }
  }

  factory SecurityEvent.fromJson(Map<dynamic, dynamic> json, {String? fallbackId}) {
    final severityStr = (json['severity'] as String?)?.toLowerCase();
    final EventSeverity severity;
    if (severityStr == 'alarm') {
      severity = EventSeverity.alarm;
    } else if (severityStr == 'warning') {
      severity = EventSeverity.warning;
    } else {
      severity = EventSeverity.normal;
    }
    final type = json['type'] is String ? json['type'] as String : '';
    final ts = json['timestamp'];

    return SecurityEvent(
      id: (json['id'] as String?) ?? fallbackId ?? '',
      type: type,
      title: (json['title'] as String?) ?? 'Security Event',
      description: (json['description'] as String?) ?? '',
      method: (json['method'] as String?) ?? 'system',
      timestamp: ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt()) : DateTime.now(),
      severity: severity,
      icon: iconFor(type, severity),
      gsmAlertSent: json['gsmAlertSent'] as bool?,
    );
  }
}
