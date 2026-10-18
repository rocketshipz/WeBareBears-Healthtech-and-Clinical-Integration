import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagemy/admin/admin_queue.dart';
import 'package:triagemy/theme.dart';
import 'package:triagemy/admin/admin_login.dart';
import 'package:triagemy/admin/admin_account.dart';
import 'package:triagemy/admin/admin_patients.dart';
import 'package:triagemy/admin/patient_profile_card.dart';
import 'package:triagemy/admin/api_admin_repository.dart';
import 'package:triagemy/admin/diagnosis_card.dart';
import 'package:triagemy/admin/admin_register.dart';
import 'package:triagemy/admin/admin_store.dart';
import 'package:triagemy/admin/admin_repository.dart';
import 'package:triagemy/admin/patient_detail.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    adminStore.useRepository(DemoAdminRepository());
  });

  testWidgets(
    'Patient detail separates tabs and unlocks diagnosis after consultation',
    (tester) async {
      final visit = adminStore.active.first;
      visit.profile = {'name': visit.name, 'ic': visit.ic, 'age': visit.age};
      visit.allergies = 'Latex';
      final doctor = visit.steps.firstWhere((step) => step.id == 'doctor');
      doctor.status = StepStatus.waiting;
      adminStore.useRepository(ApiAdminRepository());
      adminStore.visits.add(visit);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(home: PatientDetailPage(visit: visit)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Progress timeline'), findsOneWidget);
          expect(find.byType(PatientProfileCard), findsNothing);
          expect(find.text('Allergy: Latex'), findsNothing);
          expect(find.byType(DiagnosisCard), findsNothing);
          await tester.tap(find.text('Profile'));
          await tester.pumpAndSettle();
          expect(find.byType(PatientProfileCard), findsOneWidget);
          expect(find.text('Progress timeline'), findsNothing);
          await tester.tap(find.text('Timeline'));
          await tester.pumpAndSettle();
          adminStore.setStepStatus(visit, doctor, StepStatus.inProgress);
          await tester.pumpAndSettle();
          expect(find.byType(DiagnosisCard), findsNothing);
          adminStore.setStepStatus(visit, doctor, StepStatus.done);
          await tester.pumpAndSettle();
          expect(find.byType(DiagnosisCard), findsOneWidget);
          final diagnosis = find.byType(TextField).first;
          await tester.ensureVisible(diagnosis);
          await tester.enterText(diagnosis, 'Draft diagnosis');
          await tester.ensureVisible(find.text('Profile'));
          await tester.tap(find.text('Profile'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Timeline'));
          await tester.pumpAndSettle();
          expect(find.text('Draft diagnosis'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {'diagnosis': null}
                  : {'version': visit.version + 1, 'queue_no': visit.queueNo},
            ),
            200,
          ),
        ),
      );
      adminStore.useRepository(DemoAdminRepository());
    },
  );

  testWidgets('Patients lists assigned visits and searches by name and IC', (
    tester,
  ) async {
    final originalStaff = adminStore.staff;
    const nurse = StaffMember(
      id: 'N-SEARCH',
      name: 'Search Nurse',
      role: 'Nurse',
      hospital: 'Test Hospital',
      department: 'ED',
    );
    adminStore.staff = nurse;
    final visit = await adminStore.registerPatient(
      name: 'Assigned Patient',
      ic: '001010101234',
      age: 26,
      sex: 'Female',
      complaint: 'Headache',
      acuity: Acuity.green,
      tests: [],
      patientPhone: '0121234567',
    );
    adminStore.staff = const StaffMember(
      id: 'N-OTHER',
      name: 'Other Nurse',
      role: 'Nurse',
      hospital: 'Test Hospital',
      department: 'ED',
    );
    final other = await adminStore.registerPatient(
      name: 'Other Patient',
      ic: '001010105678',
      age: 26,
      sex: 'Male',
      complaint: 'Headache',
      acuity: Acuity.green,
      tests: [],
      patientPhone: '0121234568',
    );
    adminStore.staff = nurse;
    Visit? opened;
    await tester.pumpWidget(
      MaterialApp(home: PatientsPage(onOpenVisit: (v) => opened = v)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assigned Patient'), findsOneWidget);
    expect(find.text('Other Patient'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No patients match your search.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '001010101234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assigned Patient'));
    expect(opened, same(visit));
    await tester.pumpWidget(const SizedBox());
    adminStore.visits.removeWhere((v) => v == visit || v == other);
    adminStore.staff = originalStaff;
  });

  testWidgets(
    'Patient preview omits metadata and uses columns with readable dates',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatientProfileCard(
                profile: {
                  'name': 'Preview Patient',
                  'ic': '001010101234',
                  'phone': '0121234567',
                  'age': 26,
                  'email': 'hidden@example.com',
                  'date_of_birth': '2000-10-10',
                  'created_at': 'raw-created',
                  'updated_at': 'raw-updated',
                  'location_consent': true,
                  'medical_info_updated_at': '2026-10-17T12:26:00Z',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('hidden@example.com'), findsNothing);
      expect(find.text('2000-10-10'), findsNothing);
      expect(find.text('raw-created'), findsNothing);
      expect(find.textContaining('Location consent'), findsNothing);
      expect(
        find.text('Medical info updated · 17 October, 8.26pm'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('IC number')).dy,
        tester.getTopLeft(find.text('Phone number').first).dy,
      );
    },
  );

  testWidgets(
    'Staff profile opens change password and submits matching passwords',
    (tester) async {
      var writes = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: AdminAccountPage()));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Change password'));
          await tester.tap(find.text('Change password'));
          await tester.pumpAndSettle();
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), 'triagemy123');
          await tester.enterText(fields.at(1), 'new-password-123');
          await tester.enterText(fields.at(2), 'mismatch');
          // PrimaryButton uses its own animated wrapper; select its label.
          final label = find.byType(PrimaryButton);
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(find.text('New passwords do not match.'), findsOneWidget);
          expect(writes, 0);
          await tester.enterText(fields.at(2), 'new-password-123');
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(writes, 1);
          expect(find.text('Password changed successfully.'), findsOneWidget);
        },
        () => MockClient((request) async {
          writes++;
          expect(request.url.path, endsWith('/admin/change-password'));
          expect(jsonDecode(request.body), {
            'current_password': 'triagemy123',
            'new_password': 'new-password-123',
          });
          return http.Response(
            '{"message":"Password changed successfully."}',
            200,
          );
        }),
      );
    },
  );

  testWidgets('Staff login uses the database identity in the queue header', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: AdminLoginScreen()));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('Nurse'), findsNothing);
        expect(find.text('Doctor'), findsNothing);
        await tester.enterText(find.byType(TextField).first, 'DB-100');
        await tester.enterText(find.byType(TextField).last, 'test-password');
        await tester.ensureVisible(find.text('Log in'));
        await tester.tap(find.text('Log in'));
        await tester.pumpAndSettle();
        expect(find.text('Greetings Database Staff'), findsOneWidget);
        expect(find.text('Database Hospital'), findsWidgets);
        expect(find.text('Cardiology'), findsWidgets);
        expect(adminStore.staff?.role, 'Doctor');
        await tester.pumpWidget(const SizedBox());
        await adminStore.signOut();
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/admin/login'));
        expect(jsonDecode(request.body), {
          'staff_id': 'DB-100',
          'password': 'test-password',
        });
        return http.Response(
          jsonEncode({
            'token': 'staff-token',
            'staff': {
              'staff_id': 'DB-100',
              'name': 'Database Staff',
              'role': 'Doctor',
              'hospital': 'Database Hospital',
              'department': 'Cardiology',
            },
          }),
          200,
        );
      }),
    );
  });

  testWidgets('Zone counts open the matching patient cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QueuePage(onRegister: () {}, onOpenVisit: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Red zone'), findsOneWidget);
    expect(find.text('Yellow zone'), findsOneWidget);
    expect(find.text('Green zone'), findsOneWidget);
    final red = adminStore.active.firstWhere((v) => v.acuity == Acuity.red);
    expect(find.text(red.name), findsNothing);
    await tester.tap(find.text('Red zone'));
    await tester.pumpAndSettle();
    expect(find.text(red.name), findsOneWidget);
    for (final visit in adminStore.active.where(
      (v) => v.acuity != Acuity.red,
    )) {
      expect(find.text(visit.name), findsNothing);
    }
  });

  testWidgets(
    'IC lookup previews profile and carries report into registered visit',
    (tester) async {
      Visit? registered;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: RegisterPatientPage(onRegistered: (v) => registered = v),
            ),
          );
          await tester.enterText(find.byType(TextField), '001010-10-4321');
          await tester.tap(find.text('Find patient'));
          await tester.pumpAndSettle();
          expect(find.text('Lookup Test Patient'), findsOneWidget);
          expect(find.text('Latest triage report'), findsOneWidget);
          final button = find.text('Check in patient');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(registered?.triage?.symptom, 'Headache');
          expect(
            registered?.profile['emergency_contact_name'],
            'Contact Person',
          );
          expect(registered?.acuity, Acuity.yellow);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'profile': {
                'id': 'lookup-widget',
                'ic': '001010104321',
                'name': 'Lookup Test Patient',
                'age': 26,
                'sex_at_birth': 'female',
                'phone': '0121234567',
                'emergency_contact_name': 'Contact Person',
              },
              'report_id': 'report-widget',
              'triage': {
                'symptom': 'Headache',
                'severity': 'Moderate',
                'duration': '1 hour',
                'danger_signs': [],
                'level': 3,
                'submitted_at': '2026-10-18T00:00:00Z',
              },
            }),
            200,
          ),
        ),
      );
      adminStore.visits.remove(registered);
    },
  );

  testWidgets('Staff can add a named custom test to progress', (tester) async {
    final visit = adminStore.active.first;
    await tester.pumpWidget(MaterialApp(home: PatientDetailPage(visit: visit)));
    await tester.pumpAndSettle();
    final add = find.text('Add test');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Custom ultrasound');
    await tester.tap(find.text('Add custom test'));
    await tester.pumpAndSettle();
    expect(
      visit.steps.any(
        (step) => step.name == 'Custom ultrasound' && step.isTest,
      ),
      isTrue,
    );
    visit.steps.removeWhere((step) => step.name == 'Custom ultrasound');
  });
}
