import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/intro_overlay.dart';
import 'routes.dart';

class SmartLockApp extends StatelessWidget {
  final bool showIntro;

  const SmartLockApp({super.key, this.showIntro = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.initialRoute,
      routes: AppRoutes.routes,
      // The launch animation plays on top while the app starts underneath
      builder: (context, child) => showIntro ? IntroOverlay(child: child!) : child!,
    );
  }
}
