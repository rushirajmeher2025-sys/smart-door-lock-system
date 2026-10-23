import 'package:flutter_test/flutter_test.dart';
import 'package:smart_door_lock/app/app.dart';
import 'package:smart_door_lock/screens/dashboard_screen.dart';
import 'package:smart_door_lock/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('SmartLockApp smoke test - renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartLockApp());
    expect(find.text('ESA Smart Lock'), findsOneWidget);
    expect(find.text('Sign In to Lock'), findsOneWidget);
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
