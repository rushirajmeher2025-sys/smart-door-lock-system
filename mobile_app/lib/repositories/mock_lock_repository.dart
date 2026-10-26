import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/access_request.dart';
import '../models/lock_state.dart';
import '../models/remote_command.dart';
import '../models/security_event.dart';
import 'lock_repository.dart';

/// Development Mock Repository simulating ESP32 & Firebase interactions.
/// Clearly separated from production hardware code. It applies the same
/// safety rules as the firmware so the UI can be tested against them.
class MockLockRepository implements LockRepository {
  // Singleton pattern for mock state consistency across screens
  static final MockLockRepository instance = MockLockRepository._internal();
  MockLockRepository._internal() {
    _initSampleEvents();
    _startHardwarePolling();
  }

  DoorLockState _currentState = DoorLockState.initial();
  final List<SecurityEvent> _events = [];
  final _access = ValueNotifier<LockAccess>(
    const LockAccess(AccessStatus.demo, uid: 'demo-user', deviceUid: 'demo-lock'),
  );

  final _stateController = StreamController<DoorLockState>.broadcast();
  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();
  Timer? _pollTimer;

  void _startHardwarePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _syncWithHardware());
  }

  Future<void> _syncWithHardware() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8080/api/status')).timeout(const Duration(milliseconds: 500));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final bool isLocked = data['isLocked'] == true;
        final bool doorClosed = data['doorClosed'] == true;
        final bool alarmActive = data['alarmActive'] == true;
        final bool connected = data['connected'] == true;

        final newLockStatus = isLocked ? LockStatus.locked : LockStatus.unlocked;
        if (_currentState.lockStatus != newLockStatus ||
            _currentState.doorClosed != doorClosed ||
            _currentState.burglarAlarmActive != alarmActive ||
            _currentState.isOnline != connected) {
          _emit(_currentState.copyWith(
            lockStatus: newLockStatus,
            doorClosed: doorClosed,
            burglarAlarmActive: alarmActive,
            isOnline: connected,
            lastUpdated: DateTime.now(),
          ));
        }
      }
    } catch (_) {
      // Offline fallback
    }
  }

  @override
  bool get isSimulation => true;
  @override
  Stream<DoorLockState> get stateStream => _stateController.stream;
  @override
  Stream<List<SecurityEvent>> get eventsStream => _eventsController.stream;
  @override
  DoorLockState get currentState => _currentState;
  @override
  List<SecurityEvent> get currentEvents => List.unmodifiable(_events);
  @override
  bool get eventsLoaded => true;
  @override
  String? get eventsError => null;
  @override
  ValueListenable<LockAccess> get access => _access;

  void _initSampleEvents() {
    final now = DateTime.now();
    SecurityEvent e(String id, String type, String title, String description, String method, Duration ago,
            EventSeverity severity) =>
        SecurityEvent(
          id: id,
          type: type,
          title: title,
          description: description,
          method: method,
          timestamp: now.subtract(ago),
          severity: severity,
          icon: SecurityEvent.iconFor(type, severity),
        );

    _events.addAll([
      e('evt_1', 'lock', 'Door locked', 'Locked with the A key', 'Keypad', const Duration(minutes: 5),
          EventSeverity.normal),
      e('evt_2', 'lock', 'Door locked', 'Locked automatically 5 s after the door closed', 'Auto-lock',
          const Duration(minutes: 42), EventSeverity.normal),
      e('evt_3', 'door_warning', 'Door left open', 'Door open for more than 10 s', 'Door sensor',
          const Duration(hours: 2, minutes: 15), EventSeverity.warning),
      e('evt_4', 'unlock', 'Door unlocked', 'Unlocked with the keypad PIN', 'Keypad', const Duration(hours: 3),
          EventSeverity.normal),
      e('evt_5', 'lockout', 'Keypad locked out', '3 wrong PINs in a row. Keypad disabled for 10 s', 'Keypad',
          const Duration(hours: 6, minutes: 30), EventSeverity.warning),
      e('evt_6', 'burglar_alarm', 'Break-in alarm', 'Door opened while locked. Siren on until the PIN is entered',
          'Door sensor', const Duration(days: 1, hours: 2), EventSeverity.alarm),
    ]);
  }

  void _emit(DoorLockState s) {
    _currentState = s;
    _stateController.add(s);
  }

  /// Simulates the full round trip: request, lock-side checks, confirmation.
  @override
  Future<CommandOutcome> sendCommand(RemoteAction action) async {
    if (_currentState.isActionPending) {
      return const CommandOutcome(CommandResult.failed, 'Another request is still in progress.');
    }
    if (!_currentState.isOnline) {
      return const CommandOutcome(CommandResult.failed, 'The lock is offline, so the request wasn’t sent.');
    }

    _emit(_currentState.copyWith(isActionPending: true, pendingActionMessage: 'Sending to the lock…'));
    await Future.delayed(const Duration(milliseconds: 300));
    _emit(_currentState.copyWith(isActionPending: true, pendingActionMessage: 'The lock is moving the bolt…'));

    // Forward command to real ESP32 hardware bridge
    final locking = action == RemoteAction.lock;
    try {
      await http.post(
        Uri.parse('http://localhost:8080/api/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': locking ? 'LOCK' : 'UNLOCK'}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));

    String? reason;
    if (action == RemoteAction.unlock && _currentState.burglarAlarmActive) reason = 'ALARM_PIN_REQUIRED';
    if (action == RemoteAction.lock && _currentState.burglarAlarmActive) reason = 'ALARM_ACTIVE';
    if (action == RemoteAction.lock && !_currentState.doorClosed) reason = 'BLOCKED_DOOR_OPEN';
    if (action == RemoteAction.clearAlarm) reason = 'ALARM_PIN_REQUIRED';

    if (reason != null) {
      _emit(_currentState.copyWith(isActionPending: false));
      _addEvent('rej_$reason', 'Remote request rejected', CommandOutcome.describeReason(reason), 'LocKify app',
          EventSeverity.warning);
      return CommandOutcome(CommandResult.rejected, CommandOutcome.describeReason(reason));
    }

    _emit(_currentState.copyWith(
      lockStatus: locking ? LockStatus.locked : LockStatus.unlocked,
      lastMethod: 'app',
      lastUpdated: DateTime.now(),
      isActionPending: false,
    ));
    _addEvent(
      locking ? 'lock' : 'unlock',
      locking ? 'Door locked' : 'Door unlocked',
      locking ? 'Locked remotely from the app' : 'Unlocked remotely from the app',
      'LocKify app',
      EventSeverity.normal,
    );
    return CommandOutcome(
      CommandResult.succeeded,
      locking ? 'Locked. The lock confirmed it.' : 'Unlocked. The lock confirmed it.',
    );
  }


  @override
  Future<void> linkHardware(String deviceUid) async {
    _access.value = LockAccess(AccessStatus.demo, uid: 'demo-user', deviceUid: deviceUid);
  }

  @override
  Future<void> setMember(String uid, bool allowed) async {
    final members = Map<String, bool>.from(_access.value.members);
    allowed ? members[uid] = true : members.remove(uid);
    final a = _access.value;
    _access.value = LockAccess(a.status, uid: a.uid, deviceUid: a.deviceUid, members: members);
  }

  final _pendingRequestsController = StreamController<List<AccessRequest>>.broadcast();
  List<AccessRequest> _pendingRequests = [];

  @override
  Stream<List<AccessRequest>> get pendingRequestsStream => _pendingRequestsController.stream;

  @override
  List<AccessRequest> get currentPendingRequests => List.unmodifiable(_pendingRequests);

  @override
  Future<void> requestAccess({required String email}) async {
    final req = AccessRequest(
      uid: 'requested-user-1',
      email: email,
      requestedAt: DateTime.now(),
      status: 'PENDING',
    );
    _pendingRequests = [..._pendingRequests, req];
    _pendingRequestsController.add(_pendingRequests);
    _access.value = LockAccess(
      AccessStatus.denied,
      uid: 'demo-user',
      deviceUid: _access.value.deviceUid,
      myRequest: req,
    );
  }

  @override
  Future<void> approveRequest(String uid) async {
    _pendingRequests = _pendingRequests.where((r) => r.uid != uid).toList();
    _pendingRequestsController.add(_pendingRequests);
    await setMember(uid, true);
  }

  @override
  Future<void> rejectRequest(String uid) async {
    _pendingRequests = _pendingRequests.where((r) => r.uid != uid).toList();
    _pendingRequestsController.add(_pendingRequests);
    await setMember(uid, false);
  }

  final _pinController = StreamController<String?>.broadcast();
  String _pin = '1234';

  @override
  Stream<String?> get pinStream => _pinController.stream;

  @override
  String? get currentPin => _pin;

  @override
  Future<void> updatePin(String newPin) async {
    _pin = newPin;
    _pinController.add(_pin);
    _addEvent('pin_changed', 'PIN updated', 'PIN changed from app', 'LocKify app', EventSeverity.normal);
  }

  @override
  Future<void> retry() async {}

  /// Toggle door sensor simulation (Open / Closed)
  void toggleDoorSensor() {
    final nowClosed = !_currentState.doorClosed;
    final breakIn = !nowClosed && _currentState.isLocked;
    _emit(_currentState.copyWith(
      doorClosed: nowClosed,
      burglarAlarmActive: breakIn ? true : null,
      lastUpdated: DateTime.now(),
    ));

    _addEvent(
      nowClosed ? 'door_closed' : 'door_opened',
      nowClosed ? 'Door closed' : 'Door opened',
      nowClosed ? 'The door sensor reported the door closed' : 'The door sensor reported the door open',
      'Door sensor',
      EventSeverity.normal,
    );
    if (breakIn) {
      _addEvent('burglar_alarm', 'Break-in alarm', 'Door opened while locked. Siren on until the PIN is entered',
          'Door sensor', EventSeverity.alarm);
    }
  }

  /// Simulates entering the right PIN on the keypad (unlocks and stops the alarm).
  void enterPinOnKeypad() {
    final hadAlarm = _currentState.burglarAlarmActive;
    _emit(_currentState.copyWith(
      lockStatus: LockStatus.unlocked,
      burglarAlarmActive: false,
      lastMethod: 'keypad',
      lastUpdated: DateTime.now(),
    ));
    if (hadAlarm) {
      _addEvent('alarm_cleared', 'Alarm stopped', 'Alarm cleared via Keypad', 'Keypad', EventSeverity.normal);
    }
    _addEvent('unlock', 'Door unlocked', 'Unlocked with the keypad PIN', 'Keypad', EventSeverity.normal);
  }

  /// Toggle connection simulation (Online / Offline)
  void toggleConnection() {
    _emit(_currentState.copyWith(isOnline: !_currentState.isOnline));
  }

  void _addEvent(String type, String title, String description, String method, EventSeverity severity) {
    final event = SecurityEvent(
      id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      description: description,
      method: method,
      timestamp: DateTime.now(),
      severity: severity,
      icon: SecurityEvent.iconFor(type, severity),
    );
    _events.insert(0, event);
    _eventsController.add(List.unmodifiable(_events));
  }
}
