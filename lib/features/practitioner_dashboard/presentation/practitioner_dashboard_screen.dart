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
      'ëª¸ì´ ì‰½ê²Œ ë¥ê±°ë‚˜ ì¶¥ê²Œ ëŠê»´ì§€ë‚˜ìš”?',
      'ì‹ì€ë•€/ìží•œ/ë„í•œì´ ìžˆë‚˜ìš”?',
    ],
    'Appetite/Thirst': [
      'ì‹ìš•ì€ í‰ì†Œì™€ ë¹„êµí•´ ì–´ë–¤ê°€ìš”?',
      'ê°ˆì¦ì´ ìž¦ê±°ë‚˜ ì°¬ë¬¼/ë”°ëœ»í•œ ë¬¼ ì„ í˜¸ê°€ ìžˆë‚˜ìš”?',
    ],
    'Sleep': [
      'ìž ë“œëŠ” ì‹œê°„ê³¼ ê¹¨ëŠ” íšŸìˆ˜ëŠ” ì–´ë–¤ê°€ìš”?',
      'ê¿ˆì´ ë§Žê±°ë‚˜ ìžê³  ë‚˜ë„ ê°œìš´í•˜ì§€ ì•Šë‚˜ìš”?',
    ],
    'Digestion': [
      'ì‹í›„ ë”ë¶€ë£©í•¨ì´ë‚˜ ì†ì“°ë¦¼ì´ ìžˆë‚˜ìš”?',
      'íŠ¸ë¦¼/ê°€ìŠ¤/ì—­ë¥˜ ì¦ìƒì´ ìžˆë‚˜ìš”?',
    ],
    'Urine': [
      'ì†Œë³€ íšŸìˆ˜ë‚˜ ê¸‰ë°•ë‡¨ ë³€í™”ê°€ ìžˆë‚˜ìš”?',
      'ì•¼ê°„ë‡¨ê°€ ëŠ˜ì—ˆë‚˜ìš”?',
    ],
    'Stool': [
      'ë°°ë³€ ì£¼ê¸°ë‚˜ êµ³ê¸° ë³€í™”ê°€ ìžˆë‚˜ìš”?',
      'ë³€ë¹„ì™€ ì„¤ì‚¬ê°€ ë²ˆê°ˆì•„ ë‚˜íƒ€ë‚˜ë‚˜ìš”?',
    ],
    'Menses': [
      'ìƒë¦¬ ì£¼ê¸°/ì–‘/í†µì¦ ë³€í™”ê°€ ìžˆë‚˜ìš”?',
      'í˜ˆê´´(ë©ì–´ë¦¬)ë‚˜ ìƒ‰ ë³€í™”ê°€ ìžˆë‚˜ìš”?',
    ],
    'HEENT': [
      'ë‘í†µ, ëˆˆí”¼ë¡œ, ì´ëª…, ì½”ë§‰íž˜ ì¤‘ ë¶ˆíŽ¸í•œ ê²ƒì´ ìžˆë‚˜ìš”?',
      'ëª©/ì–´ê¹¨ ê¸´ìž¥ê³¼ ì—°ê´€ëœ ì¦ìƒì´ ìžˆë‚˜ìš”?',
    ],
    'Emotion': [
      'ìµœê·¼ ê°ì • ê¸°ë³µì´ë‚˜ ì˜ˆë¯¼í•¨ì´ ëŠ˜ì—ˆë‚˜ìš”?',
      'ìŠ¤íŠ¸ë ˆìŠ¤ê°€ ëª¸ ì¦ìƒì— ì˜í–¥ì„ ì£¼ë‚˜ìš”?',
    ],
    'Energy': [
      'í•˜ë£¨ ì¤‘ ì–¸ì œ ê°€ìž¥ í”¼ê³¤í•œê°€ìš”?',
      'ê¸°ìš´ì´ ê°‘ìžê¸° ë–¨ì–´ì§€ëŠ” ì‹œê°„ì´ ìžˆë‚˜ìš”?',
    ],
  };

  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _patientFilterController =
      TextEditingController();

  late String _selectedDate;
  String _selectedPatientFilter = 'ì „ì²´ í™˜ìž';
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
      animation: _store,
      builder: (context, _) {
        final visibleVisits = _visibleVisits();
        final patientNames = visibleVisits.map((v) => v.profile.name).toSet().toList()
          ..sort();
        final keyword = _patientFilterController.text.trim().toLowerCase();
        final dropdownFiltered = _selectedPatientFilter == 'ì „ì²´ í™˜ìž'
            ? visibleVisits
            : visibleVisits
                .where((v) => v.profile.name == _selectedPatientFilter)
                .toList();
        final filteredVisits = keyword.isEmpty
            ? dropdownFiltered
            : dropdownFiltered
                .where((v) => v.profile.name.toLowerCase().contains(keyword))
                .toList();
        final summary = _visitWindowSummary();
        final upcoming = _store
            .upcomingVisits(_parseDate(_selectedDate) ?? DateTime.now())
            .take(6)
            .toList();

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
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildUpcomingBoard(upcoming),
              ],
              const SizedBox(height: 12),
              const _BetaRegistrantBoard(),
              const SizedBox(height: 12),
              const _BetaSubmissionBoard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDateRange == null
                          ? '$_selectedDate í™˜ìž ${filteredVisits.length}ëª…'
                          : '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} í™˜ìž ${filteredVisits.length}ëª…',
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
                              _selectedPatientFilter == 'ì „ì²´ í™˜ìž'
                          ? _selectedPatientFilter
                          : 'ì „ì²´ í™˜ìž',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'ì „ì²´ í™˜ìž',
                          child: Text('ì „ì²´ í™˜ìž'),
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
              TextField(
                controller: _patientFilterController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  hintText: 'í™˜ìž ì´ë¦„ ì§ì ‘ ê²€ìƒ‰',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedDateRange == null
                    ? 'ì´ ë‚´ì› ì§‘ê³„: ${summary.periodLabel}'
                    : 'ì„ íƒ ê¸°ê°„ ì§‘ê³„: ${summary.periodLabel}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (filteredVisits.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('ì„ íƒí•œ ì¡°ê±´ì— ë§žëŠ” í™˜ìžê°€ ì—†ìŠµë‹ˆë‹¤.'),
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
            const Text(
              'í˜„í™©í‘œ (ì¹¨ìˆ ì‚¬ ì¸ì‚¬ì´íŠ¸)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniKpi(
                  title: 'ì´ ë‚´ì› (${summary.days}ì¼)',
                  value: '${summary.totalVisits}ëª…',
                ),
                _MiniKpi(title: 'ë“±ë¡ í™˜ìž', value: '${profiles.length}ëª…'),
                _MiniKpi(
                  title: 'ì•Œë¦¼ ê°€ëŠ¥',
                  value:
                      '${profiles.where((p) => p.hasRequiredAlertInfo).length}ëª…',
                ),
                const _MiniKpi(title: 'ìž¬ë‚´ì›ìœ¨', value: '63%'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'ì§‘ê³„ ê¸°ê°„: ${summary.fromDate} ~ ${summary.toDate}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              'ì„±ë³„ êµ¬ì„±: ${sexCounts.entries.map((e) => '${e.key} ${e.value}ëª…').join(' Â· ')}',
            ),
            const SizedBox(height: 8),
            const Text(
              'ì¦ìƒ ì¶”ì„¸ Top3',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('1) ìˆ˜ë©´/ìƒˆë²½ ê°ì„±  2) ëª©/ì–´ê¹¨ í†µì¦  3) ì†Œí™” ë¶ˆíŽ¸'),
            const SizedBox(height: 8),
            const Text('ìžì£¼ ì¤€ ì¡°ì–¸: ì·¨ì¹¨ ì „ ìŠ¤íŠ¸ë ˆì¹­ Â· ì¹´íŽ˜ì¸ ì‹œê°„ ì¡°ì ˆ Â· ì‹í›„ 10ë¶„ ê±·ê¸°'),
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
            const Text(
              'ë‚ ì§œë³„ í™˜ìž ë³´ê¸°',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text('ê¸°ê°„ ì„ íƒ', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  label: Text(AppLanguageController.instance.tr('Patient Management', '?? ?? ??')),
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
                  label: Text('$date  $countëª…'),
                  onSelected: (_) {
                    setState(() {
                      _selectedDate = date;
                      _selectedDateRange = null;
                      _selectedPatientFilter = 'ì „ì²´ í™˜ìž';
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
                  label: Text(AppLanguageController.instance.tr('Patient Management', '?? ?? ??')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDateRange == null
                        ? 'ì„ íƒ ë‚ ì§œ: ${_formatDate(selectedDate)}'
                        : 'ì„ íƒ ê¸°ê°„: ${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)}',
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
      label: Text('ìµœê·¼ $daysì¼'),
      onSelected: (_) {
        setState(() {
          _selectedRangeDays = days;
          _selectedDateRange = null;
          _selectedPatientFilter = 'ì „ì²´ í™˜ìž';
        });
      },
    );
  }

  Widget _buildUpcomingBoard(List<ScheduledVisit> upcoming) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ë‹¤ê°€ì˜¤ëŠ” í™˜ìž ë³´ë“œ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...upcoming.map((scheduledVisit) {
              final profile = scheduledVisit.profile;
              final visit = scheduledVisit.visit;
              final preview = visit.qaList.isEmpty
                  ? 'ë¬¸ì§„ ë¯¸ìž‘ì„±'
                  : '${visit.qaList.first.question} / ${visit.qaList.first.answer}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${visit.date} Â· ${visit.time} Â· ${profile.name}'),
                subtitle: Text(
                  '$preview\nì—°ë½ì²˜: ${profile.phone.isEmpty ? 'ë¯¸ìž…ë ¥' : profile.phone}',
                ),
                trailing: Chip(label: Text(visit.intakeStatus.label)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, ScheduledVisit scheduledVisit) {
    final profile = scheduledVisit.profile;
    final visit = scheduledVisit.visit;
    final firstQa = visit.qaList.isEmpty
        ? 'ë¬¸ì§„ ë¯¸ì œì¶œ - ì„¸ì…˜ ì „ ì§ì ‘ í™•ì¸ í•„ìš”'
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
                        '${profile.name} Â· ${visit.date} ${visit.time}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(firstQa),
                      const SizedBox(height: 6),
                      Text('ì§€ë‚œ ë°©ë¬¸: ${visit.lastVisitDate} (${visit.daysAgo}ì¼ ì „)'),
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
                        'ì—°ë½ì²˜: ${profile.phone.isEmpty ? 'ë¯¸ìž…ë ¥' : profile.phone} / ${profile.email.isEmpty ? 'ì´ë©”ì¼ ë¯¸ìž…ë ¥' : profile.email}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'í™˜ìž ì •ë³´: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
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
                  label: Text(canSendRequest ? 'ë‹µë³€ ìš”ì²­' : 'ì—°ë½ì²˜ í•„ìš”'),
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
                  label: Text(AppLanguageController.instance.tr('Patient Management', '?? ?? ??')),
                ),
              ],
            ),
            if (!canSendRequest) ...[
              const SizedBox(height: 8),
              const Text(
                'í™˜ìž ì •ë³´ ê´€ë¦¬ì—ì„œ ì „í™”ë²ˆí˜¸ì™€ ì´ë©”ì¼ì„ ëª¨ë‘ ìž…ë ¥í•´ì•¼ ë‹µë³€ ìš”ì²­ ì „ì†¡ì´ ê°€ëŠ¥í•©ë‹ˆë‹¤.',
                style: TextStyle(color: Colors.redAccent),
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
    final selected = _parseDate(_selectedDate);
    if (selected == null) {
      return const [];
    }
    final start = selected.subtract(Duration(days: _selectedRangeDays - 1));
    return _store.visitsInRange(start, selected);
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
            '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} ${visits.length}ëª…',
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
      periodLabel: '${_formatDate(start)} ~ ${_formatDate(selected)} ${visits.length}ëª…',
    );
  }

  String _visitTrailLabel(PatientVisit visit) {
    if (visit.scheduledSinceLast == 0 && visit.noShowSinceLast == 0) {
      return 'ì§€ë‚œ ë°©ë¬¸ ì´í›„ ì¶”ê°€ ì˜ˆì•½ ì—†ìŒ -> ì´ë²ˆ ë°©ë¬¸ì´ ì²« ìž¬ë‚´ì›';
    }
    return 'ì§€ë‚œ ë°©ë¬¸ ì´í›„ ì¶”ê°€ ì˜ˆì•½ ${visit.scheduledSinceLast}ê±´, ë…¸ì‡¼ ${visit.noShowSinceLast}ê±´';
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${profile.name}ë‹˜ ë‹µë³€ ìš”ì²­'),
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
                          'ì „ì†¡ ëŒ€ìƒ ì—°ë½ì²˜: ${profile.phone.isEmpty ? 'ì „í™”ë²ˆí˜¸ ì—†ìŒ' : profile.phone}${profile.email.isEmpty ? ' / ì´ë©”ì¼ ì—†ìŒ' : ' / ${profile.email}'}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'ìš”ì²­í•  ì§ˆë¬¸ ì„ íƒ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._questionLibraryByCategory.entries.map((entry) {
                        return ExpansionTile(
                          dense: true,
                          tilePadding: EdgeInsets.zero,
                          title: Text(entry.key),
                          children: [
                            ...entry.value.map((question) {
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(question),
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
                                        title: Text('${entry.key} ì§ì ‘ ì§ˆë¬¸ ìž…ë ¥'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            hintText:
                                                'ì˜ˆ: íŠ¹ì • ìƒí™©ì—ì„œ ì¦ìƒì´ ë” ì‹¬í•´ì§€ë‚˜ìš”?',
                                          ),
                                        ),
                                        actions: [
              const LanguageMenuButton(),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('ì·¨ì†Œ'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              controller.text.trim(),
                                            ),
                                            child: const Text('ì¶”ê°€'),
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
                                label: Text(AppLanguageController.instance.tr('Patient Management', '?? ?? ??')),
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
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'ë…¸íŠ¸ (í™˜ìžì—ê²Œ ì „ë‹¬í•  ë§)',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
              const LanguageMenuButton(),
            TextButton(
              onPressed: () {
                noteController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('ì·¨ì†Œ'),
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
                          const SnackBar(
                            content: Text('ì§ˆë¬¸ì„ 1ê°œ ì´ìƒ ì„ íƒí•˜ê±°ë‚˜ ì§ì ‘ ì¶”ê°€í•´ì£¼ì„¸ìš”.'),
                          ),
                        );
                        return;
                      }

                      final selectedQuestionList = selectedQuestions.toList()
                        ..sort();
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
                            content: Text('${profile.name}ë‹˜ ë‹µë³€ ìš”ì²­ ì €ìž¥ ì™„ë£Œ: $docId'),
                          ),
                        );
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ë‹µë³€ ìš”ì²­ ì €ìž¥ ì‹¤íŒ¨: $error')),
                        );
                      }
                    },
              child: const Text('ì „ì†¡'),
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
      helpText: 'ë‚ ì§œ ì„ íƒ',
      cancelText: 'ì·¨ì†Œ',
      confirmText: 'í™•ì¸',
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = _formatDate(picked);
      _selectedDateRange = null;
      _selectedPatientFilter = 'ì „ì²´ í™˜ìž';
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
                          helpText: 'ì‹œìž‘ì¼ ì„ íƒ',
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
                      child: Text('ì‹œìž‘ì¼: ${_formatDate(start)}'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(now.year + 10, now.month, now.day),
                          helpText: 'ì¢…ë£Œì¼ ì„ íƒ',
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
                      child: Text('ì¢…ë£Œì¼: ${_formatDate(end)}'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ì„ íƒ ë²”ìœ„: ${_formatDate(start)} ~ ${_formatDate(end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              actions: [
              const LanguageMenuButton(),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ì·¨ì†Œ'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _formatDate(end);
                      _selectedDateRange = DateTimeRange(start: start, end: end);
                      _selectedRangeDays = end.difference(start).inDays + 1;
                      _selectedPatientFilter = 'ì „ì²´ í™˜ìž';
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ì ìš©'),
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
            if (submissionSnapshot.hasError || requestSnapshot.hasError) {
              return const Text(
                'ì‹¤ì‹œê°„ í™œë™ì„ ë¶ˆëŸ¬ì˜¤ì§€ ëª»í–ˆìŠµë‹ˆë‹¤.',
                style: TextStyle(color: Colors.redAccent),
              );
            }

            if (!submissionSnapshot.hasData || !requestSnapshot.hasData) {
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

            final latestSubmission =
                submissionDocs.isNotEmpty ? submissionDocs.first.data() : null;
            final latestRequest =
                requestDocs.isNotEmpty ? requestDocs.first.data() : null;

            final submissionAt =
                (latestSubmission?['submittedAt'] as Timestamp?)?.toDate();
            final requestAt =
                (latestRequest?['requestedAt'] as Timestamp?)?.toDate();

            final answers =
                (latestSubmission?['answers'] as List<dynamic>? ?? const []);
            final selectedQuestions =
                (latestRequest?['selectedQuestions'] as List<dynamic>? ?? const []);

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
                  const Text(
                    'ì‹¤ì‹œê°„ ì•± í™œë™',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (latestRequest == null)
                    const Text('ìµœê·¼ ë‹µë³€ ìš”ì²­ ì—†ìŒ')
                  else
                    Text(
                      'ìµœê·¼ ë‹µë³€ ìš”ì²­: ${selectedQuestions.length}ê°œ ì§ˆë¬¸ Â· ${_formatDateTime(requestAt)}',
                    ),
                  const SizedBox(height: 4),
                  if (latestSubmission == null)
                    const Text('ìµœê·¼ ì œì¶œ ì—†ìŒ')
                  else
                    Text(
                      'ìµœê·¼ í™˜ìž ì œì¶œ: ${answers.length}ê°œ ë‹µë³€ Â· ${_formatDateTime(submissionAt)}',
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'ë°©ê¸ˆ ì „';
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
            const Text(
              'ì§€ì¸ ë² íƒ€ ì œì¶œí•¨',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ì´ë©”ì¼/ë¹„ë°€ë²ˆí˜¸ë¡œ ê°€ìž…í•œ ì§€ì¸ë“¤ì˜ ìµœê·¼ ì œì¶œì„ í™•ì¸í•©ë‹ˆë‹¤.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('intake_submissions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'ë² íƒ€ ì œì¶œí•¨ì„ ë¶ˆëŸ¬ì˜¤ì§€ ëª»í–ˆìŠµë‹ˆë‹¤.',
                    style: TextStyle(color: Colors.redAccent),
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
                  return const Text('ì•„ì§ ë² íƒ€ ê°€ìž…ìžì˜ ì œì¶œì´ ì—†ìŠµë‹ˆë‹¤.');
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
                        '${visitType == 'initial' ? 'ì´ˆì§„' : 'ìž¬ì§„'} Â· ë‹µë³€ $answersê°œ Â· ${_formatDateTime(submittedAt)}',
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
      return 'ë°©ê¸ˆ ì „';
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
            const Text(
              'ì§€ì¸ ë² íƒ€ ê°€ìž…ìž',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'íšŒì›ê°€ìž…ë§Œ í•œ ì‚¬ëžŒ, ì—°ë½ì²˜ê°€ ë¹ ì§„ ì‚¬ëžŒ, ì´ë¯¸ ì œì¶œê¹Œì§€ í•œ ì‚¬ëžŒì„ ì—¬ê¸°ì„œ ë°”ë¡œ í™•ì¸í•©ë‹ˆë‹¤.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .snapshots(),
              builder: (context, patientSnapshot) {
                if (patientSnapshot.hasError) {
                  return const Text(
                    'ë² íƒ€ ê°€ìž…ìž ëª©ë¡ì„ ë¶ˆëŸ¬ì˜¤ì§€ ëª»í–ˆìŠµë‹ˆë‹¤.',
                    style: TextStyle(color: Colors.redAccent),
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
                      return const Text(
                        'ë² íƒ€ ì œì¶œ ë°ì´í„°ë¥¼ ë¶ˆëŸ¬ì˜¤ì§€ ëª»í–ˆìŠµë‹ˆë‹¤.',
                        style: TextStyle(color: Colors.redAccent),
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
                      return const Text('ì•„ì§ ê°€ìž…í•œ ë² íƒ€ ì‚¬ìš©ìžê°€ ì—†ìŠµë‹ˆë‹¤.');
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BetaOverviewChip(
                                label: 'ê°€ìž…ìž',
                                value: '${patientDocs.length}ëª…',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: 'ì—°ë½ì²˜ ì™„ì„±',
                                value:
                                    '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}ëª…',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: 'ì œì¶œ ì™„ë£Œ',
                                value:
                                    '${patientDocs.where((doc) => (submissionsByPatient[doc.id] ?? const []).isNotEmpty).length}ëª…',
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
                                            ? 'ì—°ë½ì²˜ ì¤€ë¹„ë¨'
                                            : 'í•„ìˆ˜ ì •ë³´ ë¶€ì¡±',
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
                                      ? 'ì—°ë½ì²˜ ì—†ìŒ'
                                      : '${phone.isEmpty ? 'ì „í™”ë²ˆí˜¸ ì—†ìŒ' : phone} Â· ${email.isEmpty ? 'ì´ë©”ì¼ ì—†ìŒ' : email}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${birthYear?.toString() ?? 'ì¶œìƒì—°ë„ ë¯¸ìž…ë ¥'} Â· ${sex.isEmpty ? 'ì„±ë³„ ë¯¸ìž…ë ¥' : sex} Â· ${ethnicity.isEmpty ? 'ì¸ì¢…/ë¯¼ì¡± ë¯¸ìž…ë ¥' : ethnicity}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusTag(
                                      label: submissions.isEmpty
                                          ? 'ì•„ì§ ì œì¶œ ì—†ìŒ'
                                          : 'ì œì¶œ ${submissions.length}íšŒ',
                                      color: submissions.isEmpty
                                          ? const Color(0xFFF6E9C9)
                                          : const Color(0xFFDDF0E8),
                                    ),
                                    _StatusTag(
                                      label:
                                          'ê°€ìž…: ${_formatDateTime(createdAt)}',
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    _StatusTag(
                                      label:
                                          'í”„ë¡œí•„ ìˆ˜ì •: ${_formatDateTime(updatedAt)}',
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    if (latestSubmissionAt != null)
                                      _StatusTag(
                                        label:
                                            'ìµœê·¼ ì œì¶œ: ${_formatDateTime(latestSubmissionAt)}',
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
      return 'ê¸°ë¡ ì—†ìŒ';
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
      title: Text(AppLanguageController.instance.tr('Practitioner Dashboard', '침술사 대시보드')),
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
                        sex: 'ì—¬ì„±',
                        ethnicity: 'Unknown',
                        memo: '',
                      );
                      _store.saveProfile(newProfile);
                      setState(() => _selectedProfileId = newProfile.id);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(AppLanguageController.instance.tr('Patient Management', '환자 정보 관리')),
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
                                    child: const Text(
                                      '?? ?? ??',
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
                                  ? '${profile.phone} ? ${profile.email}'
                                  : '??: ${missingFields.join(', ')}',
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
                  ? const Center(child: Text('ê´€ë¦¬í•  í™˜ìžë¥¼ ì„ íƒí•˜ì„¸ìš”.'))
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
              const LanguageMenuButton(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ë‹«ê¸°'),
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
          const Text(
            'ë“±ë¡ëœ í™˜ìž ì •ë³´ê°€ ìžˆì–´ì•¼ ëŒ€ì‹œë³´ë“œì™€ ë‹µë³€ ìš”ì²­ì—ì„œ ì‚¬ìš©ë©ë‹ˆë‹¤.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ì´ë¦„',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'ì „í™”ë²ˆí˜¸',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'ì´ë©”ì¼',
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
                  decoration: const InputDecoration(
                    labelText: 'ì¶œìƒì—°ë„',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sexController,
                  decoration: const InputDecoration(
                    labelText: 'ì„±ë³„',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ethnicityController,
                  decoration: const InputDecoration(
                    labelText: 'ì¸ì¢…/ë¯¼ì¡±',
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
            decoration: const InputDecoration(
              labelText: 'ê´€ë¦¬ ë©”ëª¨',
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
                const SnackBar(content: Text('í™˜ìž ì •ë³´ ì €ìž¥ ì™„ë£Œ')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(AppLanguageController.instance.tr('Patient Management', '?? ?? ??')),
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



