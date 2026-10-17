import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triagemy/localization.dart';
import 'package:triagemy/main.dart';
import 'package:triagemy/pages/profile_page.dart';
import 'package:triagemy/pages/triage_report.dart';

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.load();
  });

  testWidgets('Login updates in both directions without navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const TriageMYApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Welcome back'), findsOneWidget);
    await AppLanguage.instance.select('ms');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Selamat kembali'), findsOneWidget);
    expect(find.text('E-mel, Nombor Telefon, atau IC'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    await AppLanguage.instance.select('en');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Profile switch saves language and retains entered details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: const ProfilePage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('profile-language')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Bahasa Melayu').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Profil Pengguna'), findsOneWidget);
    expect(profileData.value['name'], 'Aisyah Binti Ahmad');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_language'), 'ms');
    AppLanguage.instance.value = const Locale('en');
    await AppLanguage.instance.load();
    expect(AppLanguage.instance.value.languageCode, 'ms');
  });

  test('Reports translate while triage severity stays unchanged', () async {
    final report = TriageReportData(
      symptom: 'Chest pain',
      severity: 'Severe',
      duration: 'Less than 24 hours',
      dangerSigns: ['Difficulty\nbreathing'],
    );
    final english = report.toPlainText({'name': 'Aisyah'});
    expect(english, contains('Red Zone'));
    await AppLanguage.instance.select('ms');
    final malay = report.toPlainText({'name': 'Aisyah'});
    expect(malay, contains('Zon Merah'));
    expect(malay, contains('Tahap 1'));
    expect(malay, contains('Sakit dada'));
    expect(malay, contains('Kesukaran bernafas'));
    expect(malay, contains('Aisyah'));
    expect(malay, isNot(contains('Emergency care advised')));
    expect(report.level, 1);
    expect(
      tr('Step 2 of 3 \u00b7 Verify phone'),
      'Langkah 2 daripada 3 \u00b7 Sahkan telefon',
    );
    expect(tr('1\u20133 days'), '1\u20133 hari');
    final pdf = await report.buildPdf({'name': 'Aisyah'});
    expect(pdf, isNotEmpty);
  });
}
