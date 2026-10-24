import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseInitService {
  static bool isConfigured = false;
  static bool usingEmulator = false;
  static String? initError;

  /// Local Firebase emulator host, e.g. `--dart-define=LOCKIFY_EMULATOR=127.0.0.1`.
  /// Start it with `firebase emulators:start --project demo-lockify` in firebase/.
  static const String emulatorHost = String.fromEnvironment('LOCKIFY_EMULATOR');

  /// Safe initialization check
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        isConfigured = true;
        return;
      }

      if (emulatorHost.isNotEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:000000000000:web:0000000000000000',
            messagingSenderId: '000000000000',
            projectId: 'demo-lockify',
            databaseURL: 'https://demo-lockify-default-rtdb.firebaseio.com',
          ),
        );
        await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
        FirebaseDatabase.instance.useDatabaseEmulator(emulatorHost, 9000);
        usingEmulator = true;
      } else {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      isConfigured = true;
      if (kDebugMode) {
        print('[FIREBASE] Initialized${usingEmulator ? ' (local emulator at $emulatorHost)' : ''}.');
      }
    } catch (e) {
      isConfigured = false;
      initError = e.toString();
      if (kDebugMode) {
        print('[FIREBASE] Not configured, starting in Demo mode: $e');
      }
    }
  }
}
