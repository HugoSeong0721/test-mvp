import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/practitioner_shell.dart';

class SymptomTrendScreen extends StatelessWidget {
  const SymptomTrendScreen({super.key});

  static const routeName = '/symptom-trend';

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final data = arg is SymptomTrendPageArgs ? arg : const SymptomTrendPageArgs.empty();

    return PractitionerShell(
      currentItem: PractitionerNavItem.symptomTrend,
      title: lang.tr('Symptom Trends', '증상 추세'),
      subtitle: lang.tr('Weekly similar-symptom signals', '주간 유사 증상 신호'),
      actions: const [LanguageMenuButton()],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            data.periodLabel,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          ...data.weekly.entries.map((entry) {
            final values = entry.value;
            final rowMax = values.fold<int>(1, (m, v) => v > m ? v : m).toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: values.map((v) {
                        final ratio = rowMax == 0 ? 0.0 : v / rowMax;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Column(
                              children: [
                                Container(
                                  height: 28 * ratio + 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('$v'),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'W-3   W-2   W-1   This Week',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SymptomTrendPageArgs {
  const SymptomTrendPageArgs({
    required this.periodLabel,
    required this.weekly,
  });

  const SymptomTrendPageArgs.empty()
      : periodLabel = 'No data',
        weekly = const {
          'Sleep / Wakefulness': [0, 0, 0, 0],
          'Neck / Shoulder Pain': [0, 0, 0, 0],
          'Digestive Discomfort': [0, 0, 0, 0],
        };

  final String periodLabel;
  final Map<String, List<int>> weekly;
}



