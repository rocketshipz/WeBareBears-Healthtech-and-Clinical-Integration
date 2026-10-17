import 'package:flutter/material.dart';

import 'admin/admin_landing.dart';
import 'theme.dart';

/// Entry point for the hospital (staff) side.
/// Run with:  flutter run -t lib/pages/admin/main_admin.dart
void main() {
  runApp(const TriageMYAdminApp());
}

class TriageMYAdminApp extends StatelessWidget {
  const TriageMYAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TriageMY Hospital',
      theme: buildAppTheme(),
      home: const AdminLandingScreen(),
    );
  }
}