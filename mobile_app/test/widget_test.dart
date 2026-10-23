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

    expect(find.text('ESA Smart Lock'), findsOneWidget);
    expect(find.text('Sign In to Lock'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders lock status and controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const DashboardScreen(),
      ),
    );

    expect(find.text('Security Dashboard'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('UNLOCK'), findsOneWidget);
  });
}
