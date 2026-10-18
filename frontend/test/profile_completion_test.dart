import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagemy/localization.dart';
import 'package:triagemy/pages/home_page.dart';
import 'package:triagemy/pages/profile_page.dart';
import 'package:triagemy/services/auth_service.dart';

void main() {
  testWidgets(
    'Saved complete profiles hide the reminder and medical rows align',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      AppLanguage.instance.value = const Locale('en');
      profileCompleted.value = false;
      final user = {
        'id': 'complete-user',
        'name': 'Complete Patient',
        'ic': '001010101234',
        'nationality': 'Malaysia',
        'sex_at_birth': 'female',
      };
      final profile = <String, dynamic>{
        ...user,
        'date_of_birth': '2000-10-10',
        'age': 26,
        'height_cm': 155,
        'weight_kg': 45.5,
        'emergency_contact_name': 'Family Contact',
        'emergency_contact_phone': '0123456789',
        'emergency_contact_relation': 'Mother',
        'chronic_conditions': [
          {'name': 'None'},
        ],
        'allergies': [
          {'substance': 'None'},
        ],
        'location_consent': false,
        'organ_donor': false,
      };
      await http.runWithClient(
        () async {
          await AuthService.login(
            identifier: 'complete@example.com',
            password: 'password',
          );
          await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
          await tester.pumpAndSettle();
          expect(profileCompleted.value, isTrue);
          final chronic = tester.getTopLeft(find.text('Chronic Conditions'));
          final allergies = tester.getTopLeft(find.text('Allergies'));
          final medications = tester.getTopLeft(
            find.text('Current Medications'),
          );
          expect(chronic.dx, medications.dx);
          expect(allergies.dx, medications.dx);
          await tester.pumpWidget(
            MaterialApp(
              home: HomePage(
                onStartTriage: () {},
                onMedicalHistory: () {},
                onHospitals: () {},
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));
          expect(find.text('Complete your medical profile'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          profile['weight_kg'] = null;
          await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
          await tester.pumpAndSettle();
          expect(profileCompleted.value, isFalse);
          await tester.pumpWidget(const SizedBox());
          AuthService.logout();
          profileCompleted.value = false;
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/login')
                  ? {'token': 'profile-token', 'user': user}
                  : profile,
            }),
            200,
          ),
        ),
      );
    },
  );
}
