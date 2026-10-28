import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/firebase_init.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitService.initialize();
  await NotificationService.instance.initialize();
  runApp(const SmartLockApp());
}
