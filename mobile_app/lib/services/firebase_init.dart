import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitService {
  static bool isConfigured = false;
  static String? initError;

  /// Safe initialization check
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        isConfigured = true;
        return;
      }

      // Try default initialization
      await Firebase.initializeApp();
      isConfigured = true;
      if (kDebugMode) {
        print('[FIREBASE] Successfully initialized Firebase App.');
      }
    } catch (e) {
      isConfigured = false;
      initError = e.toString();
      if (kDebugMode) {
        print('[FIREBASE] Firebase not yet configured with options: $e');
      }
    }
  }
}
