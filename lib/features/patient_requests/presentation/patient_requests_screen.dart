import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/patient_shell.dart';
import '../../patient_home/presentation/patient_home_screen.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';
import '../../visit_history/presentation/visit_history_screen.dart';

enum _RequestFolder { needsReply, completed, all }

class PatientRequestsScreen extends StatefulWidget {
  const PatientRequestsScreen({super.key});

  static const routeName = '/patient-requests';

  @override
  State<PatientRequestsScreen> createState() => _PatientRequestsScreenState();
}

class _PatientRequestsScreenState extends State<PatientRequestsScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  PatientProfile? _sessionBackedProfile;
  _RequestFolder _selectedFolder = _RequestFolder.needsReply;
  bool _showGuide = true;

  PatientProfile get _currentProfile =>
      _sessionBackedProfile ?? _store.currentPatientProfile;

  String? get _activeClinicId =>
      _store.activeClinicForPatient(_currentProfile.id)?.id;

  bool _matchesActiveClinicDoc(Map<String, dynamic> data) {
    final activeClinicId = _activeClinicId;
    if (activeClinicId == null || activeClinicId.isEmpty) {
      return false;
    }
    final clinicId = (data['clinicId'] ?? '').toString();
    return clinicId == activeClinicId;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeProfile());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    final session =
        BetaSessionService.currentSession ??
        await BetaSessionService.currentSessionAsync();
    if (!mounted) {
      return;
    }

    if (session == null) {
      setState(() => _sessionBackedProfile = null);
      return;
    }

    try {
      final localProfile = await PatientProfileService.loadLocalProfile(
        session.id,
      );
      if (mounted && localProfile != null) {
        setState(() {
          _sessionBackedProfile = localProfile;
        });
      }
    } catch (_) {}

    unawaited(
      PatientProfileService.ensureProfileForSession(session)
          .then((_) async {
            final refreshed = await PatientProfileService.loadLocalProfile(
              session.id,
            );
            if (!mounted || refreshed == null) {
              return;
            }
            setState(() {
              _sessionBackedProfile = refreshed;
            });
          })
          .catchError((_) {}),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDateWithWeekday(date)} $hour:$minute';
  }

  List<String> _safeStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, List<String>> _safeQuestionMap(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, List<String>>{};
    for (final entry in raw.entries) {
      output[entry.key.toString()] = _safeStringList(entry.value);
    }
    return output;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docsForFolder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    _RequestFolder folder,
  ) {
    switch (folder) {
      case _RequestFolder.needsReply:
        return docs
            .where((doc) => (doc.data()['status'] ?? 'pending') != 'completed')
            .toList();
      case _RequestFolder.completed:
        return docs
            .where((doc) => (doc.data()['status'] ?? 'pending') == 'completed')
            .toList();
      case _RequestFolder.all:
        return docs;
    }
  }

  String _folderTitle(_RequestFolder folder, AppLanguageController lang) {
    switch (folder) {
      case _RequestFolder.needsReply:
        return lang.tr('Needs reply', '답변 필요');
      case _RequestFolder.completed:
        return lang.tr('Completed threads', '완료된 스레드');
      case _RequestFolder.all:
        return lang.tr('All messages', '전체 메시지');
    }
  }

  String _folderSubtitle(_RequestFolder folder, AppLanguageController lang) {
    switch (folder) {
      case _RequestFolder.needsReply:
        return lang.tr(
          'Follow-up requests that still need your action stay here.',
          '아직 내가 확인하거나 답해야 하는 후속 요청이 여기에 모입니다.',
        );
      case _RequestFolder.completed:
        return lang.tr(
          'Already handled or closed request threads stay here for reference.',
          '이미 처리되었거나 닫힌 요청 스레드는 참고용으로 여기에 남습니다.',
        );
      case _RequestFolder.all:
        return lang.tr(
          'Every portal message linked to your visits appears in one place.',
          '방문과 연결된 모든 포털 메시지가 한곳에 보입니다.',
        );
    }
  }

  String _statusLabel(String status, AppLanguageController lang) {
    return status == 'completed'
        ? lang.tr('Completed', '확인 완료')
        : lang.tr('Pending', '대기 중');
  }

  int _questionCount(
    List<String> selectedQuestions,
    Map<String, List<String>> customByCategory,
  ) {
    final customCount = customByCategory.values.fold<int>(
      0,
      (runningTotal, questions) => runningTotal + questions.length,
    );
    return selectedQuestions.length + customCount;
  }

  String _nextStepBody(
    String status,
    String requestType,
    int questionCount,
    AppLanguageController lang,
  ) {
    if (requestType == 'note') {
      return status == 'completed'
          ? lang.tr(
              'This portal note was already reviewed. Keep it as context for the next visit if needed.',
              '이 포털 쪽지는 이미 확인된 상태입니다. 필요하면 다음 방문 맥락 참고용으로 두면 됩니다.',
            )
          : lang.tr(
              'This is a practitioner note rather than a question set. Read it first, then return home or review history if you need context.',
              '이 스레드는 질문 세트보다 침술사 쪽지에 가깝습니다. 먼저 읽고, 필요하면 홈이나 방문 기록으로 돌아가 맥락을 보면 됩니다.',
            );
    }
    if (status == 'completed') {
      return lang.tr(
        'This thread was already handled. Use it as context if you want to review what was asked before.',
        '이 스레드는 이미 처리되었습니다. 이전에 어떤 요청이 있었는지 다시 참고할 때 사용하면 됩니다.',
      );
    }

    if (questionCount == 0) {
      return lang.tr(
        'The practitioner opened a follow-up without detailed questions, so reopen intake and share your current condition update.',
        '세부 질문 없이 후속 요청이 열린 상태라, 문진을 다시 열어 현재 상태 업데이트를 남기면 됩니다.',
      );
    }

    return lang.tr(
      'Read the questions below, then open intake and answer while this visit context is still fresh.',
      '아래 질문을 먼저 읽고, 이 방문 맥락이 남아 있을 때 문진 화면으로 들어가 답변해 주세요.',
    );
  }

  Widget _buildRequestsHero(
    AppLanguageController lang, {
    required int openCount,
    required int completedCount,
    required int totalCount,
  }) {
    return AppPanel(
      padding: const EdgeInsets.all(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.pine, AppTheme.jade, Color(0xFF2B7A66)],
      ),
      borderColor: Colors.white24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lang.tr('Requests inbox', '답변 요청함'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
              ),
              if (_showGuide)
                IconButton(
                  tooltip: lang.tr('Hide guide', '가이드 숨기기'),
                  onPressed: () => setState(() => _showGuide = false),
                  visualDensity: VisualDensity.compact,
                  color: Colors.white.withValues(alpha: 0.92),
                  icon: const Icon(Icons.close),
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _showGuide = true),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(lang.tr('Show guide', '가이드 다시 보기')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lang.tr(
              'This page works like a lightweight message center: read the newest practitioner follow-up, then continue in intake with the right visit context.',
              '이 화면은 가벼운 메시지 센터처럼 작동합니다. 최신 침술사 후속 요청을 읽고, 같은 방문 맥락으로 문진 화면에서 이어서 답하면 됩니다.',
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
              AppMetricChip(
                icon: Icons.mark_email_unread_outlined,
                label: lang.tr('Needs reply', '답변 필요'),
                value: '$openCount',
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                labelColor: Colors.white.withValues(alpha: 0.72),
                valueColor: Colors.white,
              ),
              AppMetricChip(
                icon: Icons.done_all_outlined,
                label: lang.tr('Completed', '완료'),
                value: '$completedCount',
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                labelColor: Colors.white.withValues(alpha: 0.72),
                valueColor: Colors.white,
              ),
              AppMetricChip(
                icon: Icons.forum_outlined,
                label: lang.tr('Threads', '스레드'),
                value: '$totalCount',
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                labelColor: Colors.white.withValues(alpha: 0.72),
                valueColor: Colors.white,
              ),
            ],
          ),
          if (_showGuide) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppGuideStep(
                  dark: true,
                  step: '1',
                  title: lang.tr('Read the newest request', '가장 최신 요청 읽기'),
                  description: lang.tr(
                    'Start with the visit time, requested questions, and the practitioner note.',
                    '방문 시간, 요청 질문, 침술사 메모부터 먼저 읽어주세요.',
                  ),
                ),
                AppGuideStep(
                  dark: true,
                  step: '2',
                  title: lang.tr('Continue in intake', '문진 화면에서 이어가기'),
                  description: lang.tr(
                    'Use the intake button below the thread so your answers stay tied to the right context.',
                    '스레드 아래 문진 버튼으로 들어가야 답변이 같은 맥락에 이어집니다.',
                  ),
                ),
                AppGuideStep(
                  dark: true,
                  step: '3',
                  title: lang.tr('Come back and review status', '다시 돌아와 상태 확인'),
                  description: lang.tr(
                    'Later, return here to see whether the thread moved to completed.',
                    '나중에 다시 돌아와 이 스레드가 완료로 이동했는지 확인하면 됩니다.',
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 18),
            Text(
              lang.tr(
                'The 1-2-3 guide is hidden. Use the button above if you want that walkthrough again.',
                '1-2-3 가이드는 숨겨졌습니다. 다시 보고 싶으면 위 버튼을 눌러주세요.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final profile = _currentProfile;

        return PatientShell(
          currentItem: PatientNavItem.requests,
          title: lang.tr('Requests Inbox', '답변 요청함'),
          actions: const [LanguageMenuButton()],
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('answer_requests')
                .where('patientId', isEqualTo: profile.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.tr(
                            'Could not load practitioner requests.',
                            '침술사 요청을 불러오지 못했습니다.',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final docs = [...?snapshot.data?.docs];
              docs.sort((a, b) {
                final aTime =
                    (a.data()['requestedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                final bTime =
                    (b.data()['requestedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                return bTime.compareTo(aTime);
              });
              docs.removeWhere((doc) => !_matchesActiveClinicDoc(doc.data()));

              final openCount = _docsForFolder(
                docs,
                _RequestFolder.needsReply,
              ).length;
              final completedCount = _docsForFolder(
                docs,
                _RequestFolder.completed,
              ).length;
              final filteredDocs = _docsForFolder(docs, _selectedFolder);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  docs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildRequestsHero(
                    lang,
                    openCount: openCount,
                    completedCount: completedCount,
                    totalCount: docs.length,
                  ),
                  const SizedBox(height: 16),
                  AppPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _folderTitle(_selectedFolder, lang),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _folderSubtitle(_selectedFolder, lang),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.72),
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MessageFolderChip(
                              label: lang.tr('Needs Reply', '답변 필요'),
                              count: openCount,
                              selected:
                                  _selectedFolder == _RequestFolder.needsReply,
                              onTap: () => setState(
                                () =>
                                    _selectedFolder = _RequestFolder.needsReply,
                              ),
                            ),
                            _MessageFolderChip(
                              label: lang.tr('Completed', '완료'),
                              count: completedCount,
                              selected:
                                  _selectedFolder == _RequestFolder.completed,
                              onTap: () => setState(
                                () =>
                                    _selectedFolder = _RequestFolder.completed,
                              ),
                            ),
                            _MessageFolderChip(
                              label: lang.tr('All', '전체'),
                              count: docs.length,
                              selected: _selectedFolder == _RequestFolder.all,
                              onTap: () => setState(
                                () => _selectedFolder = _RequestFolder.all,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    AppPanel(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr(
                              'No practitioner request threads are here yet.',
                              '아직 침술사 요청 스레드가 없습니다.',
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang.tr(
                              'When your practitioner asks for a follow-up answer, that message will appear here first.',
                              '침술사가 후속 답변을 요청하면 이 화면에 먼저 나타납니다.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.72),
                                ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  PatientIntakeScreen.routeName,
                                ),
                                icon: const Icon(Icons.edit_note),
                                label: Text(
                                  lang.tr('Open intake anyway', '문진 화면 열기'),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  VisitHistoryScreen.routeName,
                                ),
                                icon: const Icon(Icons.history),
                                label: Text(
                                  lang.tr('Review visit history', '방문 기록 보기'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (filteredDocs.isEmpty)
                    AppPanel(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr(
                              'Nothing is in this folder right now.',
                              '이 폴더에는 지금 메시지가 없습니다.',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _folderSubtitle(_selectedFolder, lang),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.72),
                                ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'pending').toString();
                      final requestType =
                          (data['requestType'] ?? 'answer_request').toString();
                      final selectedQuestions = _safeStringList(
                        data['selectedQuestions'],
                      );
                      final customByCategory = _safeQuestionMap(
                        data['customQuestionsByCategory'],
                      );
                      final note = (data['note'] ?? '').toString().trim();
                      final visitTime = (data['patientTime'] ?? '-').toString();
                      final lastVisitDate = (data['lastVisitDate'] ?? '-')
                          .toString();
                      final questionCount = _questionCount(
                        selectedQuestions,
                        customByCategory,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppPanel(
                          padding: const EdgeInsets.all(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.94),
                              status == 'completed'
                                  ? AppTheme.mint.withValues(alpha: 0.42)
                                  : AppTheme.blush.withValues(alpha: 0.44),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTimestamp(
                                            data['requestedAt'] as Timestamp?,
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          requestType == 'note'
                                              ? lang.tr(
                                                  'This thread is a practitioner note, so read the message first before deciding whether you need any follow-up action.',
                                                  '이 스레드는 침술사 쪽지이므로, 후속 행동이 필요한지 결정하기 전에 먼저 내용을 읽어보면 됩니다.',
                                                )
                                              : lang.tr(
                                                  'Newest message first so you can respond without scanning old history first.',
                                                  '최신 메시지가 먼저 보여서 예전 기록을 먼저 훑지 않아도 바로 이어서 답할 수 있습니다.',
                                                ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.ink.withValues(
                                                  alpha: 0.66,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Chip(label: Text(_statusLabel(status, lang))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _RequestMetaPill(
                                    icon: Icons.schedule_outlined,
                                    label:
                                        '${lang.tr('Visit Time', '방문 시간')}: $visitTime',
                                  ),
                                  _RequestMetaPill(
                                    icon: Icons.history_toggle_off,
                                    label:
                                        '${lang.tr('Last Visit', '지난 방문')}: ${_formatStoredDateWithWeekday(lastVisitDate)}',
                                  ),
                                  _RequestMetaPill(
                                    icon: requestType == 'note'
                                        ? Icons.mail_outline
                                        : Icons.quiz_outlined,
                                    label: requestType == 'note'
                                        ? lang.tr('Practitioner note', '침술사 쪽지')
                                        : lang.tr(
                                            '$questionCount question(s)',
                                            '$questionCount개 질문',
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: status == 'completed'
                                      ? AppTheme.mint.withValues(alpha: 0.34)
                                      : AppTheme.surfaceSoft.withValues(
                                          alpha: 0.9,
                                        ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.tr('What to do next', '다음에 할 일'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _nextStepBody(
                                        status,
                                        requestType,
                                        questionCount,
                                        lang,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.ink.withValues(
                                              alpha: 0.74,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                lang.tr('Requested Questions', '요청 질문'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (selectedQuestions.isEmpty &&
                                  customByCategory.isEmpty)
                                Text(
                                  lang.tr(
                                    'No detailed questions were saved in this thread.',
                                    '이 스레드에는 저장된 세부 질문이 없습니다.',
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ...selectedQuestions.map(
                                (question) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text('- $question'),
                                ),
                              ),
                              ...customByCategory.entries.expand(
                                (entry) => entry.value.map(
                                  (question) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text('- [${entry.key}] $question'),
                                  ),
                                ),
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  lang.tr('Practitioner Note', '침술사 메모'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(note),
                              ],
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      requestType == 'note'
                                          ? PatientHomeScreen.routeName
                                          : PatientIntakeScreen.routeName,
                                    ),
                                    icon: Icon(
                                      requestType == 'note'
                                          ? Icons.home_outlined
                                          : Icons.edit_note,
                                    ),
                                    label: Text(
                                      requestType == 'note'
                                          ? lang.tr(
                                              'Return to home',
                                              '홈으로 돌아가기',
                                            )
                                          : lang.tr(
                                              'Answer in Intake Form',
                                              '문진 화면에서 답하기',
                                            ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      VisitHistoryScreen.routeName,
                                    ),
                                    icon: const Icon(Icons.history),
                                    label: Text(
                                      lang.tr(
                                        'Review visit history',
                                        '방문 기록 보기',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MessageFolderChip extends StatelessWidget {
  const _MessageFolderChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppTheme.pine : AppTheme.border,
            ),
            color: selected
                ? AppTheme.pine.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.84),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppTheme.pine : AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.pine
                      : AppTheme.surfaceSoft.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : AppTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestMetaPill extends StatelessWidget {
  const _RequestMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
              label,
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
