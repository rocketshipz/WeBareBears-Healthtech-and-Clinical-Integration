import 'package:flutter/material.dart';

import 'localization.dart';
import 'main.dart' show TriageMYApp;

/// Compatibility entry point for the shared user and admin application.
/// Run with: flutter run -t lib/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  runApp(const TriageMYAdminApp());
}

class TriageMYAdminApp extends StatelessWidget {
  const TriageMYAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const TriageMYApp();
  }
}
