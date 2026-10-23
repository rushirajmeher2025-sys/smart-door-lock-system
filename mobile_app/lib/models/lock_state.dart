/// Data model representing the physical lock state from the ESP32 / Firebase.
class DoorLockState {
  final bool isLocked;
  final bool doorClosed;
  final bool burglarAlarmActive;
  final bool isLockout;
  final String lastMethod; // 'keypad', 'button', 'app', 'auto', 'sensor'
  final DateTime updatedAt;

  const DoorLockState({
    required this.isLocked,
    required this.doorClosed,
    required this.burglarAlarmActive,
    required this.isLockout,
    required this.lastMethod,
    required this.updatedAt,
  });

  /// Default initial state before synchronization
  factory DoorLockState.initial() {
    return DoorLockState(
      isLocked: true,
      doorClosed: true,
      burglarAlarmActive: false,
      isLockout: false,
      lastMethod: 'system_init',
      updatedAt: DateTime.now(),
    );
  }

  DoorLockState copyWith({
    bool? isLocked,
    bool? doorClosed,
    bool? burglarAlarmActive,
    bool? isLockout,
    String? lastMethod,
    DateTime? updatedAt,
  }) {
    return DoorLockState(
      isLocked: isLocked ?? this.isLocked,
      doorClosed: doorClosed ?? this.doorClosed,
      burglarAlarmActive: burglarAlarmActive ?? this.burglarAlarmActive,
      isLockout: isLockout ?? this.isLockout,
      lastMethod: lastMethod ?? this.lastMethod,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
