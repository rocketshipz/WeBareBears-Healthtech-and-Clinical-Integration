import 'package:flutter_test/flutter_test.dart';
import 'package:triagemy/main.dart';

void main() {
  testWidgets('App smoke test - verifies login screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TriageMYApp());
    await tester.pump();

    // Verify that the login screen elements are present.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email, Phone Number, or IC'), findsOneWidget);
  });
}
