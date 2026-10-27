/// System-wide constants for the Smart Door Lock System.
class AppConstants {
  static const String appName = 'LocKify';
  static const String appTagline = 'Security at Your Fingertips';
  static const String appVersion = '2.0.0';

  // Must match DEVICE_ID in firmware/smart_lock/config.h
  static const String deviceId = 'esp32_lock_01';
  static const String deviceName = 'Front door';

  // Hardware Timing References (mirrors firmware/smart_lock/config.h)
  static const int lockoutTimeSeconds = 10;
  static const int autoLockDelaySeconds = 5;
  static const int doorWarningSeconds = 10;
  static const int maxPinAttempts = 3;
  static const int minPinLength = 4;
  static const int maxPinLength = 8;

  // Cloud link timing. The lock reports every 10 s and rejects commands older
  // than 15 s, so waiting 20 s for a reply means a late command can never run.
  static const Duration staleAfter = Duration(seconds: 35);
  static const Duration commandTimeout = Duration(seconds: 20);

  // Route Names
  static const String routeGate = '/';
  static const String routeLogin = '/login';
  static const String routeLocks = '/locks';
  static const String routeHome = '/home';
  static const String routeDashboard = '/dashboard';
  static const String routeHistory = '/history';
  static const String routeSettings = '/settings';
}
