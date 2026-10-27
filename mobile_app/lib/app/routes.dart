import 'package:flutter/material.dart';
import '../screens/auth_gate.dart';
import '../screens/lock_selection_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/constants.dart';

class AppRoutes {
  static const String initialRoute = AppConstants.routeGate;

  static Map<String, WidgetBuilder> get routes => {
    AppConstants.routeGate: (context) => const AuthGate(),
    AppConstants.routeLogin: (context) => const LoginScreen(),
    AppConstants.routeLocks: (context) => const LockSelectionScreen(),
    AppConstants.routeHome: (context) => const MainNavScreen(),
    AppConstants.routeDashboard: (context) => const DashboardScreen(),
    AppConstants.routeHistory: (context) => const HistoryScreen(),
    AppConstants.routeSettings: (context) => const SettingsScreen(),
  };
}
