import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagemy/localization.dart';
import 'package:triagemy/pages/profile_page.dart';
import 'package:triagemy/services/auth_service.dart';

void main() {
  testWidgets('Profile loads saved data, retains failed edits, and saves repeatedly', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AppLanguage.instance.value = const Locale('en');
    final user = <String, dynamic>{'id': 'u1', 'name': 'Registered Name', 'ic': '990101145555',
      'sex_at_birth': 'female', 'nationality': 'Malaysia', 'date_of_birth': '1999-01-01'};
    final stored = <String, dynamic>{...user, 'age': 27, 'height_cm': 170,
      'preferred_language': 'English', 'blood_type': 'O+', 'location_consent': false};
    var failSave = true;
    var writes = 0;
    await http.runWithClient(() async {
      await AuthService.login(identifier: 'test@example.com', password: 'password');
      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();
      expect(find.text('Registered Name'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final conditions = find.byKey(const ValueKey('entries-Chronic Conditions'));
      await tester.ensureVisible(conditions);
      await tester.enterText(conditions, 'Asthma, Diabetes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final allergies = find.byKey(const ValueKey('entries-Allergies'));
      await tester.ensureVisible(allergies);
      await tester.enterText(allergies, 'Peanuts');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.enterText(allergies, 'Penicillin');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final height = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '170');
      await tester.ensureVisible(height);
      await tester.enterText(height, '172');
      await tester.ensureVisible(find.text('Save'));
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(stored['height_cm'], 170);
      failSave = false;
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(stored['height_cm'], 172);
      expect(stored['chronic_conditions'], [{'name': 'Asthma'}, {'name': 'Diabetes'}]);
      expect(stored['allergies'], [{'substance': 'Peanuts'}, {'substance': 'Penicillin'}]);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final changedHeight = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '172');
      await tester.ensureVisible(changedHeight);
      await tester.enterText(changedHeight, '175');
      await tester.ensureVisible(find.text('Save'));
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(stored['height_cm'], 175);
      expect(writes, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      await tester.pumpAndSettle();
      expect(find.text('175.0 cm'), findsOneWidget);
      for (final entry in ['Asthma', 'Diabetes', 'Peanuts', 'Penicillin']) {
        expect(find.text(entry), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      AuthService.logout();
    }, () => MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(jsonEncode({'data': {'token': 'test-token', 'user': user}}), 200);
      }
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.method == 'PUT') {
        if (failSave) return http.Response(jsonEncode({'detail': 'Save failed'}), 500);
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload.containsKey('name'), isFalse);
        expect(payload.containsKey('nationality'), isFalse);
        stored.addAll(payload);
        writes++;
      }
      return http.Response(jsonEncode({'data': stored}), 200);
    }));
  });
}

