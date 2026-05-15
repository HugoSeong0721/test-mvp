import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/practitioner_session_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/practitioner_shell.dart';
import '../../patient_brief/presentation/patient_brief_screen.dart';
import 'clinic_profile_workspace.dart';
import 'patient_record_workspace.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState
    extends State<PractitionerDashboardScreen> {
  static const Map<String, List<String>> _questionLibraryByCategory = {
    'Temperature/Sweat': [
      'Do you feel unusually hot or cold lately?',
      'Have you noticed spontaneous sweat, night sweat, or cold sweat?',
    ],
    'Appetite/Thirst': [
      'How has your appetite been compared with usual?',
      'Have you been more thirsty, and do you prefer cold or warm drinks?',
    ],
    'Sleep': [
      'How long does it take you to fall asleep, and how often do you wake up?',
      'Have you been dreaming a lot or waking without feeling rested?',
    ],
    'Digestion': [
      'Have you noticed bloating or heartburn after meals?',
      'Have you been dealing with belching, gas, or reflux?',
    ],
    'Urine': [
      'Any change in urinary frequency or urgency?',
      'Are you waking up more often to urinate at night?',
    ],
    'Stool': [
      'Any change in bowel movement timing or stool form?',
      'Have constipation and loose stool been alternating?',
    ],
    'Menses': [
      'Any change in cycle, flow amount, or menstrual pain?',
      'Any clotting or color change in menstrual blood?',
    ],
    'HEENT': [
      'Any headache, eye strain, tinnitus, or sinus congestion?',
      'Any symptom connected with neck and shoulder tension?',
    ],
    'Emotion': [
      'Have emotional swings or irritability increased lately?',
      'Does stress seem to make the body symptoms worse?',
    ],
    'Energy': [
      'At what time of day do you feel the most tired?',
      'Is there a time when your energy drops suddenly?',
    ],
  };

  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _patientFilterController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _appointmentInboxKey = GlobalKey();
  final GlobalKey _availabilityBoardKey = GlobalKey();
  final GlobalKey _dateSelectorKey = GlobalKey();
  final GlobalKey _patientCardsKey = GlobalKey();
  final GlobalKey _appointmentRequestsSectionKey = GlobalKey();
  final GlobalKey _recordUpdatesSectionKey = GlobalKey();
  final GlobalKey _recentSubmissionsSectionKey = GlobalKey();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _intakeSubmissionSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _membershipRequestSubscription;
  Map<String, Map<String, dynamic>> _latestPatientIntakeByPatient =
      <String, Map<String, dynamic>>{};

  late String _selectedDate;
  String _selectedPatientFilter = 'All Patients';
  String _selectedStatusFilter = 'All';
  int _selectedRangeDays = 7;
  DateTimeRange? _selectedDateRange;
  _DashboardSubView _subView = _DashboardSubView.main;

  String? get _currentClinicId =>
      PractitionerSessionService.currentSession?.clinicId;

  bool get _isPlatformAdmin =>
      PractitionerSessionService.currentSession?.loginId == 'admin';

  bool get _hasClinicContext =>
      _currentClinicId != null && _currentClinicId!.trim().isNotEmpty;

  void _selectSubView(_DashboardSubView view) {
    setState(() => _subView = _subView == view ? _DashboardSubView.main : view);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _formatDate(DateTime.now());
    _intakeSubmissionSubscription = FirebaseFirestore.instance
        .collection('intake_submissions')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) {
            return;
          }
          setState(() {
            _latestPatientIntakeByPatient = _latestSubmissionByPatient(
              snapshot.docs,
            );
          });
        });
    _membershipRequestSubscription = FirebaseFirestore.instance
        .collection('patient_clinic_membership_requests')
        .snapshots()
        .listen((snapshot) async {
          await _store.mergePatientClinicMembershipRequestsFromMaps(
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}),
          );
        });
  }

  @override
  void dispose() {
    _intakeSubmissionSubscription?.cancel();
    _membershipRequestSubscription?.cancel();
    _patientFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store, AppLanguageController.instance]),
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final theme = Theme.of(context);
        final activeClinic = _currentClinicId == null
            ? null
            : _store.clinicById(_currentClinicId!);
        final pendingMembershipRequests = _store
            .pendingMembershipRequestsForClinic(_currentClinicId);
        final pendingAppointmentInboxCount =
            _pendingAppointmentRequestCount() +
            pendingMembershipRequests.length;
        final visibleVisits = _visibleVisits();
        final summaryVisits = _summaryWindowVisits();
        final connectedProfiles = _store.profilesForClinic(_currentClinicId);
        final patientNames =
            visibleVisits.map((v) => v.profile.name).toSet().toList()..sort();
        final keyword = _patientFilterController.text.trim().toLowerCase();
        final dropdownFiltered = _selectedPatientFilter == 'All Patients'
            ? visibleVisits
            : visibleVisits
                  .where((v) => v.profile.name == _selectedPatientFilter)
                  .toList();
        final statusFiltered = dropdownFiltered
            .where((v) => _matchesStatusFilter(v))
            .toList();
        final filteredVisits = keyword.isEmpty
            ? statusFiltered
            : statusFiltered
                  .where((v) => v.profile.name.toLowerCase().contains(keyword))
                  .toList();
        final summary = _visitWindowSummary(summaryVisits);
        final connectedPatientsWithoutVisit = connectedProfiles
            .where(
              (profile) => _store
                  .historyForPatient(profile.id, clinicId: _currentClinicId)
                  .isEmpty,
            )
            .toList();
        final titleLabel = _selectedDateRange == null
            ? lang.tr(
                '${_formatStoredDateWithWeekday(_selectedDate)} Patients ${filteredVisits.length}',
                '${_formatStoredDateWithWeekday(_selectedDate)} 환자 ${filteredVisits.length}명',
              )
            : lang.tr(
                '${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)} Patients ${filteredVisits.length}',
                '${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)} 환자 ${filteredVisits.length}명',
              );

        return PractitionerShell(
          currentItem: PractitionerNavItem.dashboard,
          title: lang.tr('Practitioner Dashboard', '침술사 대시보드'),
          actions: [
            _buildCompactTopInboxAction(pendingAppointmentInboxCount),
            IconButton(
              tooltip: lang.tr('Pick date range', '날짜 범위 선택'),
              onPressed: _pickDateRange,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            IconButton(
              tooltip: 'Clinic settings',
              onPressed: () => _selectSubView(_DashboardSubView.clinicProfile),
              icon: const Icon(Icons.domain_add_outlined),
            ),
            const LanguageMenuButton(),
          ],
          tools: [
            PractitionerToolItem(
              icon: Icons.people_outline,
              labelEn: 'Patients',
              labelKo: 'Patients',
              active: _subView == _DashboardSubView.patientManagement,
              onTap: () => _selectSubView(_DashboardSubView.patientManagement),
            ),
            PractitionerToolItem(
              icon: Icons.dashboard_outlined,
              labelEn: 'Today Summary',
              labelKo: '오늘 요약',
              active: _subView == _DashboardSubView.opsHub,
              onTap: () => _selectSubView(_DashboardSubView.opsHub),
            ),
            PractitionerToolItem(
              icon: Icons.mark_email_unread_outlined,
              labelEn: 'Inbox',
              labelKo: 'Inbox',
              active: _subView == _DashboardSubView.inbox,
              onTap: () => _selectSubView(_DashboardSubView.inbox),
            ),
            PractitionerToolItem(
              icon: Icons.query_stats_outlined,
              labelEn: 'Visit Insights',
              labelKo: 'Visit Insights',
              active: _subView == _DashboardSubView.visitInsights,
              onTap: () => _selectSubView(_DashboardSubView.visitInsights),
            ),
            PractitionerToolItem(
              icon: Icons.event_available_outlined,
              labelEn: 'Schedule',
              labelKo: 'Schedule',
              active: _subView == _DashboardSubView.schedule,
              onTap: () => _selectSubView(_DashboardSubView.schedule),
            ),
            PractitionerToolItem(
              icon: Icons.domain_add_outlined,
              labelEn: 'Clinic',
              labelKo: 'Clinic',
              active: _subView == _DashboardSubView.clinicProfile,
              onTap: () => _selectSubView(_DashboardSubView.clinicProfile),
            ),
          ],
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!_hasClinicContext) ...[
                AppPanel(
                  padding: const EdgeInsets.all(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.blush.withValues(alpha: 0.72),
                      Colors.white,
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Set your clinic first', '먼저 한의원 정보를 설정해주세요'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr('Save clinic profile first.', '한의원 정보 먼저 저장'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () =>
                            _selectSubView(_DashboardSubView.clinicProfile),
                        icon: const Icon(Icons.domain_add_outlined),
                        label: Text(lang.tr('Clinic', '한의원')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_subView == _DashboardSubView.opsHub) ...[
                _buildDashboardHero(
                  summary,
                  summaryVisits,
                  filteredVisits.length,
                ),
                const SizedBox(height: 16),
              ],
              if (_subView == _DashboardSubView.visitInsights) ...[
                _buildInsightPanel(summary, summaryVisits),
                const SizedBox(height: 12),
              ],
              if (_subView == _DashboardSubView.main)
                if (pendingMembershipRequests.isNotEmpty) ...[
                  _buildMembershipRequestAlertPanel(pendingMembershipRequests),
                  const SizedBox(height: 12),
                ],
              if (_subView == _DashboardSubView.main)
                KeyedSubtree(
                  key: _dateSelectorKey,
                  child: _buildDateSelectorPanel(),
                ),
              if (_subView == _DashboardSubView.inbox) ...[
                const SizedBox(height: 4),
                _buildClinicOpenRequestsPanel(),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: _appointmentInboxKey,
                  child: _buildPatientInboxBoard(),
                ),
              ],
              if (_subView == _DashboardSubView.schedule) ...[
                const SizedBox(height: 4),
                KeyedSubtree(
                  key: _availabilityBoardKey,
                  child: _buildAvailabilityBoard(),
                ),
              ],
              if (_subView == _DashboardSubView.patientManagement) ...[
                const SizedBox(height: 4),
                AppPanel(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 720,
                    child: _PatientManagementDialog(
                      embedded: true,
                      onApproveJoin: _approveMembershipAndSendQuestionTree,
                    ),
                  ),
                ),
              ],
              if (_subView == _DashboardSubView.clinicProfile) ...[
                const SizedBox(height: 4),
                const SizedBox(height: 760, child: ClinicProfileWorkspace()),
              ],
              const SizedBox(height: 16),
              if (_subView == _DashboardSubView.main)
                KeyedSubtree(
                  key: _patientCardsKey,
                  child: AppPanel(
                    padding: const EdgeInsets.all(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.92),
                        AppTheme.blush.withValues(alpha: 0.62),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 780;
                        final headerActions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: wide
                              ? WrapAlignment.end
                              : WrapAlignment.start,
                          children: [
                            if (activeClinic != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.mint.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppTheme.border.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  lang.tr(
                                    'Clinic: ${activeClinic.name}',
                                    '현재 한의원: ${activeClinic.name}',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: _pickDateFromCalendar,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(lang.tr('Pick date', '달력에서 날짜 선택')),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _jumpToTodayDate,
                              icon: const Icon(Icons.today_outlined),
                              label: Text(lang.tr('Today', '오늘 날짜로 이동')),
                            ),
                          ],
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          titleLabel,
                                          style: theme.textTheme.headlineMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      headerActions,
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: 240,
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              patientNames.contains(
                                                    _selectedPatientFilter,
                                                  ) ||
                                                  _selectedPatientFilter ==
                                                      'All Patients'
                                              ? _selectedPatientFilter
                                              : 'All Patients',
                                          decoration: InputDecoration(
                                            labelText: lang.tr(
                                              'Patients',
                                              '환자',
                                            ),
                                          ),
                                          items: [
                                            DropdownMenuItem(
                                              value: 'All Patients',
                                              child: Text(
                                                lang.tr(
                                                  'All Patients',
                                                  '전체 환자',
                                                ),
                                              ),
                                            ),
                                            ...patientNames.map(
                                              (name) => DropdownMenuItem(
                                                value: name,
                                                child: Text(name),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }
                                            setState(
                                              () => _selectedPatientFilter =
                                                  value,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else ...[
                              Text(
                                titleLabel,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 14),
                              headerActions,
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue:
                                    patientNames.contains(
                                          _selectedPatientFilter,
                                        ) ||
                                        _selectedPatientFilter == 'All Patients'
                                    ? _selectedPatientFilter
                                    : 'All Patients',
                                decoration: InputDecoration(
                                  labelText: lang.tr('Patients', '환자'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'All Patients',
                                    child: Text(
                                      lang.tr('All Patients', '전체 환자'),
                                    ),
                                  ),
                                  ...patientNames.map(
                                    (name) => DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(
                                    () => _selectedPatientFilter = value,
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusFilterChip('All'),
                                _statusFilterChip('Alert Ready'),
                                _statusFilterChip('Missing Profile'),
                                _statusFilterChip('No Response'),
                                _statusFilterChip('In Progress'),
                                _statusFilterChip('Complete'),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _patientFilterController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: lang.tr(
                                  'Search patient name',
                                  '환자 이름 직접 검색',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (_subView == _DashboardSubView.main &&
                  connectedPatientsWithoutVisit.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildConnectedPatientsPanel(connectedPatientsWithoutVisit),
              ],
              if (filteredVisits.isEmpty)
                AppPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('No patients', 'No patients'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              if (_subView == _DashboardSubView.main)
                ...filteredVisits.map(
                  (scheduledVisit) =>
                      _buildPatientCard(context, scheduledVisit),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectedPatientsPanel(List<PatientProfile> profiles) {
    final lang = AppLanguageController.instance;
    final theme = Theme.of(context);
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1, color: AppTheme.pine),
              const SizedBox(width: 8),
              Text(
                lang.tr('New patients', 'New patients'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.pine.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${profiles.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.pine,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: profiles.map((profile) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(profile.name, style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _openPatientManagement(
                        context,
                        initialProfileId: profile.id,
                      ),
                      child: Text(lang.tr('Open', 'Open')),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHero(
    _VisitWindowSummary summary,
    List<ScheduledVisit> visibleVisits,
    int filteredCount,
  ) {
    final readyAlerts = visibleVisits
        .where((visit) => visit.profile.hasRequiredAlertInfo)
        .length;
    final inProgressIntakes = visibleVisits
        .where((visit) => visit.visit.intakeStatus == IntakeStatus.inProgress)
        .length;
    final noResponse = visibleVisits
        .where((visit) => visit.visit.intakeStatus == IntakeStatus.notStarted)
        .length;
    final visitsMetricLabel = _selectedDateRange == null
        ? AppLanguageController.instance.tr(
            'Visits in last $_selectedRangeDays days',
            '최근 $_selectedRangeDays일 방문',
          )
        : AppLanguageController.instance.tr('Visits in range', '선택 기간 방문');
    return AppPanel(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final wide = constraints.maxWidth >= 920;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguageController.instance.tr('Today', 'Today'),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLanguageController.instance.tr(
                  '${_formatStoredDateWithWeekday(summary.fromDate)} ~ ${_formatStoredDateWithWeekday(summary.toDate)} · $filteredCount',
                  '${_formatStoredDateWithWeekday(summary.fromDate)} ~ ${_formatStoredDateWithWeekday(summary.toDate)} · $filteredCount',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.72),
                ),
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppMetricChip(
                icon: Icons.calendar_today_outlined,
                label: visitsMetricLabel,
                value: '${summary.totalVisits}',
                backgroundColor: AppTheme.surface,
                labelColor: AppTheme.ink.withValues(alpha: 0.58),
                valueColor: AppTheme.ink,
                onTap: _scrollToDateSelectorPanel,
              ),
              AppMetricChip(
                icon: Icons.notifications_active_outlined,
                label: AppLanguageController.instance.tr(
                  'Alert ready',
                  '알림 가능',
                ),
                value: '$readyAlerts',
                backgroundColor: AppTheme.surface,
                labelColor: AppTheme.ink.withValues(alpha: 0.58),
                valueColor: AppTheme.ink,
                onTap: () => _focusPatientCards(statusFilter: 'Alert Ready'),
              ),
              AppMetricChip(
                icon: Icons.pending_actions_outlined,
                label: AppLanguageController.instance.tr(
                  'Pending intakes',
                  '진행중 문진',
                ),
                value: '$inProgressIntakes',
                backgroundColor: AppTheme.surface,
                labelColor: AppTheme.ink.withValues(alpha: 0.58),
                valueColor: AppTheme.ink,
                onTap: () => _focusPatientCards(statusFilter: 'In Progress'),
              ),
              AppMetricChip(
                icon: Icons.mark_email_unread_outlined,
                label: AppLanguageController.instance.tr('No response', '미응답'),
                value: '$noResponse',
                backgroundColor: AppTheme.surface,
                labelColor: AppTheme.ink.withValues(alpha: 0.58),
                valueColor: AppTheme.ink,
                onTap: () => _focusPatientCards(statusFilter: 'No Response'),
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 18), metrics],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 10, child: intro),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 9,
                    child: Align(alignment: Alignment.topRight, child: metrics),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInsightPanel(
    _VisitWindowSummary summary,
    List<ScheduledVisit> visibleVisits,
  ) {
    final lang = AppLanguageController.instance;
    final visibleProfiles = {
      for (final scheduledVisit in visibleVisits)
        scheduledVisit.profile.id: scheduledVisit.profile,
    }.values.toList();
    final sexCounts = <String, int>{};
    for (final profile in visibleProfiles) {
      sexCounts.update(profile.sex, (value) => value + 1, ifAbsent: () => 1);
    }
    final contactReadyCount = visibleProfiles
        .where((profile) => profile.hasRequiredAlertInfo)
        .length;
    final completedVisits = visibleVisits
        .where((visit) => visit.visit.intakeStatus == IntakeStatus.completed)
        .length;
    final inProgressVisits = visibleVisits
        .where((visit) => visit.visit.intakeStatus == IntakeStatus.inProgress)
        .length;
    final noResponseVisits = visibleVisits
        .where((visit) => visit.visit.intakeStatus == IntakeStatus.notStarted)
        .length;
    final intakeCompletionRate = visibleVisits.isEmpty
        ? 0
        : ((completedVisits / visibleVisits.length) * 100).round();
    final topCareFocus = _topCountEntry(_careFocusCounts(visibleVisits));
    final topIntakeTopic = _topCountEntry(_intakeCategoryCounts(visibleVisits));
    final signalLines = <String>[
      if (topCareFocus != null)
        lang.tr(
          'Most repeated care focus: ${topCareFocus.key} (${topCareFocus.value} visits)',
          '가장 자주 본 케어 포커스: ${topCareFocus.key} ${topCareFocus.value}건',
        ),
      if (topIntakeTopic != null)
        lang.tr(
          'Most repeated intake topic: ${topIntakeTopic.key} (${topIntakeTopic.value} mentions)',
          '가장 자주 나온 문진 주제: ${topIntakeTopic.key} ${topIntakeTopic.value}건',
        ),
      if (noResponseVisits > 0 || inProgressVisits > 0)
        lang.tr(
          'Follow-up gap now: $noResponseVisits no response · $inProgressVisits in progress',
          '바로 확인할 후속 대응: 미응답 $noResponseVisits명 · 진행중 $inProgressVisits명',
        )
      else
        lang.tr(
          'All visible visits have a completed intake.',
          '현재 보이는 일정은 모두 문진 완료 상태입니다.',
        ),
    ];

    final theme = Theme.of(context);

    return AppPanel(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          AppTheme.mint.withValues(alpha: 0.58),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('Selection Snapshot', '선택 기간 요약'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniKpi(
                title: lang.tr('Visits in selection', '선택 기간 방문'),
                value: AppLanguageController.instance.tr(
                  '${summary.totalVisits}',
                  '${summary.totalVisits}명',
                ),
              ),
              _MiniKpi(
                title: lang.tr('Patients in view', '방문 환자'),
                value: AppLanguageController.instance.tr(
                  '${visibleProfiles.length}',
                  '${visibleProfiles.length}명',
                ),
              ),
              _MiniKpi(
                title: lang.tr('Contact ready', '연락 가능 환자'),
                value: AppLanguageController.instance.tr(
                  '$contactReadyCount',
                  '$contactReadyCount명',
                ),
              ),
              _MiniKpi(
                title: lang.tr('Intake completion', '문진 완료율'),
                value: '$intakeCompletionRate%',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sexCounts.isNotEmpty)
            Text(
              lang.tr(
                'Patient mix: ${sexCounts.entries.map((e) => '${e.key} ${e.value}').join(' · ')}',
                '환자 구성: ${sexCounts.entries.map((e) => '${e.key} ${e.value}명').join(' · ')}',
              ),
              style: theme.textTheme.bodyLarge,
            ),
          if (signalLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              lang.tr('Current Care Signals', '이번 기간 인사이트'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...signalLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 7, color: AppTheme.pine),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _intakeCategoryCounts(List<ScheduledVisit> visits) {
    final counts = <String, int>{};
    for (final scheduledVisit in visits) {
      final seenCategories = <String>{};
      for (final qa in scheduledVisit.visit.qaList) {
        final label = _localizedQaCategory(qa.category);
        if (label.isEmpty || !seenCategories.add(label)) {
          continue;
        }
        counts.update(label, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Map<String, int> _careFocusCounts(List<ScheduledVisit> visits) {
    final lang = AppLanguageController.instance;
    final counts = <String, int>{};

    void registerTheme(String label) {
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }

    for (final scheduledVisit in visits) {
      final visit = scheduledVisit.visit;
      final text = [
        visit.previousTreatmentArea,
        visit.previousSessionNote,
        ...visit.qaList.map(
          (qa) => '${qa.category} ${qa.question} ${qa.answer}',
        ),
      ].join(' ').toLowerCase();
      final matchedThemes = <String>{};

      bool containsAny(List<String> keywords) =>
          keywords.any((keyword) => text.contains(keyword));

      if (containsAny([
        'neck',
        'shoulder',
        'scapular',
        'cervical',
        'trapezius',
      ])) {
        matchedThemes.add(lang.tr('Neck / shoulder', '목·어깨'));
      }
      if (containsAny(['sleep', 'waking', 'fatigue', 'energy', '새벽', '수면'])) {
        matchedThemes.add(lang.tr('Sleep / energy', '수면·기력'));
      }
      if (containsAny([
        'digestion',
        'digestive',
        'abdominal',
        'bloating',
        'reflux',
        '식후',
        '소화',
      ])) {
        matchedThemes.add(lang.tr('Digestion', '소화'));
      }
      if (containsAny([
        'headache',
        'temple',
        'sinus',
        'eye strain',
        'tinnitus',
        '두통',
      ])) {
        matchedThemes.add(lang.tr('Head / HEENT', '두부·heent'));
      }
      if (containsAny([
        'lumbar',
        'glute',
        'hamstring',
        'low back',
        'driving',
        '허리',
      ])) {
        matchedThemes.add(lang.tr('Low back', '허리'));
      }

      for (final label in matchedThemes) {
        registerTheme(label);
      }
    }

    return counts;
  }

  String _localizedQaCategory(String value) {
    final lang = AppLanguageController.instance;
    switch (value.trim()) {
      case 'Temperature/Sweat':
        return lang.tr('Temperature / Sweat', '한열·땀');
      case 'Appetite/Thirst':
        return lang.tr('Appetite / Thirst', '식욕·갈증');
      case 'Sleep':
        return lang.tr('Sleep', '수면');
      case 'Digestion':
        return lang.tr('Digestion', '소화');
      case 'Urine':
        return lang.tr('Urine', '소변');
      case 'Stool':
        return lang.tr('Stool', '대변');
      case 'Menses':
        return lang.tr('Menses', '생리');
      case 'HEENT':
        return lang.tr('HEENT', '두부·heent');
      case 'Emotion':
        return lang.tr('Emotion', '감정·스트레스');
      case 'Energy':
        return lang.tr('Energy', '기력');
      default:
        return value.trim();
    }
  }

  MapEntry<String, int>? _topCountEntry(Map<String, int> counts) {
    if (counts.isEmpty) {
      return null;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.first;
  }

  Future<void> _pickDateRange() async {
    final lang = AppLanguageController.instance;
    final now = DateTime.now();
    final initial =
        _selectedDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: lang.tr('Pick start and end dates', '시작일과 종료일을 선택하세요'),
      saveText: lang.tr('Apply', '적용'),
      cancelText: lang.tr('Cancel', '취소'),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDateRange = picked;
      _selectedDate = _formatDate(picked.end);
    });
  }

  Widget _buildDateSelectorPanel() {
    final lang = AppLanguageController.instance;
    final theme = Theme.of(context);
    final rangeLabel = _selectedDateRange == null
        ? lang.tr('Last $_selectedRangeDays days', '최근 $_selectedRangeDays일')
        : '${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)}';

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          AppTheme.blush.withValues(alpha: 0.34),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: AppTheme.pine,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.tr('Date range', '날짜 범위'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(rangeLabel, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(lang.tr('Change', '변경')),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: lang.tr('Reset to last 7 days', '최근 7일로 초기화'),
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _selectedRangeDays = 7;
                });
              },
              icon: const Icon(Icons.restart_alt, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyDateSelectorPanelDeprecated() {
    final dates = _store.allDatesForClinic(_currentClinicId);
    final selectedDate = _parseDate(_selectedDate) ?? DateTime.now();
    final theme = Theme.of(context);
    return AppPanel(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          AppTheme.blush.withValues(alpha: 0.54),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguageController.instance.tr('Patients by Date', '날짜별 환자 보기'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguageController.instance.tr(
              'Switch between rolling windows and specific clinic dates without losing context.',
              '최근 기간과 특정 날짜를 오가면서도 환자 문맥을 유지할 수 있습니다.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppLanguageController.instance.tr('Range Selection', '기간 선택'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rangeChip(7),
              _rangeChip(14),
              _rangeChip(30),
              OutlinedButton.icon(
                onPressed: _pickDateRangeWithDialog,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  AppLanguageController.instance.tr('Select Range', '기간 선택'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dates.map((date) {
              final count = _store
                  .visitsForDate(date, clinicId: _currentClinicId)
                  .length;
              final isSelected =
                  _selectedDate == date && _selectedDateRange == null;
              return ChoiceChip(
                selected: isSelected,
                label: Text(
                  AppLanguageController.instance.tr(
                    '${_formatStoredDateWithWeekday(date)}  $count',
                    '${_formatStoredDateWithWeekday(date)}  $count명',
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedDate = date;
                    _selectedDateRange = null;
                    _selectedPatientFilter = 'All Patients';
                    _selectedStatusFilter = 'All';
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDateFromCalendar,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  AppLanguageController.instance.tr('Pick Date', '날짜 선택'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedDateRange == null
                      ? AppLanguageController.instance.tr(
                          'Selected Date: ${_formatDateWithWeekday(selectedDate)}',
                          '선택 날짜: ${_formatDateWithWeekday(selectedDate)}',
                        )
                      : AppLanguageController.instance.tr(
                          'Selected Range: ${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)}',
                          '선택 기간: ${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)}',
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(int days) {
    final selected = _selectedDateRange == null && _selectedRangeDays == days;
    return ChoiceChip(
      selected: selected,
      label: Text(
        AppLanguageController.instance.tr('Last $days days', '최근 $days일'),
      ),
      onSelected: (_) {
        setState(() {
          _selectedRangeDays = days;
          _selectedDateRange = null;
          _selectedPatientFilter = 'All Patients';
          _selectedStatusFilter = 'All';
        });
      },
    );
  }

  Widget _statusFilterChip(String value) {
    return ChoiceChip(
      selected: _selectedStatusFilter == value,
      label: Text(_statusFilterLabel(value)),
      onSelected: (_) {
        setState(() => _selectedStatusFilter = value);
      },
    );
  }

  String _statusFilterLabel(String value) {
    switch (value) {
      case 'All':
        return AppLanguageController.instance.tr('All', '전체');
      case 'Alert Ready':
        return AppLanguageController.instance.tr('Ready', '준비');
      case 'Missing Profile':
        return AppLanguageController.instance.tr('Missing', '부족');
      case 'No Response':
        return AppLanguageController.instance.tr('No reply', '미응답');
      case 'In Progress':
        return AppLanguageController.instance.tr('Active', '진행');
      case 'Complete':
        return AppLanguageController.instance.tr('Done', '완료');
      default:
        return value;
    }
  }

  bool _matchesStatusFilter(ScheduledVisit scheduledVisit) {
    switch (_selectedStatusFilter) {
      case 'Alert Ready':
        return scheduledVisit.profile.hasRequiredAlertInfo;
      case 'Missing Profile':
        return !scheduledVisit.profile.hasRequiredAlertInfo;
      case 'No Response':
        return scheduledVisit.visit.intakeStatus == IntakeStatus.notStarted;
      case 'In Progress':
        return scheduledVisit.visit.intakeStatus == IntakeStatus.inProgress;
      case 'Complete':
        return scheduledVisit.visit.intakeStatus == IntakeStatus.completed;
      case 'All':
      default:
        return true;
    }
  }

  Widget _buildPatientCard(
    BuildContext context,
    ScheduledVisit scheduledVisit,
  ) {
    final profile = scheduledVisit.profile;
    final visit = scheduledVisit.visit;
    final firstQa = visit.qaList.isEmpty
        ? AppLanguageController.instance.tr('No intake', '문진 없음')
        : '${visit.qaList.first.question} / ${visit.qaList.first.answer}';
    final currentInputLabel = visit.qaList.isEmpty
        ? AppLanguageController.instance.tr(
            'Current visit status for this selected booking date',
            '선택한 예약 날짜 기준 현재 방문 상태',
          )
        : AppLanguageController.instance.tr(
            'Current visit intake submitted from the patient portal',
            '환자 포털에서 제출한 이번 방문 문진',
          );
    final canSendRequest = profile.hasRequiredAlertInfo;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        '${profile.name} · ${_formatStoredDateWithWeekday(visit.date)} ${visit.time}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentInputLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(firstQa),
                      const SizedBox(height: 6),
                      Text(
                        AppLanguageController.instance.tr(
                          'Last Visit: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${visit.daysAgo} days ago)',
                          '지난 방문: ${_formatStoredDateWithWeekday(visit.lastVisitDate)} (${visit.daysAgo}일 전)',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _visitTrailLabel(visit),
                        style: TextStyle(
                          color: visit.noShowSinceLast > 0
                              ? Colors.redAccent
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppLanguageController.instance.tr('Contact', '연락처')}: ${profile.phone.isEmpty ? AppLanguageController.instance.tr('Missing', '미입력') : profile.phone} / ${profile.email.isEmpty ? AppLanguageController.instance.tr('Email missing', '이메일 미입력') : profile.email}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLanguageController.instance.tr('Profile', '환자 정보')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(visit.intakeStatus.label)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: canSendRequest
                      ? () => _sendReminder(context, scheduledVisit)
                      : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    canSendRequest
                        ? AppLanguageController.instance.tr('Request', '요청')
                        : AppLanguageController.instance.tr(
                            'Contact Needed',
                            '연락처 필요',
                          ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _sendPatientNote(context, scheduledVisit),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(AppLanguageController.instance.tr('Note', '쪽지')),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      PatientBriefScreen.routeName,
                      arguments: PatientHistoryArgs(
                        current: scheduledVisit,
                        history: _store.historyForPatient(
                          profile.id,
                          clinicId: _currentClinicId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right),
                  label: Text(
                    AppLanguageController.instance.tr('Detail', '상세'),
                  ),
                ),
              ],
            ),
            if (!canSendRequest) ...[
              const SizedBox(height: 8),
              Text(
                AppLanguageController.instance.tr(
                  'Phone and email needed.',
                  '전화번호와 이메일 필요',
                ),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            _PatientRealtimeActivity(
              patientId: profile.id,
              clinicId: visit.clinicId,
            ),
          ],
        ),
      ),
    );
  }

  bool _storedDateMatchesSelectedWindow(String storedDate) {
    if (_selectedDateRange == null) {
      return storedDate == _selectedDate;
    }
    final parsed = _parseDate(storedDate);
    if (parsed == null) {
      return false;
    }
    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    final start = DateTime(
      _selectedDateRange!.start.year,
      _selectedDateRange!.start.month,
      _selectedDateRange!.start.day,
    );
    final end = DateTime(
      _selectedDateRange!.end.year,
      _selectedDateRange!.end.month,
      _selectedDateRange!.end.day,
    );
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  bool _isActiveAppointmentRequest(AppointmentRequest request) {
    return request.status == AppointmentRequestStatus.pending ||
        request.status == AppointmentRequestStatus.confirmed;
  }

  List<AppointmentRequest> _selectedWindowRequests() {
    if (!_hasClinicContext) {
      return const [];
    }
    final items =
        _store
            .appointmentRequestsForClinic(_currentClinicId)
            .where(_isActiveAppointmentRequest)
            .where((request) => _storedDateMatchesSelectedWindow(request.date))
            .toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) {
              return dateCompare;
            }
            final timeCompare = a.time.compareTo(b.time);
            if (timeCompare != 0) {
              return timeCompare;
            }
            return a.patientId.compareTo(b.patientId);
          });
    return items;
  }

  bool _storedDateMatchesSummaryWindow(String storedDate) {
    if (_selectedDateRange != null) {
      return _storedDateMatchesSelectedWindow(storedDate);
    }
    final parsed = _parseDate(storedDate);
    if (parsed == null) {
      return false;
    }
    final selected = _parseDate(_selectedDate) ?? DateTime.now();
    final end = DateTime(selected.year, selected.month, selected.day);
    final start = end.subtract(Duration(days: _selectedRangeDays - 1));
    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  List<AppointmentRequest> _summaryWindowRequests() {
    if (!_hasClinicContext) {
      return const [];
    }
    final items =
        _store
            .appointmentRequestsForClinic(_currentClinicId)
            .where(_isActiveAppointmentRequest)
            .where((request) => _storedDateMatchesSummaryWindow(request.date))
            .toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) {
              return dateCompare;
            }
            final timeCompare = a.time.compareTo(b.time);
            if (timeCompare != 0) {
              return timeCompare;
            }
            return a.patientId.compareTo(b.patientId);
          });
    return items;
  }

  Set<String> _selectedWindowPatientIds() {
    return _selectedWindowRequests()
        .map((request) => request.patientId)
        .toSet();
  }

  Map<String, Map<String, dynamic>> _latestSubmissionByPatient(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> submissionDocs,
  ) {
    if (!_hasClinicContext) {
      return const <String, Map<String, dynamic>>{};
    }
    final items =
        submissionDocs.where((doc) {
          final source = (doc.data()['source'] ?? '').toString();
          final clinicId = (doc.data()['clinicId'] ?? '').toString();
          return (source.isEmpty || source == 'patient_intake_screen') &&
              clinicId == _currentClinicId;
        }).toList()..sort((a, b) {
          final aTime =
              (a.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          final bTime =
              (b.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              0;
          return bTime.compareTo(aTime);
        });

    final latestByPatient = <String, Map<String, dynamic>>{};
    for (final doc in items) {
      final patientId = (doc.data()['patientId'] ?? '').toString();
      if (patientId.isEmpty || latestByPatient.containsKey(patientId)) {
        continue;
      }
      latestByPatient[patientId] = doc.data();
    }
    return latestByPatient;
  }

  bool _matchesCurrentClinicDoc(Map<String, dynamic> data) {
    if (!_hasClinicContext) {
      return false;
    }
    final clinicId = (data['clinicId'] ?? '').toString();
    return clinicId == _currentClinicId;
  }

  DateTime? _slotDateTime(String storedDate, String slotTime) {
    final date = _parseDate(storedDate);
    if (date == null) {
      return null;
    }
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(slotTime.trim());
    if (match == null) {
      return DateTime(date.year, date.month, date.day);
    }
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)!.toUpperCase();
    if (meridiem == 'PM' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'AM' && hour == 12) {
      hour = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  ScheduledVisit? _latestHistoryBeforeSlot(
    String patientId,
    String storedDate,
    String slotTime,
  ) {
    final targetDateTime = _slotDateTime(storedDate, slotTime);
    final history = _store.historyForPatient(
      patientId,
      clinicId: _currentClinicId,
    );
    for (final item in history) {
      final historyDateTime = _slotDateTime(item.visit.date, item.visit.time);
      if (historyDateTime == null || targetDateTime == null) {
        if (item.visit.date != storedDate || item.visit.time != slotTime) {
          return item;
        }
        continue;
      }
      if (historyDateTime.isBefore(targetDateTime)) {
        return item;
      }
    }
    return null;
  }

  String _submissionCategory(String questionText) {
    final value = questionText.toLowerCase();
    if (value.contains('sleep') || value.contains('wake')) {
      return 'Sleep';
    }
    if (value.contains('stress') ||
        value.contains('mood') ||
        value.contains('emotion')) {
      return 'Emotion';
    }
    if (value.contains('energy') || value.contains('fatigue')) {
      return 'Energy';
    }
    if (value.contains('appetite') ||
        value.contains('thirst') ||
        value.contains('drink')) {
      return 'Appetite/Thirst';
    }
    if (value.contains('digest') ||
        value.contains('bloat') ||
        value.contains('meal')) {
      return 'Digestion';
    }
    if (value.contains('bowel') || value.contains('stool')) {
      return 'Stool';
    }
    if (value.contains('urine')) {
      return 'Urine';
    }
    if (value.contains('headache') ||
        value.contains('eye') ||
        value.contains('sinus') ||
        value.contains('neck') ||
        value.contains('shoulder')) {
      return 'HEENT';
    }
    if (value.contains('period') ||
        value.contains('cycle') ||
        value.contains('menstrual')) {
      return 'Menses';
    }
    if (value.contains('sweat') ||
        value.contains('cold') ||
        value.contains('hot')) {
      return 'Temperature/Sweat';
    }
    return 'Patient Intake';
  }

  List<QaItem> _qaListFromSubmission(Map<String, dynamic>? data) {
    if (data == null) {
      return const [];
    }
    final answers = (data['answers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((answer) {
          final questionText = (answer['questionText'] ?? '').toString().trim();
          final answerText = (answer['answerText'] ?? '').toString().trim();
          if (questionText.isEmpty || answerText.isEmpty) {
            return null;
          }
          return QaItem(
            category: _submissionCategory(questionText),
            question: questionText,
            answer: answerText,
          );
        })
        .whereType<QaItem>()
        .toList();
    return answers;
  }

  List<ScheduledVisit> _buildVisitsFromRequests(
    List<AppointmentRequest> requests,
  ) {
    final visits = <ScheduledVisit>[];

    for (final request in requests) {
      final profile = _store.profileById(request.patientId);
      if (profile == null) {
        continue;
      }
      final latestHistory = _latestHistoryBeforeSlot(
        request.patientId,
        request.date,
        request.time,
      );
      final targetDate = _parseDate(request.date);
      final latestHistoryDate = latestHistory == null
          ? null
          : _parseDate(latestHistory.visit.date);
      final daysAgo = targetDate == null || latestHistoryDate == null
          ? 0
          : targetDate.difference(latestHistoryDate).inDays;
      final submission = _latestPatientIntakeByPatient[request.patientId];
      final qaList = _qaListFromSubmission(submission);

      visits.add(
        ScheduledVisit(
          profile: profile,
          visit: PatientVisit(
            id: 'dashboard_${request.id}',
            patientId: profile.id,
            clinicId: request.clinicId,
            date: request.date,
            time: request.time,
            lastVisitDate: latestHistory?.visit.date ?? request.date,
            daysAgo: daysAgo < 0 ? 0 : daysAgo,
            scheduledSinceLast: latestHistory == null ? 0 : 1,
            noShowSinceLast: 0,
            intakeStatus: qaList.isEmpty
                ? IntakeStatus.notStarted
                : IntakeStatus.completed,
            previousTreatmentArea:
                latestHistory?.visit.previousTreatmentArea ??
                AppLanguageController.instance.tr('No prior area', '이전 부위 없음'),
            previousSessionNote:
                latestHistory?.visit.previousSessionNote ??
                AppLanguageController.instance.tr('Portal booking', '포털 예약'),
            qaList: qaList,
          ),
        ),
      );
    }

    visits.sort((a, b) {
      final dateCompare = a.visit.date.compareTo(b.visit.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final timeCompare = a.visit.time.compareTo(b.visit.time);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return a.profile.name.compareTo(b.profile.name);
    });
    return visits;
  }

  List<ScheduledVisit> _visibleVisits() {
    return _buildVisitsFromRequests(_selectedWindowRequests());
  }

  List<ScheduledVisit> _summaryWindowVisits() {
    return _buildVisitsFromRequests(_summaryWindowRequests());
  }

  Widget _buildPatientInboxBoard() {
    final lang = AppLanguageController.instance;
    final selectedPatientIds = _selectedWindowPatientIds();
    final requests =
        _store
            .appointmentRequestsForClinic(_currentClinicId)
            .where(
              (request) =>
                  request.status == AppointmentRequestStatus.pending &&
                  _storedDateMatchesSelectedWindow(request.date),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr('Patient Inbox', '환자 쪽지함'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppLanguageController.instance.tr(
                'Check patient-sent appointment requests, visit-record updates, and recent intake submissions in one place.',
                '환자가 보낸 예약 신청, 방문기록 수정 요청, 최근 문진 제출을 여기서 한 번에 확인합니다.',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('visit_record_feedback')
                  .snapshots(),
              builder: (context, feedbackSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('intake_submissions')
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    final pendingFeedbackCount =
                        [...?feedbackSnapshot.data?.docs].where((doc) {
                          final data = doc.data();
                          final feedbackText =
                              (data['feedbackText'] as String? ?? '').trim();
                          return feedbackText.isNotEmpty &&
                              _matchesCurrentClinicDoc(data) &&
                              _storedDateMatchesSelectedWindow(
                                (data['visitDate'] ?? '').toString(),
                              ) &&
                              (data['status'] ?? 'pending') != 'reviewed';
                        }).length;
                    final recentSubmissionCount =
                        [...?submissionSnapshot.data?.docs].where((doc) {
                          final source = (doc.data()['source'] ?? '')
                              .toString();
                          final patientId = (doc.data()['patientId'] ?? '')
                              .toString();
                          return (source.isEmpty ||
                                  source == 'patient_intake_screen') &&
                              _matchesCurrentClinicDoc(doc.data()) &&
                              selectedPatientIds.contains(patientId);
                        }).length;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        AppMetricChip(
                          icon: Icons.calendar_today_outlined,
                          label: lang.tr('Appointment requests', '예약 신청'),
                          value: '${requests.length}',
                          onTap: _scrollToAppointmentRequestsSection,
                        ),
                        AppMetricChip(
                          icon: Icons.mark_email_unread_outlined,
                          label: lang.tr('Record updates', '수정 요청'),
                          value: '$pendingFeedbackCount',
                          onTap: _scrollToRecordUpdatesSection,
                        ),
                        AppMetricChip(
                          icon: Icons.assignment_turned_in_outlined,
                          label: lang.tr('Recent submissions', '최근 제출'),
                          value: '$recentSubmissionCount',
                          onTap: _scrollToRecentSubmissionsSection,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _appointmentRequestsSectionKey,
              child: Text(
                lang.tr('Appointments', '예약'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 6),
            if (requests.isEmpty)
              Text(
                AppLanguageController.instance.tr(
                  'No appointment requests',
                  '예약 신청 없음',
                ),
              )
            else
              ...requests.map((request) {
                final profile = _store.profileById(request.patientId);
                if (profile == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.name} · ${_formatStoredDateWithWeekday(request.date)} ${request.time}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLanguageController.instance.tr('Requested', '신청')}: '
                          '${_formatDateTimeValue(request.requestedAt)}',
                        ),
                        Text(
                          '${AppLanguageController.instance.tr('Contact', '연락처')}: '
                          '${profile.phone.isEmpty ? AppLanguageController.instance.tr('Missing', '미입력') : profile.phone}'
                          ' / '
                          '${profile.email.isEmpty ? AppLanguageController.instance.tr('Email missing', '이메일 미입력') : profile.email}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                _store.confirmAppointmentRequest(request.id);
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                AppLanguageController.instance.tr(
                                  'Confirm',
                                  '확정하기',
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _store.declineAppointmentRequest(request.id);
                              },
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text(
                                AppLanguageController.instance.tr(
                                  'Decline',
                                  '거절하기',
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openLatestPatientBriefForProfile(profile),
                              icon: const Icon(Icons.history_outlined),
                              label: Text(lang.tr('History', '기록')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openPatientManagement(
                                context,
                                initialProfileId: profile.id,
                              ),
                              icon: const Icon(Icons.person_outline),
                              label: Text(lang.tr('Patient', '환자')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('visit_record_feedback')
                  .snapshots(),
              builder: (context, feedbackSnapshot) {
                final pendingFeedbackDocs = [...?feedbackSnapshot.data?.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['updatedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['updatedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });
                final actionableDocs = pendingFeedbackDocs.where((doc) {
                  final data = doc.data();
                  final feedbackText = (data['feedbackText'] as String? ?? '')
                      .trim();
                  return feedbackText.isNotEmpty &&
                      _matchesCurrentClinicDoc(data) &&
                      _storedDateMatchesSelectedWindow(
                        (data['visitDate'] ?? '').toString(),
                      ) &&
                      (data['status'] ?? 'pending') != 'reviewed';
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: _recordUpdatesSectionKey,
                      child: Text(
                        lang.tr('Visit-record update requests', '방문기록 수정 요청'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!feedbackSnapshot.hasData)
                      const LinearProgressIndicator(minHeight: 4)
                    else if (feedbackSnapshot.hasError)
                      Text(
                        lang.tr(
                          'Could not load patient update messages.',
                          '환자 수정 요청을 불러오지 못했습니다.',
                        ),
                        style: const TextStyle(color: Colors.redAccent),
                      )
                    else if (actionableDocs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(lang.tr('No updates', '수정 요청 없음')),
                      )
                    else
                      ...actionableDocs.take(4).map((doc) {
                        final data = doc.data();
                        final patientId = (data['patientId'] ?? '').toString();
                        final visitId = (data['visitId'] ?? '').toString();
                        final patientName = (data['patientName'] ?? '')
                            .toString();
                        final visitDate = (data['visitDate'] ?? '-').toString();
                        final visitTime = (data['visitTime'] ?? '-').toString();
                        final feedbackText = (data['feedbackText'] ?? '')
                            .toString()
                            .trim();
                        final updatedAt = (data['updatedAt'] as Timestamp?)
                            ?.toDate();
                        final profile = _store.profileById(patientId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FBFA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD7EAE6),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$patientName · ${_formatStoredDateWithWeekday(visitDate)} $visitTime',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lang.tr('Updated At', '수정 시각')}: ${updatedAt == null ? lang.tr('Just now', '방금 전') : _formatDateTimeValue(updatedAt)}',
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(feedbackText),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed:
                                          patientId.isEmpty || visitId.isEmpty
                                          ? null
                                          : () async {
                                              await AppFirestoreService.markVisitRecordFeedbackReviewed(
                                                patientId: patientId,
                                                visitId: visitId,
                                              );
                                              if (!context.mounted) {
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    lang.tr(
                                                      'Marked the patient update as reviewed.',
                                                      '환자 수정 요청을 확인 완료로 표시했습니다.',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: const Icon(
                                        Icons.mark_email_read_outlined,
                                      ),
                                      label: Text(
                                        lang.tr('Mark Reviewed', '확인 완료'),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: profile == null
                                          ? null
                                          : () => _openPatientManagement(
                                              context,
                                              initialProfileId: profile.id,
                                            ),
                                      icon: const Icon(Icons.person_outline),
                                      label: Text(lang.tr('Patient', '환자')),
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
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('intake_submissions')
                  .snapshots(),
              builder: (context, submissionSnapshot) {
                final recentSubmissionDocs = [...?submissionSnapshot.data?.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });
                final patientSubmissions = recentSubmissionDocs
                    .where((doc) {
                      final source = (doc.data()['source'] ?? '').toString();
                      final patientId = (doc.data()['patientId'] ?? '')
                          .toString();
                      return (source.isEmpty ||
                              source == 'patient_intake_screen') &&
                          _matchesCurrentClinicDoc(doc.data()) &&
                          selectedPatientIds.contains(patientId);
                    })
                    .take(4)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: _recentSubmissionsSectionKey,
                      child: Text(
                        lang.tr('Recent intake submissions', '최근 문진 제출'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang.tr(
                        'When patients submit from their side, the newest intake updates appear here.',
                        '환자 화면에서 문진을 제출하면 최신 내용이 여기로 올라옵니다.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!submissionSnapshot.hasData)
                      const LinearProgressIndicator(minHeight: 4)
                    else if (submissionSnapshot.hasError)
                      Text(
                        lang.tr(
                          'Could not load recent patient submissions.',
                          '최근 환자 문진 제출을 불러오지 못했습니다.',
                        ),
                        style: const TextStyle(color: Colors.redAccent),
                      )
                    else if (patientSubmissions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSoft.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(lang.tr('No submissions', '제출 없음')),
                      )
                    else
                      ...patientSubmissions.map((doc) {
                        final data = doc.data();
                        final patientId = (data['patientId'] ?? '').toString();
                        final patientName = (data['patientName'] ?? '')
                            .toString();
                        final visitType = (data['visitType'] ?? 'follow_up')
                            .toString();
                        final answers =
                            (data['answers'] as List<dynamic>? ?? const [])
                                .length;
                        final extraMemo = (data['extraMemo'] as String? ?? '')
                            .trim();
                        final submittedAt = (data['submittedAt'] as Timestamp?)
                            ?.toDate();
                        final profile = _store.profileById(patientId);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientName.isEmpty
                                      ? lang.tr('Unknown patient', '미확인 환자')
                                      : patientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${lang.tr('Submitted At', '제출 시각')}: ${submittedAt == null ? lang.tr('Just now', '방금 전') : _formatDateTimeValue(submittedAt)}',
                                ),
                                Text(
                                  '${lang.tr('Visit Type', '방문 유형')}: ${visitType == 'initial' ? lang.tr('Initial', '초진') : lang.tr('Follow-up', '재진')} · ${lang.tr('Answers', '답변')} $answers',
                                ),
                                if (extraMemo.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('${lang.tr('Memo', '메모')}: $extraMemo'),
                                ],
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: profile == null
                                      ? null
                                      : () => _openPatientManagement(
                                          context,
                                          initialProfileId: profile.id,
                                        ),
                                  icon: const Icon(Icons.person_outline),
                                  label: Text(lang.tr('Patient', '환자')),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBoard() {
    final lang = AppLanguageController.instance;
    final grouped = <String, List<AppointmentSlot>>{};

    bool slotInRange(String slotDate) {
      if (_selectedDateRange == null) {
        return true;
      }
      final parsed = _parseDate(slotDate);
      if (parsed == null) return true;
      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
      );
      return !parsed.isBefore(start) && !parsed.isAfter(end);
    }

    for (final slot in _store.slotsForClinic(_currentClinicId)) {
      if (!slotInRange(slot.date)) continue;
      grouped.putIfAbsent(slot.date, () => <AppointmentSlot>[]).add(slot);
    }
    final dates = grouped.keys.toList()..sort();

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
                    AppLanguageController.instance.tr(
                      'Shared Time Slots',
                      '공유 예약 슬롯',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: lang.tr('Open daily patient counts', '날짜별 환자 수 보기'),
                  onPressed: _openAvailabilityDateCountsSheet,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr(
                'Turn off any time you do not want patients to see. Reserved patients appear by name, and you can tap them to open patient info.',
                '침술사가 원하지 않는 시간은 꺼둘 수 있고, 예약된 환자는 이름으로 표시되며 눌러서 환자 정보를 볼 수 있습니다.',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...dates.map((date) {
              final slots = grouped[date]!
                ..sort((a, b) => a.time.compareTo(b.time));
              final patientCount = _store
                  .visitsForDate(date, clinicId: _currentClinicId)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatStoredDateWithWeekday(date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lang.tr(
                        'Patients on this date: $patientCount',
                        '이 날짜 환자 수: $patientCount명',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: slots.map((slot) {
                        final occupancy = _slotOccupancyFor(slot);
                        return _buildAvailabilitySlotRow(
                          slot: slot,
                          occupancy: occupancy,
                          lang: lang,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySlotRow({
    required AppointmentSlot slot,
    required _SlotOccupancy? occupancy,
    required AppLanguageController lang,
  }) {
    final reserved = occupancy != null;
    final isConfirmed = reserved && occupancy.scheduledVisit != null;
    final reservedColor = isConfirmed ? AppTheme.pine : AppTheme.copper;

    final timeText = Text(
      slot.time,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: reserved ? Colors.black87 : Colors.black,
        decoration: reserved ? TextDecoration.lineThrough : null,
        decorationColor: reservedColor,
        decorationThickness: 2,
      ),
    );

    final Widget rightSide;
    if (reserved) {
      rightSide = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed
                ? Icons.event_available_outlined
                : Icons.hourglass_top_outlined,
            size: 16,
            color: reservedColor,
          ),
          const SizedBox(width: 6),
          Text(
            isConfirmed ? lang.tr('Booked', '예약됨') : lang.tr('Pending', '대기중'),
            style: TextStyle(
              color: reservedColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      );
    } else {
      rightSide = Switch(
        value: slot.isOpen,
        onChanged: (selected) {
          _store.setSlotOpen(
            clinicId: slot.clinicId,
            date: slot.date,
            time: slot.time,
            isOpen: selected,
          );
        },
      );
    }

    final Widget body = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: reserved
            ? (isConfirmed ? const Color(0xFFE3F3EF) : const Color(0xFFF6E7D7))
            : (slot.isOpen ? const Color(0xFFEFEFEF) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reserved
              ? (isConfirmed
                    ? const Color(0xFFCFE6DE)
                    : const Color(0xFFE2C6A6))
              : (slot.isOpen
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: timeText),
              const SizedBox(width: 8),
              rightSide,
            ],
          ),
          if (reserved) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: reservedColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      occupancy.profile.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black.withValues(alpha: 0.84),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              slot.isOpen
                  ? lang.tr('Open · patients can book', '열림 · 환자가 예약 가능')
                  : lang.tr(
                      'Hidden · not visible to patients',
                      '숨김 · 환자에게 보이지 않음',
                    ),
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.58),
              ),
            ),
          ],
        ],
      ),
    );

    if (reserved) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openReservedSlotPatientInfo(context, occupancy),
          child: body,
        ),
      );
    }
    return body;
  }

  Future<void> _openAvailabilityDateCountsSheet() async {
    final lang = AppLanguageController.instance;
    final dates =
        _store
            .slotsForClinic(_currentClinicId)
            .map((slot) => slot.date)
            .toSet()
            .toList()
          ..sort();

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('Daily counts', '날짜별 수'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  lang.tr('By date', '날짜별'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                ...dates.map((date) {
                  final patientCount = _store
                      .visitsForDate(date, clinicId: _currentClinicId)
                      .length;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatStoredDateWithWeekday(date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            lang.tr('$patientCount patients', '$patientCount명'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppTheme.pine,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  _SlotOccupancy? _slotOccupancyFor(AppointmentSlot slot) {
    final scheduledVisit = _store.scheduledVisitForSlot(
      slot.date,
      slot.time,
      clinicId: _currentClinicId,
    );
    if (scheduledVisit != null) {
      return _SlotOccupancy(
        profile: scheduledVisit.profile,
        scheduledVisit: scheduledVisit,
      );
    }

    final request = _store.latestActiveRequestForSlot(
      slot.date,
      slot.time,
      clinicId: _currentClinicId,
    );
    if (request == null) {
      return null;
    }

    final profile = _store.profileById(request.patientId);
    if (profile == null) {
      return null;
    }

    return _SlotOccupancy(profile: profile, appointmentRequest: request);
  }

  Future<void> _openReservedSlotPatientInfo(
    BuildContext context,
    _SlotOccupancy occupancy,
  ) async {
    final lang = AppLanguageController.instance;
    final history = _store.historyForPatient(
      occupancy.profile.id,
      clinicId: _currentClinicId,
    );
    final latestHistory = history.isNotEmpty ? history.first.visit : null;
    final scheduledVisit = occupancy.scheduledVisit;
    final request = occupancy.appointmentRequest;
    final slotDate = _formatStoredDateWithWeekday(
      scheduledVisit?.visit.date ?? request?.date ?? '-',
    );
    final slotTime = scheduledVisit?.visit.time ?? request?.time ?? '-';
    final statusLabel = scheduledVisit != null
        ? lang.tr('Booked appointment', '예약 확정')
        : lang.tr('Pending appointment request', '예약 신청 대기');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(occupancy.profile.name),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('${lang.tr('Slot', '슬롯')}: $slotDate $slotTime'),
                  const SizedBox(height: 4),
                  Text(
                    '${lang.tr('Contact', '연락처')}: '
                    '${occupancy.profile.phone.isEmpty ? lang.tr('Phone missing', '전화번호 없음') : occupancy.profile.phone}'
                    ' / '
                    '${occupancy.profile.email.isEmpty ? lang.tr('Email missing', '이메일 없음') : occupancy.profile.email}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lang.tr('Profile', '프로필')}: '
                    '${occupancy.profile.sex}, ${occupancy.profile.ageRange}, ${occupancy.profile.ethnicity}',
                  ),
                  if (request != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Requested', '신청')}: '
                      '${_formatDateTimeValue(request.requestedAt)}',
                    ),
                  ],
                  if (latestHistory != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      lang.tr('Last Visit Summary', '지난 방문 요약'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${lang.tr('Last visit', '지난 방문')}: ${_formatStoredDateWithWeekday(latestHistory.date)} ${latestHistory.time}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Treatment area', '치료 부위')}: ${latestHistory.previousTreatmentArea}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Practitioner note', '침술사 메모')}: ${latestHistory.previousSessionNote}',
                    ),
                  ],
                  if (occupancy.profile.memo.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      lang.tr('Internal Note', '관리 메모'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(occupancy.profile.memo),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(lang.tr('Close', '닫기')),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openPatientManagement(
                  context,
                  initialProfileId: occupancy.profile.id,
                );
              },
              icon: const Icon(Icons.badge_outlined),
              label: Text(lang.tr('Patient', '환자')),
            ),
            if (scheduledVisit != null)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(
                    context,
                    PatientBriefScreen.routeName,
                    arguments: PatientHistoryArgs(
                      current: scheduledVisit,
                      history: _store.historyForPatient(
                        occupancy.profile.id,
                        clinicId: _currentClinicId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chevron_right),
                label: Text(lang.tr('Detail', '상세')),
              ),
          ],
        );
      },
    );
  }

  _VisitWindowSummary _visitWindowSummary(List<ScheduledVisit> visibleVisits) {
    if (_selectedDateRange != null) {
      return _VisitWindowSummary(
        days: _selectedDateRange!.duration.inDays + 1,
        totalVisits: visibleVisits.length,
        fromDate: _formatDate(_selectedDateRange!.start),
        toDate: _formatDate(_selectedDateRange!.end),
        periodLabel: AppLanguageController.instance.tr(
          '${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)} ${visibleVisits.length}',
          '${_formatDateWithWeekday(_selectedDateRange!.start)} ~ ${_formatDateWithWeekday(_selectedDateRange!.end)} ${visibleVisits.length}명',
        ),
      );
    }

    final selected = _parseDate(_selectedDate) ?? DateTime.now();
    final start = selected.subtract(Duration(days: _selectedRangeDays - 1));
    return _VisitWindowSummary(
      days: _selectedRangeDays,
      totalVisits: visibleVisits.length,
      fromDate: _formatDate(start),
      toDate: _formatDate(selected),
      periodLabel: AppLanguageController.instance.tr(
        '${_formatDateWithWeekday(start)} ~ ${_formatDateWithWeekday(selected)} ${visibleVisits.length}',
        '${_formatDateWithWeekday(start)} ~ ${_formatDateWithWeekday(selected)} ${visibleVisits.length}명',
      ),
    );
  }

  String _visitTrailLabel(PatientVisit visit) {
    if (visit.scheduledSinceLast == 0 && visit.noShowSinceLast == 0) {
      return AppLanguageController.instance.tr(
        'No additional appointments since the last visit -> this is the first return visit',
        '지난 방문 이후 추가 예약 없음 -> 이번 방문이 첫 재내원',
      );
    }
    return AppLanguageController.instance.tr(
      'Since last visit: ${visit.scheduledSinceLast} more appointment(s), ${visit.noShowSinceLast} no-show(s)',
      '지난 방문 이후 추가 예약 ${visit.scheduledSinceLast}건, 노쇼 ${visit.noShowSinceLast}건',
    );
  }

  Future<void> _sendReminder(
    BuildContext context,
    ScheduledVisit scheduledVisit,
  ) async {
    final profile = scheduledVisit.profile;
    final visit = scheduledVisit.visit;
    final selectedQuestions = <String>{};
    final noteController = TextEditingController();
    final customQuestionsByCategory = <String, List<String>>{};
    final answeredByCategory = <String, List<QaItem>>{};

    for (final qa in visit.qaList) {
      answeredByCategory.putIfAbsent(qa.category, () => <QaItem>[]).add(qa);
    }

    final totalAnsweredCount = visit.qaList.length;
    final answeredCategoryCount = answeredByCategory.keys.length;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppLanguageController.instance.tr(
              'Request Answers from ${profile.name}',
              '${profile.name}님 답변 요청',
            ),
          ),
          content: SizedBox(
            width: 520,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${AppLanguageController.instance.tr('Contact target', '전송 대상 연락처')}: '
                          '${profile.phone.isEmpty ? AppLanguageController.instance.tr('Phone missing', '전화번호 없음') : profile.phone}'
                          '${profile.email.isEmpty ? ' / ${AppLanguageController.instance.tr('Email missing', '이메일 없음')}' : ' / ${profile.email}'}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7EAE6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLanguageController.instance.tr(
                                'Answered',
                                '답변됨',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLanguageController.instance.tr(
                                '$totalAnsweredCount answer(s) · $answeredCategoryCount categor${answeredCategoryCount == 1 ? 'y' : 'ies'}',
                                '$totalAnsweredCount개 답변 · $answeredCategoryCount개 카테고리',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLanguageController.instance.tr(
                          'Request questions',
                          '질문 요청',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._questionLibraryByCategory.entries.map((entry) {
                        final answeredItems =
                            answeredByCategory[entry.key] ?? const <QaItem>[];
                        return ExpansionTile(
                          dense: true,
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: answeredItems.isEmpty
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  answeredItems.isEmpty
                                      ? AppLanguageController.instance.tr(
                                          'None',
                                          '없음',
                                        )
                                      : AppLanguageController.instance.tr(
                                          '${answeredItems.length}',
                                          '${answeredItems.length}',
                                        ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: answeredItems.isEmpty
                                        ? Colors.orange.shade800
                                        : Colors.teal.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            if (answeredItems.isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLanguageController.instance.tr(
                                        'Answered',
                                        '답변',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...answeredItems.map(
                                      (qa) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '• ${qa.question}\n  ${qa.answer}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...entry.value.map((question) {
                              final answeredItem = answeredItems
                                  .cast<QaItem?>()
                                  .firstWhere(
                                    (qa) => qa?.question == question,
                                    orElse: () => null,
                                  );
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(question),
                                subtitle: answeredItem == null
                                    ? Text(
                                        AppLanguageController.instance.tr(
                                          'No answer',
                                          '답변 없음',
                                        ),
                                      )
                                    : Text(
                                        AppLanguageController.instance.tr(
                                          'Answered: ${answeredItem.answer}',
                                          '답변: ${answeredItem.answer}',
                                        ),
                                      ),
                                value: selectedQuestions.contains(question),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedQuestions.add(question);
                                    } else {
                                      selectedQuestions.remove(question);
                                    }
                                  });
                                },
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final controller = TextEditingController();
                                  final custom = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(
                                          AppLanguageController.instance.tr(
                                            'Add Custom Question for ${entry.key}',
                                            '${entry.key} 직접 질문 입력',
                                          ),
                                        ),
                                        content: TextField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(),
                                            hintText: AppLanguageController
                                                .instance
                                                .tr(
                                                  'Example: Does the symptom get worse in a specific situation?',
                                                  '예: 특정 상황에서 증상이 더 심해지나요?',
                                                ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              AppLanguageController.instance.tr(
                                                'Cancel',
                                                '취소',
                                              ),
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              controller.text.trim(),
                                            ),
                                            child: Text(
                                              AppLanguageController.instance.tr(
                                                'Add',
                                                '추가',
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  controller.dispose();
                                  if (custom == null || custom.isEmpty) {
                                    return;
                                  }
                                  setDialogState(() {
                                    customQuestionsByCategory
                                        .putIfAbsent(
                                          entry.key,
                                          () => <String>[],
                                        )
                                        .add(custom);
                                  });
                                },
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: Text(
                                  AppLanguageController.instance.tr(
                                    'Add Custom Question',
                                    '직접 질문 추가',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (customQuestionsByCategory.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...customQuestionsByCategory.entries.map((entry) {
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Chip(label: Text(entry.key)),
                              ...entry.value.map(
                                (question) => Chip(
                                  label: Text(question),
                                  onDeleted: () {
                                    setDialogState(() {
                                      entry.value.remove(question);
                                      if (entry.value.isEmpty) {
                                        customQuestionsByCategory.remove(
                                          entry.key,
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLanguageController.instance.tr(
                            'Note (message for the patient)',
                            '노트 (환자에게 전달할 말)',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                noteController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text(AppLanguageController.instance.tr('Cancel', '취소')),
            ),
            FilledButton(
              onPressed: !profile.hasRequiredAlertInfo
                  ? null
                  : () async {
                      final customCount = customQuestionsByCategory.values
                          .fold<int>(
                            0,
                            (runningTotal, list) => runningTotal + list.length,
                          );
                      if (selectedQuestions.isEmpty && customCount == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLanguageController.instance.tr(
                                'Please select at least one question or add a custom question.',
                                '질문을 1개 이상 선택하거나 직접 추가해주세요.',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      final selectedQuestionList = selectedQuestions.toList()
                        ..sort();
                      final note = noteController.text.trim();

                      try {
                        final docId =
                            await AppFirestoreService.sendAnswerRequest(
                              patientId: profile.id,
                              clinicId: visit.clinicId,
                              patientName: profile.name,
                              patientPhone: profile.phone,
                              patientEmail: profile.email,
                              patientTime: visit.time,
                              lastVisitDate: visit.lastVisitDate,
                              intakeStatus: visit.intakeStatus.name,
                              selectedQuestions: selectedQuestionList,
                              customQuestionsByCategory:
                                  customQuestionsByCategory.map(
                                    (key, value) =>
                                        MapEntry(key, List<String>.from(value)),
                                  ),
                              note: note,
                            );

                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }

                        noteController.dispose();
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLanguageController.instance.tr(
                                'Answer request saved for ${profile.name}: $docId',
                                '${profile.name}님 답변 요청 저장 완료: $docId',
                              ),
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLanguageController.instance.tr(
                                'Failed to save answer request: $error',
                                '답변 요청 저장 실패: $error',
                              ),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(AppLanguageController.instance.tr('Send', '전송')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPatientNote(
    BuildContext context,
    ScheduledVisit scheduledVisit,
  ) async {
    final profile = scheduledVisit.profile;
    final visit = scheduledVisit.visit;
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppLanguageController.instance.tr(
              'Send a note to ${profile.name}',
              '${profile.name}님께 쪽지 보내기',
            ),
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD7EAE6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLanguageController.instance.tr(
                          'Patient note',
                          '환자 메모',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLanguageController.instance.tr(
                          'Visit context: ${_formatStoredDateWithWeekday(visit.date)} ${visit.time}',
                          '방문 맥락: ${_formatStoredDateWithWeekday(visit.date)} ${visit.time}',
                        ),
                      ),
                      Text(
                        profile.email.trim().isEmpty
                            ? AppLanguageController.instance.tr(
                                'Portal only',
                                '포털에만 표시',
                              )
                            : AppLanguageController.instance.tr(
                                'Email also queued',
                                '이메일 알림 포함',
                              ),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLanguageController.instance.tr(
                      'Message for the patient',
                      '환자에게 보낼 내용',
                    ),
                    hintText: AppLanguageController.instance.tr(
                      'Write a short note',
                      '짧게 입력',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                noteController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text(AppLanguageController.instance.tr('Cancel', '취소')),
            ),
            FilledButton.icon(
              onPressed: () async {
                final note = noteController.text.trim();
                if (note.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLanguageController.instance.tr(
                          'Please enter a note before sending.',
                          '쪽지 내용을 입력한 뒤 전송해주세요.',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                try {
                  final docId = await AppFirestoreService.sendPractitionerNote(
                    patientId: profile.id,
                    clinicId: visit.clinicId,
                    patientName: profile.name,
                    patientPhone: profile.phone,
                    patientEmail: profile.email,
                    patientTime: visit.time,
                    lastVisitDate: visit.lastVisitDate,
                    intakeStatus: visit.intakeStatus.name,
                    note: note,
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  noteController.dispose();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLanguageController.instance.tr(
                          'Portal note saved for ${profile.name}: $docId',
                          '${profile.name}님 쪽지 저장 완료: $docId',
                        ),
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLanguageController.instance.tr(
                          'Failed to save the patient note: $error',
                          '환자 쪽지 저장 실패: $error',
                        ),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: Text(AppLanguageController.instance.tr('Send', '전송')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final currentDate = _parseDate(_selectedDate) ?? now;
    DateTime selectedDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final lang = AppLanguageController.instance;
    final theme = Theme.of(context);
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final storedDate = _formatDate(selectedDate);
            final bookedCount = _bookedPatientCountForDate(storedDate);
            final actualVisitCount = _actualVisitCountForDate(storedDate);

            Widget buildCountCard({
              required String label,
              required String value,
            }) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;

                    final summaryPanel = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft.withValues(alpha: 0.58),
                        border: wide
                            ? Border(right: BorderSide(color: AppTheme.border))
                            : Border(
                                bottom: BorderSide(color: AppTheme.border),
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr('Pick Date', '날짜 선택'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _formatDateWithWeekday(selectedDate),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          buildCountCard(
                            label: lang.tr('Booked patients', '예약 환자'),
                            value: lang.tr(
                              '$bookedCount patients',
                              '$bookedCount명',
                            ),
                          ),
                          const SizedBox(height: 10),
                          buildCountCard(
                            label: lang.tr('Actual visits', '실제 방문'),
                            value: lang.tr(
                              '$actualVisitCount patients',
                              '$actualVisitCount명',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lang.tr(
                              'Booked = saved visits plus pending or confirmed reservations for that date.',
                              '예약 환자 = 그 날짜의 저장된 방문과 대기/확정 예약을 함께 본 숫자입니다.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.62),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    );

                    final calendarPanel = Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lang.tr('Pick date.', '날짜 선택'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.68),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CalendarDatePicker(
                            initialDate: selectedDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime(
                              now.year + 10,
                              now.month,
                              now.day,
                            ),
                            currentDate: now,
                            onDateChanged: (value) {
                              setDialogState(() {
                                selectedDate = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(lang.tr('Cancel', '취소')),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, selectedDate),
                                child: Text(lang.tr('OK', '확인')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    return wide
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: 240, child: summaryPanel),
                              Expanded(child: calendarPanel),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [summaryPanel, calendarPanel],
                            ),
                          );
                  },
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null) {
      return;
    }

    _applySelectedDate(picked);
  }

  int _bookedPatientCountForDate(String date) {
    final patientIds = <String>{
      ..._store
          .appointmentRequestsForClinic(_currentClinicId)
          .where(
            (request) =>
                request.date == date && _isActiveAppointmentRequest(request),
          )
          .map((request) => request.patientId),
    };
    return patientIds.length;
  }

  List<DateTime> _dashboardDates() {
    final dates = <DateTime>{
      for (final slot in _store.slotsForClinic(_currentClinicId))
        if (_parseDate(slot.date) != null)
          DateTime(
            _parseDate(slot.date)!.year,
            _parseDate(slot.date)!.month,
            _parseDate(slot.date)!.day,
          ),
      for (final request in _store.appointmentRequestsForClinic(
        _currentClinicId,
      ))
        if (_isActiveAppointmentRequest(request) &&
            _parseDate(request.date) != null)
          DateTime(
            _parseDate(request.date)!.year,
            _parseDate(request.date)!.month,
            _parseDate(request.date)!.day,
          ),
    }.toList()..sort();
    return dates;
  }

  int _actualVisitCountForDate(String date) {
    return _store.visitsForDate(date, clinicId: _currentClinicId).length;
  }

  void _applySelectedDate(DateTime picked) {
    setState(() {
      _selectedDate = _formatDate(picked);
      _selectedDateRange = null;
      _selectedPatientFilter = 'All Patients';
      _selectedStatusFilter = 'All';
      _patientFilterController.clear();
    });
  }

  Future<void> _jumpToTodayDate() async {
    final lang = AppLanguageController.instance;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final dates = _dashboardDates();

    DateTime targetDate = normalizedToday;
    String? message;

    final hasToday = dates.any((date) => date == normalizedToday);
    if (!hasToday && dates.isNotEmpty) {
      final earlierOrSame = dates.where(
        (date) => !date.isAfter(normalizedToday),
      );
      targetDate = earlierOrSame.isNotEmpty ? earlierOrSame.last : dates.first;
      message = lang.tr(
        'No visits are saved for today, so the dashboard moved to the nearest clinic date ${_formatDateWithWeekday(targetDate)}.',
        '오늘 일정이 없어 가장 가까운 클리닉 날짜 ${_formatDateWithWeekday(targetDate)} 로 이동했습니다.',
      );
    }

    _applySelectedDate(targetDate);

    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickDateRangeWithDialog() async {
    final now = DateTime.now();
    DateTime start =
        _selectedDateRange?.start ??
        (_parseDate(
              _selectedDate,
            )?.subtract(Duration(days: _selectedRangeDays - 1)) ??
            now);
    DateTime end =
        _selectedDateRange?.end ?? (_parseDate(_selectedDate) ?? now);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                AppLanguageController.instance.tr(
                  'Practitioner Dashboard',
                  '침술사 대시보드',
                ),
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(now.year + 10, now.month, now.day),
                          helpText: AppLanguageController.instance.tr(
                            'Pick Start Date',
                            '시작일 선택',
                          ),
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          start = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                          if (end.isBefore(start)) {
                            end = start;
                          }
                        });
                      },
                      child: Text(
                        AppLanguageController.instance.tr(
                          'Start: ${_formatDateWithWeekday(start)}',
                          '시작일: ${_formatDateWithWeekday(start)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(now.year + 10, now.month, now.day),
                          helpText: AppLanguageController.instance.tr(
                            'Pick End Date',
                            '종료일 선택',
                          ),
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          end = DateTime(picked.year, picked.month, picked.day);
                          if (end.isBefore(start)) {
                            start = end;
                          }
                        });
                      },
                      child: Text(
                        AppLanguageController.instance.tr(
                          'End: ${_formatDateWithWeekday(end)}',
                          '종료일: ${_formatDateWithWeekday(end)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLanguageController.instance.tr(
                        'Selected Range: ${_formatDateWithWeekday(start)} ~ ${_formatDateWithWeekday(end)}',
                        '선택 범위: ${_formatDateWithWeekday(start)} ~ ${_formatDateWithWeekday(end)}',
                      ),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              actions: [
                const LanguageMenuButton(),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    AppLanguageController.instance.tr('Cancel', '취소'),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _formatDate(end);
                      _selectedDateRange = DateTimeRange(
                        start: start,
                        end: end,
                      );
                      _selectedRangeDays = end.difference(start).inDays + 1;
                      _selectedPatientFilter = 'All Patients';
                      _selectedStatusFilter = 'All';
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: Text(AppLanguageController.instance.tr('Apply', '적용')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _pendingAppointmentRequestCount() {
    return _store
        .appointmentRequestsForClinic(_currentClinicId)
        .where((request) => request.status == AppointmentRequestStatus.pending)
        .length;
  }

  Future<void> _scrollToAppointmentInbox() async {
    final targetContext = _appointmentInboxKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _scrollToAppointmentRequestsSection() async {
    final targetContext = _appointmentRequestsSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _scrollToRecordUpdatesSection() async {
    final targetContext = _recordUpdatesSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _scrollToRecentSubmissionsSection() async {
    final targetContext = _recentSubmissionsSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Map<String, List<String>> _defaultOnboardingFollowUpTree() {
    return {
      for (final entry in _questionLibraryByCategory.entries)
        entry.key: [
          if (entry.value.length > 1) entry.value[1],
          'If yes, when did it start and what makes it better or worse?',
          'How often does this happen, and how much does it affect daily life?',
        ],
    };
  }

  Future<void> _approveMembershipAndSendQuestionTree(
    PatientClinicMembershipRequest request,
  ) async {
    final profile = _store.profileById(request.patientId);
    final selectedQuestions = _questionLibraryByCategory.values
        .where((questions) => questions.isNotEmpty)
        .map((questions) => questions.first)
        .toList();
    final followUpTree = _defaultOnboardingFollowUpTree();

    var approved = false;
    try {
      await _store.approvePatientClinicMembership(request.id);
      approved = true;
      await AppFirestoreService.sendAnswerRequest(
        patientId: request.patientId,
        clinicId: request.clinicId,
        patientName: profile?.name ?? request.patientName,
        patientPhone: profile?.phone ?? '',
        patientEmail: profile?.email ?? request.patientEmail,
        patientTime: 'Membership onboarding',
        lastVisitDate: 'New patient',
        intakeStatus: 'initial',
        selectedQuestions: selectedQuestions,
        customQuestionsByCategory: followUpTree,
        note:
            'Your clinic approved your account. Please start with this intake question tree so the practitioner can understand your baseline before the first visit.',
        requestType: 'membership_onboarding',
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageController.instance.tr(
              '${request.patientName} approved. It stays in Inbox under Recent joins.',
              '${request.patientName} approved. It stays in Inbox under Recent joins.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? AppLanguageController.instance.tr(
                    'Patient was approved, but the starter questions could not be sent. Please try sending questions again.',
                    'Patient was approved, but the starter questions could not be sent. Please try sending questions again.',
                  )
                : AppLanguageController.instance.tr(
                    'The approval button could not finish. Please try again.',
                    'The approval button could not finish. Please try again.',
                  ),
          ),
        ),
      );
    }
  }

  Widget _buildMembershipRequestAlertPanel(
    List<PatientClinicMembershipRequest> requests,
  ) {
    final lang = AppLanguageController.instance;
    final next = requests.first;
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.copper.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt_1, color: AppTheme.pine),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr(
                    '${requests.length} join request${requests.length == 1 ? '' : 's'}',
                    '${requests.length} join request${requests.length == 1 ? '' : 's'}',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  lang.tr(
                    '${next.patientName} · ${next.clinicName}',
                    '${next.patientName} · ${next.clinicName}',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          _approveMembershipAndSendQuestionTree(next),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(lang.tr('Approve + questions', '승인 + 질문')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _selectSubView(_DashboardSubView.inbox),
                      icon: const Icon(Icons.inbox_outlined),
                      label: Text(lang.tr('Inbox', '요청함')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicOpenRequestsPanel() {
    final lang = AppLanguageController.instance;
    final membershipRequests = _store.pendingMembershipRequestsForClinic(
      _currentClinicId,
    );
    final recentMembershipRequests = _store
        .membershipRequestsForClinic(
          _currentClinicId,
          statuses: {'approved', 'declined'},
        )
        .take(8)
        .toList();
    final requests = _isPlatformAdmin
        ? _store.pendingClinicOpenRequests
        : const <ClinicOpenRequest>[];
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('Inbox', 'Inbox'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            lang.tr('Joins', '가입'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (membershipRequests.isEmpty)
            Text(lang.tr('No joins', '가입 없음'))
          else
            ...membershipRequests.map((request) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.72),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.patientName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Clinic', 'Clinic')}: ${request.clinicName}',
                    ),
                    if (request.patientEmail.trim().isNotEmpty)
                      Text(
                        '${lang.tr('Email', 'Email')}: ${request.patientEmail}',
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              _approveMembershipAndSendQuestionTree(request),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            lang.tr('Approve + questions', '승인 + 질문'),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _store.declinePatientClinicMembership(request.id),
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(lang.tr('Decline', 'Decline')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (recentMembershipRequests.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              lang.tr('Recent joins', 'Recent joins'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...recentMembershipRequests.map((request) {
              final profile = _store.profileById(request.patientId);
              final isApproved = request.status == 'approved';
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.72),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: isApproved ? AppTheme.pine : AppTheme.copper,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.patientName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (request.patientEmail.trim().isNotEmpty)
                            Text(
                              request.patientEmail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      isApproved
                          ? lang.tr('Approved', 'Approved')
                          : lang.tr('Declined', 'Declined'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    if (profile != null)
                      OutlinedButton(
                        onPressed: () => _openPatientManagement(
                          context,
                          initialProfileId: profile.id,
                        ),
                        child: Text(lang.tr('Open', 'Open')),
                      ),
                  ],
                ),
              );
            }),
          ],
          if (_isPlatformAdmin) ...[
            const SizedBox(height: 18),
            Text(
              lang.tr('Leads', '리드'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (requests.isEmpty)
              Text(lang.tr('No clinic leads', '한의원 요청 없음'))
            else
              ...requests.map((request) {
                final detail = [
                  if (request.practitionerName.trim().isNotEmpty)
                    request.practitionerName,
                  if (request.location.trim().isNotEmpty) request.location,
                ].join(' · ');
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.clinicName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(detail),
                      ],
                      if (request.patientEmail.trim().isNotEmpty)
                        Text(
                          '${lang.tr('Email', '이메일')}: ${request.patientEmail}',
                        ),
                      if (request.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${lang.tr('Patient note', '환자 메모')}: ${request.note}',
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _selectSubView(_DashboardSubView.clinicProfile),
                            icon: const Icon(Icons.domain_add_outlined),
                            label: Text(lang.tr('Clinic', '한의원')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _store
                                .markClinicOpenRequestReviewed(request.id),
                            icon: const Icon(Icons.done_outline),
                            label: Text(lang.tr('Reviewed', '확인')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Future<void> _scrollToDateSelectorPanel() async {
    final targetContext = _dateSelectorKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _scrollToPatientCards() async {
    final targetContext = _patientCardsKey.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _focusPatientCards({String? statusFilter}) async {
    if (mounted) {
      setState(() {
        _selectedPatientFilter = 'All Patients';
        _patientFilterController.clear();
        if (statusFilter != null) {
          _selectedStatusFilter = statusFilter;
        }
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _scrollToPatientCards();
  }

  Future<void> _openDateQuickActionsSheet() async {
    final lang = AppLanguageController.instance;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('Date quick actions', '날짜 빠른 선택'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  lang.tr(
                    'Current selection: ${_currentTopDateValue()}',
                    '현재 선택: ${_currentTopDateValue()}',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {
                          _selectedRangeDays = 7;
                          _selectedDateRange = null;
                          _selectedPatientFilter = 'All Patients';
                          _selectedStatusFilter = 'All';
                        });
                      },
                      child: Text(lang.tr('Last 7 days', '최근 7일')),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {
                          _selectedRangeDays = 14;
                          _selectedDateRange = null;
                          _selectedPatientFilter = 'All Patients';
                          _selectedStatusFilter = 'All';
                        });
                      },
                      child: Text(lang.tr('Last 14 days', '최근 14일')),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() {
                          _selectedRangeDays = 30;
                          _selectedDateRange = null;
                          _selectedPatientFilter = 'All Patients';
                          _selectedStatusFilter = 'All';
                        });
                      },
                      child: Text(lang.tr('Last 30 days', '최근 30일')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(lang.tr('Pick a single date', '하루 날짜 선택')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickDateFromCalendar();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text(lang.tr('Pick a custom range', '직접 기간 선택')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickDateRangeWithDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPatientManagement(
    BuildContext context, {
    String? initialProfileId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PatientManagementDialog(
        initialProfileId: initialProfileId,
        onApproveJoin: _approveMembershipAndSendQuestionTree,
      ),
    );
  }

  Future<void> _openLatestPatientBriefForProfile(PatientProfile profile) async {
    final lang = AppLanguageController.instance;
    final history = _store.historyForPatient(
      profile.id,
      clinicId: _currentClinicId,
    );
    if (history.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'There is no previous visit history for this patient yet.',
              '이 환자에게는 아직 이전 방문 기록이 없습니다.',
            ),
          ),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      PatientBriefScreen.routeName,
      arguments: PatientHistoryArgs(current: history.first, history: history),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _weekdayShort(DateTime date) {
    const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const korean = ['월', '화', '수', '목', '금', '토', '일'];
    return AppLanguageController.instance.tr(
      english[date.weekday - 1],
      korean[date.weekday - 1],
    );
  }

  String _formatDateWithWeekday(DateTime date, {bool compact = false}) {
    final base = compact
        ? '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : _formatDate(date);
    final weekday = _weekdayShort(date);
    return AppLanguageController.instance.tr(
      '$base ($weekday)',
      '$base ($weekday)',
    );
  }

  String _formatStoredDateWithWeekday(String value, {bool compact = false}) {
    final parsed = _parseDate(value);
    if (parsed == null) {
      return value;
    }
    return _formatDateWithWeekday(parsed, compact: compact);
  }

  String _formatDateTimeValue(DateTime value) {
    final dateLabel = _formatDateWithWeekday(value);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$dateLabel $hour:$minute';
  }

  String _currentTopDateTitle() {
    return _selectedDateRange == null
        ? AppLanguageController.instance.tr('Selected date', '선택 날짜')
        : AppLanguageController.instance.tr('Selected range', '선택 기간');
  }

  String _currentTopDateValue() {
    if (_selectedDateRange == null) {
      return _formatStoredDateWithWeekday(_selectedDate);
    }
    return '${_formatDateWithWeekday(_selectedDateRange!.start)} - ${_formatDateWithWeekday(_selectedDateRange!.end)}';
  }

  // ignore: unused_element
  Widget _buildTopInboxAction(int count) {
    final lang = AppLanguageController.instance;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _scrollToAppointmentInbox,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2F8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBED5E4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.mail_outline, color: Color(0xFF43799A)),
                    if (count > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF43799A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lang.tr('Patient inbox', '환자 쪽지함'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.72),
                      ),
                    ),
                    Text(
                      lang.tr('$count waiting', '$count건 대기'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTopInboxAction(int count) {
    return IconButton(
      tooltip: AppLanguageController.instance.tr(
        'Open patient inbox',
        '환자 쪽지함 열기',
      ),
      onPressed: () {
        if (_subView == _DashboardSubView.inbox) {
          _scrollToAppointmentInbox();
          return;
        }
        _selectSubView(_DashboardSubView.inbox);
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.mail_outline),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.copper,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopDateAction() {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openDateQuickActionsSheet,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8E9E4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3C3B7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFFB0664C),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentTopDateTitle(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.72),
                      ),
                    ),
                    Text(
                      _currentTopDateValue(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DateTime? _parseDate(String value) {
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
}

class _PatientRealtimeActivity extends StatelessWidget {
  const _PatientRealtimeActivity({
    required this.patientId,
    required this.clinicId,
  });

  final String patientId;
  final String? clinicId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('intake_submissions')
          .where('patientId', isEqualTo: patientId)
          .snapshots(),
      builder: (context, submissionSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('answer_requests')
              .where('patientId', isEqualTo: patientId)
              .snapshots(),
          builder: (context, requestSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('visit_record_feedback')
                  .where('patientId', isEqualTo: patientId)
                  .snapshots(),
              builder: (context, feedbackSnapshot) {
                if (submissionSnapshot.hasError ||
                    requestSnapshot.hasError ||
                    feedbackSnapshot.hasError) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'Unable to load real-time activity.',
                      '실시간 앱 활동을 불러올 수 없습니다.',
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }

                if (!submissionSnapshot.hasData ||
                    !requestSnapshot.hasData ||
                    !feedbackSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 4),
                  );
                }

                final submissionDocs = [...submissionSnapshot.data!.docs]
                  ..removeWhere((doc) {
                    final docClinicId = (doc.data()['clinicId'] ?? '')
                        .toString();
                    return clinicId == null ||
                        clinicId!.isEmpty ||
                        docClinicId != clinicId;
                  })
                  ..sort((a, b) {
                    final aDate = (a.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });

                final requestDocs = [...requestSnapshot.data!.docs]
                  ..removeWhere((doc) {
                    final docClinicId = (doc.data()['clinicId'] ?? '')
                        .toString();
                    return clinicId == null ||
                        clinicId!.isEmpty ||
                        docClinicId != clinicId;
                  })
                  ..sort((a, b) {
                    final aDate = (a.data()['requestedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['requestedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });

                final feedbackDocs = [...feedbackSnapshot.data!.docs]
                  ..removeWhere((doc) {
                    final docClinicId = (doc.data()['clinicId'] ?? '')
                        .toString();
                    return clinicId == null ||
                        clinicId!.isEmpty ||
                        docClinicId != clinicId;
                  })
                  ..sort((a, b) {
                    final aDate = (a.data()['updatedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['updatedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });

                final latestSubmission = submissionDocs.isNotEmpty
                    ? submissionDocs.first.data()
                    : null;
                final latestRequest = requestDocs.isNotEmpty
                    ? requestDocs.first.data()
                    : null;
                final latestFeedback = feedbackDocs.isNotEmpty
                    ? feedbackDocs.first.data()
                    : null;
                final pendingFeedbackCount = feedbackDocs
                    .where(
                      (doc) => (doc.data()['status'] ?? 'pending') == 'pending',
                    )
                    .length;

                final submissionAt =
                    (latestSubmission?['submittedAt'] as Timestamp?)?.toDate();
                final requestAt = (latestRequest?['requestedAt'] as Timestamp?)
                    ?.toDate();
                final feedbackAt = (latestFeedback?['updatedAt'] as Timestamp?)
                    ?.toDate();

                final answers =
                    (latestSubmission?['answers'] as List<dynamic>? ??
                    const []);
                final selectedQuestions =
                    (latestRequest?['selectedQuestions'] as List<dynamic>? ??
                    const []);
                final latestRequestType =
                    (latestRequest?['requestType'] ?? 'answer_request')
                        .toString();

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD7EAE6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLanguageController.instance.tr(
                          'Real-Time App Activity',
                          '실시간 앱 활동',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (latestRequest == null)
                        Text(
                          AppLanguageController.instance.tr(
                            'No recent answer request',
                            '최근 답변 요청 없음',
                          ),
                        )
                      else
                        Text(
                          latestRequestType == 'note'
                              ? AppLanguageController.instance.tr(
                                  'Latest practitioner note: ${_formatDateTime(requestAt)}',
                                  '최근 침술사 쪽지: ${_formatDateTime(requestAt)}',
                                )
                              : AppLanguageController.instance.tr(
                                  'Latest answer request: ${selectedQuestions.length} questions ? ${_formatDateTime(requestAt)}',
                                  '최근 답변 요청: 질문 ${selectedQuestions.length}개 · ${_formatDateTime(requestAt)}',
                                ),
                        ),
                      const SizedBox(height: 4),
                      if (latestSubmission == null)
                        Text(
                          AppLanguageController.instance.tr(
                            'No recent submission',
                            '최근 제출 없음',
                          ),
                        )
                      else
                        Text(
                          AppLanguageController.instance.tr(
                            'Latest patient submission: ${answers.length} answers ? ${_formatDateTime(submissionAt)}',
                            '최근 환자 제출: 답변 ${answers.length}개 · ${_formatDateTime(submissionAt)}',
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (latestFeedback == null)
                        Text(
                          AppLanguageController.instance.tr(
                            'No feedback',
                            '방문 기록 피드백 없음',
                          ),
                        )
                      else
                        Text(
                          AppLanguageController.instance.tr(
                            'Visit-record feedback: $pendingFeedbackCount pending ? ${_formatDateTime(feedbackAt)}',
                            '방문 기록 피드백: 미확인 $pendingFeedbackCount건 · ${_formatDateTime(feedbackAt)}',
                          ),
                          style: TextStyle(
                            color: pendingFeedbackCount > 0
                                ? Colors.deepOrange
                                : Colors.black87,
                            fontWeight: pendingFeedbackCount > 0
                                ? FontWeight.w700
                                : FontWeight.w400,
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

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return AppLanguageController.instance.tr('Just now', '방금 전');
    }
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

// ignore: unused_element
class _BetaSubmissionBoard extends StatelessWidget {
  const _BetaSubmissionBoard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Beta Submission Feed',
                '지인 베타 제출함',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguageController.instance.tr(
                'Recent beta submissions.',
                '이메일/비밀번호로 가입한 지인들의 최근 제출을 확인합니다.',
              ),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('intake_submissions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'Could not load beta submissions.',
                      '베타 제출함을 불러오지 못했습니다.',
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator(minHeight: 4);
                }

                final docs = [...snapshot.data!.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    final bDate = (b.data()['submittedAt'] as Timestamp?)
                        ?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(
                      aDate ?? DateTime(2000),
                    );
                  });

                if (docs.isEmpty) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'No beta submissions',
                      '베타 제출 없음',
                    ),
                  );
                }

                return Column(
                  children: docs.take(5).map((doc) {
                    final data = doc.data();
                    final patientName =
                        (data['patientName'] as String?) ?? 'Unknown';
                    final visitType =
                        (data['visitType'] as String?) ?? 'follow_up';
                    final answers =
                        (data['answers'] as List<dynamic>? ?? const []).length;
                    final submittedAt = (data['submittedAt'] as Timestamp?)
                        ?.toDate();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_turned_in_outlined),
                      ),
                      title: Text(patientName),
                      subtitle: Text(
                        '${visitType == 'initial' ? AppLanguageController.instance.tr('Initial', '초진') : AppLanguageController.instance.tr('Follow-up', '재진')} · ${AppLanguageController.instance.tr('Answers', '답변')} $answers · ${_formatDateTime(submittedAt)}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return AppLanguageController.instance.tr('Just now', '방금 전');
    }
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

// ignore: unused_element
class _BetaRegistrantBoard extends StatelessWidget {
  const _BetaRegistrantBoard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Beta Registrants',
                '지인 베타 가입자',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguageController.instance.tr(
                'See who only signed up, who still has missing contact details, and who already submitted.',
                '회원가입만 한 사람, 연락처가 빠진 사람, 이미 제출까지 한 사람을 여기서 바로 확인합니다.',
              ),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .snapshots(),
              builder: (context, patientSnapshot) {
                if (patientSnapshot.hasError) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'Could not load beta registrants.',
                      '베타 가입자 목록을 불러오지 못했습니다.',
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
                if (!patientSnapshot.hasData) {
                  return const LinearProgressIndicator(minHeight: 4);
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('intake_submissions')
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    if (submissionSnapshot.hasError) {
                      return Text(
                        AppLanguageController.instance.tr(
                          'Could not load beta submission data.',
                          '베타 제출 데이터를 불러오지 못했습니다.',
                        ),
                        style: const TextStyle(color: Colors.redAccent),
                      );
                    }
                    if (!submissionSnapshot.hasData) {
                      return const LinearProgressIndicator(minHeight: 4);
                    }

                    final patientDocs = [...patientSnapshot.data!.docs]
                      ..sort((a, b) {
                        final aDate = (a.data()['updatedAt'] as Timestamp?)
                            ?.toDate();
                        final bDate = (b.data()['updatedAt'] as Timestamp?)
                            ?.toDate();
                        return (bDate ?? DateTime(2000)).compareTo(
                          aDate ?? DateTime(2000),
                        );
                      });

                    final submissionsByPatient =
                        <String, List<Map<String, dynamic>>>{};
                    for (final doc in submissionSnapshot.data!.docs) {
                      final data = doc.data();
                      final patientId = (data['patientId'] as String?) ?? '';
                      if (patientId.isEmpty) {
                        continue;
                      }
                      submissionsByPatient
                          .putIfAbsent(patientId, () => [])
                          .add(data);
                    }

                    if (patientDocs.isEmpty) {
                      return Text(
                        AppLanguageController.instance.tr(
                          'No beta users',
                          '베타 사용자 없음',
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr(
                                  'Registrants',
                                  '가입자',
                                ),
                                value: AppLanguageController.instance.tr(
                                  '${patientDocs.length}',
                                  '${patientDocs.length}명',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr(
                                  'Contact Complete',
                                  '연락처 완성',
                                ),
                                value: AppLanguageController.instance.tr(
                                  '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}',
                                  '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}명',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr(
                                  'Submitted',
                                  '제출 완료',
                                ),
                                value: AppLanguageController.instance.tr(
                                  '${patientDocs.where((doc) => (submissionsByPatient[doc.id] ?? const []).isNotEmpty).length}',
                                  '${patientDocs.where((doc) => (submissionsByPatient[doc.id] ?? const []).isNotEmpty).length}명',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...patientDocs.take(8).map((doc) {
                          final data = doc.data();
                          final name = ((data['name'] as String?) ?? '').trim();
                          final displayName = name.isEmpty
                              ? 'New Patient'
                              : name;
                          final phone = ((data['phone'] as String?) ?? '')
                              .trim();
                          final email = ((data['email'] as String?) ?? '')
                              .trim();
                          final sex = ((data['sex'] as String?) ?? '').trim();
                          final ethnicity =
                              ((data['ethnicity'] as String?) ?? '').trim();
                          final birthYear = (data['birthYear'] as num?)
                              ?.toInt();
                          final updatedAt = (data['updatedAt'] as Timestamp?)
                              ?.toDate();
                          final createdAt = (data['createdAt'] as Timestamp?)
                              ?.toDate();
                          final hasRequired =
                              phone.isNotEmpty && email.isNotEmpty;
                          final submissions =
                              submissionsByPatient[doc.id] ?? const [];
                          submissions.sort((a, b) {
                            final aDate = (a['submittedAt'] as Timestamp?)
                                ?.toDate();
                            final bDate = (b['submittedAt'] as Timestamp?)
                                ?.toDate();
                            return (bDate ?? DateTime(2000)).compareTo(
                              aDate ?? DateTime(2000),
                            );
                          });
                          final latestSubmission = submissions.isNotEmpty
                              ? submissions.first
                              : null;
                          final latestSubmissionAt =
                              (latestSubmission?['submittedAt'] as Timestamp?)
                                  ?.toDate();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: hasRequired
                                  ? const Color(0xFFF8FBFA)
                                  : const Color(0xFFFFF6F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasRequired
                                    ? const Color(0xFFD8E9E5)
                                    : const Color(0xFFF2C8C8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        hasRequired
                                            ? AppLanguageController.instance.tr(
                                                'Contact Ready',
                                                '연락처 준비됨',
                                              )
                                            : AppLanguageController.instance.tr(
                                                'Missing Required Info',
                                                '필수 정보 부족',
                                              ),
                                      ),
                                      backgroundColor: hasRequired
                                          ? const Color(0xFFE3F3EF)
                                          : const Color(0xFFFFE2E2),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  phone.isEmpty && email.isEmpty
                                      ? AppLanguageController.instance.tr(
                                          'No contact info',
                                          '연락처 없음',
                                        )
                                      : '${phone.isEmpty ? AppLanguageController.instance.tr('Phone missing', '전화번호 없음') : phone} · ${email.isEmpty ? AppLanguageController.instance.tr('Email missing', '이메일 없음') : email}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${birthYear?.toString() ?? AppLanguageController.instance.tr('Birth year missing', '출생연도 미입력')} · ${sex.isEmpty ? AppLanguageController.instance.tr('Sex missing', '성별 미입력') : sex} · ${ethnicity.isEmpty ? AppLanguageController.instance.tr('Ethnicity missing', '인종/민족 미입력') : ethnicity}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusTag(
                                      label: submissions.isEmpty
                                          ? AppLanguageController.instance.tr(
                                              'No submission yet',
                                              '아직 제출 없음',
                                            )
                                          : AppLanguageController.instance.tr(
                                              'Submitted ${submissions.length} time(s)',
                                              '제출 ${submissions.length}회',
                                            ),
                                      color: submissions.isEmpty
                                          ? const Color(0xFFF6E9C9)
                                          : const Color(0xFFDDF0E8),
                                    ),
                                    _StatusTag(
                                      label: AppLanguageController.instance.tr(
                                        'Signed up: ${_formatDateTime(createdAt)}',
                                        '가입: ${_formatDateTime(createdAt)}',
                                      ),
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    _StatusTag(
                                      label: AppLanguageController.instance.tr(
                                        'Profile updated: ${_formatDateTime(updatedAt)}',
                                        '프로필 수정: ${_formatDateTime(updatedAt)}',
                                      ),
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    if (latestSubmissionAt != null)
                                      _StatusTag(
                                        label: AppLanguageController.instance.tr(
                                          'Latest submission: ${_formatDateTime(latestSubmissionAt)}',
                                          '최근 제출: ${_formatDateTime(latestSubmissionAt)}',
                                        ),
                                        color: const Color(0xFFDDF0E8),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasRequiredInfo(Map<String, dynamic> data) {
    final phone = ((data['phone'] as String?) ?? '').trim();
    final email = ((data['email'] as String?) ?? '').trim();
    return phone.isNotEmpty && email.isNotEmpty;
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return AppLanguageController.instance.tr('No record', '기록 없음');
    }
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _BetaOverviewChip extends StatelessWidget {
  const _BetaOverviewChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PatientManagementDialog extends StatefulWidget {
  const _PatientManagementDialog({
    this.initialProfileId,
    this.embedded = false,
    this.onApproveJoin,
  });

  final String? initialProfileId;
  final bool embedded;
  final Future<void> Function(PatientClinicMembershipRequest request)?
  onApproveJoin;

  @override
  State<_PatientManagementDialog> createState() =>
      _PatientManagementDialogState();
}

class _PatientManagementDialogState extends State<_PatientManagementDialog> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  String? _selectedProfileId;

  bool get _showManualPatientCreation => false;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.initialProfileId;
  }

  @override
  Widget build(BuildContext context) {
    final activeClinicId = PractitionerSessionService.currentSession?.clinicId;
    final profiles = _store.profilesForClinic(activeClinicId);
    PatientProfile? selected;
    if (_selectedProfileId == null) {
      selected = profiles.isNotEmpty ? profiles.first : null;
    } else {
      for (final profile in profiles) {
        if (profile.id == _selectedProfileId) {
          selected = profile;
          break;
        }
      }
      selected ??= profiles.isNotEmpty ? profiles.first : null;
    }
    final pendingJoinRequest =
        selected == null || activeClinicId == null || activeClinicId.isEmpty
        ? null
        : _store.membershipRequestForPatientClinic(
            patientId: selected.id,
            clinicId: activeClinicId,
          );

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showManualPatientCreation)
                FilledButton.icon(
                  onPressed: () async {
                    final newProfile = PatientProfile(
                      id: 'patient_${DateTime.now().millisecondsSinceEpoch}',
                      name: 'New Patient',
                      phone: '',
                      email: '',
                      birthYear: 1990,
                      sex: 'Female',
                      ethnicity: 'Unknown',
                      memo: '',
                    );
                    _store.saveProfile(newProfile);
                    if (activeClinicId != null && activeClinicId.isNotEmpty) {
                      await _store.setDefaultClinicForPatient(
                        patientId: newProfile.id,
                        clinicId: activeClinicId,
                      );
                    }
                    if (!mounted) {
                      return;
                    }
                    setState(() => _selectedProfileId = newProfile.id);
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    AppLanguageController.instance.tr('Add Patient', '환자 추가'),
                  ),
                ),
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            AppLanguageController.instance.tr(
                              'No patients',
                              '환자 없음',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.68),
                                  height: 1.45,
                                ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: profiles.length,
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final isSelected = selected?.id == profile.id;
                          final missingFields = <String>[
                            if (profile.phone.trim().isEmpty)
                              AppLanguageController.instance.tr(
                                'Phone',
                                '전화번호',
                              ),
                            if (profile.email.trim().isEmpty)
                              AppLanguageController.instance.tr('Email', '이메일'),
                          ];
                          final missingContactLabel = missingFields.length == 1
                              ? AppLanguageController.instance.tr(
                                  '${missingFields.first} missing',
                                  '${missingFields.first} 없음',
                                )
                              : AppLanguageController.instance.tr(
                                  'Contact missing',
                                  '연락처 없음',
                                );
                          return Card(
                            color: isSelected ? const Color(0xFFF4FBFA) : null,
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(profile.name)),
                                  if (missingFields.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE2E2),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        missingContactLabel,
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                missingFields.isEmpty
                                    ? '${profile.phone} · ${profile.email}'
                                    : '${AppLanguageController.instance.tr('Missing', '누락')}: ${missingFields.join(', ')}',
                              ),
                              trailing: IconButton(
                                onPressed: () {
                                  _store.deleteProfile(profile.id);
                                  setState(() {
                                    if (_selectedProfileId == profile.id) {
                                      _selectedProfileId = null;
                                    }
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                              onTap: () => setState(
                                () => _selectedProfileId = profile.id,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                    AppLanguageController.instance.tr(
                      'Select a patient to manage.',
                      '관리할 환자를 선택하세요.',
                    ),
                  ),
                )
              : _PatientProfileEditor(
                  profile: selected,
                  clinicId: PractitionerSessionService.currentSession?.clinicId,
                  membershipStatus: pendingJoinRequest?.status,
                  pendingJoinRequest: pendingJoinRequest?.status == 'pending'
                      ? pendingJoinRequest
                      : null,
                  onApproveJoin: pendingJoinRequest?.status == 'pending'
                      ? () async {
                          await widget.onApproveJoin?.call(pendingJoinRequest!);
                          if (mounted) {
                            setState(() => _selectedProfileId = selected!.id);
                          }
                        }
                      : null,
                  onSave: (updated) {
                    _store.saveProfile(updated);
                    setState(() => _selectedProfileId = updated.id);
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return AlertDialog(
      title: Text(
        AppLanguageController.instance.tr('Patient Management', '환자 정보 관리'),
      ),
      content: SizedBox(width: 1280, height: 760, child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLanguageController.instance.tr('Close', '닫기')),
        ),
      ],
    );
  }
}

class _PatientProfileEditor extends StatefulWidget {
  const _PatientProfileEditor({
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
  State<_PatientProfileEditor> createState() => _PatientProfileEditorState();
}

class _PatientProfileEditorState extends State<_PatientProfileEditor> {
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
  void didUpdateWidget(covariant _PatientProfileEditor oldWidget) {
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
    return PatientRecordWorkspace(
      profile: widget.profile,
      clinicId: widget.clinicId,
      membershipStatus: widget.membershipStatus,
      pendingJoinRequest: widget.pendingJoinRequest,
      onApproveJoin: widget.onApproveJoin,
      onSave: widget.onSave,
    );
    /*
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguageController.instance.tr(
              'Registered patient information is used across the dashboard and answer request flow.',
              '등록된 환자 정보가 있어야 대시보드와 답변 요청에서 사용됩니다.',
            ),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppLanguageController.instance.tr('Name', '이름'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: AppLanguageController.instance.tr(
                      'Phone',
                      '전화번호',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: AppLanguageController.instance.tr(
                      'Email',
                      '이메일',
                    ),
                    border: OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: AppLanguageController.instance.tr(
                      'Birth Year',
                      '출생연도',
                    ),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sexController,
                  decoration: InputDecoration(
                    labelText: AppLanguageController.instance.tr(
                      'Sex / Gender',
                      '성별',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ethnicityController,
                  decoration: InputDecoration(
                    labelText: AppLanguageController.instance.tr(
                      'Ethnicity',
                      '인종/민족',
                    ),
                    border: OutlineInputBorder(),
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
              labelText: AppLanguageController.instance.tr(
                'Internal Note',
                '관리 메모',
              ),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
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
                  content: Text(
                    AppLanguageController.instance.tr(
                      'Patient information saved',
                      '환자 정보 저장 완료',
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(
              AppLanguageController.instance.tr(
                'Save patient',
                '환자 정보 저장',
              ),
            ),
          ),
        ],
      ),
    );
    */
  }
}

class _SlotOccupancy {
  const _SlotOccupancy({
    required this.profile,
    this.scheduledVisit,
    this.appointmentRequest,
  });

  final PatientProfile profile;
  final ScheduledVisit? scheduledVisit;
  final AppointmentRequest? appointmentRequest;
}

class _VisitWindowSummary {
  const _VisitWindowSummary({
    required this.days,
    required this.totalVisits,
    required this.fromDate,
    required this.toDate,
    required this.periodLabel,
  });

  final int days;
  final int totalVisits;
  final String fromDate;
  final String toDate;
  final String periodLabel;
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.74),
              AppTheme.surfaceSoft.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DashboardSubView {
  main,
  opsHub,
  inbox,
  visitInsights,
  schedule,
  patientManagement,
  clinicProfile,
}
