import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';

enum _PatientRecordTab { overview, visits, requests, intake, feedback }

class PatientRecordWorkspace extends StatefulWidget {
  const PatientRecordWorkspace({
    super.key,
    required this.profile,
    required this.onSave,
    this.clinicId,
    this.membershipStatus,
    this.pendingJoinRequest,
    this.onApproveJoin,
  });

  final PatientProfile profile;
  final ValueChanged<PatientProfile> onSave;
  final String? clinicId;
  final String? membershipStatus;
  final PatientClinicMembershipRequest? pendingJoinRequest;
  final Future<void> Function()? onApproveJoin;

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
  _PatientRecordTab _selectedTab = _PatientRecordTab.overview;
  bool _isApprovingJoin = false;

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
    final history = widget.clinicId == null || widget.clinicId!.isEmpty
        ? const <ScheduledVisit>[]
        : _store.historyForPatient(profile.id, clinicId: widget.clinicId);
    final completedVisits = history
        .where((item) => item.visit.intakeStatus == IntakeStatus.completed)
        .length;
    bool matchesClinic(Map<String, dynamic> data) {
      final clinicId = widget.clinicId;
      if (clinicId == null || clinicId.isEmpty) {
        return false;
      }
      final docClinicId = (data['clinicId'] ?? '').toString();
      return docClinicId == clinicId;
    }

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
                ).where((doc) => matchesClinic(doc.data())).toList();
                final submissionDocs = _sortDocsByTimestamp(
                  submissionSnapshot.data?.docs ?? const [],
                  'submittedAt',
                ).where((doc) => matchesClinic(doc.data())).toList();
                final feedbackDocs = _sortDocsByTimestamp(
                  feedbackSnapshot.data?.docs ?? const [],
                  'updatedAt',
                ).where((doc) => matchesClinic(doc.data())).toList();
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
                final compact = MediaQuery.sizeOf(context).width < 430;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppPanel(
                        padding: EdgeInsets.all(compact ? 16 : 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Patient chart', '환자 차트'),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.58),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppTheme.ink),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: compact ? 8 : 12,
                              runSpacing: compact ? 8 : 12,
                              children: [
                                if (!compact)
                                  AppMetricChip(
                                    icon: Icons.badge_outlined,
                                    label: lang.tr('Profile', '프로필'),
                                    value:
                                        '${profile.sex} · ${profile.ageRange} · ${profile.ethnicity}',
                                    backgroundColor: AppTheme.surface,
                                    labelColor: AppTheme.ink.withValues(
                                      alpha: 0.58,
                                    ),
                                    valueColor: AppTheme.ink,
                                  ),
                                AppMetricChip(
                                  icon: Icons.history_outlined,
                                  label: lang.tr('Visits', '방문'),
                                  value: '${history.length}',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.assignment_turned_in_outlined,
                                  label: lang.tr('Intakes', '문진'),
                                  value: '$completedVisits',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.mark_email_unread_outlined,
                                  label: lang.tr('Feedback', '피드백'),
                                  value: '$pendingFeedbackCount',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(compact ? 12 : 16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    '${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? lang.tr('Missing', '미입력') : profile.phone}',
                                    style: TextStyle(
                                      color: AppTheme.ink.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? lang.tr('Missing', '미입력') : profile.email}',
                                    style: TextStyle(
                                      color: AppTheme.ink.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                                  ),
                                  if (!compact)
                                    Text(
                                      '${lang.tr('Note', '메모')}: ${profile.memo.trim().isEmpty ? '-' : profile.memo.trim()}',
                                      style: TextStyle(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.pendingJoinRequest != null) ...[
                        const SizedBox(height: 12),
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.mint.withValues(alpha: 0.72),
                              Colors.white.withValues(alpha: 0.94),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_add_alt_1,
                                color: AppTheme.pine,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.tr('Join request', '가입 요청'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                            widget
                                                .pendingJoinRequest!
                                                .patientEmail,
                                            _formatDateWithWeekday(
                                              widget
                                                  .pendingJoinRequest!
                                                  .requestedAt,
                                            ),
                                            widget
                                                .pendingJoinRequest!
                                                .clinicName,
                                          ]
                                          .where(
                                            (item) => item.trim().isNotEmpty,
                                          )
                                          .join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.ink.withValues(
                                              alpha: 0.68,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    _isApprovingJoin ||
                                        widget.onApproveJoin == null
                                    ? null
                                    : () async {
                                        setState(() => _isApprovingJoin = true);
                                        await widget.onApproveJoin?.call();
                                        if (mounted) {
                                          setState(
                                            () => _isApprovingJoin = false,
                                          );
                                        }
                                      },
                                icon: Icon(
                                  _isApprovingJoin
                                      ? Icons.hourglass_top
                                      : Icons.check_circle_outline,
                                ),
                                label: Text(
                                  _isApprovingJoin
                                      ? lang.tr('Approving...', '승인 중...')
                                      : lang.tr(
                                          'Approve + intake',
                                          '승인 + 문진 보내기',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        _MembershipStatusPanel(
                          status: widget.membershipStatus == 'approved'
                              ? lang.tr('Clinic approved', '한의원 승인됨')
                              : lang.tr('Clinic linked', '한의원 연결됨'),
                        ),
                      ],
                      const SizedBox.shrink(),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            label: Text(lang.tr('Overview', '기본 정보')),
                            selected:
                                _selectedTab == _PatientRecordTab.overview,
                            onSelected: (_) {
                              setState(
                                () => _selectedTab = _PatientRecordTab.overview,
                              );
                            },
                          ),
                          ChoiceChip(
                            label: Text(lang.tr('Visits', '방문 기록')),
                            selected: _selectedTab == _PatientRecordTab.visits,
                            onSelected: (_) {
                              setState(
                                () => _selectedTab = _PatientRecordTab.visits,
                              );
                            },
                          ),
                          ChoiceChip(
                            label: Text(lang.tr('Requests', '요청')),
                            selected:
                                _selectedTab == _PatientRecordTab.requests,
                            onSelected: (_) {
                              setState(
                                () => _selectedTab = _PatientRecordTab.requests,
                              );
                            },
                          ),
                          ChoiceChip(
                            label: Text(lang.tr('Intake', '문진')),
                            selected: _selectedTab == _PatientRecordTab.intake,
                            onSelected: (_) {
                              setState(
                                () => _selectedTab = _PatientRecordTab.intake,
                              );
                            },
                          ),
                          ChoiceChip(
                            label: Text(lang.tr('Feedback', '피드백')),
                            selected:
                                _selectedTab == _PatientRecordTab.feedback,
                            onSelected: (_) {
                              setState(
                                () => _selectedTab = _PatientRecordTab.feedback,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox.shrink(),
                      if (_selectedTab == _PatientRecordTab.overview) ...[
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Profile', '프로필'),
                                style: Theme.of(context).textTheme.titleLarge,
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
                              _ResponsiveFieldGroup(
                                children: [
                                  TextField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Phone', '전화번호'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Email', '이메일'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _ResponsiveFieldGroup(
                                children: [
                                  TextField(
                                    controller: _birthYearController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Birth Year', '출생연도'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  TextField(
                                    controller: _sexController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Sex / Gender', '성별'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  TextField(
                                    controller: _ethnicityController,
                                    decoration: InputDecoration(
                                      labelText: lang.tr('Ethnicity', '인종/민족'),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _memoController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: lang.tr('Note', '이 환자에 대한 내 메모'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _saveProfile,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(lang.tr('Save', '저장')),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox.shrink(),
                      if (_selectedTab == _PatientRecordTab.visits) ...[
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Visits', '방문'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              if (history.isEmpty)
                                _EmptyRecordState(
                                  message: lang.tr('No visits', '방문 없음'),
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
                                            '${lang.tr('Focus', '포인트')}: ${visit.previousTreatmentArea}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${lang.tr('Note', '기록')}: ${visit.previousSessionNote}',
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
                                              'Intake answers',
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
                                                'No intake answers',
                                                '문진 답변 없음',
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
                                              lang.tr('No feedback', '피드백 없음'),
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
                      ],
                      const SizedBox.shrink(),
                      if (_selectedTab == _PatientRecordTab.requests) ...[
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Requests', '요청'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              if (requestSnapshot.hasError)
                                const _RecordErrorState()
                              else if (!requestSnapshot.hasData)
                                const LinearProgressIndicator(minHeight: 4)
                              else if (requestDocs.isEmpty)
                                _EmptyRecordState(
                                  message: lang.tr('No requests', '요청 없음'),
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
                                            '${lang.tr('Visit', '방문')}: ${(data['patientTime'] ?? '-').toString()}',
                                          ),
                                          Text(
                                            '${lang.tr('Previous', '이전')}: ${_formatStoredDateWithWeekday((data['lastVisitDate'] ?? '-').toString())}',
                                          ),
                                          Text(
                                            '${lang.tr('Questions', '질문')}: $questionCount',
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
                                                  padding:
                                                      const EdgeInsets.only(
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
                      ],
                      const SizedBox(height: 16),
                      if (_selectedTab == _PatientRecordTab.intake) ...[
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Intake', '문진'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              if (submissionSnapshot.hasError)
                                const _RecordErrorState()
                              else if (!submissionSnapshot.hasData)
                                const LinearProgressIndicator(minHeight: 4)
                              else if (submissionDocs.isEmpty)
                                _EmptyRecordState(
                                  message: lang.tr('No intake', '문진 없음'),
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
                                        (item) =>
                                            item['markedMainPain'] == true,
                                      )
                                      .length;
                                  final markedRememberCount = answers
                                      .where(
                                        (item) =>
                                            item['markedRemember'] == true,
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
                                            '${lang.tr('Type', '유형')}: ${_visitTypeLabel((data['visitType'] ?? 'follow_up').toString())}',
                                          ),
                                          Text(
                                            '${lang.tr('Answers', '답변')}: ${answers.length}',
                                          ),
                                          Text(
                                            '${lang.tr('Complete', '완료')}: ${percent.round()}%',
                                          ),
                                          Text(
                                            '${lang.tr('Main', '중요')}: $markedMainPainCount · ${lang.tr('Pinned', '고정')}: $markedRememberCount',
                                          ),
                                          if (extraMemo.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '${lang.tr('Memo', '메모')}: $extraMemo',
                                            ),
                                          ],
                                          if (answers.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              lang.tr('Answers', '답변'),
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
                                                  lang.tr('Main', '중요 통증'),
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
                      ],
                      const SizedBox(height: 16),
                      if (_selectedTab == _PatientRecordTab.feedback) ...[
                        AppPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Feedback', '피드백'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              if (feedbackSnapshot.hasError)
                                const _RecordErrorState()
                              else if (!feedbackSnapshot.hasData)
                                const LinearProgressIndicator(minHeight: 4)
                              else if (feedbackDocs.isEmpty)
                                _EmptyRecordState(
                                  message: lang.tr('No feedback', '피드백 없음'),
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
                                            '${lang.tr('Updated', '수정')}: ${_formatTimestamp(data['updatedAt'] as Timestamp?)}',
                                          ),
                                          const SizedBox(height: 8),
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

class _ResponsiveFieldGroup extends StatelessWidget {
  const _ResponsiveFieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560;
        if (stacked) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _MembershipStatusPanel extends StatelessWidget {
  const _MembershipStatusPanel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.pine),
          const SizedBox(width: 10),
          Text(
            status,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.pine,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
