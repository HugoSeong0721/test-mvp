import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
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
  final TextEditingController _currentStatusController =
      TextEditingController();
  final TextEditingController _actionGuideController = TextEditingController();

  bool _initialized = false;
  bool _showGuide = false;

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

  void _openVisitDetail(
    ScheduledVisit targetVisit,
    List<ScheduledVisit> history,
  ) {
    Navigator.pushNamed(
      context,
      PatientBriefScreen.routeName,
      arguments: PatientHistoryArgs(current: targetVisit, history: history),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final arg = ModalRoute.of(context)?.settings.arguments;
    final historyArgs = arg is PatientHistoryArgs ? arg : null;

    if (historyArgs == null) {
      return Scaffold(
        body: Center(
          child: Text(
            lang.tr('Unable to load the patient record.', '환자 기록을 불러오지 못했습니다.'),
          ),
        ),
      );
    }

    final current = historyArgs.current;
    final patient = current.profile;
    final visit = current.visit;
    final history = historyArgs.history;
    final grouped = _buildGroupedMap(visit.qaList);
    final coveredCount = grouped.values
        .where((items) => items.isNotEmpty)
        .length;
    final unasked = _categoryOrder
        .where((category) => grouped[category]!.isEmpty)
        .toList();
    final previousVisit = history
        .where((item) => item.visit.id != visit.id)
        .cast<ScheduledVisit?>()
        .firstWhere((item) => item != null, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Patient Detail Brief', '환자 상세 브리핑')),
        actions: [
          const LanguageMenuButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(label: Text(lang.tr('Practitioner View', '침술사 화면'))),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_showGuide) ...[
            AppPanel(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Patient detail brief', '환자 상세 브리핑'),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppTheme.ink),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: lang.tr('Hide guide', '가이드 숨기기'),
                        onPressed: () => setState(() => _showGuide = false),
                        icon: const Icon(Icons.close),
                        color: AppTheme.ink.withValues(alpha: 0.72),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppGuideStep(
                        dark: false,
                        step: '1',
                        title: lang.tr('History', '이력'),
                        description: lang.tr('Visits and notes', '방문/메모'),
                      ),
                      AppGuideStep(
                        dark: false,
                        step: '2',
                        title: lang.tr('Intake', '문진'),
                        description: lang.tr('Categories', '카테고리'),
                      ),
                      AppGuideStep(
                        dark: false,
                        step: '3',
                        title: lang.tr('Notes', '메모'),
                        description: lang.tr('Plan and share', '계획/공유'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppPanel(
            padding: const EdgeInsets.all(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.94),
                AppTheme.blush.withValues(alpha: 0.34),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BriefBadge(
                      icon: Icons.visibility_outlined,
                      label: lang.tr('Current visit', '이번 방문'),
                    ),
                    _BriefBadge(
                      icon: Icons.schedule_outlined,
                      label: lang.tr(
                        'Intake status: ${visit.intakeStatus.label}',
                        '문진 상태: ${visit.intakeStatus.label}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${patient.name} · ${_formatStoredDateWithWeekday(visit.date)} ${visit.time}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.person_outline,
                      text:
                          '${lang.tr('Patient info', '환자 정보')}: ${patient.sex}, ${patient.ageRange}, ${patient.ethnicity}',
                    ),
                    _InfoChip(
                      icon: Icons.history_toggle_off,
                      text: lang.tr(
                        'Reference last visit: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${_formatDaysAgo(visit.daysAgo)})',
                        '참고 지난 방문: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${_formatDaysAgo(visit.daysAgo)})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: previousVisit == null
                      ? Text(lang.tr('No earlier visits', '이전 방문 없음'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Last completed visit', '지난 방문 바로 보기'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${previousVisit.profile.name} · ${_formatStoredDateWithWeekday(previousVisit.visit.date)} ${previousVisit.visit.time}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${lang.tr('Treatment area', '치료 부위')}: ${previousVisit.visit.previousTreatmentArea}',
                            ),
                            Text(
                              '${lang.tr('Session note', '세션 메모')}: ${previousVisit.visit.previousSessionNote}',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openVisitDetail(previousVisit, history),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(lang.tr('Last visit', '지난 방문')),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr(
                    '1. Full Visit History (${history.length} visits)',
                    '1. 전체 방문 이력 (${history.length}회)',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  lang.tr(
                    'Current visit is highlighted.',
                    '현재 강조된 카드가 지금 이 화면이 다루는 이번 방문입니다. 이전 방문은 각각 상세로 열 수 있습니다.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 14),
                ...history.map((item) {
                  final preview = item.visit.qaList.isEmpty
                      ? lang.tr('No intake record', '문진 기록 없음')
                      : '${item.visit.qaList.first.question} / ${item.visit.qaList.first.answer}';
                  final isCurrentVisit = item.visit.id == visit.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrentVisit
                            ? AppTheme.mint.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentVisit
                              ? AppTheme.jade.withValues(alpha: 0.45)
                              : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_formatStoredDateWithWeekday(item.visit.date)} · ${item.visit.time}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(
                                  isCurrentVisit
                                      ? lang.tr('Current visit', '이번 방문')
                                      : lang.tr('Previous visit', '이전 방문'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${lang.tr('Treatment area', '치료 부위')}: ${item.visit.previousTreatmentArea}',
                          ),
                          Text(
                            '${lang.tr('Notes', '메모')}: ${item.visit.previousSessionNote}',
                          ),
                          Text('${lang.tr('Summary', '요약')}: $preview'),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: isCurrentVisit
                                  ? null
                                  : () => _openVisitDetail(item, history),
                              icon: Icon(
                                isCurrentVisit
                                    ? Icons.visibility
                                    : Icons.open_in_new,
                              ),
                              label: Text(
                                isCurrentVisit
                                    ? lang.tr('Viewing now', '현재 보고 있음')
                                    : lang.tr('Open', '열기'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr(
                    '2. Category coverage: $coveredCount / ${_categoryOrder.length}',
                    '2. 카테고리 커버리지: $coveredCount / ${_categoryOrder.length}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  lang.tr(
                    'Total questions in this current visit: ${visit.qaList.length}',
                    '이번 방문 문진 총 질문 수: ${visit.qaList.length}',
                  ),
                ),
                if (unasked.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    lang.tr(
                      'Categories not asked yet: ${unasked.join(', ')}',
                      '아직 묻지 않은 카테고리: ${unasked.join(', ')}',
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lang.tr('3. 10-Category Intake', '3. 10개 카테고리 문진'),
            style: Theme.of(context).textTheme.titleLarge,
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
                      '$category (${list.length} ${lang.tr('questions', '질문')})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      Text(
                        lang.tr('No questions', '질문 없음'),
                        style: const TextStyle(color: Colors.black54),
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
            title: lang.tr(
              '4. Previous Visit Record (Private)',
              '4. 이전 방문 기록 (내부용)',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lang.tr('Previous treatment area', '이전 치료 부위')}: ${visit.previousTreatmentArea}',
                ),
                const SizedBox(height: 6),
                Text(
                  '${lang.tr('Previous notes', '이전 메모')}: ${visit.previousSessionNote}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: lang.tr('5. This Visit Notes', '5. 이번 방문 메모'),
            child: Column(
              children: [
                TextField(
                  controller: _thisSessionTreatmentAreaController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr(
                      'Treatment area for this visit',
                      '이번 방문 치료 부위',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _thisSessionMemoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr(
                      'Session notes for this visit',
                      '이번 방문 세션 메모',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nextObservationController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr(
                      'What to observe at the next visit',
                      '다음 방문에서 확인할 점',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: lang.tr('6. Advice / Follow-Up', '6. 안내 / 후속 확인'),
            child: Column(
              children: [
                TextField(
                  controller: _adviceGivenController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr('Advice given this time', '이번에 준 안내'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adherenceFollowupController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr(
                      'What to review for adherence next visit',
                      '다음 방문 때 순응도 확인 포인트',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: lang.tr(
              '7. Shared Notes (Visible to Patient)',
              '7. 환자 공유 메모',
            ),
            child: Column(
              children: [
                TextField(
                  controller: _patientAlertController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr('Patient alert', '환자 알림'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weeklyMustDoController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr(
                      'What to follow carefully this week',
                      '이번 주 꼭 지켜야 할 점',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentStatusController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr('Status note', '상태 메모'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _actionGuideController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: lang.tr('Next step', '다음 단계'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('visit_record_feedback')
                .doc(
                  AppFirestoreService.visitFeedbackDocumentId(
                    patientId: patient.id,
                    visitId: visit.id,
                  ),
                )
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final feedbackText = (data?['feedbackText'] ?? '')
                  .toString()
                  .trim();
              final hasFeedback = feedbackText.isNotEmpty;
              final isReviewed = data?['status'] == 'reviewed';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('8. Visit feedback', '8. 방문 피드백'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (!hasFeedback)
                        Text(lang.tr('No feedback', '피드백 없음'))
                      else ...[
                        Text(
                          '${lang.tr('Status', '상태')}: ${isReviewed ? lang.tr('Reviewed', '검토 완료') : lang.tr('Pending', '대기')}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${lang.tr('Submitted At', '제출 시각')}: ${_formatFeedbackTimestamp(data?['submittedAt'] as Timestamp?)}',
                        ),
                        if (data?['reviewedAt'] != null)
                          Text(
                            '${lang.tr('Reviewed At', '검토 시각')}: ${_formatFeedbackTimestamp(data?['reviewedAt'] as Timestamp?)}',
                          ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(feedbackText),
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
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          lang.tr(
                                            'Marked as reviewed. The patient can now see that you checked it.',
                                            '검토 완료로 표시했습니다. 이제 환자도 확인된 상태를 볼 수 있습니다.',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: Text(
                              isReviewed
                                  ? lang.tr('Already Reviewed', '이미 검토 완료')
                                  : lang.tr('Mark as Reviewed', '검토 완료로 표시'),
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
            label: Text(lang.tr('Save Notes', '메모 저장')),
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
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatDaysAgo(int daysAgo) {
    return AppLanguageController.instance.tr(
      '$daysAgo days ago',
      '$daysAgo일 전',
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseStoredDate(String value) {
    try {
      final parts = value.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _weekdayShort(DateTime date) {
    const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const korean = ['월', '화', '수', '목', '금', '토', '일'];
    return AppLanguageController.instance.tr(
      english[date.weekday - 1],
      korean[date.weekday - 1],
    );
  }

  String _formatDateWithWeekday(DateTime date) {
    return '${_formatDate(date)} (${_weekdayShort(date)})';
  }

  String _formatStoredDateWithWeekday(String value) {
    final parsed = _parseStoredDate(value);
    if (parsed == null) {
      return value;
    }
    return _formatDateWithWeekday(parsed);
  }

  Widget _buildMemoCard({required String title, required Widget child}) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
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

class _BriefBadge extends StatelessWidget {
  const _BriefBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.pine.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.pine),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.pine),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.76),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
