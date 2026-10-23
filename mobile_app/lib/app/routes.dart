import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/main_nav_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/constants.dart';

class AppRoutes {
  static const String initialRoute = AppConstants.routeLogin;

  static Map<String, WidgetBuilder> get routes => {
    AppConstants.routeLogin: (context) => const LoginScreen(),
    AppConstants.routeHome: (context) => const MainNavScreen(),
    AppConstants.routeDashboard: (context) => const DashboardScreen(),
    AppConstants.routeHistory: (context) => const HistoryScreen(),
    AppConstants.routeSettings: (context) => const SettingsScreen(),
  };
}
