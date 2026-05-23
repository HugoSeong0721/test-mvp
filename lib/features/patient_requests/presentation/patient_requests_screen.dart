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
import '../../../core/widgets/patient_clinic_context_panel.dart';
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
        return docs.where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString();
          final requestType = (data['requestType'] ?? 'answer_request')
              .toString();
          return status != 'completed' && requestType != 'note';
        }).toList();
      case _RequestFolder.completed:
        return docs
            .where((doc) => (doc.data()['status'] ?? 'pending') == 'completed')
            .toList();
      case _RequestFolder.all:
        return docs;
    }
  }

  String _statusLabel(String status, AppLanguageController lang) {
    return status == 'completed'
        ? lang.tr('Done', '완료')
        : lang.tr('Open', '열림');
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

  Widget _buildNextActionPanel(
    AppLanguageController lang,
    QueryDocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) {
    final data = requestDoc.data();
    final requestType = (data['requestType'] ?? 'answer_request').toString();
    final selectedQuestions = _safeStringList(data['selectedQuestions']);
    final customByCategory = _safeQuestionMap(
      data['customQuestionsByCategory'],
    );
    final questionCount = _questionCount(selectedQuestions, customByCategory);
    final visitTime = (data['patientTime'] ?? '-').toString();
    final isNote = requestType == 'note';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final icon = Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.pine.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isNote ? Icons.mark_email_unread_outlined : Icons.edit_note,
            color: AppTheme.pine,
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNote ? lang.tr('New note', '새 메모') : lang.tr('Reply', '답변'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RequestMetaPill(
                  icon: Icons.schedule_outlined,
                  label: visitTime,
                ),
                _RequestMetaPill(
                  icon: Icons.quiz_outlined,
                  label: isNote
                      ? lang.tr('Note', '메모')
                      : lang.tr(
                          '$questionCount questions',
                          '$questionCount개 질문',
                        ),
                ),
              ],
            ),
          ],
        );
        final button = FilledButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            isNote
                ? PatientHomeScreen.routeName
                : PatientIntakeScreen.routeName,
          ),
          icon: Icon(
            isNote ? Icons.local_hospital_outlined : Icons.arrow_forward,
          ),
          label: Text(
            isNote ? lang.tr('Clinic', '한의원') : lang.tr('Intake', '문진'),
          ),
        );

        return AppPanel(
          padding: const EdgeInsets.all(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.mint.withValues(alpha: 0.72),
              Colors.white.withValues(alpha: 0.94),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: copy),
                      ],
                    ),
                    const SizedBox(height: 14),
                    button,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: copy),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMessageHeader(
    AppLanguageController lang, {
    required int openCount,
    required int completedCount,
    required int totalCount,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return AppPanel(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            openCount > 0
                ? lang.tr('$openCount to answer', '$openCount개 답변 필요')
                : lang.tr('Inbox clear', '새 요청 없음'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              lang.tr(
                'Practitioner notes and follow-up questions appear here. Start with anything marked Reply.',
                '침술사 메모와 후속 질문이 여기에 표시됩니다. 답변이 필요한 항목부터 시작하세요.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.68),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MessageFolderChip(
                label: lang.tr('Reply', '답변'),
                count: openCount,
                selected: _selectedFolder == _RequestFolder.needsReply,
                onTap: () =>
                    setState(() => _selectedFolder = _RequestFolder.needsReply),
              ),
              if (!compact) ...[
                _MessageFolderChip(
                  label: lang.tr('Done', '완료'),
                  count: completedCount,
                  selected: _selectedFolder == _RequestFolder.completed,
                  onTap: () => setState(
                    () => _selectedFolder = _RequestFolder.completed,
                  ),
                ),
                _MessageFolderChip(
                  label: lang.tr('All', '전체'),
                  count: totalCount,
                  selected: _selectedFolder == _RequestFolder.all,
                  onTap: () =>
                      setState(() => _selectedFolder = _RequestFolder.all),
                ),
              ],
            ],
          ),
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
        final activeClinic = _store.activeClinicForPatient(profile.id);

        return PatientShell(
          currentItem: PatientNavItem.requests,
          title: lang.tr('Requests', '요청함'),
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
                            'Could not load requests.',
                            '요청을 불러오지 못했습니다.',
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
              final needsReplyDocs = _docsForFolder(
                docs,
                _RequestFolder.needsReply,
              );
              final filteredDocs = _docsForFolder(docs, _selectedFolder);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  docs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PatientClinicContextPanel(
                    clinic: activeClinic,
                    onChooseClinic: () => Navigator.pushNamed(
                      context,
                      PatientHomeScreen.routeName,
                    ),
                  ),
                  if (needsReplyDocs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNextActionPanel(lang, needsReplyDocs.first),
                  ],
                  const SizedBox(height: 16),
                  _buildMessageHeader(
                    lang,
                    openCount: openCount,
                    completedCount: completedCount,
                    totalCount: docs.length,
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    AppPanel(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr('No requests', '요청 없음'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang.tr(
                              'There is nothing waiting from this clinic right now.',
                              '현재 이 클리닉에서 기다리는 요청이 없습니다.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.68),
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
                                label: Text(lang.tr('Intake', '문진')),
                              ),
                              if (MediaQuery.sizeOf(context).width >= 430)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    VisitHistoryScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.history),
                                  label: Text(lang.tr('History', '기록')),
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
                            lang.tr('Empty', '비어 있음'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) {
                      final compact = MediaQuery.sizeOf(context).width < 430;
                      final data = doc.data();
                      final status = (data['status'] ?? 'pending').toString();
                      final requestType =
                          (data['requestType'] ?? 'answer_request').toString();
                      final rawSelectedQuestions = _safeStringList(
                        data['selectedQuestions'],
                      );
                      final rawCustomByCategory = _safeQuestionMap(
                        data['customQuestionsByCategory'],
                      );
                      final selectedQuestions = compact
                          ? rawSelectedQuestions.take(3).toList()
                          : rawSelectedQuestions;
                      final customByCategory = compact
                          ? const <String, List<String>>{}
                          : rawCustomByCategory;
                      final note = (data['note'] ?? '').toString().trim();
                      final visitTime = (data['patientTime'] ?? '-').toString();
                      final lastVisitDate = (data['lastVisitDate'] ?? '-')
                          .toString();
                      final questionCount = _questionCount(
                        rawSelectedQuestions,
                        rawCustomByCategory,
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
                                        '${lang.tr('Visit', '방문')}: $visitTime',
                                  ),
                                  _RequestMetaPill(
                                    icon: Icons.history_toggle_off,
                                    label:
                                        '${lang.tr('Last', '지난')}: ${_formatStoredDateWithWeekday(lastVisitDate)}',
                                  ),
                                  _RequestMetaPill(
                                    icon: requestType == 'note'
                                        ? Icons.mail_outline
                                        : Icons.quiz_outlined,
                                    label: requestType == 'note'
                                        ? lang.tr('Note', '쪽지')
                                        : lang.tr(
                                            '$questionCount question(s)',
                                            '$questionCount개 질문',
                                          ),
                                  ),
                                ],
                              ),
                              if (requestType != 'note') ...[
                                const SizedBox(height: 14),
                                Text(
                                  lang.tr('Questions', '질문'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                if (selectedQuestions.isEmpty &&
                                    customByCategory.isEmpty)
                                  Text(
                                    lang.tr(
                                      'No questions',
                                      '이 스레드에는 저장된 세부 질문이 없습니다.',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
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
                                if (compact &&
                                    questionCount > selectedQuestions.length)
                                  Text(
                                    lang.tr(
                                      '+${questionCount - selectedQuestions.length} more',
                                      '+${questionCount - selectedQuestions.length}개 더',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: AppTheme.pine),
                                  ),
                              ],
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
                                          ? Icons.local_hospital_outlined
                                          : Icons.edit_note,
                                    ),
                                    label: Text(
                                      requestType == 'note'
                                          ? lang.tr('Clinic', '한의원')
                                          : lang.tr('Answer', '답하기'),
                                    ),
                                  ),
                                  if (!compact)
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        VisitHistoryScreen.routeName,
                                      ),
                                      icon: const Icon(Icons.history),
                                      label: Text(lang.tr('History', '기록')),
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
