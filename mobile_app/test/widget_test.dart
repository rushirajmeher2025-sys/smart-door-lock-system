import 'package:flutter_test/flutter_test.dart';
import 'package:smart_door_lock/app/app.dart';

void main() {
  testWidgets('SmartLockApp smoke test - renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartLockApp());
    expect(find.text('ESA Smart Lock'), findsOneWidget);
    expect(find.text('Sign In to Lock'), findsOneWidget);
  });
}
