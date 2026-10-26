// File generated for project lockify-2e19b
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC6hIhBF3fjtAft2VU7q0wHUI9FbsdYbYQ',
    appId: '1:13928106435:web:d2292bee211b17d3f09576',
    messagingSenderId: '13928106435',
    projectId: 'lockify-2e19b',
    authDomain: 'lockify-2e19b.firebaseapp.com',
    databaseURL: 'https://lockify-2e19b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lockify-2e19b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC6hIhBF3fjtAft2VU7q0wHUI9FbsdYbYQ',
    appId: '1:13928106435:android:d2292bee211b17d3f09576',
    messagingSenderId: '13928106435',
    projectId: 'lockify-2e19b',
    databaseURL: 'https://lockify-2e19b-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'lockify-2e19b.firebasestorage.app',
  );
}
