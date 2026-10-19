import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:triagemy/services/auth_service.dart';
import 'package:triagemy/widgets/family_access_card.dart';

void main() {
  testWidgets('Profile creates WhatsApp invitation and manages family approval', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var status = 'pending';
    var invitations = 0;
    await http.runWithClient(
      () async {
        await AuthService.login(identifier: 'patient', password: 'password');
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: FamilyAccessCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Family Member · pending'), findsOneWidget);
        await tester.tap(find.text('Accept'));
        await tester.pumpAndSettle();
        expect(status, 'approved');
        expect(find.text('Revoke access'), findsOneWidget);
        await tester.tap(find.text('Revoke access'));
        await tester.pumpAndSettle();
        expect(status, 'revoked');
        expect(find.text('Revoke access'), findsNothing);
        await tester.tap(find.text('Create WhatsApp invitation'));
        await tester.pumpAndSettle();
        expect(invitations, 1);
        expect(
          find.text('https://triagemy.example/api/family/invitations/1'),
          findsOneWidget,
        );
        expect(find.text('Share via WhatsApp'), findsOneWidget);
        expect(find.textContaining('One request per link'), findsOneWidget);
        await tester.tap(find.text('Create another invitation'));
        await tester.pumpAndSettle();
        expect(invitations, 2);
        expect(
          find.text('https://triagemy.example/api/family/invitations/2'),
          findsOneWidget,
        );
        status = 'pending';
        await tester.tap(find.byTooltip('Refresh requests'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Reject'));
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        expect(status, 'rejected');
        await tester.pumpWidget(const SizedBox());
        AuthService.logout();
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'token': 'patient-token',
              'user': {'id': 'patient'},
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer patient-token');
        if (request.url.path.endsWith('/invitations')) {
          invitations++;
          return http.Response(
            jsonEncode({
              'invitation_url':
                  'https://triagemy.example/api/family/invitations/$invitations',
              'expires_at': '2026-10-20T12:00:00Z',
            }),
            200,
          );
        }
        if (request.method == 'PUT') {
          status = jsonDecode(request.body)['status'] as String;
          return http.Response(jsonEncode({'status': status}), 200);
        }
        return http.Response(
          jsonEncode({
            'incoming': [
              {
                'viewer_id': 'family',
                'name': 'Family Member',
                'status': status,
              },
            ],
            'outgoing': [],
          }),
          200,
        );
      }),
    );
  });
}
