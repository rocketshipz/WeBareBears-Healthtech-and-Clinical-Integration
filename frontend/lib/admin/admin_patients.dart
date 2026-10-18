import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'admin_queue.dart';

class PatientsPage extends StatefulWidget {
  final ValueChanged<Visit> onOpenVisit;
  const PatientsPage({super.key, required this.onOpenVisit});
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: GradientBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: adminStore,
          builder: (context, _) {
            final search = query.trim().toLowerCase();
            final patients =
                adminStore.assignedPatients
                    .where(
                      (v) => '${v.name} ${v.ic} ${v.queueNo}'
                          .toLowerCase()
                          .contains(search),
                    )
                    .toList()
                  ..sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const BrandWordmark(size: 28),
                    const SizedBox(height: 26),
                    Text('Patients', style: AppText.display),
                    const SizedBox(height: 8),
                    Text(
                      'Patients checked in under your care, including completed visits.',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      onChanged: (value) => setState(() => query = value),
                      decoration: appInputDecoration(
                        hint: 'Search name, queue number or IC',
                        icon: Icons.search_rounded,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${patients.length} patients',
                      style: AppText.bodyStrong,
                    ),
                    const SizedBox(height: 16),
                    if (patients.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: cardDecoration(),
                        child: Text(
                          search.isEmpty
                              ? 'No patients assigned yet. Check in a patient to start.'
                              : 'No patients match your search.',
                          style: AppText.body,
                        ),
                      ),
                    for (final patient in patients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PatientVisitCard(
                          visit: patient,
                          onTap: () => widget.onOpenVisit(patient),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
