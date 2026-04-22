import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';

class PatientBriefScreen extends StatefulWidget {
  const PatientBriefScreen({super.key});

  static const routeName = '/brief';

  @override
  State<PatientBriefScreen> createState() => _PatientBriefScreenState();
}

class _PatientBriefScreenState extends State<PatientBriefScreen> {
  static const List<String> _categoryOrder = [
    'Temperature/Sweat',
    'Appetite/Thirst',
    'Sleep',
    'Digestion',
    'Urine',
    'Stool',
    'Menses',
    'HEENT',
    'Emotion',
    'Energy',
  ];

  final TextEditingController _thisSessionTreatmentAreaController =
      TextEditingController();
  final TextEditingController _thisSessionMemoController =
      TextEditingController();
  final TextEditingController _nextObservationController =
      TextEditingController();
  final TextEditingController _adviceGivenController = TextEditingController();
  final TextEditingController _adherenceFollowupController =
      TextEditingController();
  final TextEditingController _patientAlertController = TextEditingController();
  final TextEditingController _weeklyMustDoController = TextEditingController();
  final TextEditingController _currentStatusController = TextEditingController();
  final TextEditingController _actionGuideController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _adviceGivenController.text =
        'Reduce caffeine before bed and do 5 minutes of shoulder stretching.';
    _adherenceFollowupController.text =
        'At the next visit, review how often the stretching routine was followed.';
    _patientAlertController.text =
        'This week, sleep and fatigue changes are the main things to watch.';
    _weeklyMustDoController.text =
        'Stretch at least 4 days this week, 1 hour before bed.';
    _currentStatusController.text =
        'Right now, decreased sleep quality and shoulder tension appear together.';
    _actionGuideController.text =
        'Prioritize a low-intensity relaxation routine over intense exercise.';
  }

  @override
  void dispose() {
    _thisSessionTreatmentAreaController.dispose();
    _thisSessionMemoController.dispose();
    _nextObservationController.dispose();
    _adviceGivenController.dispose();
    _adherenceFollowupController.dispose();
    _patientAlertController.dispose();
    _weeklyMustDoController.dispose();
    _currentStatusController.dispose();
    _actionGuideController.dispose();
    super.dispose();
  }

  void _saveMemos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saved (temporary): database connection will be added in the next step.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final historyArgs = arg is PatientHistoryArgs ? arg : null;

    if (historyArgs == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to load the patient record.')),
      );
    }

    final current = historyArgs.current;
    final patient = current.profile;
    final visit = current.visit;
    final history = historyArgs.history;
    final grouped = _buildGroupedMap(visit.qaList);
    final coveredCount = grouped.values.where((items) => items.isNotEmpty).length;
    final unasked =
        _categoryOrder.where((category) => grouped[category]!.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Patient Detail Brief', '환자 상세 브리핑')),
        actions: [
          const LanguageMenuButton(),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text(lang.tr('Practitioner View', '침술사 화면')))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${patient.name} · ${visit.time}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Last visit: ${visit.lastVisitDate} (${visit.daysAgo} days ago)',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            'Patient info: ${patient.sex}, ${patient.ageRange}, ${patient.ethnicity}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Visit History (${history.length} visits)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((item) {
                    final preview = item.visit.qaList.isEmpty
                        ? 'No intake record'
                        : '${item.visit.qaList.first.question} / ${item.visit.qaList.first.answer}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.visit.date} · ${item.visit.time}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('Treatment area: ${item.visit.previousTreatmentArea}'),
                            Text('Notes: ${item.visit.previousSessionNote}'),
                            Text('Summary: $preview'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category coverage: $coveredCount / ${_categoryOrder.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Total questions: ${visit.qaList.length}'),
                  if (unasked.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Categories not asked yet: ${unasked.join(', ')}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '10-Category Intake',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._categoryOrder.map((category) {
            final list = grouped[category]!;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category (${list.length} questions)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      const Text(
                        'No questions yet',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ...list.map(
                      (qa) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('- Q: ${qa.question}'),
                            Text('  A: ${qa.answer}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          _buildMemoCard(
            title: 'Previous Visit Record (Private)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Previous treatment area: ${visit.previousTreatmentArea}'),
                const SizedBox(height: 6),
                Text('Previous notes: ${visit.previousSessionNote}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: 'This Visit Notes',
            child: Column(
              children: [
                TextField(
                  controller: _thisSessionTreatmentAreaController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Treatment area for this visit',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _thisSessionMemoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Session notes for this visit',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nextObservationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'What to observe at the next visit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: 'Advice / Follow-Up',
            child: Column(
              children: [
                TextField(
                  controller: _adviceGivenController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Advice given this time',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adherenceFollowupController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'What to review for adherence next visit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: 'Shared Notes (Visible to Patient)',
            child: Column(
              children: [
                TextField(
                  controller: _patientAlertController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Patient alert',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weeklyMustDoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'What to follow carefully this week',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentStatusController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Current status note',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _actionGuideController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'What to do next',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('visit_record_feedback')
                .doc(AppFirestoreService.visitFeedbackDocumentId(
                  patientId: patient.id,
                  visitId: visit.id,
                ))
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final hasFeedback = data != null && ((data['feedbackText'] ?? '') as String).trim().isNotEmpty;
              final isReviewed = data?['status'] == 'reviewed';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Patient Visit Record Update Request', '?? ???? ?? ??'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (!hasFeedback)
                        Text(
                          lang.tr('There is no patient correction or follow-up note for this visit yet.', '? ??? ?? ??? ?? ?? ?? ?? ??? ?? ????.'),
                        )
                      else ...[
                        Text('${lang.tr('Status', '??')}: ${isReviewed ? lang.tr('Reviewed', '?? ??') : lang.tr('Pending Review', '?? ??')}'),
                        const SizedBox(height: 6),
                        Text('${lang.tr('Submitted At', '?? ??')}: ${_formatFeedbackTimestamp(data['submittedAt'] as Timestamp?)}'),
                        if (data['reviewedAt'] != null)
                          Text('${lang.tr('Reviewed At', '?? ??')}: ${_formatFeedbackTimestamp(data['reviewedAt'] as Timestamp?)}'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text((data['feedbackText'] ?? '').toString()),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: isReviewed
                                ? null
                                : () async {
                                    await AppFirestoreService.markVisitRecordFeedbackReviewed(
                                      patientId: patient.id,
                                      visitId: visit.id,
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(lang.tr('Marked as reviewed. The patient can now see that you checked it.', '?? ?? ???????. ?? ????? ?? ??? ????.')),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: Text(
                              isReviewed
                                  ? lang.tr('Already Reviewed', '?? ???')
                                  : lang.tr('Mark as Reviewed', '?????'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saveMemos,
            icon: const Icon(Icons.save_outlined),
            label: Text(lang.tr('Save Notes', '?? ??')),
          ),
        ],
      ),
    );
  }

  String _formatFeedbackTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMemoCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Map<String, List<QaItem>> _buildGroupedMap(List<QaItem> qaList) {
    final grouped = {
      for (final category in _categoryOrder) category: <QaItem>[],
    };
    for (final qa in qaList) {
      grouped.putIfAbsent(qa.category, () => <QaItem>[]).add(qa);
    }
    return grouped;
  }
}



