import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/access_request.dart';
import '../models/lock_device_info.dart';
import '../models/lock_state.dart';
import '../models/remote_command.dart';
import '../models/security_event.dart';
import '../utils/constants.dart';
import 'lock_repository.dart';

/// Live lock data from Firebase Realtime Database (`/devices/{deviceId}`).
///
/// Physical state only ever comes from what the ESP32 reports in `status`.
/// Commands are written to `commands` and count as done only when the lock
/// marks them EXECUTED.
class FirebaseLockRepository implements LockRepository {
  FirebaseLockRepository._();
  static final FirebaseLockRepository instance = FirebaseLockRepository._();

  FirebaseDatabase get _db => FirebaseDatabase.instance;
  String _activeDeviceId = AppConstants.deviceId;
  String _activeDeviceName = AppConstants.deviceName;

  @override
  String get activeDeviceId => _activeDeviceId;
  @override
  String get activeDeviceName => _activeDeviceName;

  DatabaseReference get _device => _db.ref('devices/$_activeDeviceId');

  final _availableLocksController = StreamController<List<LockDeviceInfo>>.broadcast();
  List<LockDeviceInfo> _availableLocks = const [];
  StreamSubscription<DatabaseEvent>? _devicesListSub;

  @override
  Stream<List<LockDeviceInfo>> get availableLocksStream => _availableLocksController.stream;
  @override
  List<LockDeviceInfo> get availableLocks => _availableLocks;

  @override
  Future<void> setActiveDevice(String deviceId, {String? deviceName}) async {
    final trimmed = deviceId.trim();
    if (trimmed.isEmpty) return;
    if (_activeDeviceId == trimmed && _subs.isNotEmpty) {
      if (deviceName != null) _activeDeviceName = deviceName;
      return;
    }
    _activeDeviceId = trimmed;
    if (deviceName != null) {
      _activeDeviceName = deviceName;
    } else {
      final found = _availableLocks.where((d) => d.deviceId == trimmed).firstOrNull;
      if (found != null) _activeDeviceName = found.deviceName;
    }
    final user = _user;
    if (user != null) {
      await _disconnect();
      await _connect(user);
    }
  }

  final _stateController = StreamController<DoorLockState>.broadcast();
  final _eventsController = StreamController<List<SecurityEvent>>.broadcast();
  final _pendingRequestsController = StreamController<List<AccessRequest>>.broadcast();
  final _pinController = StreamController<String?>.broadcast();
  final _access = ValueNotifier<LockAccess>(const LockAccess(AccessStatus.checking));

  DoorLockState _report = DoorLockState.waiting();
  DoorLockState _state = DoorLockState.waiting();
  List<SecurityEvent> _events = const [];
  List<AccessRequest> _pendingRequests = const [];
  AccessRequest? _myRequest;
  String? _currentPin;
  bool _eventsLoaded = false;
  String? _eventsError;
  bool _pending = false;
  String? _pendingMessage;
  int _serverOffsetMs = 0;

  bool _started = false;
  User? _user;
  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<DatabaseEvent>> _subs = [];
  StreamSubscription<DatabaseEvent>? _requestsSub;
  Timer? _ticker;

  @override
  bool get isSimulation => false;
  @override
  Stream<DoorLockState> get stateStream => _stateController.stream;
  @override
  Stream<List<SecurityEvent>> get eventsStream => _eventsController.stream;
  @override
  Stream<List<AccessRequest>> get pendingRequestsStream => _pendingRequestsController.stream;
  @override
  List<AccessRequest> get currentPendingRequests => _pendingRequests;
  @override
  Stream<String?> get pinStream => _pinController.stream;
  @override
  String? get currentPin => _currentPin;
  @override
  DoorLockState get currentState => _state;
  @override
  List<SecurityEvent> get currentEvents => _events;
  @override
  bool get eventsLoaded => _eventsLoaded;
  @override
  String? get eventsError => _eventsError;
  @override
  ValueListenable<LockAccess> get access => _access;

  void start() {
    if (_started) return;
    _started = true;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _authSub?.cancel();
    await _disconnect();
    await _pinController.close();
    _started = false;
  }

  Future<void> _onUser(User? user) async {
    if (user?.uid == _user?.uid && _subs.isNotEmpty) return;
    await _disconnect();
    _user = user;
    if (user == null) {
      _access.value = const LockAccess(AccessStatus.checking);
      _report = DoorLockState.waiting();
      _events = const [];
      _eventsLoaded = false;
      _currentPin = null;
      _pinController.add(null);
      _emit();
      _eventsController.add(_events);
      return;
    }
    await _connect(user);
  }

  Future<void> _disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _connect(User user) async {
    _access.value = LockAccess(AccessStatus.checking, uid: user.uid);
    _report = DoorLockState.waiting();
    _emit();

    final ok = await _ensureAccess(user);
    if (!ok || _user?.uid != user.uid) return;

    _devicesListSub?.cancel();
    _devicesListSub = _db.ref('devices').onValue.listen((e) {
      final v = e.snapshot.value;
      final list = <LockDeviceInfo>[];
      if (v is Map) {
        v.forEach((key, val) {
          if (val is Map) {
            list.add(LockDeviceInfo.fromMap(key.toString(), val, currentUid: user.uid));
          }
        });
      }
      if (!list.any((d) => d.deviceId == _activeDeviceId)) {
        list.insert(0, _buildCurrentActiveLockInfo(user.uid));
      }
      _availableLocks = List.unmodifiable(list);
      _availableLocksController.add(_availableLocks);
    }, onError: (_) {
      _syncActiveLockDeviceInfo(user.uid);
    });
    _subs.add(_devicesListSub!);

    _subs.add(_db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _serverOffsetMs = v.toInt();
    }));

    _subs.add(_device.child('requests/${user.uid}').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is Map) {
        _myRequest = AccessRequest.fromJson(Map<String, dynamic>.from(v), uid: user.uid);
      } else {
        _myRequest = null;
      }
      final cur = _access.value;
      final isOwner = cur.status == AccessStatus.owner;
      final isApproved = cur.members[user.uid] == true || _myRequest?.isApproved == true;
      final newStatus = isOwner
          ? AccessStatus.owner
          : (isApproved ? AccessStatus.member : AccessStatus.denied);

      _access.value = LockAccess(
        newStatus,
        uid: cur.uid,
        deviceUid: cur.deviceUid,
        members: cur.members,
        message: cur.message,
        myRequest: _myRequest,
      );
      _syncActiveLockDeviceInfo(user.uid);
    }));

    _subs.add(_device.child('pin/currentPin').onValue.listen((e) {
      final v = e.snapshot.value;
      _currentPin = v?.toString();
      _pinController.add(_currentPin);
    }));

    _subs.add(_device.child('metadata').onValue.listen(
      (e) {
        _applyMetadata(user.uid, e.snapshot.value);
        _syncActiveLockDeviceInfo(user.uid, e.snapshot.value is Map ? e.snapshot.value as Map : null);
      },
      onError: (Object e) => _setIssue(_describe(e)),
    ));

    _subs.add(_device.child('status').onValue.listen(
      (e) {
        final v = e.snapshot.value;
        _report = v is Map ? DoorLockState.fromJson(v) : DoorLockState.waiting();
        _emit();
        _syncActiveLockDeviceInfo(user.uid);
      },
      onError: (Object e) => _setIssue(_describe(e)),
    ));

    _subs.add(_device.child('events').orderByKey().limitToLast(100).onValue.listen(
      (e) {
        final v = e.snapshot.value;
        final list = <SecurityEvent>[];
        if (v is Map) {
          v.forEach((key, value) {
            if (value is Map) list.add(SecurityEvent.fromJson(value, fallbackId: key.toString()));
          });
        }
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _events = List.unmodifiable(list);
        _eventsLoaded = true;
        _eventsError = null;
        _eventsController.add(_events);
      },
      onError: (Object e) {
        _eventsError = _describe(e);
        _eventsLoaded = true;
        _eventsController.add(_events);
      },
    ));

    // Re-check freshness every few seconds so "offline" shows up on its own
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
  }

  /// Makes sure this account can see the lock. The first account to sign in
  /// claims an unclaimed lock as its owner.
  Future<bool> _ensureAccess(User user) async {
    final meta = _device.child('metadata');
    try {
      final snap = await meta.get();
      if (snap.exists) {
        _applyMetadata(user.uid, snap.value);
        return true;
      }
    } catch (e) {
      if (!_isPermissionDenied(e)) {
        _access.value = LockAccess(AccessStatus.error, uid: user.uid, message: _describe(e));
        _setIssue(_describe(e));
        return false;
      }
    }

    // Unclaimed (or someone else's): try to claim it
    try {
      await meta.set({
        'deviceId': _activeDeviceId,
        'deviceName': _activeDeviceName,
        'ownerUid': user.uid,
        'hardware': 'ESP32 DevKit V4',
      });
      await _db.ref('users/${user.uid}/devices/$_activeDeviceId').set(true);
      _access.value = LockAccess(AccessStatus.owner, uid: user.uid);
      return true;
    } catch (e) {
      final denied = _isPermissionDenied(e);
      final message = denied
          ? 'This lock belongs to another account. Ask its owner to add your user ID.'
          : _describe(e);
      _access.value = LockAccess(denied ? AccessStatus.denied : AccessStatus.error, uid: user.uid, message: message);
      _setIssue(message);
      return false;
    }
  }

  void _applyMetadata(String uid, Object? value) {
    if (value is! Map) return;
    final devName = value['deviceName'] as String?;
    if (devName != null && devName.isNotEmpty) {
      _activeDeviceName = devName;
    }
    final owner = value['ownerUid'];
    final members = <String, bool>{};
    final raw = value['authorizedUsers'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v == true) members[k.toString()] = true;
      });
    }

    final isOwner = owner == uid;
    final isApproved = members[uid] == true || _myRequest?.isApproved == true;
    final status = isOwner
        ? AccessStatus.owner
        : (isApproved ? AccessStatus.member : AccessStatus.denied);

    _access.value = LockAccess(
      status,
      uid: uid,
      deviceUid: value['deviceUid'] as String?,
      members: members,
      myRequest: _myRequest,
    );

    // If owner, listen for access requests from other users
    if (isOwner && _requestsSub == null) {
      _requestsSub = _device.child('requests').onValue.listen((e) {
        final v = e.snapshot.value;
        final list = <AccessRequest>[];
        if (v is Map) {
          v.forEach((k, reqVal) {
            if (reqVal is Map) {
              final req = AccessRequest.fromJson(Map<String, dynamic>.from(reqVal), uid: k.toString());
              if (req.isPending) list.add(req);
            }
          });
        }
        list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        _pendingRequests = List.unmodifiable(list);
        _pendingRequestsController.add(_pendingRequests);
      });
      _subs.add(_requestsSub!);
    }

    if (_report.syncIssue != null) {
      _report = _report.copyWith(clearSyncIssue: true);
      _emit();
    }
  }

  Map<dynamic, dynamic>? _lastMetadataMap;

  LockDeviceInfo _buildCurrentActiveLockInfo(String uid) {
    final meta = _lastMetadataMap ?? {};
    final members = <String, bool>{};
    final rawAuth = meta['authorizedUsers'];
    if (rawAuth is Map) {
      rawAuth.forEach((k, v) {
        if (v == true) members[k.toString()] = true;
      });
    }

    final isApproved = (meta['ownerUid'] == uid) || members[uid] == true || _myRequest?.isApproved == true;
    final reqStatus = isApproved ? 'APPROVED' : (_myRequest?.status);

    return LockDeviceInfo(
      deviceId: _activeDeviceId,
      deviceName: _activeDeviceName,
      hardware: meta['hardware']?.toString() ?? 'ESP32 DevKit V4',
      ownerUid: meta['ownerUid']?.toString(),
      isOnline: _report.isOnline,
      isLocked: _report.isLocked,
      authorizedUsers: members,
      myRequestStatus: reqStatus,
    );
  }

  void _syncActiveLockDeviceInfo(String uid, [Map? metaValue]) {
    if (metaValue != null) {
      _lastMetadataMap = metaValue;
    }
    final activeLock = _buildCurrentActiveLockInfo(uid);
    final list = List<LockDeviceInfo>.from(_availableLocks);
    final idx = list.indexWhere((l) => l.deviceId == _activeDeviceId);
    if (idx >= 0) {
      list[idx] = activeLock;
    } else {
      list.insert(0, activeLock);
    }
    _availableLocks = List.unmodifiable(list);
    _availableLocksController.add(_availableLocks);
  }

  void _setIssue(String message) {
    _report = _report.copyWith(syncIssue: message);
    _emit();
  }

  DateTime get _serverNow => DateTime.now().add(Duration(milliseconds: _serverOffsetMs));

  void _emit() {
    final heartbeat = _report.lastHeartbeat;
    final fresh = heartbeat != null && _serverNow.difference(heartbeat) < AppConstants.staleAfter;
    _state = _report.copyWith(
      isOnline: _report.hasReport && _report.isOnline && fresh,
      isActionPending: _pending,
      pendingActionMessage: _pendingMessage,
    );
    _stateController.add(_state);
  }

  void _setPending(bool pending, [String? message]) {
    _pending = pending;
    _pendingMessage = message;
    _emit();
  }

  @override
  Future<CommandOutcome> sendCommand(RemoteAction action) async {
    final user = _user;
    if (user == null) return const CommandOutcome(CommandResult.failed, 'Sign in again to control the lock.');
    if (_pending) return const CommandOutcome(CommandResult.failed, 'Another request is still in progress.');
    if (!_state.isConfirmed) {
      return const CommandOutcome(
        CommandResult.failed,
        'The lock is offline, so the request wasn’t sent.',
      );
    }
    if (action == RemoteAction.lock && !_state.doorClosed) {
      return CommandOutcome(CommandResult.rejected, CommandOutcome.describeReason('BLOCKED_DOOR_OPEN'));
    }

    final ref = _device.child('commands').push();
    final id = ref.key!;
    _setPending(true, 'Sending to the lock…');

    try {
      await ref.set({
        'commandId': id,
        'action': actionName(action),
        'requestedBy': user.uid,
        'requestedAt': ServerValue.timestamp,
        'status': 'PENDING',
      });
    } catch (e) {
      _setPending(false);
      return CommandOutcome(CommandResult.failed, 'Couldn’t send the request: ${_describe(e)}');
    }

    _setPending(true, 'Waiting for the lock to confirm…');
    final done = Completer<CommandOutcome>();
    final sub = ref.onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is! Map || done.isCompleted) return;
      final cmd = RemoteCommand.fromJson(Map<String, dynamic>.from(v));
      switch (cmd.status) {
        case RemoteCommandStatus.processing:
          _setPending(true, 'The lock is moving the bolt…');
        case RemoteCommandStatus.executed:
          done.complete(CommandOutcome(
            CommandResult.succeeded,
            action == RemoteAction.lock ? 'Locked. The lock confirmed it.' : 'Unlocked. The lock confirmed it.',
          ));
        case RemoteCommandStatus.rejected:
          done.complete(CommandOutcome(CommandResult.rejected, CommandOutcome.describeReason(cmd.failureReason)));
        case RemoteCommandStatus.failed:
          done.complete(CommandOutcome(CommandResult.failed, CommandOutcome.describeReason(cmd.failureReason)));
        case RemoteCommandStatus.pending:
          break;
      }
    }, onError: (Object e) {
      if (!done.isCompleted) done.complete(CommandOutcome(CommandResult.failed, _describe(e)));
    });

    final outcome = await done.future.timeout(
      AppConstants.commandTimeout,
      onTimeout: () => const CommandOutcome(
        CommandResult.timedOut,
        'The lock didn’t answer in time. It ignores late requests, so nothing will happen.',
      ),
    );
    await sub.cancel();
    _setPending(false);
    return outcome;
  }

  @override
  Future<void> linkHardware(String deviceUid) async {
    await _device.child('metadata/deviceUid').set(deviceUid.trim());
  }

  @override
  Future<void> setMember(String uid, bool allowed) async {
    await _device.child('metadata/authorizedUsers/${uid.trim()}').set(allowed ? true : null);
  }

  @override
  Future<void> requestAccess({required String email}) async {
    final user = _user;
    if (user == null) return;
    await _device.child('requests/${user.uid}').set({
      'uid': user.uid,
      'email': email.trim(),
      'requestedAt': ServerValue.timestamp,
      'status': 'PENDING',
    });
    await _db.ref('users/${user.uid}/devices/$_activeDeviceId').set('PENDING');
  }

  @override
  Future<void> approveRequest(String uid) async {
    final cleaned = uid.trim();
    await _device.child('metadata/authorizedUsers/$cleaned').set(true);
    await _device.child('requests/$cleaned/status').set('APPROVED');
    try {
      await _db.ref('users/$cleaned/devices/$_activeDeviceId').set('APPROVED');
    } catch (_) {}
  }

  @override
  Future<void> rejectRequest(String uid) async {
    final cleaned = uid.trim();
    await _device.child('metadata/authorizedUsers/$cleaned').remove();
    await _device.child('requests/$cleaned/status').set('REJECTED');
    try {
      await _db.ref('users/$cleaned/devices/$_activeDeviceId').remove();
    } catch (_) {}
  }

  @override
  Future<void> updatePin(String newPin) async {
    final user = _user;
    if (user == null) throw Exception('Must be signed in to update PIN');
    final cleaned = newPin.trim();
    if (cleaned.length < 4 || cleaned.length > 8 || !RegExp(r'^\d+$').hasMatch(cleaned)) {
      throw Exception('PIN must be 4 to 8 digits');
    }
    await _device.child('pin').set({
      'currentPin': cleaned,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': user.uid,
    });
    _currentPin = cleaned;
    _pinController.add(cleaned);
  }

  @override
  Future<void> retry() async {
    final user = _user;
    if (user == null) return;
    await _disconnect();
    await _connect(user);
  }

  static bool _isPermissionDenied(Object e) {
    final text = e is FirebaseException ? '${e.code} ${e.message}' : e.toString();
    return text.toLowerCase().contains('permission');
  }

  static String _describe(Object e) {
    if (_isPermissionDenied(e)) return 'You don’t have access to this lock.';
    if (e is FirebaseException) return e.message ?? e.code;
    return e.toString();
  }
}
