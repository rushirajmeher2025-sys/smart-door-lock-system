import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/intro_overlay.dart';
import 'routes.dart';

class SmartLockApp extends StatefulWidget {
  final bool showIntro;

  const SmartLockApp({super.key, this.showIntro = true});

  @override
  State<SmartLockApp> createState() => _SmartLockAppState();
}

class _SmartLockAppState extends State<SmartLockApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.instance.themeModeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.instance.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeService.instance.themeMode,
      initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.routes,
      // The launch animation plays on top while the app starts underneath
      builder: (context, child) => widget.showIntro ? IntroOverlay(child: child!) : child!,
    );
  }
}
