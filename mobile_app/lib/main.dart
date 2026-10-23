import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitService.initialize();
  runApp(const SmartLockApp());
}
