import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLanguage.instance.load();
  runApp(const TriageMYApp());
}

class TriageMYApp extends StatelessWidget {
  const TriageMYApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: AppLanguage.instance,
    builder: (context, locale, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ms')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const LoginScreen(),
    ),
  );
}
