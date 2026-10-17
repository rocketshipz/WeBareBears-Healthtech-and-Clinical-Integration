import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_account.dart';
import 'admin_models.dart';
import 'patient_detail.dart';
import 'admin_queue.dart';
import 'admin_register.dart';
import 'admin_widgets.dart';

/// Main frame for hospital staff: Queue / Register / Account.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;

  void _openVisit(Visit visit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientDetailPage(visit: visit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: index,
        children: [
          QueuePage(
            onRegister: () => setState(() => index = 1),
            onOpenVisit: _openVisit,
          ),
          RegisterPatientPage(
            onRegistered: (visit) {
              setState(() => index = 0);
              _openVisit(visit);
            },
          ),
          const AdminAccountPage(),
        ],
      ),
      bottomNavigationBar: StaffBottomNav(
        selectedIndex: index,
        onSelected: (i) => setState(() => index = i),
      ),
    );
  }
}