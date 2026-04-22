import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../patient_brief/presentation/patient_brief_screen.dart';
import '../../symptom_trend/presentation/symptom_trend_screen.dart';

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

  late String _selectedDate;
  String _selectedPatientFilter = 'All Patients';
  String _selectedStatusFilter = 'All';
  int _selectedRangeDays = 7;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final dates = _store.allDates;
    final today = _formatDate(DateTime.now());
    if (dates.contains(today)) {
      _selectedDate = today;
      return;
    }
    final pastOrToday = dates.where((d) => d.compareTo(today) <= 0).toList()
      ..sort();
    _selectedDate = pastOrToday.isNotEmpty ? pastOrToday.last : dates.first;
  }

  @override
  void dispose() {
    _patientFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
        return AnimatedBuilder(
      animation: Listenable.merge([_store, AppLanguageController.instance]),
      builder: (context, _) {
        final visibleVisits = _visibleVisits();
        final patientNames = visibleVisits.map((v) => v.profile.name).toSet().toList()
          ..sort();
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
        final summary = _visitWindowSummary();

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLanguageController.instance.tr('Practitioner Dashboard', '침술사 대시보드')),
            actions: [
              const LanguageMenuButton(),
              TextButton.icon(
                onPressed: () => _openPatientManagement(context),
                icon: const Icon(Icons.people_outline),
                label: Text(AppLanguageController.instance.tr('Patient Management', '환자 정보 관리')),
              ),
              IconButton(
                tooltip: AppLanguageController.instance.tr('View symptom trends', '유사증상 추세 보기'),
                onPressed: () =>
                    Navigator.pushNamed(context, SymptomTrendScreen.routeName),
                icon: const Icon(Icons.insights_outlined),
              ),
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: Chip(label: Text(AppLanguageController.instance.tr('Practitioner View', '침술사 화면'))),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  if (!wide) {
                    return Column(
                      children: [
                        _buildInsightPanel(summary),
                        const SizedBox(height: 12),
                        _buildDateSelectorPanel(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: _buildInsightPanel(summary)),
                      const SizedBox(width: 12),
                      Expanded(flex: 9, child: _buildDateSelectorPanel()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const _BetaRegistrantBoard(),
              const SizedBox(height: 12),
              const _BetaSubmissionBoard(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  if (!wide) {
                    return Column(
                      children: [
                        _buildAppointmentRequestBoard(),
                        const SizedBox(height: 12),
                        _buildAvailabilityBoard(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: _buildAppointmentRequestBoard()),
                      const SizedBox(width: 12),
                      Expanded(flex: 8, child: _buildAvailabilityBoard()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDateRange == null
                          ? AppLanguageController.instance.tr(
                              '$_selectedDate Patients ${filteredVisits.length}',
                              '$_selectedDate 환자 ${filteredVisits.length}명',
                            )
                          : AppLanguageController.instance.tr(
                              '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} Patients ${filteredVisits.length}',
                              '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} 환자 ${filteredVisits.length}명',
                            ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: patientNames.contains(_selectedPatientFilter) ||
                              _selectedPatientFilter == 'All Patients'
                          ? _selectedPatientFilter
                          : 'All Patients',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'All Patients',
                          child: Text(AppLanguageController.instance.tr('All Patients', '전체 환자')),
                        ),
                        ...patientNames.map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedPatientFilter = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusFilterChip('All'),
                  _statusFilterChip('Missing Profile'),
                  _statusFilterChip('No Response'),
                  _statusFilterChip('In Progress'),
                  _statusFilterChip('Complete'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _patientFilterController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  hintText: AppLanguageController.instance.tr(
                    'Search patient name',
                    '환자 이름 직접 검색',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedDateRange == null
                    ? AppLanguageController.instance.tr(
                        'Visit summary: ${summary.periodLabel}',
                        '? ?? ??: ${summary.periodLabel}',
                      )
                    : AppLanguageController.instance.tr(
                        'Selected range summary: ${summary.periodLabel}',
                        '?? ?? ??: ${summary.periodLabel}',
                      ),
                style: const TextStyle(color: Colors.black54),
              ),
              if (_selectedDateRange == null && filteredVisits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppLanguageController.instance.tr(
                      'Showing ${filteredVisits.length} of ${_store.visitsForDate(_selectedDate).length} patient(s) scheduled on $_selectedDate.',
                      '$_selectedDate ?? ?? ${_store.visitsForDate(_selectedDate).length}? ? ${filteredVisits.length}?? ?? ???? ????.',
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 12),
              if (filteredVisits.isEmpty)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLanguageController.instance.tr(
                            'No patients match the selected filters.',
                            '??? ??? ?? ??? ????.',
                          ),
                        ),
                        if (_selectedDateRange == null &&
                            _store.visitsForDate(_selectedDate).isNotEmpty &&
                            _selectedStatusFilter != 'All') ...[
                          const SizedBox(height: 8),
                          Text(
                            AppLanguageController.instance.tr(
                              'There are visits on $_selectedDate, but the current status filter "${_statusFilterLabel(_selectedStatusFilter)}" is hiding them.',
                              '$_selectedDate?? ??? ??? ?? ?? ?? "${_statusFilterLabel(_selectedStatusFilter)}" ??? ??? ????.',
                            ),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ...filteredVisits.map(
                (scheduledVisit) => _buildPatientCard(context, scheduledVisit),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightPanel(_VisitWindowSummary summary) {
    final profiles = _store.profiles;
    final sexCounts = <String, int>{};
    for (final profile in profiles) {
      sexCounts.update(profile.sex, (value) => value + 1, ifAbsent: () => 1);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Overview (Practitioner Insight)',
                '현황표 (침술사 인사이트)',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniKpi(
                  title: AppLanguageController.instance.tr(
                    'Visits (${summary.days} days)',
                    '총 내원 (${summary.days}일)',
                  ),
                  value: AppLanguageController.instance.tr(
                    '${summary.totalVisits}',
                    '${summary.totalVisits}명',
                  ),
                ),
                _MiniKpi(
                  title: AppLanguageController.instance.tr(
                    'Registered Patients',
                    '등록 환자',
                  ),
                  value: AppLanguageController.instance.tr(
                    '${profiles.length}',
                    '${profiles.length}명',
                  ),
                ),
                _MiniKpi(
                  title: AppLanguageController.instance.tr(
                    'Alert Ready',
                    '알림 가능',
                  ),
                  value: AppLanguageController.instance.tr(
                    '${profiles.where((p) => p.hasRequiredAlertInfo).length}',
                    '${profiles.where((p) => p.hasRequiredAlertInfo).length}명',
                  ),
                ),
                _MiniKpi(
                  title: AppLanguageController.instance.tr(
                    'Return Visit Rate',
                    '재내원율',
                  ),
                  value: '63%',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              AppLanguageController.instance.tr(
                'Summary Window: ${summary.fromDate} ~ ${summary.toDate}',
                '집계 기간: ${summary.fromDate} ~ ${summary.toDate}',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              AppLanguageController.instance.tr(
                'Sex Mix: ${sexCounts.entries.map((e) => '${e.key} ${e.value}').join(' · ')}',
                '성별 구성: ${sexCounts.entries.map((e) => '${e.key} ${e.value}명').join(' · ')}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguageController.instance.tr(
                'Top 3 Symptom Trends',
                '증상 추세 Top3',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              AppLanguageController.instance.tr(
                '1) Sleep / early waking  2) Neck / shoulder pain  3) Digestive discomfort',
                '1) 수면/새벽 각성  2) 목/어깨 통증  3) 소화 불편',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguageController.instance.tr(
                'Most common guidance: pre-sleep stretching · caffeine timing adjustment · 10-minute walk after meals',
                '자주 준 조언: 취침 전 스트레칭 · 카페인 시간 조절 · 식후 10분 걷기',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorPanel() {
    final dates = _store.allDates;
    final selectedDate = _parseDate(_selectedDate) ?? DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Patients by Date',
                '날짜별 환자 보기',
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              AppLanguageController.instance.tr(
                'Range Selection',
                '기간 선택',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700),
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
                  label: Text(AppLanguageController.instance.tr('Select Range', '기간 선택')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dates.map((date) {
                final count = _store.visitsForDate(date).length;
                final isSelected =
                    _selectedDate == date && _selectedDateRange == null;
                return ChoiceChip(
                  selected: isSelected,
                   label: Text(
                     AppLanguageController.instance.tr(
                       '$date  $count',
                       '$date  ${count}명',
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
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateFromCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                   label: Text(AppLanguageController.instance.tr('Pick Date', '날짜 선택')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDateRange == null
                        ? AppLanguageController.instance.tr(
                            'Selected Date: ${_formatDate(selectedDate)}',
                            '선택 날짜: ${_formatDate(selectedDate)}',
                          )
                        : AppLanguageController.instance.tr(
                            'Selected Range: ${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)}',
                            '선택 기간: ${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)}',
                          ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(int days) {
    final selected = _selectedDateRange == null && _selectedRangeDays == days;
    return ChoiceChip(
      selected: selected,
      label: Text(
        AppLanguageController.instance.tr(
          'Last $days days',
          '최근 $days일',
        ),
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
        return AppLanguageController.instance.tr('All', '??');
      case 'Missing Profile':
        return AppLanguageController.instance.tr(
          'Missing Profile',
          '??? ???',
        );
      case 'No Response':
        return AppLanguageController.instance.tr('No Response', '???');
      case 'In Progress':
        return AppLanguageController.instance.tr('In Progress', '???');
      case 'Complete':
        return AppLanguageController.instance.tr('Complete', '??');
      default:
        return value;
    }
  }

  bool _matchesStatusFilter(ScheduledVisit scheduledVisit) {
    switch (_selectedStatusFilter) {
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

  Widget _buildPatientCard(BuildContext context, ScheduledVisit scheduledVisit) {
    final profile = scheduledVisit.profile;
    final visit = scheduledVisit.visit;
    final firstQa = visit.qaList.isEmpty
        ? AppLanguageController.instance.tr(
            'No intake submitted yet - please review directly before the session',
            '문진 미제출 - 세션 전 직접 확인 필요',
          )
        : '${visit.qaList.first.question} / ${visit.qaList.first.answer}';
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
                        '${profile.name} · ${visit.date} ${visit.time}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(firstQa),
                      const SizedBox(height: 6),
                      Text(
                        AppLanguageController.instance.tr(
                          'Last Visit: ${visit.lastVisitDate} (${visit.daysAgo} days ago)',
                          '지난 방문: ${visit.lastVisitDate} (${visit.daysAgo}일 전)',
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
                  onPressed:
                      canSendRequest ? () => _sendReminder(context, scheduledVisit) : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    canSendRequest
                        ? AppLanguageController.instance.tr('Request Answers', '답변 요청')
                        : AppLanguageController.instance.tr('Contact Needed', '연락처 필요'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      PatientBriefScreen.routeName,
                      arguments: PatientHistoryArgs(
                        current: scheduledVisit,
                        history: _store.historyForPatient(profile.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right),
                  label: Text(AppLanguageController.instance.tr('View Detail', '상세 보기')),
                ),
              ],
            ),
            if (!canSendRequest) ...[
              const SizedBox(height: 8),
              Text(
                AppLanguageController.instance.tr(
                  'You can only send an answer request after both phone number and email are saved in Patient Management.',
                  '환자 정보 관리에서 전화번호와 이메일을 모두 입력해야 답변 요청 전송이 가능합니다.',
                ),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            _PatientRealtimeActivity(patientId: profile.id),
          ],
        ),
      ),
    );
  }

  List<ScheduledVisit> _visibleVisits() {
    if (_selectedDateRange != null) {
      return _store.visitsInRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
    }
    if (_selectedDate.isEmpty) {
      return const [];
    }
    return _store.visitsForDate(_selectedDate);
  }

  Widget _buildAppointmentRequestBoard() {
    final requests = _store.appointmentRequests
        .where((request) => request.status == AppointmentRequestStatus.pending)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Appointment Request Inbox',
                '예약 신청함',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppLanguageController.instance.tr(
                'Patients can only request open time slots. Confirm or decline them here.',
                '환자는 열려 있는 시간만 신청할 수 있고, 여기서 침술사가 확정 또는 거절합니다.',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              Text(
                AppLanguageController.instance.tr(
                  'There are no pending appointment requests right now.',
                  '지금 확인할 예약 신청이 없습니다.',
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
                          '${profile.name} · ${request.date} ${request.time}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLanguageController.instance.tr('Requested At', '신청 시각')}: '
                          '${request.requestedAt.year}-${request.requestedAt.month.toString().padLeft(2, '0')}-${request.requestedAt.day.toString().padLeft(2, '0')} '
                          '${request.requestedAt.hour.toString().padLeft(2, '0')}:${request.requestedAt.minute.toString().padLeft(2, '0')}',
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
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBoard() {
    final grouped = <String, List<AppointmentSlot>>{};
    for (final slot in _store.slots) {
      grouped.putIfAbsent(slot.date, () => <AppointmentSlot>[]).add(slot);
    }
    final dates = grouped.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguageController.instance.tr(
                'Shared Time Slots',
                '공유 예약 슬롯',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              AppLanguageController.instance.tr(
                'Turn off any time you do not want patients to see. Patients can request only open slots.',
                '침술사가 원하지 않는 시간은 꺼둘 수 있고, 환자는 열려 있는 슬롯만 신청할 수 있습니다.',
              ),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...dates.map((date) {
              final slots = grouped[date]!..sort((a, b) => a.time.compareTo(b.time));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots.map((slot) {
                        return FilterChip(
                          selected: slot.isOpen,
                          label: Text(
                            slot.isOpen
                                ? '${slot.time} ${AppLanguageController.instance.tr('Open', '열림')}'
                                : '${slot.time} ${AppLanguageController.instance.tr('Hidden', '숨김')}',
                          ),
                          onSelected: (selected) {
                            _store.setSlotOpen(slot.date, slot.time, selected);
                          },
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

  _VisitWindowSummary _visitWindowSummary() {
    if (_selectedDateRange != null) {
      final visits = _store.visitsInRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
      return _VisitWindowSummary(
        days: _selectedDateRange!.duration.inDays + 1,
        totalVisits: visits.length,
        fromDate: _formatDate(_selectedDateRange!.start),
        toDate: _formatDate(_selectedDateRange!.end),
        periodLabel:
            AppLanguageController.instance.tr(
              '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} ${visits.length}',
              '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} ${visits.length}명',
            ),
      );
    }

    final selected = _parseDate(_selectedDate) ?? DateTime.now();
    final start = selected.subtract(Duration(days: _selectedRangeDays - 1));
    final visits = _store.visitsInRange(start, selected);

    return _VisitWindowSummary(
      days: _selectedRangeDays,
      totalVisits: visits.length,
      fromDate: _formatDate(start),
      toDate: _formatDate(selected),
      periodLabel: AppLanguageController.instance.tr(
        '${_formatDate(start)} ~ ${_formatDate(selected)} ${visits.length}',
        '${_formatDate(start)} ~ ${_formatDate(selected)} ${visits.length}명',
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
                                'Already Answered Snapshot',
                                '이미 답한 내용 요약',
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLanguageController.instance.tr(
                                '$totalAnsweredCount answered question(s) across $answeredCategoryCount categor${answeredCategoryCount == 1 ? 'y' : 'ies'}',
                                '$answeredCategoryCount개 카테고리에서 총 $totalAnsweredCount개 질문에 이미 답했습니다',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLanguageController.instance.tr(
                                'Use the category sections below to request what is still missing or what needs clarification.',
                                '아래 카테고리에서 아직 안 물어본 것과 추가 확인이 필요한 것을 골라 요청할 수 있습니다.',
                              ),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLanguageController.instance.tr(
                          'Select Questions to Request',
                          '요청할 질문 선택',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._questionLibraryByCategory.entries.map((entry) {
                        final answeredItems = answeredByCategory[entry.key] ?? const <QaItem>[];
                        return ExpansionTile(
                          dense: true,
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: answeredItems.isEmpty
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  answeredItems.isEmpty
                                      ? AppLanguageController.instance.tr('No answers yet', '아직 답변 없음')
                                      : AppLanguageController.instance.tr(
                                          '${answeredItems.length} answered',
                                          '${answeredItems.length}개 답변됨',
                                        ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: answeredItems.isEmpty ? Colors.orange.shade800 : Colors.teal.shade800,
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
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLanguageController.instance.tr(
                                        'Already answered in this category',
                                        '이 카테고리에서 이미 답한 내용',
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    ...answeredItems.map(
                                      (qa) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text('• ${qa.question}\n  ${qa.answer}'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...entry.value.map((question) {
                              final answeredItem = answeredItems.cast<QaItem?>().firstWhere(
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
                                          'No answer saved yet',
                                          '아직 저장된 답변 없음',
                                        ),
                                      )
                                    : Text(
                                        AppLanguageController.instance.tr(
                                          'Already answered: ${answeredItem.answer}',
                                          '이미 답변됨: ${answeredItem.answer}',
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
                                            hintText: AppLanguageController.instance.tr(
                                              'Example: Does the symptom get worse in a specific situation?',
                                              '예: 특정 상황에서 증상이 더 심해지나요?',
                                            ),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(AppLanguageController.instance.tr('Cancel', '취소')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              controller.text.trim(),
                                            ),
                                            child: Text(AppLanguageController.instance.tr('Add', '추가')),
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
                                        .putIfAbsent(entry.key, () => <String>[])
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
                                        customQuestionsByCategory.remove(entry.key);
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
                      final customCount = customQuestionsByCategory.values.fold<int>(
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

                      final selectedQuestionList = selectedQuestions.toList()..sort();
                      final note = noteController.text.trim();

                      try {
                        final docId = await AppFirestoreService.sendAnswerRequest(
                          patientId: profile.id,
                          patientName: profile.name,
                          patientPhone: profile.phone,
                          patientEmail: profile.email,
                          patientTime: visit.time,
                          lastVisitDate: visit.lastVisitDate,
                          intakeStatus: visit.intakeStatus.name,
                          selectedQuestions: selectedQuestionList,
                          customQuestionsByCategory: customQuestionsByCategory.map(
                            (key, value) => MapEntry(key, List<String>.from(value)),
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

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final currentDate = _parseDate(_selectedDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 10, now.month, now.day),
      helpText: AppLanguageController.instance.tr('Pick Date', '날짜 선택'),
      cancelText: AppLanguageController.instance.tr('Cancel', '취소'),
      confirmText: AppLanguageController.instance.tr('Confirm', '확인'),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = _formatDate(picked);
      _selectedDateRange = null;
      _selectedPatientFilter = 'All Patients';
      _selectedStatusFilter = 'All';
    });
  }

  Future<void> _pickDateRangeWithDialog() async {
    final now = DateTime.now();
    DateTime start = _selectedDateRange?.start ??
        (_parseDate(_selectedDate)?.subtract(
              Duration(days: _selectedRangeDays - 1),
            ) ??
            now);
    DateTime end =
        _selectedDateRange?.end ?? (_parseDate(_selectedDate) ?? now);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppLanguageController.instance.tr('Practitioner Dashboard', '침술사 대시보드')),
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
                          helpText: AppLanguageController.instance.tr('Pick Start Date', '시작일 선택'),
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
                          'Start: ${_formatDate(start)}',
                          '시작일: ${_formatDate(start)}',
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
                          helpText: AppLanguageController.instance.tr('Pick End Date', '종료일 선택'),
                        );
                        if (picked == null) {
                          return;
                        }
                        setDialogState(() {
                          end = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                          if (end.isBefore(start)) {
                            start = end;
                          }
                        });
                      },
                      child: Text(
                        AppLanguageController.instance.tr(
                          'End: ${_formatDate(end)}',
                          '종료일: ${_formatDate(end)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                      Text(
                      AppLanguageController.instance.tr(
                        'Selected Range: ${_formatDate(start)} ~ ${_formatDate(end)}',
                        '선택 범위: ${_formatDate(start)} ~ ${_formatDate(end)}',
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
                    child: Text(AppLanguageController.instance.tr('Cancel', '취소')),
                ),
                FilledButton(
                  onPressed: () {
                      setState(() {
                        _selectedDate = _formatDate(end);
                        _selectedDateRange = DateTimeRange(start: start, end: end);
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

  Future<void> _openPatientManagement(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _PatientManagementDialog(),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
  const _PatientRealtimeActivity({required this.patientId});

  final String patientId;

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
                if (submissionSnapshot.hasError || requestSnapshot.hasError || feedbackSnapshot.hasError) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'Unable to load real-time activity.',
                      '실시간 앱 활동을 불러올 수 없습니다.',
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }

                if (!submissionSnapshot.hasData || !requestSnapshot.hasData || !feedbackSnapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 4),
                  );
                }

                final submissionDocs = [...submissionSnapshot.data!.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['submittedAt'] as Timestamp?)?.toDate();
                    final bDate = (b.data()['submittedAt'] as Timestamp?)?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
                  });

                final requestDocs = [...requestSnapshot.data!.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['requestedAt'] as Timestamp?)?.toDate();
                    final bDate = (b.data()['requestedAt'] as Timestamp?)?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
                  });

                final feedbackDocs = [...feedbackSnapshot.data!.docs]
                  ..sort((a, b) {
                    final aDate = (a.data()['updatedAt'] as Timestamp?)?.toDate();
                    final bDate = (b.data()['updatedAt'] as Timestamp?)?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
                  });

                final latestSubmission = submissionDocs.isNotEmpty ? submissionDocs.first.data() : null;
                final latestRequest = requestDocs.isNotEmpty ? requestDocs.first.data() : null;
                final latestFeedback = feedbackDocs.isNotEmpty ? feedbackDocs.first.data() : null;
                final pendingFeedbackCount = feedbackDocs.where((doc) => (doc.data()['status'] ?? 'pending') == 'pending').length;

                final submissionAt = (latestSubmission?['submittedAt'] as Timestamp?)?.toDate();
                final requestAt = (latestRequest?['requestedAt'] as Timestamp?)?.toDate();
                final feedbackAt = (latestFeedback?['updatedAt'] as Timestamp?)?.toDate();

                final answers = (latestSubmission?['answers'] as List<dynamic>? ?? const []);
                final selectedQuestions = (latestRequest?['selectedQuestions'] as List<dynamic>? ?? const []);

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
                        AppLanguageController.instance.tr('Real-Time App Activity', '실시간 앱 활동'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (latestRequest == null)
                        Text(AppLanguageController.instance.tr('No recent answer request', '최근 답변 요청 없음'))
                      else
                        Text(
                          AppLanguageController.instance.tr(
                            'Latest answer request: ${selectedQuestions.length} questions ? ${_formatDateTime(requestAt)}',
                            '최근 답변 요청: 질문 ${selectedQuestions.length}개 · ${_formatDateTime(requestAt)}',
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (latestSubmission == null)
                        Text(AppLanguageController.instance.tr('No recent submission', '최근 제출 없음'))
                      else
                        Text(
                          AppLanguageController.instance.tr(
                            'Latest patient submission: ${answers.length} answers ? ${_formatDateTime(submissionAt)}',
                            '최근 환자 제출: 답변 ${answers.length}개 · ${_formatDateTime(submissionAt)}',
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (latestFeedback == null)
                        Text(AppLanguageController.instance.tr('No visit-record feedback yet', '방문 기록 피드백 없음'))
                      else
                        Text(
                          AppLanguageController.instance.tr(
                            'Visit-record feedback: $pendingFeedbackCount pending ? ${_formatDateTime(feedbackAt)}',
                            '방문 기록 피드백: 미확인 $pendingFeedbackCount건 · ${_formatDateTime(feedbackAt)}',
                          ),
                          style: TextStyle(
                            color: pendingFeedbackCount > 0 ? Colors.deepOrange : Colors.black87,
                            fontWeight: pendingFeedbackCount > 0 ? FontWeight.w700 : FontWeight.w400,
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
                'Review the most recent submissions from beta sign-ups using email and password.',
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
                    final aDate = (a.data()['submittedAt'] as Timestamp?)?.toDate();
                    final bDate = (b.data()['submittedAt'] as Timestamp?)?.toDate();
                    return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
                  });

                if (docs.isEmpty) {
                  return Text(
                    AppLanguageController.instance.tr(
                      'No beta submissions yet.',
                      '아직 베타 가입자의 제출이 없습니다.',
                    ),
                  );
                }

                return Column(
                  children: docs.take(5).map((doc) {
                    final data = doc.data();
                    final patientName = (data['patientName'] as String?) ?? 'Unknown';
                    final visitType = (data['visitType'] as String?) ?? 'follow_up';
                    final answers =
                        (data['answers'] as List<dynamic>? ?? const []).length;
                    final submittedAt =
                        (data['submittedAt'] as Timestamp?)?.toDate();

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
                        final aDate =
                            (a.data()['updatedAt'] as Timestamp?)?.toDate();
                        final bDate =
                            (b.data()['updatedAt'] as Timestamp?)?.toDate();
                        return (bDate ?? DateTime(2000))
                            .compareTo(aDate ?? DateTime(2000));
                      });

                    final submissionsByPatient = <String, List<Map<String, dynamic>>>{};
                    for (final doc in submissionSnapshot.data!.docs) {
                      final data = doc.data();
                      final patientId = (data['patientId'] as String?) ?? '';
                      if (patientId.isEmpty) {
                        continue;
                      }
                      submissionsByPatient.putIfAbsent(patientId, () => []).add(data);
                    }

                    if (patientDocs.isEmpty) {
                      return Text(
                        AppLanguageController.instance.tr(
                          'No beta users have signed up yet.',
                          '아직 가입한 베타 사용자가 없습니다.',
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr('Registrants', '가입자'),
                                value: AppLanguageController.instance.tr('${patientDocs.length}', '${patientDocs.length}명'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr('Contact Complete', '연락처 완성'),
                                value:
                                    AppLanguageController.instance.tr(
                                      '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}',
                                      '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}명',
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: AppLanguageController.instance.tr('Submitted', '제출 완료'),
                                value:
                                    AppLanguageController.instance.tr(
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
                          final displayName =
                              name.isEmpty ? 'New Patient' : name;
                          final phone = ((data['phone'] as String?) ?? '').trim();
                          final email = ((data['email'] as String?) ?? '').trim();
                          final sex = ((data['sex'] as String?) ?? '').trim();
                          final ethnicity =
                              ((data['ethnicity'] as String?) ?? '').trim();
                          final birthYear =
                              (data['birthYear'] as num?)?.toInt();
                          final updatedAt =
                              (data['updatedAt'] as Timestamp?)?.toDate();
                          final createdAt =
                              (data['createdAt'] as Timestamp?)?.toDate();
                          final hasRequired = phone.isNotEmpty && email.isNotEmpty;
                          final submissions =
                              submissionsByPatient[doc.id] ?? const [];
                          submissions.sort((a, b) {
                            final aDate =
                                (a['submittedAt'] as Timestamp?)?.toDate();
                            final bDate =
                                (b['submittedAt'] as Timestamp?)?.toDate();
                            return (bDate ?? DateTime(2000))
                                .compareTo(aDate ?? DateTime(2000));
                          });
                          final latestSubmission =
                              submissions.isNotEmpty ? submissions.first : null;
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
                                            ? AppLanguageController.instance.tr('Contact Ready', '연락처 준비됨')
                                            : AppLanguageController.instance.tr('Missing Required Info', '필수 정보 부족'),
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
                                      ? AppLanguageController.instance.tr('No contact info', '연락처 없음')
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
                                          ? AppLanguageController.instance.tr('No submission yet', '아직 제출 없음')
                                          : AppLanguageController.instance.tr('Submitted ${submissions.length} time(s)', '제출 ${submissions.length}회'),
                                      color: submissions.isEmpty
                                          ? const Color(0xFFF6E9C9)
                                          : const Color(0xFFDDF0E8),
                                    ),
                                    _StatusTag(
                                      label:
                                          AppLanguageController.instance.tr('Signed up: ${_formatDateTime(createdAt)}', '가입: ${_formatDateTime(createdAt)}'),
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    _StatusTag(
                                      label:
                                          AppLanguageController.instance.tr('Profile updated: ${_formatDateTime(updatedAt)}', '프로필 수정: ${_formatDateTime(updatedAt)}'),
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    if (latestSubmissionAt != null)
                                      _StatusTag(
                                        label:
                                            AppLanguageController.instance.tr('Latest submission: ${_formatDateTime(latestSubmissionAt)}', '최근 제출: ${_formatDateTime(latestSubmissionAt)}'),
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
  const _BetaOverviewChip({
    required this.label,
    required this.value,
  });

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
  const _StatusTag({
    required this.label,
    required this.color,
  });

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
  const _PatientManagementDialog();

  @override
  State<_PatientManagementDialog> createState() =>
      _PatientManagementDialogState();
}

class _PatientManagementDialogState extends State<_PatientManagementDialog> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  String? _selectedProfileId;

  @override
  Widget build(BuildContext context) {
    final profiles = _store.profiles;
    final selected = _selectedProfileId == null
        ? (profiles.isNotEmpty ? profiles.first : null)
        : _store.profileById(_selectedProfileId!);

    return AlertDialog(
      title: Text(AppLanguageController.instance.tr('Patient Management', '환자 정보 관리')),
      content: SizedBox(
        width: 960,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () {
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
                      setState(() => _selectedProfileId = newProfile.id);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(AppLanguageController.instance.tr('Add Patient', '환자 추가')),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final isSelected = selected?.id == profile.id;
                        final missingFields = <String>[
                          if (profile.phone.trim().isEmpty) '전화번호',
                          if (profile.email.trim().isEmpty) '이메일',
                        ];
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
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      AppLanguageController.instance.tr('Missing Required Info', '필수 정보 부족'),
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
                            onTap: () =>
                                setState(() => _selectedProfileId = profile.id),
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
                  ? Center(child: Text(AppLanguageController.instance.tr('Select a patient to manage.', '관리할 환자를 선택하세요.')))
                  : _PatientProfileEditor(
                      profile: selected,
                      onSave: (updated) {
                        _store.saveProfile(updated);
                        setState(() => _selectedProfileId = updated.id);
                      },
                    ),
            ),
          ],
        ),
      ),
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
  });

  final PatientProfile profile;
  final ValueChanged<PatientProfile> onSave;

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
    _ethnicityController = TextEditingController(text: widget.profile.ethnicity);
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
                      labelText: AppLanguageController.instance.tr('Phone', '전화번호'),
                      border: OutlineInputBorder(),
                    ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppLanguageController.instance.tr('Email', '이메일'),
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
                      labelText: AppLanguageController.instance.tr('Birth Year', '출생연도'),
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
                      labelText: AppLanguageController.instance.tr('Sex / Gender', '성별'),
                      border: OutlineInputBorder(),
                    ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ethnicityController,
                    decoration: InputDecoration(
                      labelText: AppLanguageController.instance.tr('Ethnicity', '인종/민족'),
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
                labelText: AppLanguageController.instance.tr('Internal Note', '관리 메모'),
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
                birthYear: int.tryParse(_birthYearController.text.trim()) ??
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
            label: Text(AppLanguageController.instance.tr('Save Patient Info', '환자 정보 저장')),
          ),
        ],
      ),
    );
  }
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
      width: 150,
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
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}





