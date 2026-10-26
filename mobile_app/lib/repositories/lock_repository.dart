import 'package:flutter/foundation.dart';
import '../models/access_request.dart';
import '../models/lock_state.dart';
import '../models/remote_command.dart';
import '../models/security_event.dart';
import '../services/firebase_init.dart';
import 'firebase_lock_repository.dart';
import 'mock_lock_repository.dart';

/// What finally happened to a remote command. Success only comes from the
/// lock itself reporting EXECUTED, never from the request being written.
enum CommandResult { succeeded, rejected, failed, timedOut }

class CommandOutcome {
  final CommandResult result;
  final String message;

  const CommandOutcome(this.result, this.message);

  bool get ok => result == CommandResult.succeeded;

  /// Turns firmware failure codes into something a person can act on.
  static String describeReason(String? code) {
    switch (code) {
      case 'BLOCKED_DOOR_OPEN':
        return 'The door is open. Close it and try again.';
      case 'ALARM_PIN_REQUIRED':
        return 'The alarm is on. Only the keypad PIN can stop it.';
      case 'ALARM_ACTIVE':
        return 'The alarm is on. Enter the PIN on the keypad first.';
      case 'EXPIRED':
        return 'The request reached the lock too late, so it was ignored.';
      case 'UNAUTHORIZED':
        return 'Your account isn’t allowed to control this lock.';
      case 'MALFORMED':
        return 'The lock didn’t understand the request.';
      case 'LOCK_BUSY':
        return 'The lock was busy. Try again in a moment.';
      case 'UNLOCK_FAILED':
        return 'The lock couldn’t move the bolt.';
      default:
        return code == null || code.isEmpty ? 'The lock refused the request.' : code;
    }
  }
}

/// Who the signed-in account is for this lock.
enum AccessStatus { checking, owner, member, denied, error, demo }

class LockAccess {
  final AccessStatus status;
  final String? uid;
  final String? deviceUid;
  final Map<String, bool> members;
  final String? message;
  final AccessRequest? myRequest;

  const LockAccess(
    this.status, {
    this.uid,
    this.deviceUid,
    this.members = const {},
    this.message,
    this.myRequest,
  });

  bool get isOwner => status == AccessStatus.owner || status == AccessStatus.demo;
  bool get hardwareLinked => deviceUid != null && deviceUid!.isNotEmpty;
  bool get isPendingApproval => status == AccessStatus.denied && myRequest?.isPending == true;
  bool get isRequestRejected => status == AccessStatus.denied && myRequest?.isRejected == true;
}

/// One lock, as the screens see it. The demo build and Firebase build share it.
abstract class LockRepository {
  /// True for the built-in simulation (no hardware, no cloud).
  bool get isSimulation;

  Stream<DoorLockState> get stateStream;
  Stream<List<SecurityEvent>> get eventsStream;
  DoorLockState get currentState;
  List<SecurityEvent> get currentEvents;

  /// Null until the history has loaded; an error message if it can't load.
  bool get eventsLoaded;
  String? get eventsError;

  ValueListenable<LockAccess> get access;

  /// Pending requests from other users waiting for owner approval
  Stream<List<AccessRequest>> get pendingRequestsStream;
  List<AccessRequest> get currentPendingRequests;

  Future<CommandOutcome> sendCommand(RemoteAction action);

  /// Owner only: lets the lock's own Firebase account act for this lock.
  Future<void> linkHardware(String deviceUid);

  /// Owner only: give or remove another account's access.
  Future<void> setMember(String uid, bool allowed);

  /// Submit an access request from this account to the lock owner.
  Future<void> requestAccess({required String email});

  /// Owner only: approve a pending access request.
  Future<void> approveRequest(String uid);

  /// Owner only: reject a pending access request.
  Future<void> rejectRequest(String uid);

  /// Keypad PIN synchronization
  Stream<String?> get pinStream;
  String? get currentPin;
  Future<void> updatePin(String newPin);

  /// Re-reads access and status, e.g. after an error.
  Future<void> retry();
}

/// The repository for this run: Firebase when configured, otherwise the simulation.
LockRepository lockRepository() {
  if (FirebaseInitService.isConfigured) {
    final repo = FirebaseLockRepository.instance;
    repo.start();
    return repo;
  }
  return MockLockRepository.instance;
}

/// Wire name the firmware expects (RemoteAction.name would give 'clearAlarm').
String actionName(RemoteAction action) {
  switch (action) {
    case RemoteAction.lock:
      return 'LOCK';
    case RemoteAction.unlock:
      return 'UNLOCK';
    case RemoteAction.clearAlarm:
      return 'CLEAR_ALARM';
    case RemoteAction.ping:
      return 'PING';
  }
}
