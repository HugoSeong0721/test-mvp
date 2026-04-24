import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';

class PatientRecordWorkspace extends StatefulWidget {
  const PatientRecordWorkspace({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final PatientProfile profile;
  final ValueChanged<PatientProfile> onSave;

  @override
  State<PatientRecordWorkspace> createState() => _PatientRecordWorkspaceState();
}

class _PatientRecordWorkspaceState extends State<PatientRecordWorkspace> {
  final ClinicDataStore _store = ClinicDataStore.instance;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _birthYearController;
  late TextEditingController _sexController;
  late TextEditingController _ethnicityController;
  late TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant PatientRecordWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.profile.name);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _emailController = TextEditingController(text: widget.profile.email);
    _birthYearController = TextEditingController(
      text: widget.profile.birthYear.toString(),
    );
    _sexController = TextEditingController(text: widget.profile.sex);
    _ethnicityController = TextEditingController(
      text: widget.profile.ethnicity,
    );
    _memoController = TextEditingController(text: widget.profile.memo);
  }

  void _disposeControllers() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthYearController.dispose();
    _sexController.dispose();
    _ethnicityController.dispose();
    _memoController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final profile = widget.profile;
    final history = _store.historyForPatient(profile.id);
    final completedVisits = history
        .where((item) => item.visit.intakeStatus == IntakeStatus.completed)
        .length;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('answer_requests')
          .where('patientId', isEqualTo: profile.id)
          .snapshots(),
      builder: (context, requestSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('intake_submissions')
              .where('patientId', isEqualTo: profile.id)
              .snapshots(),
          builder: (context, submissionSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('visit_record_feedback')
                  .where('patientId', isEqualTo: profile.id)
                  .snapshots(),
              builder: (context, feedbackSnapshot) {
                final requestDocs = _sortDocsByTimestamp(
                  requestSnapshot.data?.docs ?? const [],
                  'requestedAt',
                );
                final submissionDocs = _sortDocsByTimestamp(
                  submissionSnapshot.data?.docs ?? const [],
                  'submittedAt',
                );
                final feedbackDocs = _sortDocsByTimestamp(
                  feedbackSnapshot.data?.docs ?? const [],
                  'updatedAt',
                );
                final pendingFeedbackCount = feedbackDocs
                    .where(
                      (doc) =>
                          (doc.data()['status'] ?? 'pending') != 'reviewed',
                    )
                    .length;
                final feedbackByVisitId = <String, Map<String, dynamic>>{};
                for (final doc in feedbackDocs) {
                  final data = doc.data();
                  final visitId = (data['visitId'] ?? '').toString();
                  if (visitId.isNotEmpty &&
                      !feedbackByVisitId.containsKey(visitId)) {
                    feedbackByVisitId[visitId] = data;
                  }
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppPanel(
                        padding: const EdgeInsets.all(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.pine,
                            AppTheme.jade,
                            Color(0xFF2A7A66),
                          ],
                        ),
                        borderColor: Colors.white24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Unified patient chart', '통합 환자 차트'),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.74),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                'Use this as the single place to review demographics, visit-by-visit notes, pre-visit intake behavior, patient feedback, and your internal note.',
                                '기본 정보, 방문별 기록, 사전문진 패턴, 환자 피드백, 내 메모를 한 곳에서 보는 공용 환자 차트입니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AppMetricChip(
                                  icon: Icons.badge_outlined,
                                  label: lang.tr('Basic profile', '기본 프로필'),
                                  value:
                                      '${profile.sex} · ${profile.ageRange} · ${profile.ethnicity}',
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.74,
                                  ),
                                  valueColor: Colors.white,
                                ),
                                AppMetricChip(
                                  icon: Icons.history_outlined,
                                  label: lang.tr('Visits', '방문 수'),
                                  value: '${history.length}',
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.74,
                                  ),
                                  valueColor: Colors.white,
                                ),
                                AppMetricChip(
                                  icon: Icons.assignment_turned_in_outlined,
                                  label: lang.tr('Completed intakes', '완료 문진'),
                                  value: '$completedVisits',
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.74,
                                  ),
                                  valueColor: Colors.white,
                                ),
                                AppMetricChip(
                                  icon: Icons.mark_email_unread_outlined,
                                  label: lang.tr('Pending feedback', '미확인 피드백'),
                                  value: '$pendingFeedbackCount',
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.74,
                                  ),
                                  valueColor: Colors.white,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    '${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? lang.tr('Missing', '미입력') : profile.phone}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    '${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? lang.tr('Missing', '미입력') : profile.email}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    '${lang.tr('Internal note', '내 메모')}: ${profile.memo.trim().isEmpty ? lang.tr('No internal note yet', '아직 메모 없음') : profile.memo.trim()}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                '1. Basic profile and my note',
                                '1. 기본 정보와 내 메모',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.tr(
                                'Keep demographics, contact information, and your standing note about this patient in sync here.',
                                '환자 기본 정보, 연락처, 그리고 이 환자에 대한 상시 메모를 여기서 함께 관리합니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.66),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: lang.tr('Name', '이름'),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Phone', '전화번호'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Email', '이메일'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _birthYearController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Birth Year', '출생연도'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _sexController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Sex / Gender', '성별'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _ethnicityController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Ethnicity', '인종/민족'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _memoController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: lang.tr(
                                  'My standing note about this patient',
                                  '이 환자에 대한 내 메모',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _saveProfile,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                lang.tr('Save patient profile', '환자 정보 저장'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                '2. Visit-by-visit record timeline',
                                '2. 방문별 전체 기록',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.tr(
                                'Review why the patient came in, what you focused on, what you documented, and whether the patient later sent a correction or follow-up message.',
                                '환자가 어떤 이유로 왔는지, 어떤 치료 포인트를 봤는지, 내가 무엇을 남겼는지, 이후 환자 피드백이 있었는지를 방문별로 확인합니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.66),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (history.isEmpty)
                              _EmptyRecordState(
                                message: lang.tr(
                                  'No visit history is saved for this patient yet.',
                                  '이 환자에게는 아직 저장된 방문 기록이 없습니다.',
                                ),
                              )
                            else
                              ...history.map((item) {
                                final visit = item.visit;
                                final feedback = feedbackByVisitId[visit.id];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceSoft.withValues(
                                        alpha: 0.56,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppTheme.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${_formatStoredDateWithWeekday(visit.date)} ${visit.time}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Chip(
                                              label: Text(
                                                visit.intakeStatus.label,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${lang.tr('Visit reason / treatment focus', '내원 이유 / 치료 포인트')}: ${visit.previousTreatmentArea}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${lang.tr('What I documented', '내가 남긴 기록')}: ${visit.previousSessionNote}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lang.tr(
                                            'Since the last visit: ${visit.scheduledSinceLast} scheduled, ${visit.noShowSinceLast} no-show',
                                            '이전 방문 이후 예약 ${visit.scheduledSinceLast}건, 노쇼 ${visit.noShowSinceLast}건',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          lang.tr(
                                            'Pre-visit intake answers',
                                            '사전문진 답변',
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
                                              '이 방문에는 저장된 사전문진 답변이 없습니다.',
                                            ),
                                          )
                                        else ...[
                                          ...visit.qaList
                                              .take(3)
                                              .map(
                                                (qa) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Text(
                                                    '- [${qa.category}] ${qa.question} / ${qa.answer}',
                                                  ),
                                                ),
                                              ),
                                          if (visit.qaList.length > 3)
                                            Text(
                                              lang.tr(
                                                '+ ${visit.qaList.length - 3} more answers',
                                                '+ ${visit.qaList.length - 3}개 답변 더 있음',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.ink
                                                        .withValues(
                                                          alpha: 0.62,
                                                        ),
                                                  ),
                                            ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          lang.tr(
                                            'Patient feedback about this visit',
                                            '이 방문에 대한 환자 피드백',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (feedback == null ||
                                            (feedback['feedbackText'] ?? '')
                                                .toString()
                                                .trim()
                                                .isEmpty)
                                          Text(
                                            lang.tr(
                                              'No patient correction or follow-up feedback yet.',
                                              '아직 환자 수정 요청이나 후속 피드백이 없습니다.',
                                            ),
                                          )
                                        else ...[
                                          Text(
                                            '${lang.tr('Status', '상태')}: ${_feedbackStatusLabel((feedback['status'] ?? 'pending').toString())}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${lang.tr('Updated', '수정 시각')}: ${_formatTimestamp(feedback['updatedAt'] as Timestamp?)}',
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: AppTheme.border,
                                              ),
                                            ),
                                            child: Text(
                                              (feedback['feedbackText'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                '3. My pre-visit requests and notes',
                                '3. 내가 보낸 사전 요청과 메모',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.tr(
                                'See what you asked this patient before the visit and what note or guidance you sent along with the request.',
                                '방문 전에 어떤 질문을 요청했는지와 함께 보낸 메모를 한 번에 확인합니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.66),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (requestSnapshot.hasError)
                              const _RecordErrorState()
                            else if (!requestSnapshot.hasData)
                              const LinearProgressIndicator(minHeight: 4)
                            else if (requestDocs.isEmpty)
                              _EmptyRecordState(
                                message: lang.tr(
                                  'No practitioner answer requests were saved for this patient yet.',
                                  '이 환자에게 보낸 사전 질문 요청이 아직 없습니다.',
                                ),
                              )
                            else
                              ...requestDocs.map((doc) {
                                final data = doc.data();
                                final selectedQuestions = _safeStringList(
                                  data['selectedQuestions'],
                                );
                                final customByCategory = _safeQuestionMap(
                                  data['customQuestionsByCategory'],
                                );
                                final note = (data['note'] ?? '')
                                    .toString()
                                    .trim();
                                final questionCount =
                                    selectedQuestions.length +
                                    customByCategory.values.fold<int>(
                                      0,
                                      (total, item) => total + item.length,
                                    );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBFE),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFD5E3EF),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTimestamp(
                                            data['requestedAt'] as Timestamp?,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${lang.tr('Requested for visit time', '대상 방문 시간')}: ${(data['patientTime'] ?? '-').toString()}',
                                        ),
                                        Text(
                                          '${lang.tr('Reference last visit', '기준 이전 방문')}: ${_formatStoredDateWithWeekday((data['lastVisitDate'] ?? '-').toString())}',
                                        ),
                                        Text(
                                          '${lang.tr('Requested questions', '요청 질문 수')}: $questionCount',
                                        ),
                                        if (note.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '${lang.tr('My note to the patient', '환자에게 남긴 메모')}: $note',
                                          ),
                                        ],
                                        if (selectedQuestions.isNotEmpty ||
                                            customByCategory.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            lang.tr('Question list', '질문 목록'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...selectedQuestions.map(
                                            (question) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text('- $question'),
                                            ),
                                          ),
                                          ...customByCategory.entries.expand(
                                            (entry) => entry.value.map(
                                              (question) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  '- [${entry.key}] $question',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                '4. How this patient fills pre-visit intake',
                                '4. 이 환자의 사전문진 제출 패턴',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.tr(
                                'Review how often they submit, how many questions they answer, what extra memo they leave, and which answers they mark as important.',
                                '문진을 얼마나 자주 제출하는지, 몇 개를 답하는지, 어떤 추가 메모를 남기는지, 어떤 답변을 중요 표시하는지 확인합니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.66),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (submissionSnapshot.hasError)
                              const _RecordErrorState()
                            else if (!submissionSnapshot.hasData)
                              const LinearProgressIndicator(minHeight: 4)
                            else if (submissionDocs.isEmpty)
                              _EmptyRecordState(
                                message: lang.tr(
                                  'No intake submissions were saved for this patient yet.',
                                  '이 환자의 사전문진 제출 기록이 아직 없습니다.',
                                ),
                              )
                            else
                              ...submissionDocs.map((doc) {
                                final data = doc.data();
                                final answers = _safeAnswerItems(
                                  data['answers'],
                                );
                                final adherence = _safeMap(data['adherence']);
                                final percent =
                                    ((adherence['percent'] as num?)
                                            ?.toDouble() ??
                                        0) *
                                    100;
                                final extraMemo = (data['extraMemo'] ?? '')
                                    .toString()
                                    .trim();
                                final markedMainPainCount = answers
                                    .where(
                                      (item) => item['markedMainPain'] == true,
                                    )
                                    .length;
                                final markedRememberCount = answers
                                    .where(
                                      (item) => item['markedRemember'] == true,
                                    )
                                    .length;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCFAF6),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFE7DCC7),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTimestamp(
                                            data['submittedAt'] as Timestamp?,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${lang.tr('Visit type', '문진 유형')}: ${_visitTypeLabel((data['visitType'] ?? 'follow_up').toString())}',
                                        ),
                                        Text(
                                          '${lang.tr('Answered questions', '답변한 질문 수')}: ${answers.length}',
                                        ),
                                        Text(
                                          '${lang.tr('Completion snapshot', '완료율')}: ${percent.round()}%',
                                        ),
                                        Text(
                                          '${lang.tr('Marked as main concern', '중요 통증 표시')}: $markedMainPainCount · ${lang.tr('Marked to remember', '기억할 내용 표시')}: $markedRememberCount',
                                        ),
                                        if (extraMemo.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '${lang.tr('Extra memo from patient', '환자 추가 메모')}: $extraMemo',
                                          ),
                                        ],
                                        if (answers.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            lang.tr(
                                              'Latest saved answers',
                                              '저장된 답변',
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...answers.take(3).map((item) {
                                            final question =
                                                (item['questionText'] ?? '')
                                                    .toString();
                                            final answer =
                                                (item['answerText'] ?? '')
                                                    .toString();
                                            final flags = <String>[
                                              if (item['markedMainPain'] ==
                                                  true)
                                                lang.tr(
                                                  'Main concern',
                                                  '중요 통증',
                                                ),
                                              if (item['markedRemember'] ==
                                                  true)
                                                lang.tr('Remember', '기억할 것'),
                                            ];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Text(
                                                flags.isEmpty
                                                    ? '- $question / $answer'
                                                    : '- $question / $answer (${flags.join(', ')})',
                                              ),
                                            );
                                          }),
                                          if (answers.length > 3)
                                            Text(
                                              lang.tr(
                                                '+ ${answers.length - 3} more answers',
                                                '+ ${answers.length - 3}개 답변 더 있음',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.ink
                                                        .withValues(
                                                          alpha: 0.62,
                                                        ),
                                                  ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                '5. Patient corrections and follow-up feedback',
                                '5. 환자 수정 요청과 후속 피드백',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lang.tr(
                                'This section keeps what the patient later said about the visit record so you can compare your note with the patient response.',
                                '환자가 나중에 방문 기록에 대해 남긴 내용을 모아 보여주므로, 내 기록과 환자 반응을 바로 비교할 수 있습니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.66),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (feedbackSnapshot.hasError)
                              const _RecordErrorState()
                            else if (!feedbackSnapshot.hasData)
                              const LinearProgressIndicator(minHeight: 4)
                            else if (feedbackDocs.isEmpty)
                              _EmptyRecordState(
                                message: lang.tr(
                                  'No patient feedback has been submitted yet.',
                                  '아직 제출된 환자 피드백이 없습니다.',
                                ),
                              )
                            else
                              ...feedbackDocs.map((doc) {
                                final data = doc.data();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7FBFA),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppTheme.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_formatStoredDateWithWeekday((data['visitDate'] ?? '-').toString())} ${(data['visitTime'] ?? '').toString()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${lang.tr('Status', '상태')}: ${_feedbackStatusLabel((data['status'] ?? 'pending').toString())}',
                                        ),
                                        Text(
                                          '${lang.tr('Updated', '수정 시각')}: ${_formatTimestamp(data['updatedAt'] as Timestamp?)}',
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.border,
                                            ),
                                          ),
                                          child: Text(
                                            (data['feedbackText'] ?? '')
                                                .toString(),
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
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _saveProfile() {
    final lang = AppLanguageController.instance;
    final updated = widget.profile.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.profile.name
          : _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      birthYear:
          int.tryParse(_birthYearController.text.trim()) ??
          widget.profile.birthYear,
      sex: _sexController.text.trim().isEmpty
          ? widget.profile.sex
          : _sexController.text.trim(),
      ethnicity: _ethnicityController.text.trim().isEmpty
          ? widget.profile.ethnicity
          : _ethnicityController.text.trim(),
      memo: _memoController.text.trim(),
    );
    widget.onSave(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.tr('Patient information saved.', '환자 정보 저장 완료')),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocsByTimestamp(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
  ) {
    final copy = [...docs];
    copy.sort((a, b) {
      final aTime = (a.data()[field] as Timestamp?)?.toDate();
      final bTime = (b.data()[field] as Timestamp?)?.toDate();
      return (bTime ?? DateTime(2000)).compareTo(aTime ?? DateTime(2000));
    });
    return copy;
  }

  Map<String, dynamic> _safeMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<String> _safeStringList(Object? raw) {
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, List<String>> _safeQuestionMap(Object? raw) {
    final source = _safeMap(raw);
    return source.map((key, value) {
      final items = value is List
          ? value.map((item) => item.toString()).toList()
          : <String>[];
      return MapEntry(key, items);
    });
  }

  List<Map<String, dynamic>> _safeAnswerItems(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map((item) => _safeMap(item)).toList();
  }

  String _visitTypeLabel(String value) {
    final lang = AppLanguageController.instance;
    return value == 'initial'
        ? lang.tr('Initial visit intake', '초진 문진')
        : lang.tr('Follow-up intake', '재진 문진');
  }

  String _feedbackStatusLabel(String value) {
    final lang = AppLanguageController.instance;
    return value == 'reviewed'
        ? lang.tr('Reviewed', '확인 완료')
        : lang.tr('Pending review', '확인 대기');
  }

  String _formatTimestamp(Timestamp? timestamp) {
    final lang = AppLanguageController.instance;
    if (timestamp == null) {
      return lang.tr('Just now', '방금 전');
    }
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDateWithWeekday(date)} $hour:$minute';
  }

  String _formatStoredDateWithWeekday(String value) {
    final parsed = _parseDate(value);
    if (parsed == null) {
      return value;
    }
    return _formatDateWithWeekday(parsed);
  }

  String _formatDateWithWeekday(DateTime date) {
    final base =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '$base (${_weekdayShort(date)})';
  }

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('-');
      if (parts.length != 3) {
        return null;
      }
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
}

class _EmptyRecordState extends StatelessWidget {
  const _EmptyRecordState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(message),
    );
  }
}

class _RecordErrorState extends StatelessWidget {
  const _RecordErrorState();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLanguageController.instance.tr(
        'Could not load this part of the patient record.',
        '이 환자 기록 섹션을 불러오지 못했습니다.',
      ),
      style: const TextStyle(color: Colors.redAccent),
    );
  }
}
