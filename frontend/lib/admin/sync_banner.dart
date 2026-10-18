import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';

class StaffSyncBanner extends StatelessWidget {
  const StaffSyncBanner({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: adminStore.syncError,
    builder: (context, error, _) => error == null
        ? const SizedBox.shrink()
        : Material(
            color: AppColors.paleTeal,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(error, style: AppText.bodyStrong)),
                    TextButton(
                      onPressed: () async {
                        adminStore.syncError.value = null;
                        await adminStore.refresh();
                        if (context.mounted &&
                            adminStore.syncError.value == null) {
                          showAppSnack(
                            context,
                            'Reloaded saved progress. Check the timeline before editing again.',
                          );
                        }
                      },
                      child: const Text('Reload'),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
