import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_account.dart';
import 'admin_models.dart';
import 'patient_detail.dart';
import 'admin_queue.dart';
import 'admin_register.dart';
import 'admin_widgets.dart';
import 'admin_patients.dart';
import 'sync_banner.dart';

/// Main frame for hospital staff: Home / Check-In / Patients / Account.
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
      body: Column(
        children: [
          const StaffSyncBanner(),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                QueuePage(
                  onRegister: () => setState(() => index = 1),
                  onOpenVisit: _openVisit,
                ),
                RegisterPatientPage(
                  onRegistered: (visit) {
                    setState(() => index = 2);
                    _openVisit(visit);
                  },
                ),
                PatientsPage(onOpenVisit: _openVisit),
                const AdminAccountPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StaffBottomNav(
        selectedIndex: index,
        onSelected: (i) => setState(() => index = i),
      ),
    );
  }
}
