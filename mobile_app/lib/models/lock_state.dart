import 'security_event.dart';

/// Data model representing the physical lock state from the ESP32 / Firebase.
class DoorLockState {
  final LockStatus lockStatus;
  final bool doorClosed;
  final bool isOnline;
  final bool burglarAlarmActive;
  final bool isLockout;
  final String lastMethod; // 'keypad', 'button', 'app', 'auto', 'sensor'
  final DateTime lastUpdated;
  final DateTime? lastHeartbeat;
  final String? firmwareVersion;

  /// False until the lock has written its first status report.
  final bool hasReport;

  /// Set when the app can't read the lock at all (no access, database error).
  final String? syncIssue;

  final bool isActionPending;
  final String? pendingActionMessage;
  final String? lastProcessedCommandId;

  const DoorLockState({
    required this.lockStatus,
    required this.doorClosed,
    required this.isOnline,
    required this.burglarAlarmActive,
    required this.isLockout,
    required this.lastMethod,
    required this.lastUpdated,
    this.lastHeartbeat,
    this.firmwareVersion,
    this.hasReport = true,
    this.syncIssue,
    this.isActionPending = false,
    this.pendingActionMessage,
    this.lastProcessedCommandId,
  });

  bool get isLocked => lockStatus == LockStatus.locked;
  bool get isUnlocked => lockStatus == LockStatus.unlocked;
  bool get isUnknown => lockStatus == LockStatus.unknown;

  /// The app only trusts the reported state while the lock is checking in.
  bool get isConfirmed => hasReport && isOnline && syncIssue == null;

  /// Friendly label for what last moved the bolt.
  String get lastMethodLabel {
    switch (lastMethod) {
      case 'keypad':
        return 'Keypad';
      case 'button':
        return 'Inside button';
      case 'app':
        return 'App';
      case 'auto':
        return 'Auto-lock';
      case 'sensor':
        return 'Door sensor';
      default:
        return lastMethod;
    }
  }

  /// Default initial mock state for UI development
  factory DoorLockState.initial() {
    return DoorLockState(
      lockStatus: LockStatus.locked,
      doorClosed: true,
      isOnline: true,
      burglarAlarmActive: false,
      isLockout: false,
      lastMethod: 'keypad',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 3)),
      lastHeartbeat: DateTime.now(),
      firmwareVersion: '3.0',
      isActionPending: false,
    );
  }

  /// State before the lock has reported anything.
  factory DoorLockState.waiting({String? syncIssue}) {
    return DoorLockState(
      lockStatus: LockStatus.unknown,
      doorClosed: true,
      isOnline: false,
      burglarAlarmActive: false,
      isLockout: false,
      lastMethod: '',
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
      hasReport: false,
      syncIssue: syncIssue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLocked': isLocked,
      'doorClosed': doorClosed,
      'isOnline': isOnline,
      'burglarAlarmActive': burglarAlarmActive,
      'isLockout': isLockout,
      'lastMethod': lastMethod,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'lastHeartbeat': lastHeartbeat?.millisecondsSinceEpoch,
      'lastProcessedCommandId': lastProcessedCommandId,
    };
  }

  /// Parses `/devices/{id}/status`. Malformed fields fall back to "unknown"
  /// rather than guessing, so a bad report never shows the door as locked.
  factory DoorLockState.fromJson(Map<dynamic, dynamic> json) {
    final locked = json['isLocked'];
    LockStatus status;
    if (locked == true) {
      status = LockStatus.locked;
    } else if (locked == false) {
      status = LockStatus.unlocked;
    } else {
      status = LockStatus.unknown;
    }

    DateTime? time(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    final heartbeat = time(json['lastHeartbeat']);

    return DoorLockState(
      lockStatus: status,
      doorClosed: json['doorClosed'] is bool ? json['doorClosed'] as bool : true,
      isOnline: json['isOnline'] == true,
      burglarAlarmActive: json['burglarAlarmActive'] == true,
      isLockout: json['isLockout'] == true,
      lastMethod: json['lastMethod'] is String ? json['lastMethod'] as String : 'sensor',
      lastUpdated: time(json['lastUpdated']) ?? heartbeat ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastHeartbeat: heartbeat,
      firmwareVersion: json['firmwareVersion'] is String ? json['firmwareVersion'] as String : null,
      lastProcessedCommandId: json['lastProcessedCommandId'] as String?,
    );
  }

  DoorLockState copyWith({
    LockStatus? lockStatus,
    bool? doorClosed,
    bool? isOnline,
    bool? burglarAlarmActive,
    bool? isLockout,
    String? lastMethod,
    DateTime? lastUpdated,
    DateTime? lastHeartbeat,
    String? firmwareVersion,
    bool? hasReport,
    String? syncIssue,
    bool clearSyncIssue = false,
    bool? isActionPending,
    String? pendingActionMessage,
    String? lastProcessedCommandId,
  }) {
    return DoorLockState(
      lockStatus: lockStatus ?? this.lockStatus,
      doorClosed: doorClosed ?? this.doorClosed,
      isOnline: isOnline ?? this.isOnline,
      burglarAlarmActive: burglarAlarmActive ?? this.burglarAlarmActive,
      isLockout: isLockout ?? this.isLockout,
      lastMethod: lastMethod ?? this.lastMethod,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hasReport: hasReport ?? this.hasReport,
      syncIssue: clearSyncIssue ? null : (syncIssue ?? this.syncIssue),
      isActionPending: isActionPending ?? this.isActionPending,
      pendingActionMessage: pendingActionMessage,
      lastProcessedCommandId: lastProcessedCommandId ?? this.lastProcessedCommandId,
    );
  }
}
