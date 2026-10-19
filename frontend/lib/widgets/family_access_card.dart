import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class FamilyAccessCard extends StatefulWidget {
  const FamilyAccessCard({super.key});

  @override
  State<FamilyAccessCard> createState() => _FamilyAccessCardState();
}

class _FamilyAccessCardState extends State<FamilyAccessCard> {
  Timer? timer;
  List<dynamic> incoming = [];
  List<dynamic> outgoing = [];
  String? error;
  bool busy = false;
  bool refreshing = false;
  String? invitationUrl;
  DateTime? expiresAt;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> call(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (AuthService.token == null) throw Exception('Please log in first.');
    final request = http.Request(
      method,
      Uri.parse('${ApiService.baseUrl}/family$path'),
    );
    request.headers.addAll(ApiService.defaultHeaders);
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 20)),
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] is String
            ? data['detail']
            : 'Could not update family access.',
      );
    }
    return data;
  }

  Future<void> refresh() async {
    if (AuthService.token == null || refreshing) return;
    refreshing = true;
    final token = AuthService.token;
    try {
      final data = await call('GET', '/requests');
      if (!mounted || token != AuthService.token) return;
      setState(() {
        incoming = data['incoming'] as List;
        outgoing = data['outgoing'] as List;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load family access. Tap refresh to retry.',
        );
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> generate() => perform(() async {
    final data = await call('POST', '/invitations');
    if (!mounted) return;
    setState(() {
      invitationUrl = data['invitation_url'] as String;
      expiresAt = DateTime.parse(data['expires_at'] as String).toLocal();
    });
  });

  Future<void> share() => perform(() async {
    final message =
        'Request to follow my hospital progress on TriageMY: $invitationUrl\n\n'
        'Log in with your own account and send a request. I need to accept before you can see progress. '
        'This link can be used for one request only.';
    final whatsapp = Uri.https('wa.me', '/', {'text': message});
    if (!await launchUrl(whatsapp, mode: LaunchMode.externalApplication)) {
      throw Exception(
        'Could not open WhatsApp. Copy the link below and send it instead.',
      );
    }
  });

  Future<void> decide(Map<String, dynamic> row, String status) =>
      perform(() async {
        await call(
          'PUT',
          '/requests/${Uri.encodeComponent(row['viewer_id'] as String)}',
          {'status': status},
        );
        await refresh();
      });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: cardDecoration(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.family_restroom, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Family progress access', style: AppText.heading),
            ),
            IconButton(
              onPressed: busy ? null : refresh,
              tooltip: 'Refresh requests',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Send a one-use invitation through WhatsApp. Your family member requests access, then you accept or reject below.',
          style: AppText.body.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : generate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  textStyle: AppText.bodyStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_link, size: 24),
                label: Text(
                  invitationUrl == null
                      ? 'Create WhatsApp invitation'
                      : 'Create another invitation',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        if (invitationUrl != null) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paleTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              invitationUrl!,
              style: AppText.caption.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'One request per link · Expires ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year} at ${TimeOfDay.fromDateTime(expiresAt!).format(context)}',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : share,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Share via WhatsApp'),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: invitationUrl!),
                        );
                        if (context.mounted) {
                          showAppSnack(context, 'Invitation link copied.');
                        }
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy link'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create a separate invitation for each family member. Opening a link does not use it up; submitting a request does.',
            style: AppText.caption.copyWith(height: 1.5),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.red)),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Text('Who can follow you', style: AppText.bodyStrong),
        const SizedBox(height: 6),
        Text(
          'Approved access continues until you revoke it.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        if (incoming.isEmpty) const Text('No family requests yet.'),
        for (final row in incoming) ...[
          const Divider(),
          Text('${row['name']} · ${row['status']}', style: AppText.bodyStrong),
          if (row['status'] == 'pending')
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy
                      ? null
                      : () =>
                            decide(Map<String, dynamic>.from(row), 'approved'),
                  child: const Text('Accept'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () =>
                            decide(Map<String, dynamic>.from(row), 'rejected'),
                  child: const Text('Reject'),
                ),
              ],
            ),
          if (row['status'] == 'approved')
            TextButton(
              onPressed: busy
                  ? null
                  : () => decide(Map<String, dynamic>.from(row), 'revoked'),
              child: const Text('Revoke access'),
            ),
        ],
        const SizedBox(height: 24),
        Text('Patients you follow', style: AppText.bodyStrong),
        const SizedBox(height: 10),
        if (outgoing.isEmpty)
          const Text('Open a patient’s WhatsApp invitation to request access.'),
        for (final row in outgoing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${row['name']} · ${row['status']}${row['status'] == 'approved' ? ' — Open Progress > Family' : ''}',
            ),
          ),
      ],
    ),
  );
}
