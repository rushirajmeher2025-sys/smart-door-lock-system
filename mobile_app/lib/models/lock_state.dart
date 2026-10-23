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
  final bool isActionPending;
  final String? pendingActionMessage;

  const DoorLockState({
    required this.lockStatus,
    required this.doorClosed,
    required this.isOnline,
    required this.burglarAlarmActive,
    required this.isLockout,
    required this.lastMethod,
    required this.lastUpdated,
    this.isActionPending = false,
    this.pendingActionMessage,
  });

  bool get isLocked => lockStatus == LockStatus.locked;
  bool get isUnlocked => lockStatus == LockStatus.unlocked;
  bool get isUnknown => lockStatus == LockStatus.unknown;

  /// Default initial mock state for UI development
  factory DoorLockState.initial() {
    return DoorLockState(
      lockStatus: LockStatus.locked,
      doorClosed: true,
      isOnline: true,
      burglarAlarmActive: false,
      isLockout: false,
      lastMethod: 'Keypad (Local)',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 3)),
      isActionPending: false,
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
    bool? isActionPending,
    String? pendingActionMessage,
  }) {
    return DoorLockState(
      lockStatus: lockStatus ?? this.lockStatus,
      doorClosed: doorClosed ?? this.doorClosed,
      isOnline: isOnline ?? this.isOnline,
      burglarAlarmActive: burglarAlarmActive ?? this.burglarAlarmActive,
      isLockout: isLockout ?? this.isLockout,
      lastMethod: lastMethod ?? this.lastMethod,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActionPending: isActionPending ?? this.isActionPending,
      pendingActionMessage: pendingActionMessage,
    );
  }
}
