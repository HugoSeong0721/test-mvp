import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  static const routeName = '/patient-history';

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  final Map<String, TextEditingController> _feedbackControllers = {};
  final Set<String> _submittingVisitIds = <String>{};
  StreamSubscription<PatientSession?>? _sessionSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _sessionBackedProfile;

  PatientProfile get _currentProfile =>
      _sessionBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history =>
      _store.historyForPatient(_currentProfile.id);

  @override
  void initState() {
    super.initState();
    _sessionSubscription = BetaSessionService.watchSession().listen((
      session,
    ) async {
      await _profileSubscription?.cancel();
      if (session == null) {
        if (mounted) {
          setState(() => _sessionBackedProfile = null);
        }
        return;
      }

      await PatientProfileService.ensureProfileForSession(session);
      _profileSubscription =
          PatientProfileService.watchProfileForSession(session).listen((
            profile,
          ) {
            if (!mounted || profile == null) {
              return;
            }
            setState(() => _sessionBackedProfile = profile);
          });
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _profileSubscription?.cancel();
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String visitId, String initialText) {
    return _feedbackControllers.putIfAbsent(visitId, () {
      return TextEditingController(text: initialText);
    });
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

  String _formatVisitSlot(String date, String time) {
    return '${_formatStoredDateWithWeekday(date)} · $time';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDateWithWeekday(date)} $hour:$minute';
  }

  Future<void> _submitFeedback({
    required ScheduledVisit scheduledVisit,
    required String feedbackText,
  }) async {
    final lang = AppLanguageController.instance;
    if (feedbackText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Please enter your update before sending.',
              '보내기 전에 수정 또는 추가 내용을 입력해주세요.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _submittingVisitIds.add(scheduledVisit.visit.id));
    try {
      await AppFirestoreService.submitVisitRecordFeedback(
        patientId: scheduledVisit.profile.id,
        patientName: scheduledVisit.profile.name,
        visitId: scheduledVisit.visit.id,
        visitDate: scheduledVisit.visit.date,
        visitTime: scheduledVisit.visit.time,
        feedbackText: feedbackText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Your update was sent to the practitioner.',
              '수정/추가 내용이 침술사에게 전달되었습니다.',
            ),
          ),
        ),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'The practitioner already reviewed this visit, so editing is locked.',
              '침술사가 이미 확인해서 더 이상 수정할 수 없습니다.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingVisitIds.remove(scheduledVisit.visit.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final profile = _currentProfile;
        final history = _history;
        final lastVisit = history.isNotEmpty ? history.first.visit : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(lang.tr('Visit History', '방문 기록')),
            actions: const [LanguageMenuButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppPanel(
                padding: const EdgeInsets.all(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.pine, AppTheme.jade, Color(0xFF2E7A66)],
                ),
                borderColor: Colors.white24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      lang.tr(
                        'Use this page in order: review the session note, compare it with your memory, then send a correction only if something should be updated.',
                        '이 화면은 세션 메모 확인, 기억과 비교, 필요한 경우 수정 요청 전송 순서로 보면 가장 쉽습니다.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _HistorySummaryChip(
                          label: lang.tr('Total Visits', '총 방문'),
                          value: '${history.length}',
                          dark: true,
                        ),
                        _HistorySummaryChip(
                          label: lang.tr('Last Visit', '최근 방문'),
                          value: lastVisit == null
                              ? '-'
                              : _formatStoredDateWithWeekday(lastVisit.date),
                          dark: true,
                        ),
                        _HistorySummaryChip(
                          label: lang.tr('Most Recent Status', '최근 상태'),
                          value: lastVisit == null
                              ? '-'
                              : lastVisit.intakeStatus.label,
                          dark: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppGuideStep(
                          dark: true,
                          step: '1',
                          title: lang.tr('Read the visit note', '방문 메모 읽기'),
                          description: lang.tr(
                            'Start with the treatment focus and session note at the top of each visit card.',
                            '각 방문 카드 상단의 치료 부위와 세션 메모부터 읽어보세요.',
                          ),
                        ),
                        AppGuideStep(
                          dark: true,
                          step: '2',
                          title: lang.tr('Check Q&A snapshot', '질문/답변 보기'),
                          description: lang.tr(
                            'Then review what symptoms and answers were saved for that visit.',
                            '그 다음 저장된 증상 질문과 답변을 확인하세요.',
                          ),
                        ),
                        AppGuideStep(
                          dark: true,
                          step: '3',
                          title: lang.tr(
                            'Send an update if needed',
                            '필요 시 수정 요청',
                          ),
                          description: lang.tr(
                            'Only use the update box if something is missing or incorrect.',
                            '빠진 내용이나 다른 점이 있을 때만 수정 요청 칸을 사용하세요.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      lang.tr(
                        'No visit history is available yet.',
                        '아직 방문 기록이 없습니다.',
                      ),
                    ),
                  ),
                )
              else
                ...history.map((scheduledVisit) {
                  final visit = scheduledVisit.visit;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('visit_record_feedback')
                          .doc(
                            AppFirestoreService.visitFeedbackDocumentId(
                              patientId: profile.id,
                              visitId: visit.id,
                            ),
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final isReviewed = (data?['status'] == 'reviewed');
                        final hasFeedback =
                            data != null &&
                            ((data['feedbackText'] ?? '') as String)
                                .trim()
                                .isNotEmpty;
                        final controller = _controllerFor(
                          visit.id,
                          hasFeedback
                              ? (data['feedbackText'] as String? ?? '')
                              : '',
                        );
                        if (hasFeedback && controller.text.trim().isEmpty) {
                          controller.text =
                              data['feedbackText'] as String? ?? '';
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatVisitSlot(
                                          visit.date,
                                          visit.time,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Chip(label: Text(visit.intakeStatus.label)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${lang.tr('Last Visit Before This', '그 전 방문')}: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${visit.daysAgo} ${lang.tr('days ago', '일 전')})',
                                ),
                                Text(
                                  '${lang.tr('Treatment Focus', '치료 부위')}: ${visit.previousTreatmentArea}',
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  lang.tr('Session Note', '세션 메모'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(visit.previousSessionNote),
                                const SizedBox(height: 12),
                                Text(
                                  lang.tr(
                                    'Question / Answer Snapshot',
                                    '질문 / 답변 요약',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (visit.qaList.isEmpty)
                                  Text(
                                    lang.tr(
                                      'No intake answers were saved for this visit.',
                                      '이 방문에는 저장된 문진 답변이 없습니다.',
                                    ),
                                  )
                                else
                                  ...visit.qaList.map(
                                    (qa) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '[${qa.category}] ${qa.question}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(qa.answer),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FBFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFD7EAE6),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lang.tr(
                                                'Request a Record Update',
                                                '방문기록 수정/추가 요청',
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              isReviewed
                                                  ? lang.tr('Reviewed', '확인 완료')
                                                  : hasFeedback
                                                  ? lang.tr('Sent', '보냄')
                                                  : lang.tr('Not sent', '미전송'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        lang.tr(
                                          'If anything looks different from your memory, or if you want to add something you could not mention earlier, write it here for the practitioner.',
                                          '기억과 다른 부분이 있거나 미처 못한 말이 있으면 여기 적어서 침술사에게 전달하세요.',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: controller,
                                        enabled: !isReviewed,
                                        minLines: 4,
                                        maxLines: 6,
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: lang.tr(
                                            'Your correction / additional note',
                                            '수정 또는 추가 메모',
                                          ),
                                          helperText: isReviewed
                                              ? lang.tr(
                                                  'Editing is now locked because the practitioner reviewed this update.',
                                                  '침술사가 확인해서 더 이상 수정할 수 없습니다.',
                                                )
                                              : lang.tr(
                                                  'You can update this message until the practitioner marks it as reviewed.',
                                                  '침술사가 확인 처리하기 전까지는 수정해서 다시 보낼 수 있습니다.',
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (hasFeedback) ...[
                                        Text(
                                          '${lang.tr('Sent at', '보낸 시각')}: ${_formatTimestamp(data['submittedAt'] as Timestamp?)}',
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        isReviewed
                                            ? '${lang.tr('Practitioner status', '침술사 상태')}: ${lang.tr('Reviewed', '확인 완료')} · ${_formatTimestamp(data?['reviewedAt'] as Timestamp?)}'
                                            : '${lang.tr('Practitioner status', '침술사 상태')}: ${lang.tr('Not reviewed yet', '아직 확인 전')}',
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.icon(
                                          onPressed:
                                              isReviewed ||
                                                  _submittingVisitIds.contains(
                                                    visit.id,
                                                  )
                                              ? null
                                              : () => _submitFeedback(
                                                  scheduledVisit:
                                                      scheduledVisit,
                                                  feedbackText: controller.text,
                                                ),
                                          icon: const Icon(Icons.send_outlined),
                                          label: Text(
                                            _submittingVisitIds.contains(
                                                  visit.id,
                                                )
                                                ? lang.tr(
                                                    'Sending...',
                                                    '보내는 중...',
                                                  )
                                                : lang.tr(
                                                    'Send to Practitioner',
                                                    '침술사에게 보내기',
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _HistorySummaryChip extends StatelessWidget {
  const _HistorySummaryChip({
    required this.label,
    required this.value,
    this.dark = false,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: dark ? Border.all(color: Colors.white24) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }
}
