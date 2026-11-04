import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/firebase_init.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/widget_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseInitService.initialize();
    await NotificationService.instance.handleBackgroundMessage(message);
  } catch (e) {
    debugPrint('[FCM Background] Error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent any unhandled Flutter framework errors from terminating the app
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER] ${details.exceptionAsString()}');
  };

  // 1. Initialize Firebase
  try {
    await FirebaseInitService.initialize();
  } catch (e) {
    debugPrint('[INIT] Firebase init error: $e');
  }

  // 2. Register FCM background message handler only if Firebase configured
  if (!kIsWeb && FirebaseInitService.isConfigured) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[INIT] FCM onBackgroundMessage error: $e');
    }
  }

  // 3. Initialize Theme Service
  try {
    await ThemeService.instance.initialize();
  } catch (e) {
    debugPrint('[INIT] ThemeService init error: $e');
  }

  // 4. Initialize Notification Service
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[INIT] NotificationService init error: $e');
  }

  // 5. Initialize Lock Widget Service
  try {
    await LockWidgetService.instance.initialize();
  } catch (e) {
    debugPrint('[INIT] LockWidgetService init error: $e');
  }

  // 6. Always mount and run the application
  runApp(const SmartLockApp());
}
