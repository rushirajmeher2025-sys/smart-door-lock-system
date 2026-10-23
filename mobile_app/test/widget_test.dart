import 'package:flutter_test/flutter_test.dart';
import 'package:smart_door_lock/screens/dashboard_screen.dart';
import 'package:smart_door_lock/screens/login_screen.dart';
import 'package:smart_door_lock/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('LoginScreen renders fields and sign in button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('DashboardScreen renders lock status and controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );

    expect(find.text('Front door'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Hold to unlock'), findsOneWidget);
  });
}
