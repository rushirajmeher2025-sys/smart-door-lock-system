import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  // Stream for notification click handling across the app
  final StreamController<Map<String, dynamic>> _notificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationClick => _notificationClickController.stream;

  // Tracking processed events so historical events don't trigger duplicate alerts
  final Set<String> _seenEventIds = <String>{};
  bool _hasInitialBatch = false;
  StreamSubscription<List<SecurityEvent>>? _eventsSubscription;
  int _notificationCounter = 1000;
  String? _subscribedDeviceId;

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
          _notificationClickController.add({'payload': response.payload});
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

      // Initialize Firebase Cloud Messaging (FCM) for background & terminated pushes
      await _initializeFCM();

      _isInitialized = true;
      debugPrint('NotificationService successfully initialized with FCM background support');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  Future<void> _initializeFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request push permissions
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] User granted permission status: ${settings.authorizationStatus}');

      // Configure foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for incoming FCM messages while app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.messageId}');
        _handleRemoteMessage(message, isForeground: true);
      });

      // Handle user tapping notification when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened from background: ${message.data}');
        _notificationClickController.add(message.data);
      });

      // Handle user tapping notification that launched the app from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App launched from terminated state via notification: ${initialMessage.data}');
        _notificationClickController.add(initialMessage.data);
      }
    } catch (e) {
      debugPrint('[FCM] Could not initialize FirebaseMessaging: $e');
    }
  }

  /// Process background or terminated push messages
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Handling background/terminated message: ${message.messageId}');
    _handleRemoteMessage(message, isForeground: false);
  }

  void _handleRemoteMessage(RemoteMessage message, {required bool isForeground}) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'LocKify Notification';
    final body = notification?.body ?? data['description'] ?? data['body'] ?? 'Security event received';
    final severityStr = (data['severity'] ?? '').toString().toLowerCase();
    final isAlarm = severityStr == 'alarm' || severityStr == 'warning';

    // In foreground, we also trigger in-app floating banner
    if (isForeground) {
      final event = SecurityEvent(
        id: data['eventId'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: data['type'] ?? 'fcm_alert',
        title: title,
        description: body,
        method: data['method'] ?? 'Cloud',
        timestamp: DateTime.now(),
        severity: isAlarm ? EventSeverity.alarm : EventSeverity.normal,
        icon: SecurityEvent.iconFor(data['type'] ?? '', isAlarm ? EventSeverity.alarm : EventSeverity.normal),
      );

      if (inAppBannersEnabled.value) {
        _inAppEventController.add(event);
      }

      // If notification was not auto-displayed by system in foreground, show local notification
      showSystemNotification(
        id: _notificationCounter++,
        title: title,
        body: body,
        isAlarm: isAlarm,
      );
    }
  }

  /// Start monitoring the repository events stream and subscribe to FCM topics
  void attachLockRepository(LockRepository repository) {
    _eventsSubscription?.cancel();
    _seenEventIds.clear();
    _hasInitialBatch = false;

    final deviceId = repository.activeDeviceId;
    final lockName = repository.activeDeviceName;

    // Register FCM topic subscription and store push token for this device
    _registerDevicePush(deviceId);

    _eventsSubscription = repository.eventsStream.listen((events) {
      _handleEventsUpdate(events, lockName);
    });
  }

  /// Subscribes this phone to the lock's push notification topic and stores FCM token
  Future<void> _registerDevicePush(String deviceId) async {
    if (deviceId.isEmpty || deviceId == 'mock_device') return;

    try {
      // Unsubscribe from previous device topic if changed
      if (_subscribedDeviceId != null && _subscribedDeviceId != deviceId) {
        if (!kIsWeb) {
          await FirebaseMessaging.instance.unsubscribeFromTopic('lock_$_subscribedDeviceId');
        }
      }

      // Subscribe to the new device topic (delivers pushes when app is closed)
      if (!kIsWeb) {
        await FirebaseMessaging.instance.subscribeToTopic('lock_$deviceId');
        _subscribedDeviceId = deviceId;
        debugPrint('[FCM] Subscribed to topic: lock_$deviceId');
      }

      // Save user FCM device token to Realtime Database under /devices/{deviceId}/fcmTokens/{uid}
      final token = await FirebaseMessaging.instance.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        final tokenRef = FirebaseDatabase.instance.ref('devices/$deviceId/fcmTokens/${user.uid}');
        await tokenRef.set({
          'token': token,
          'updatedAt': ServerValue.timestamp,
          'platform': defaultTargetPlatform.name,
        });
        debugPrint('[FCM] Stored FCM token for user ${user.uid} on device $deviceId');
      }
    } catch (e) {
      debugPrint('[FCM] Error registering push subscription: $e');
    }
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
    _notificationClickController.close();
  }
}
