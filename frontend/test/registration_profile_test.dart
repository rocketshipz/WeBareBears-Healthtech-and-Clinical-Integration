import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:triagemy/localization.dart';
import 'package:triagemy/pages/profile_page.dart';
import 'package:triagemy/screens/signup_page.dart';
import 'package:triagemy/theme.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppLanguage.instance.value = const Locale('en');
  });

  testWidgets('Sign-up requires name and offers all three sexes', (
    tester,
  ) async {
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
    final button = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Send Verification Code'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Signup gives live feedback and blocks incomplete credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.pumpAndSettle();

    Future<void> enter(String field, String value) async {
      final finder = find.byKey(ValueKey('signup-$field'));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
      await tester.pump();
    }

    TextField field(String name) =>
        tester.widget<TextField>(find.byKey(ValueKey('signup-$name')));
    Color borderColor(String name) =>
        field(name).decoration!.enabledBorder!.borderSide.color;
    bool canContinue() =>
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Send Verification Code'),
            )
            .onPressed !=
        null;

    expect(canContinue(), isFalse);
    await enter('email', 'invalid@');
    expect(borderColor('email'), AppColors.red);
    expect(
      field('email').decoration!.errorText,
      'Please enter a valid email address.',
    );
    await enter('email', 'user+tag@clinic.healthcare');
    expect(borderColor('email'), AppColors.green);
    expect(field('email').decoration!.errorText, isNull);
    expect(
      find.text('Valid email format. Verify with email TAC.'),
      findsOneWidget,
    );

    await enter('phone', '123abc');
    expect(borderColor('phone'), AppColors.red);
    await enter('phone', '0123456789');
    expect(borderColor('phone'), AppColors.green);

    // Every missing password requirement must keep the button disabled.
    for (final weak in [
      'Aa1!',
      'password1!',
      'PASSWORD1!',
      'Password!!',
      'Password12',
    ]) {
      await enter('password', weak);
      await enter('confirmPassword', weak);
      expect(borderColor('password'), AppColors.red);
      expect(canContinue(), isFalse);
    }
    await enter('password', 'Password1!');
    expect(borderColor('password'), AppColors.green);
    expect(find.text('All password requirements met.'), findsOneWidget);
    for (final label in [
      'At least 8 characters',
      'One uppercase letter (A-Z)',
      'One lowercase letter (a-z)',
      'One number (0-9)',
      'One symbol (e.g. !@#)',
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        AppColors.green,
      );
    }
    expect(canContinue(), isFalse);
    await enter('confirmPassword', 'Password1!');
    expect(borderColor('confirmPassword'), AppColors.green);
    expect(canContinue(), isTrue);

    await enter('email', 'bad');
    expect(canContinue(), isFalse);
    await enter('email', 'user@example.com');
    await enter('phone', 'abc');
    expect(canContinue(), isFalse);
    await enter('phone', '+60123456789');
    expect(canContinue(), isTrue);
    await enter('password', 'weak');
    expect(borderColor('password'), AppColors.red);
    expect(borderColor('confirmPassword'), AppColors.red);
    expect(canContinue(), isFalse);
  });

  testWidgets('Nationality search supports non-Malaysian registration', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
    await tester.pump(const Duration(seconds: 2));
    final nationality = find.byKey(const ValueKey('signup-nationality'));
    await tester.ensureVisible(nationality);
    final search = find.descendant(
      of: nationality,
      matching: find.byType(TextField),
    );
    await tester.tap(search);
    await tester.pumpAndSettle();
    await tester.enterText(search, 'Indonesia');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indonesia').hitTestable().last);
    await tester.pumpAndSettle();
    expect(find.text('Select date of birth'), findsOneWidget);
    expect(find.text('IC / Passport Number'), findsOneWidget);
  });

  testWidgets('Name and sex stay read-only while editing profile', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Aisyah Binti Ahmad'), findsNWidgets(2));
    expect(find.text('Female'), findsOneWidget);
    final editableIdentity = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          [
            'Aisyah Binti Ahmad',
            'Female',
            '020101-08-1234',
            'Malaysia',
          ].contains(widget.controller?.text),
    );
    expect(editableIdentity, findsNothing);
  });
}
