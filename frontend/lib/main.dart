import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TriageMYApp());
}

class TriageMYApp extends StatelessWidget {
  const TriageMYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}