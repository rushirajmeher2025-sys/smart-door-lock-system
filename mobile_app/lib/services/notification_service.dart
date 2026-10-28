import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/security_event.dart';
import '../repositories/lock_repository.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // User notification preferences
  final ValueNotifier<bool> activityNotificationsEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> alarmNotificationsEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> inAppBannersEnabled = ValueNotifier<bool>(true);

  // In-app banner broadcast stream
  final StreamController<SecurityEvent> _inAppEventController = StreamController<SecurityEvent>.broadcast();
  Stream<SecurityEvent> get inAppEventStream => _inAppEventController.stream;

  // Tracking processed events so historical events don't trigger alerts
  final Set<String> _seenEventIds = <String>{};
  bool _hasInitialBatch = false;
  StreamSubscription<List<SecurityEvent>>? _eventsSubscription;
  int _notificationCounter = 1000;

  static const String _channelActivityId = 'lockify_activity_channel';
  static const String _channelActivityName = 'Door Activity';
  static const String _channelActivityDesc = 'Notifications for door lock, unlock, and normal activity';

  static const String _channelAlarmId = 'lockify_alarm_channel';
  static const String _channelAlarmName = 'Security Alarms & Warnings';
  static const String _channelAlarmDesc = 'Critical notifications for break-ins, tampering, and wrong PIN lockouts';

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: payload=${response.payload}');
        },
      );

      // Create Android Notification Channels explicitly
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Request runtime permission on Android 13+
        await androidPlugin.requestNotificationsPermission();

        const activityChannel = AndroidNotificationChannel(
          _channelActivityId,
          _channelActivityName,
          description: _channelActivityDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        const alarmChannel = AndroidNotificationChannel(
          _channelAlarmId,
          _channelAlarmName,
          description: _channelAlarmDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await androidPlugin.createNotificationChannel(activityChannel);
        await androidPlugin.createNotificationChannel(alarmChannel);
      }

      _isInitialized = true;
      debugPrint('NotificationService successfully initialized');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Start monitoring the repository events stream for real-time door activity
  void attachLockRepository(LockRepository repository) {
    _eventsSubscription?.cancel();
    _seenEventIds.clear();
    _hasInitialBatch = false;

    _eventsSubscription = repository.eventsStream.listen((events) {
      _handleEventsUpdate(events, repository.activeDeviceName);
    });
  }

  void _handleEventsUpdate(List<SecurityEvent> events, String lockName) {
    if (events.isEmpty) return;

    if (!_hasInitialBatch) {
      // First snapshot contains historical events loaded from Firebase
      for (final event in events) {
        _seenEventIds.add(event.id);
      }
      _hasInitialBatch = true;
      return;
    }

    final now = DateTime.now();

    // Find new events that haven't been processed yet
    for (final event in events) {
      if (!_seenEventIds.contains(event.id)) {
        _seenEventIds.add(event.id);

        // Only notify if event occurred recently (within the last 3 minutes)
        final age = now.difference(event.timestamp);
        if (age.inMinutes.abs() <= 3) {
          _triggerEventAlert(event, lockName);
        }
      }
    }
  }

  void _triggerEventAlert(SecurityEvent event, String lockName) {
    final isAlarm = event.severity == EventSeverity.alarm;
    final isWarning = event.severity == EventSeverity.warning;

    // Filter by user preference
    if (isAlarm || isWarning) {
      if (!alarmNotificationsEnabled.value) return;
    } else {
      if (!activityNotificationsEnabled.value) return;
    }

    // 1. Post system notification
    showSystemNotification(
      id: _notificationCounter++,
      title: _formatTitle(event, lockName),
      body: _formatBody(event),
      isAlarm: isAlarm,
    );

    // 2. Emit for in-app floating banner
    if (inAppBannersEnabled.value) {
      _inAppEventController.add(event);
    }
  }

  String _formatTitle(SecurityEvent event, String lockName) {
    switch (event.severity) {
      case EventSeverity.alarm:
        return '🚨 $lockName: ${event.title}';
      case EventSeverity.warning:
        return '⚠️ $lockName: ${event.title}';
      case EventSeverity.normal:
        if (event.type == 'unlock' || event.title.toLowerCase().contains('unlock')) {
          return '🔓 $lockName: Unlocked';
        }
        if (event.type == 'lock' || event.title.toLowerCase().contains('lock')) {
          return '🔒 $lockName: Locked';
        }
        return '🔔 $lockName: ${event.title}';
    }
  }

  String _formatBody(SecurityEvent event) {
    if (event.description.isNotEmpty && event.description != event.title) {
      return event.description;
    }
    if (event.method.isNotEmpty && event.method != 'system') {
      return 'Via ${event.method}';
    }
    return event.title;
  }

  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    bool isAlarm = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      isAlarm ? _channelAlarmId : _channelActivityId,
      isAlarm ? _channelAlarmName : _channelActivityName,
      channelDescription: isAlarm ? _channelAlarmDesc : _channelActivityDesc,
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Failed to display system notification: $e');
    }
  }

  /// Sends a sample test notification so the user can verify system & in-app alerts
  Future<void> sendTestNotification({required String lockName}) async {
    final testEvent = SecurityEvent(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      type: 'unlock',
      title: 'Door Unlocked (Test)',
      description: 'Front door was unlocked via LocKify Mobile App',
      method: 'Mobile App',
      timestamp: DateTime.now(),
      severity: EventSeverity.normal,
      icon: SecurityEvent.iconFor('unlock', EventSeverity.normal),
    );

    await showSystemNotification(
      id: 9999,
      title: '🔓 $lockName: Door Unlocked (Test)',
      body: 'Front door was unlocked via LocKify Mobile App',
      isAlarm: false,
    );

    if (inAppBannersEnabled.value) {
      _inAppEventController.add(testEvent);
    }
  }

  void dispose() {
    _eventsSubscription?.cancel();
    _inAppEventController.close();
  }
}
