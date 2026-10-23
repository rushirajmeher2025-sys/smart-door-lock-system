import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_state.dart';
import '../models/security_event.dart';

/// Development Mock Repository simulating ESP32 & Firebase interactions.
/// Clearly separated from production hardware code.
class MockLockRepository {
  // Singleton pattern for mock state consistency across screens
  static final MockLockRepository instance = MockLockRepository._internal();
  MockLockRepository._internal() {
    _initSampleEvents();
  }

  DoorLockState _currentState = DoorLockState.initial();
  final List<SecurityEvent> _events = [];

  final _stateController = StreamController<DoorLockState>.broadcast();
  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();

  Stream<DoorLockState> get stateStream => _stateController.stream;
  Stream<List<SecurityEvent>> get eventsStream => _eventsController.stream;

  DoorLockState get currentState => _currentState;
  List<SecurityEvent> get currentEvents => List.unmodifiable(_events);

  void _initSampleEvents() {
    final now = DateTime.now();
    _events.addAll([
      SecurityEvent(
        id: 'evt_1',
        title: 'Door Locked',
        description: 'Deadbolt engaged via Keypad',
        method: 'Keypad (Key A)',
        timestamp: now.subtract(const Duration(minutes: 5)),
        severity: EventSeverity.normal,
        icon: Icons.lock_outline_rounded,
      ),
      SecurityEvent(
        id: 'evt_2',
        title: 'Auto-Lock Triggered',
        description: 'Auto-locked 5s after door closure',
        method: 'Firmware Auto-Lock',
        timestamp: now.subtract(const Duration(minutes: 42)),
        severity: EventSeverity.normal,
        icon: Icons.timer_outlined,
      ),
      SecurityEvent(
        id: 'evt_3',
        title: 'Door Left Open Warning',
        description: 'Door remained open for >10 seconds (audible beeps played)',
        method: 'Sensor GPIO 5',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 15)),
        severity: EventSeverity.warning,
        icon: Icons.warning_amber_rounded,
      ),
      SecurityEvent(
        id: 'evt_4',
        title: 'PIN Access Granted',
        description: 'Unlocked with user PIN credentials',
        method: 'Keypad PIN (****)',
        timestamp: now.subtract(const Duration(hours: 3)),
        severity: EventSeverity.normal,
        icon: Icons.pin_outlined,
      ),
      SecurityEvent(
        id: 'evt_5',
        title: 'Keypad Lockout Alert',
        description: '3 consecutive incorrect PIN entries. Keypad locked for 10s',
        method: 'Anti-Brute Force FSM',
        timestamp: now.subtract(const Duration(hours: 6, minutes: 30)),
        severity: EventSeverity.warning,
        icon: Icons.lock_clock_rounded,
      ),
      SecurityEvent(
        id: 'evt_6',
        title: 'Burglar Alarm Siren',
        description: 'Door forced open while locked! Siren sounded & strobe active',
        method: 'Intrusion Detection',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        severity: EventSeverity.alarm,
        icon: Icons.crisis_alert_rounded,
      ),
    ]);
  }

  /// Simulate sending a lock command to ESP32
  Future<bool> sendLockCommand() async {
    if (!_currentState.doorClosed) {
      // Safety rule: Cannot lock when door is open
      return false;
    }

    _currentState = _currentState.copyWith(
      isActionPending: true,
      pendingActionMessage: 'Transmitting Lock command to ESP32...',
    );
    _stateController.add(_currentState);

    // Simulate network roundtrip to ESP32
    await Future.delayed(const Duration(milliseconds: 1400));

    _currentState = _currentState.copyWith(
      lockStatus: LockStatus.locked,
      lastMethod: 'Mobile App (Remote)',
      lastUpdated: DateTime.now(),
      isActionPending: false,
      pendingActionMessage: null,
    );
    _stateController.add(_currentState);

    _addEvent(
      title: 'Door Locked Remotely',
      description: 'Command issued from Mobile Application',
      method: 'Mobile App',
      severity: EventSeverity.normal,
      icon: Icons.lock_rounded,
    );

    return true;
  }

  /// Simulate sending an unlock command to ESP32
  Future<bool> sendUnlockCommand() async {
    _currentState = _currentState.copyWith(
      isActionPending: true,
      pendingActionMessage: 'Transmitting Unlock command to ESP32...',
    );
    _stateController.add(_currentState);

    // Simulate network roundtrip to ESP32
    await Future.delayed(const Duration(milliseconds: 1400));

    _currentState = _currentState.copyWith(
      lockStatus: LockStatus.unlocked,
      lastMethod: 'Mobile App (Remote)',
      lastUpdated: DateTime.now(),
      isActionPending: false,
      pendingActionMessage: null,
    );
    _stateController.add(_currentState);

    _addEvent(
      title: 'Door Unlocked Remotely',
      description: 'Command issued from Mobile Application',
      method: 'Mobile App',
      severity: EventSeverity.normal,
      icon: Icons.lock_open_rounded,
    );

    return true;
  }

  /// Toggle door sensor simulation (Open / Closed)
  void toggleDoorSensor() {
    final newDoorState = !_currentState.doorClosed;
    _currentState = _currentState.copyWith(
      doorClosed: newDoorState,
      lastUpdated: DateTime.now(),
    );
    _stateController.add(_currentState);

    _addEvent(
      title: newDoorState ? 'Door Closed' : 'Door Opened',
      description: newDoorState ? 'Door frame contact closed' : 'Door frame contact open',
      method: 'Sensor GPIO 5',
      severity: newDoorState ? EventSeverity.normal : EventSeverity.warning,
      icon: Icons.door_front_door_outlined,
    );
  }

  /// Toggle connection simulation (Online / Offline)
  void toggleConnection() {
    _currentState = _currentState.copyWith(
      isOnline: !_currentState.isOnline,
      lastUpdated: DateTime.now(),
    );
    _stateController.add(_currentState);
  }

  void _addEvent({
    required String title,
    required String description,
    required String method,
    required EventSeverity severity,
    required IconData icon,
  }) {
    final event = SecurityEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      method: method,
      timestamp: DateTime.now(),
      severity: severity,
      icon: icon,
    );
    _events.insert(0, event);
    _eventsController.add(List.unmodifiable(_events));
  }
}
