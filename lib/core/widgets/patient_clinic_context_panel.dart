import 'package:flutter/material.dart';

import '../data/clinic_data_store.dart';
import '../settings/app_language_controller.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class PatientClinicContextPanel extends StatelessWidget {
  const PatientClinicContextPanel({
    super.key,
    required this.clinic,
    this.onChooseClinic,
  });

  final ClinicCenter? clinic;
  final VoidCallback? onChooseClinic;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final activeClinic = clinic;

    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              activeClinic == null
                  ? Icons.domain_disabled_outlined
                  : Icons.local_hospital_outlined,
              color: AppTheme.pine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeClinic == null
                      ? lang.tr('No clinic selected', 'No clinic selected')
                      : lang.tr('Current clinic', 'Current clinic'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeClinic?.name ??
                      lang.tr(
                        'Choose a clinic before sending intake, requests, or visit updates.',
                        'Choose a clinic before sending intake, requests, or visit updates.',
                      ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (activeClinic != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      activeClinic.practitionerName,
                      if (activeClinic.location.trim().isNotEmpty)
                        activeClinic.location,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onChooseClinic != null) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onChooseClinic,
              icon: const Icon(Icons.sync_alt_outlined),
              label: Text(
                activeClinic == null
                    ? lang.tr('Choose clinic', 'Choose clinic')
                    : lang.tr('Change', 'Change'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
