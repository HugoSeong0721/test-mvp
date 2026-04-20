import 'package:flutter/material.dart';

class PractitionerInsightsScreen extends StatelessWidget {
  const PractitionerInsightsScreen({super.key});

  static const routeName = '/insights';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practitioner Insights Dashboard'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('Practitioner View'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Last 12 Weeks Summary (Demo)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _KpiCard(title: 'Total Visits', value: '148'),
              _KpiCard(title: 'Return Rate', value: '63%'),
              _KpiCard(title: 'Pre-Visit Intake Response Rate', value: '71%'),
              _KpiCard(title: 'No-Show Rate', value: '9%'),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Patient Mix'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Gender: Female 58% · Male 39% · Other/No Response 3%'),
                  SizedBox(height: 4),
                  Text('Age Range: 20s 18% · 30s 33% · 40s 27% · 50+ 22%'),
                  SizedBox(height: 4),
                  Text('Race/Cultural Background: East Asian 41% · White 29% · Hispanic 15% · Black 9% · Other 6%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Most Common Symptom Trends'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _TrendRow('Poor Sleep / Early Morning Waking', 42),
                  _TrendRow('Neck / Shoulder Pain', 38),
                  _TrendRow('Digestive Discomfort / Reflux', 31),
                  _TrendRow('Headache / Eye Fatigue (HEENT)', 27),
                  _TrendRow('Low Energy / Fatigue', 25),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Most Common Advice Given'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _AdviceRow('Bedtime Stretching / Breathing Routine', 36, 63),
                  _AdviceRow('Adjust Caffeine Timing', 30, 57),
                  _AdviceRow('10-Minute Walk After Meals', 26, 52),
                  _AdviceRow('Hydration Pattern Adjustment', 19, 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Product Opportunity Insights (For Practitioner)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('1) Sleep + pain tracking card: high priority because repeat visits often cluster here'),
                  SizedBox(height: 6),
                  Text('2) Personalized reminder templates: clear room to improve pre-visit intake response rate'),
                  SizedBox(height: 6),
                  Text('3) Advice adherence checklist: useful for capturing behavior data tied to return visits'),
                  SizedBox(height: 6),
                  Text('4) Missing-category warning (based on the 10-question system): helps improve diagnostic consistency'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final width = (count / 45).clamp(0.1, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ($count)'),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: width,
            child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(99))),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow(this.label, this.count, this.followupRate);

  final String label;
  final int count;
  final int followupRate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('Recommended $count times · Follow-through $followupRate%'),
        ],
      ),
    );
  }
}
