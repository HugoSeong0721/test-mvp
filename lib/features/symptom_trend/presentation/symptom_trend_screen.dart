import 'package:flutter/material.dart';

class SymptomTrendScreen extends StatelessWidget {
  const SymptomTrendScreen({super.key});

  static const routeName = '/symptom-trend';

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final data = arg is SymptomTrendPageArgs ? arg : const SymptomTrendPageArgs.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('유사증상 주별 추세'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('침술사 화면'))),
          ),
        ],
      ),
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
                      'W-3   W-2   W-1   이번주',
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
      : periodLabel = '데이터 없음',
        weekly = const {
          '수면/각성': [0, 0, 0, 0],
          '목/어깨 통증': [0, 0, 0, 0],
          '소화 불편': [0, 0, 0, 0],
        };

  final String periodLabel;
  final Map<String, List<int>> weekly;
}
