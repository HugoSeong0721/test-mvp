import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
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
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;

  PatientProfile get _currentProfile =>
      _authBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history => _store.historyForPatient(_currentProfile.id);

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      await _profileSubscription?.cancel();
      if (user == null) {
        if (mounted) {
          setState(() => _authBackedProfile = null);
        }
        return;
      }

      await PatientProfileService.ensureProfileForUser(user);
      _profileSubscription = PatientProfileService.watchProfile(user.uid).listen((profile) {
        if (!mounted || profile == null) {
          return;
        }
        setState(() => _authBackedProfile = profile);
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitFeedback({
    required ScheduledVisit scheduledVisit,
    required String feedbackText,
  }) async {
    final lang = AppLanguageController.instance;
    if (feedbackText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr('Please enter your update before sending.', '보내기 전에 수정 또는 추가 내용을 입력해주세요.')),
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
          content: Text(lang.tr('Your update was sent to the practitioner.', '수정/추가 내용이 침술사에게 전달되었습니다.')),
        ),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.tr('The practitioner already reviewed this visit, so editing is locked.', '침술사가 이미 확인해서 더 이상 수정할 수 없습니다.')),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _HistorySummaryChip(
                            label: lang.tr('Total Visits', '총 방문'),
                            value: '${history.length}',
                          ),
                          _HistorySummaryChip(
                            label: lang.tr('Last Visit', '최근 방문'),
                            value: lastVisit == null ? '-' : lastVisit.date,
                          ),
                          _HistorySummaryChip(
                            label: lang.tr('Most Recent Status', '최근 상태'),
                            value: lastVisit == null ? '-' : lastVisit.intakeStatus.label,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      lang.tr('No visit history is available yet.', '아직 방문 기록이 없습니다.'),
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
                          .doc(AppFirestoreService.visitFeedbackDocumentId(
                            patientId: profile.id,
                            visitId: visit.id,
                          ))
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final isReviewed = (data?['status'] == 'reviewed');
                        final hasFeedback = data != null && ((data['feedbackText'] ?? '') as String).trim().isNotEmpty;
                        final controller = _controllerFor(
                          visit.id,
                          hasFeedback ? (data['feedbackText'] as String? ?? '') : '',
                        );
                        if (hasFeedback && controller.text.trim().isEmpty) {
                          controller.text = data['feedbackText'] as String? ?? '';
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
                                        '${visit.date} · ${visit.time}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Chip(label: Text(visit.intakeStatus.label)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${lang.tr('Last Visit Before This', '그 전 방문')}: ${visit.lastVisitDate} (${visit.daysAgo} ${lang.tr('days ago', '일 전')})'),
                                Text('${lang.tr('Treatment Focus', '치료 부위')}: ${visit.previousTreatmentArea}'),
                                const SizedBox(height: 10),
                                Text(
                                  lang.tr('Session Note', '세션 메모'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(visit.previousSessionNote),
                                const SizedBox(height: 12),
                                Text(
                                  lang.tr('Question / Answer Snapshot', '질문 / 답변 요약'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                if (visit.qaList.isEmpty)
                                  Text(lang.tr('No intake answers were saved for this visit.', '이 방문에는 저장된 문진 답변이 없습니다.'))
                                else
                                  ...visit.qaList.map(
                                    (qa) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '[${qa.category}] ${qa.question}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
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
                                    border: Border.all(color: const Color(0xFFD7EAE6)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lang.tr('Request a Record Update', '방문기록 수정/추가 요청'),
                                              style: const TextStyle(fontWeight: FontWeight.w700),
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
                                          labelText: lang.tr('Your correction / additional note', '수정 또는 추가 메모'),
                                          helperText: isReviewed
                                              ? lang.tr('Editing is now locked because the practitioner reviewed this update.', '침술사가 확인해서 더 이상 수정할 수 없습니다.')
                                              : lang.tr('You can update this message until the practitioner marks it as reviewed.', '침술사가 확인 처리하기 전까지는 수정해서 다시 보낼 수 있습니다.'),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (hasFeedback) ...[
                                        Text('${lang.tr('Sent at', '보낸 시각')}: ${_formatTimestamp(data['submittedAt'] as Timestamp?)}'),
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
                                          onPressed: isReviewed || _submittingVisitIds.contains(visit.id)
                                              ? null
                                              : () => _submitFeedback(
                                                    scheduledVisit: scheduledVisit,
                                                    feedbackText: controller.text,
                                                  ),
                                          icon: const Icon(Icons.send_outlined),
                                          label: Text(
                                            _submittingVisitIds.contains(visit.id)
                                                ? lang.tr('Sending...', '보내는 중...')
                                                : lang.tr('Send to Practitioner', '침술사에게 보내기'),
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
