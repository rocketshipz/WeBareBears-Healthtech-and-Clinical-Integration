import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagemy/admin/api_admin_repository.dart';
import 'package:triagemy/admin/admin_models.dart';
import 'package:triagemy/admin/patient_lookup.dart';
import 'package:triagemy/admin/visit_codec.dart';
import 'package:triagemy/pages/progress_tracking.dart';
import 'package:triagemy/services/auth_service.dart';

Map<String, dynamic> savedVisit() => {
  'id': 'saved-visit',
  'patient_id': 'patient-1',
  'queue_no': 'Q-SAVED',
  'assigned_staff_id': 'N-1',
  'hospital': 'Connected Hospital',
  'department': 'ED',
  'acuity': 'yellow',
  'complaint': 'Headache',
  'version': 0,
  'family_sharing': false,
  'arrived_at': '2026-10-18T00:00:00Z',
  'profile': {'name': 'Connected Patient', 'ic': '001010101234', 'age': 26},
  'steps': [
    {
      'id': 'registration',
      'name': 'Registration',
      'is_test': false,
      'status': 'done',
    },
    {
      'id': 'triage',
      'name': 'Nurse triage',
      'is_test': false,
      'status': 'done',
    },
    {'id': 'x_ray', 'name': 'X-ray', 'is_test': true, 'status': 'waiting'},
    {
      'id': 'doctor',
      'name': 'Doctor consultation',
      'is_test': false,
      'status': 'waiting',
    },
    {
      'id': 'discharge',
      'name': 'Discharge',
      'is_test': false,
      'status': 'waiting',
    },
  ],
  'logs': [],
  'diagnosis': null,
};

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() {
    AuthService.logout();
    PatientLookup.token = null;
  });

  test(
    'API repository persists steps and reloads them without demo data',
    () async {
      var stored = savedVisit();
      var version = 0;
      await http.runWithClient(
        () async {
          PatientLookup.token = 'staff-token';
          final repo = ApiAdminRepository();
          expect(repo.isDemo, isFalse);
          final visit = decodeVisit(stored);
          await repo.saveVisit(visit);
          expect(visit.version, 1);
          visit.steps[2].status = StepStatus.inProgress;
          visit.steps.add(VisitStep.test('Custom laboratory test'));
          await repo.saveVisit(visit);
          final reloaded = await ApiAdminRepository().loadVisits(
            'Connected Hospital',
          );
          expect(reloaded.single.steps[2].status, StepStatus.inProgress);
          expect(reloaded.single.steps.last.name, 'Custom laboratory test');
          expect(reloaded.single.version, 2);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer staff-token');
          if (request.method == 'POST') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload['version'], version);
            version++;
            stored = {
              ...stored,
              ...payload,
              'version': version,
              'queue_no': 'Q-SAVED',
            };
            return http.Response(jsonEncode(stored), 200);
          }
          return http.Response(
            jsonEncode({
              'visits': [stored],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets('Patient timeline loads saved progress and refreshes changes', (
    tester,
  ) async {
    final stored = savedVisit();
    await http.runWithClient(
      () async {
        await AuthService.login(
          identifier: 'patient@example.com',
          password: 'password',
        );
        await tester.pumpWidget(
          const MaterialApp(home: ProgressTrackingPage()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Progress Tracking'), findsOneWidget);
        expect(find.text('Queue number'), findsOneWidget);
        expect(find.text('Connected Hospital'), findsOneWidget);
        expect(find.text('Q-SAVED'), findsOneWidget);
        expect(find.text('A128'), findsNothing);
        final steps = stored['steps'] as List;
        steps[2]['name'] = 'Updated custom test';
        steps[2]['status'] = 'in_progress';
        stored['diagnosis'] = {
          'diagnosis': 'Released diagnosis',
          'medications': ['Medicine'],
          'treatment_notes': 'Care plan',
        };
        await tester.tap(find.byTooltip('Refresh progress'));
        await tester.pumpAndSettle();
        expect(find.text('Updated custom test'), findsOneWidget);
        expect(find.text('Released diagnosis'), findsOneWidget);
        await tester.ensureVisible(find.text('Family'));
        await tester.tap(find.text('Family'));
        await tester.pumpAndSettle();
        expect(find.text('No shared family visits'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'data': {
                'token': 'patient-token',
                'user': {'id': 'patient-1'},
              },
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer patient-token');
        return http.Response(
          jsonEncode({
            'visits': request.url.path.endsWith('/family') ? [] : [stored],
          }),
          200,
        );
      }),
    );
  });
}
