import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:triagemy/localization.dart';
import 'package:triagemy/pages/profile_page.dart';
import 'package:triagemy/screens/signup_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppLanguage.instance.value = const Locale('en');
  });

  testWidgets('Sign-up requires name and offers all three sexes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('signup-name')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('signup-sex')));
    await tester.pumpAndSettle();
    for (final sex in ['Male', 'Female', 'Intersex']) {
      expect(find.text(sex).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text('Intersex').last);
    await tester.pumpAndSettle();
    final send = find.text('Send Verification Code');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pump();
    expect(find.text('Please complete all required fields.'), findsOneWidget);
  });

  testWidgets('Nationality search supports non-Malaysian registration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.pump(const Duration(seconds: 2));
    final nationality = find.byKey(const ValueKey('signup-nationality'));
    await tester.ensureVisible(nationality);
    final search = find.descendant(of: nationality, matching: find.byType(TextField));
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'Indonesia');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indonesia').hitTestable().last);
    await tester.pumpAndSettle();
    expect(find.text('Select date of birth'), findsOneWidget);
    expect(find.text('IC / Passport Number'), findsOneWidget);
  });

  testWidgets('Name and sex stay read-only while editing profile', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Aisyah Binti Ahmad'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    final editableIdentity = find.byWidgetPredicate((widget) => widget is TextField &&
        ['Aisyah Binti Ahmad', 'Female', '020101-08-1234', 'Malaysia'].contains(widget.controller?.text));
    expect(editableIdentity, findsNothing);
  });
}
