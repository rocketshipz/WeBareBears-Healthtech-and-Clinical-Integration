import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:triagemy/main.dart';

void main() {
  testWidgets('App opens with a choice of user or admin login', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TriageMYApp());
    await tester.pump();

    expect(find.text('Normal user'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
