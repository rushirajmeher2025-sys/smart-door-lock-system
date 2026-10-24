import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_door_lock/models/lock_state.dart';
import 'package:smart_door_lock/models/remote_command.dart';
import 'package:smart_door_lock/models/security_event.dart';
import 'package:smart_door_lock/repositories/lock_repository.dart';
import 'package:smart_door_lock/repositories/mock_lock_repository.dart';
import 'package:smart_door_lock/screens/dashboard_screen.dart';
import 'package:smart_door_lock/screens/login_screen.dart';
import 'package:smart_door_lock/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.darkTheme, home: home);

void main() {
  // Tests run offline; fall back to the default font instead of fetching Geist
  GoogleFonts.config.allowRuntimeFetching = false;

  group('screens', () {
    testWidgets('LoginScreen renders the form', (tester) async {
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('DashboardScreen shows the confirmed state and the slider', (tester) async {
      tester.view.physicalSize = const Size(800, 1720);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const DashboardScreen()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Slide to unlock'), findsOneWidget);
      expect(find.textContaining('Confirmed by the lock'), findsOneWidget);
    });
  });

  group('simulated lock follows the firmware safety rules', () {
    final repo = MockLockRepository.instance;

    test('unlocks and reports success only after the lock confirms', () async {
      final outcome = await repo.sendCommand(RemoteAction.unlock);
      expect(outcome.result, CommandResult.succeeded);
      expect(repo.currentState.isUnlocked, isTrue);
      expect(repo.currentState.lastMethod, 'app');
    });

    test('refuses to lock while the door is open', () async {
      repo.toggleDoorSensor(); // open
      final outcome = await repo.sendCommand(RemoteAction.lock);
      expect(outcome.result, CommandResult.rejected);
      expect(outcome.message, CommandOutcome.describeReason('BLOCKED_DOOR_OPEN'));
      repo.toggleDoorSensor(); // close
    });

    test('opening a locked door sets off the alarm, and only the PIN stops it', () async {
      expect((await repo.sendCommand(RemoteAction.lock)).result, CommandResult.succeeded);
      repo.toggleDoorSensor(); // break-in
      expect(repo.currentState.burglarAlarmActive, isTrue);

      final outcome = await repo.sendCommand(RemoteAction.unlock);
      expect(outcome.result, CommandResult.rejected);
      expect(repo.currentState.burglarAlarmActive, isTrue);

      repo.enterPinOnKeypad();
      expect(repo.currentState.burglarAlarmActive, isFalse);
      repo.toggleDoorSensor(); // close again
    });

    test('nothing is sent while the lock is offline', () async {
      repo.toggleConnection();
      final outcome = await repo.sendCommand(RemoteAction.lock);
      expect(outcome.result, CommandResult.failed);
      repo.toggleConnection();
    });
  });

  group('parsing what the ESP32 writes', () {
    test('malformed status never shows a definite lock state', () {
      final s = DoorLockState.fromJson({'isLocked': 'yes', 'doorClosed': 1});
      expect(s.lockStatus, LockStatus.unknown);
      expect(s.isOnline, isFalse);
    });

    test('status with timestamps', () {
      final s = DoorLockState.fromJson({
        'isLocked': true,
        'doorClosed': false,
        'isOnline': true,
        'lastMethod': 'auto',
        'lastUpdated': 1792870000000,
        'lastHeartbeat': 1792870010000,
        'firmwareVersion': '3.0',
      });
      expect(s.isLocked, isTrue);
      expect(s.doorClosed, isFalse);
      expect(s.lastMethodLabel, 'Auto-lock');
      expect(s.lastHeartbeat, DateTime.fromMillisecondsSinceEpoch(1792870010000));
      expect(s.firmwareVersion, '3.0');
    });

    test('events map firmware types to icons and severities', () {
      final e = SecurityEvent.fromJson({
        'type': 'burglar_alarm',
        'title': 'Break-in alarm',
        'severity': 'alarm',
        'timestamp': 1792870000000,
      }, fallbackId: '-abc');
      expect(e.id, '-abc');
      expect(e.severity, EventSeverity.alarm);
      expect(e.icon, Icons.crisis_alert_rounded);
      expect(SecurityEvent.iconFor('rej_EXPIRED', EventSeverity.warning), Icons.block_rounded);
    });

    test('command wire names match the firmware', () {
      expect(actionName(RemoteAction.clearAlarm), 'CLEAR_ALARM');
      expect(actionName(RemoteAction.unlock), 'UNLOCK');
    });
  });
}
