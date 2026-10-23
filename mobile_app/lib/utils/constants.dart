/// System-wide constants for the Smart Door Lock System.
class AppConstants {
  static const String appName = 'ESA Smart Lock';
  static const String appVersion = '1.0.0';

  // Hardware Timing References
  static const int lockoutTimeSeconds = 10;
  static const int autoLockDelaySeconds = 5;
  static const int doorWarningSeconds = 10;
  static const int maxPinAttempts = 3;
  static const int minPinLength = 4;
  static const int maxPinLength = 8;

  // Route Names
  static const String routeGate = '/';
  static const String routeLogin = '/login';
  static const String routeHome = '/home';
  static const String routeDashboard = '/dashboard';
  static const String routeHistory = '/history';
  static const String routeSettings = '/settings';
}
