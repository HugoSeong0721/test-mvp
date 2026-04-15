import 'package:flutter/material.dart';

import '../../patient_brief/presentation/patient_brief_screen.dart';

class PractitionerDashboardScreen extends StatefulWidget {
  const PractitionerDashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  State<PractitionerDashboardScreen> createState() =>
      _PractitionerDashboardScreenState();
}

class _PractitionerDashboardScreenState extends State<PractitionerDashboardScreen> {
  static const Map<String, List<String>> _questionLibraryByCategory = {
    'Temperature/Sweat': [
      '몸이 쉽게 덥거나 춥게 느껴지나요?',
      '식은땀/자한/도한이 있나요?',
    ],
    'Appetite/Thirst': [
      '식욕은 평소와 비교해 어떤가요?',
      '갈증이 잦거나 찬물/따뜻한 물 선호가 있나요?',
    ],
    'Sleep': [
      '잠드는 시간과 깨는 횟수는 어떤가요?',
      '꿈이 많거나 자고 나도 개운하지 않나요?',
    ],
    'Digestion': [
      '식후 더부룩함이나 속쓰림이 있나요?',
      '트림/가스/역류 증상이 있나요?',
    ],
    'Urine': [
      '소변 횟수나 급박뇨 변화가 있나요?',
      '야간뇨가 늘었나요?',
    ],
    'Stool': [
      '배변 주기나 굳기 변화가 있나요?',
      '변비와 설사가 번갈아 나타나나요?',
    ],
    'Menses': [
      '생리 주기/양/통증 변화가 있나요?',
      '혈괴(덩어리)나 색 변화가 있나요?',
    ],
    'HEENT': [
      '두통, 눈피로, 이명, 코막힘 중 불편한 것이 있나요?',
      '목/어깨 긴장과 연관된 증상이 있나요?',
    ],
    'Emotion': [
      '최근 감정 기복이나 예민함이 늘었나요?',
      '스트레스가 몸 증상에 영향을 주나요?',
    ],
    'Energy': [
      '하루 중 언제 가장 피곤한가요?',
      '기운이 갑자기 떨어지는 시간이 있나요?',
    ],
  };

  final List<String> _dates = [
    '2026-04-01',
    '2026-04-08',
    '2026-04-12',
    '2026-04-15',
  ];

  late String _selectedDate;
  String _selectedPatientFilter = '전체 환자';
  final TextEditingController _patientFilterController = TextEditingController();
  int _selectedRangeDays = 7;
  DateTimeRange? _selectedDateRange;

  static final Map<String, List<PatientItem>> _patientsByDate = {
    '2026-04-01': [
      PatientItem(
        name: 'Daniel Cho',
        time: '4:00 PM',
        lastVisitDate: '2026-03-18',
        daysAgo: 14,
        scheduledSinceLast: 1,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.completed,
        previousTreatmentArea: '승모근 상부 + 측두부',
        previousSessionNote: '긴장성 두통 패턴.',
        qaList: const [
          QAItem('HEENT', '두통/눈피로는?', '오후에 눈이 뻑뻑하고 두통이 와요.'),
          QAItem('Emotion', '감정 기복은?', '예민해지고 짜증이 늘었어요.'),
        ],
      ),
      PatientItem(
        name: 'Min Park',
        time: '5:30 PM',
        lastVisitDate: '2026-03-15',
        daysAgo: 17,
        scheduledSinceLast: 2,
        noShowSinceLast: 1,
        intakeStatus: IntakeStatus.notStarted,
        previousTreatmentArea: '요추 주변 + 둔부 트리거포인트',
        previousSessionNote: '장시간 앉을 때 통증 악화.',
        qaList: const [],
      ),
    ],
    '2026-04-08': [
      PatientItem(
        name: 'Jane Kim',
        time: '3:30 PM',
        lastVisitDate: '2026-04-01',
        daysAgo: 7,
        scheduledSinceLast: 1,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.completed,
        previousTreatmentArea: '우측 견갑 주변 + 경추 C5-C7 주변',
        previousSessionNote: '견갑 내측 압통 강함, 새벽 각성 빈도 높음.',
        qaList: const [
          QAItem('Sleep', '최근 수면은 어떠셨나요?', '새벽 3시에 자주 깨고 다시 잠들기 어려워요.'),
          QAItem('Energy', '오후 피로감은 어떤가요?', '오후 2시 이후 급격히 피곤해져요.'),
        ],
      ),
    ],
    '2026-04-12': [
      PatientItem(
        name: 'Hana Yoo',
        time: '5:30 PM',
        lastVisitDate: '2026-04-08',
        daysAgo: 4,
        scheduledSinceLast: 0,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.inProgress,
        previousTreatmentArea: '측두부 + 흉쇄유돌근',
        previousSessionNote: '두통 빈도 추적 중.',
        qaList: const [
          QAItem('Temperature/Sweat', '땀/체온 변화는?', '밤에 식은땀이 가끔 나요.'),
        ],
      ),
    ],
    '2026-04-15': [
      PatientItem(
        name: 'Jane Kim',
        time: '3:30 PM',
        lastVisitDate: '2026-04-08',
        daysAgo: 7,
        scheduledSinceLast: 1,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.completed,
        previousTreatmentArea: '우측 견갑 주변 + 경추 C5-C7 주변',
        previousSessionNote: '견갑 내측 압통 강함, 새벽 각성 빈도 높음.',
        qaList: const [
          QAItem('Sleep', '최근 수면은 어떠셨나요?', '새벽 3시에 자주 깨고 다시 잠들기 어려워요.'),
          QAItem('Energy', '오후 피로감은 어떤가요?', '오후 2시 이후 급격히 피곤해져요.'),
          QAItem('Emotion', '최근 스트레스 정도는?', '업무 스트레스가 높은 편이에요.'),
        ],
      ),
      PatientItem(
        name: 'Min Park',
        time: '4:00 PM',
        lastVisitDate: '2026-03-31',
        daysAgo: 15,
        scheduledSinceLast: 2,
        noShowSinceLast: 1,
        intakeStatus: IntakeStatus.notStarted,
        previousTreatmentArea: '요추 주변 + 둔부 트리거포인트',
        previousSessionNote: '장시간 앉을 때 통증 악화.',
        qaList: const [],
      ),
      PatientItem(
        name: 'Eunji Lee',
        time: '4:30 PM',
        lastVisitDate: '2026-04-10',
        daysAgo: 5,
        scheduledSinceLast: 0,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.inProgress,
        previousTreatmentArea: '복부 + 비위 관련 포인트',
        previousSessionNote: '식후 복부팽만 호소.',
        qaList: const [
          QAItem('Appetite/Thirst', '식욕/갈증은 어떠셨나요?', '입이 자주 마르고 찬물 찾게 돼요.'),
        ],
      ),
      PatientItem(
        name: 'Daniel Cho',
        time: '5:00 PM',
        lastVisitDate: '2026-04-01',
        daysAgo: 14,
        scheduledSinceLast: 3,
        noShowSinceLast: 1,
        intakeStatus: IntakeStatus.completed,
        previousTreatmentArea: '승모근 상부 + 측두부',
        previousSessionNote: '긴장성 두통 패턴.',
        qaList: const [
          QAItem('HEENT', '두통/눈피로는?', '오후에 눈이 뻑뻑하고 두통이 와요.'),
          QAItem('Emotion', '감정 기복은?', '예민해지고 짜증이 늘었어요.'),
        ],
      ),
      PatientItem(
        name: 'Hana Yoo',
        time: '5:30 PM',
        lastVisitDate: '2026-04-12',
        daysAgo: 3,
        scheduledSinceLast: 0,
        noShowSinceLast: 0,
        intakeStatus: IntakeStatus.inProgress,
        previousTreatmentArea: '측두부 + 흉쇄유돌근',
        previousSessionNote: '두통 빈도 추적 중.',
        qaList: const [
          QAItem('Temperature/Sweat', '땀/체온 변화는?', '밤에 식은땀이 가끔 나요.'),
        ],
      ),
      PatientItem(
        name: 'Chris Jung',
        time: '6:00 PM',
        lastVisitDate: '2026-03-20',
        daysAgo: 26,
        scheduledSinceLast: 2,
        noShowSinceLast: 2,
        intakeStatus: IntakeStatus.notStarted,
        previousTreatmentArea: '요추 기립근 + 햄스트링',
        previousSessionNote: '장시간 운전 후 악화.',
        qaList: const [],
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = _dates.last;
  }

  @override
  void dispose() {
    _patientFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _parseDate(_selectedDate);
    final isRangeMode = _selectedDateRange != null;
    final visibleVisits = _collectVisibleVisits();
    final patientNames = <String>{...visibleVisits.map((v) => v.patient.name)}.toList()
      ..sort();
    final keyword = _patientFilterController.text.trim().toLowerCase();
    final filteredPatients = _selectedPatientFilter == '전체 환자'
        ? visibleVisits
        : visibleVisits.where((v) => v.patient.name == _selectedPatientFilter).toList();
    final nameFilteredPatients = keyword.isEmpty
        ? filteredPatients
        : filteredPatients
            .where((v) => v.patient.name.toLowerCase().contains(keyword))
            .toList();
    final visitWindow = _visitWindowSummary();
    return Scaffold(
      appBar: AppBar(
        title: const Text('침술사 대시보드'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(label: Text('침술사 화면')),
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
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: _insightPanel(visitWindow)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 9,
                      child: Column(
                        children: [
                          _dateSelectorPanel(context),
                          const SizedBox(height: 10),
                          _similarSymptomTrendPanel(),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _insightPanel(visitWindow),
                  const SizedBox(height: 10),
                  _dateSelectorPanel(context),
                  const SizedBox(height: 10),
                  _similarSymptomTrendPanel(),
                ],
              );
            },
          ),
          if (visibleVisits.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '선택한 날짜에 등록된 환자가 없습니다.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  isRangeMode && _selectedDateRange != null
                      ? '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} 환자 ${nameFilteredPatients.length}명'
                      : '${selectedDate == null ? _selectedDate : _formatDate(selectedDate)} 환자 ${nameFilteredPatients.length}명',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 220,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPatientFilter,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '전체 환자',
                          child: Text('전체 환자'),
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
                        setState(() => _selectedPatientFilter = value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _patientFilterController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _patientFilterController.clear();
                        }),
                      ),
                hintText: '환자 이름 직접 검색',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '총 내원 집계: ${visitWindow.periodLabel}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ...nameFilteredPatients.map(
            (visit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _patientCard(context, visit),
            ),
          ),
          if (nameFilteredPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                '선택한 환자 필터에 해당하는 내역이 없습니다.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _patientCard(BuildContext context, _PatientVisitItem visit) {
    final patient = visit.patient;
    final preview = patient.qaList.isEmpty
        ? '문진 미제출 - 세션 전 직접 확인 필요'
        : '${patient.qaList.first.question} / ${patient.qaList.first.answer}';
    final appointmentStatus = _buildAppointmentStatus(patient);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${patient.name} · ${visit.date} ${patient.time}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                _responseRateBadge(patient.intakeStatus),
              ],
            ),
            const SizedBox(height: 8),
            Text(preview),
            const SizedBox(height: 4),
            Text(
              '지난 방문: ${patient.lastVisitDate} (${patient.daysAgo}일 전)',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              appointmentStatus,
              style: TextStyle(
                fontSize: 12,
                color: patient.noShowSinceLast > 0 ? Colors.redAccent : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _sendReminder(context, patient),
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('답변 요청'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    final history = _buildPatientHistory(patient.name);
                    Navigator.pushNamed(
                      context,
                      PatientBriefScreen.routeName,
                      arguments: PatientHistoryArgs(
                        current: patient,
                        history: history,
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('상세 보기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightPanel(_VisitWindowSummary visitWindow) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현황표 (침술사 인사이트)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniKpi(
                  title: '총 내원 (${visitWindow.days}일)',
                  value: '${visitWindow.totalVisits}명',
                ),
                const _MiniKpi(title: '재내원율', value: '63%'),
                const _MiniKpi(title: '문진 응답률', value: '71%'),
                const _MiniKpi(title: '노쇼율', value: '9%'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '집계 기간: ${visitWindow.fromDate} ~ ${visitWindow.toDate}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Text('증상 추세 Top3', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('1) 수면/새벽 각성  2) 목/어깨 통증  3) 소화 불편'),
            const SizedBox(height: 6),
            const Text(
              '자주 준 조언: 취침 전 스트레칭 · 카페인 시간 조절 · 식후 10분 걷기',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSelectorPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '날짜별 환자 보기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('기간 선택', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [7, 14, 30].map((days) {
                final selected = _selectedRangeDays == days;
                return ChoiceChip(
                  label: Text('최근 $days일'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedRangeDays = days),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dates.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final date = _dates[index];
                        final selected = date == _selectedDate;
                        final count = (_patientsByDate[date] ?? const <PatientItem>[]).length;
                        return ChoiceChip(
                          label: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(text: date),
                                TextSpan(
                                  text: '  $count명',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _selectedDate = date;
                            _selectedDateRange = null;
                            _selectedPatientFilter = '전체 환자';
                          }),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '달력에서 날짜 선택',
                  onPressed: _pickDateFromCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: _pickDateRangeFromCalendar,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: const Text('기간 선택'),
                ),
              ],
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(height: 6),
              Text(
                '선택 기간: ${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              '날짜를 클릭하면 아래에 해당 날짜 환자 정보가 표시됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseRateBadge(IntakeStatus status) {
    final rate = _responseRate(status);
    final label = rate == 100 ? '사전문진 응답률 100%' : '사전문진 응답률 $rate%';
    return Chip(label: Text(label));
  }

  int _responseRate(IntakeStatus status) {
    switch (status) {
      case IntakeStatus.notStarted:
        return 0;
      case IntakeStatus.inProgress:
        return 50;
      case IntakeStatus.completed:
        return 100;
    }
  }

  Widget _similarSymptomTrendPanel() {
    final weekly = _weeklySymptomTrend();
    final selected = _parseDate(_selectedDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '유사증상 주별 추세',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '최근 4주 기준 (선택일 ${selected == null ? '-' : _formatDate(selected)} / 기간 반영)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            ...weekly.entries.map((entry) {
              final values = entry.value;
              final rowMax = values.fold<int>(1, (m, v) => v > m ? v : m).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 3),
                    Row(
                      children: values.map((v) {
                        final ratio = rowMax == 0 ? 0.0 : v / rowMax;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Column(
                              children: [
                                Container(
                                  height: 14 * ratio + 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text('$v', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 2),
            const Text(
              'W-3   W-2   W-1   이번주',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<int>> _weeklySymptomTrend() {
    final selected = _parseDate(_selectedDate);
    if (selected == null) {
      return {
        '수면/각성': [0, 0, 0, 0],
        '목/어깨 통증': [0, 0, 0, 0],
        '소화 불편': [0, 0, 0, 0],
      };
    }

    final periodStart = DateTime(
      selected.year,
      selected.month,
      selected.day,
    ).subtract(Duration(days: _selectedRangeDays - 1));

    final sleepTrend = <int>[];
    final neckTrend = <int>[];
    final digestionTrend = <int>[];

    for (var week = 3; week >= 0; week--) {
      final weekEnd = DateTime(
        selected.year,
        selected.month,
        selected.day,
      ).subtract(Duration(days: 7 * week));
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      var sleep = 0;
      var neck = 0;
      var digestion = 0;

      for (final entry in _patientsByDate.entries) {
        final visitDate = _parseDate(entry.key);
        if (visitDate == null) {
          continue;
        }
        final normalized = DateTime(visitDate.year, visitDate.month, visitDate.day);
        final inSelectedPeriod =
            !normalized.isBefore(periodStart) &&
            !normalized.isAfter(DateTime(selected.year, selected.month, selected.day));
        final inWeek = !normalized.isBefore(weekStart) && !normalized.isAfter(weekEnd);
        if (!inSelectedPeriod || !inWeek) {
          continue;
        }

        for (final patient in entry.value) {
          for (final qa in patient.qaList) {
            if (qa.category == 'Sleep' || qa.category == 'Energy') {
              sleep++;
            }
            if (qa.category == 'Appetite/Thirst' ||
                qa.category == 'Digestion' ||
                qa.category == 'Stool') {
              digestion++;
            }
            if (qa.category == 'HEENT' ||
                qa.question.contains('어깨') ||
                qa.answer.contains('어깨') ||
                qa.question.contains('목') ||
                qa.answer.contains('목')) {
              neck++;
            }
          }

          if (patient.previousTreatmentArea.contains('어깨') ||
              patient.previousTreatmentArea.contains('목')) {
            neck++;
          }
        }
      }

      sleepTrend.add(sleep);
      neckTrend.add(neck);
      digestionTrend.add(digestion);
    }

    return {
      '수면/각성': sleepTrend,
      '목/어깨 통증': neckTrend,
      '소화 불편': digestionTrend,
    };
  }

  String _buildAppointmentStatus(PatientItem patient) {
    if (patient.scheduledSinceLast == 0) {
      return '지난 방문 이후 추가 예약 없음 -> 이번 방문이 첫 재내원';
    }
    if (patient.noShowSinceLast == 0) {
      return '지난 방문 이후 추가 예약 ${patient.scheduledSinceLast}건, 모두 내원';
    }
    return '지난 방문 이후 추가 예약 ${patient.scheduledSinceLast}건, 노쇼 ${patient.noShowSinceLast}건';
  }

  List<PatientVisitRecord> _buildPatientHistory(String name) {
    final list = <PatientVisitRecord>[];
    for (final entry in _patientsByDate.entries) {
      for (final p in entry.value) {
        if (p.name == name) {
          list.add(
            PatientVisitRecord(
              visitDate: entry.key,
              patient: p,
            ),
          );
        }
      }
    }
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return list;
  }

  List<_PatientVisitItem> _collectVisibleVisits() {
    if (_selectedDateRange == null) {
      final list = (_patientsByDate[_selectedDate] ?? const <PatientItem>[])
          .map((patient) => _PatientVisitItem(date: _selectedDate, patient: patient))
          .toList();
      list.sort((a, b) => a.patient.time.compareTo(b.patient.time));
      return list;
    }

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

    final visits = <_PatientVisitItem>[];
    for (final entry in _patientsByDate.entries) {
      final date = _parseDate(entry.key);
      if (date == null) {
        continue;
      }
      final normalized = DateTime(date.year, date.month, date.day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        visits.addAll(
          entry.value.map((patient) => _PatientVisitItem(date: entry.key, patient: patient)),
        );
      }
    }

    visits.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) {
        return byDate;
      }
      return a.patient.time.compareTo(b.patient.time);
    });
    return visits;
  }

  void _sendReminder(BuildContext context, PatientItem patient) {
    final selectedQuestions = <String>{};
    final noteController = TextEditingController();
    final customQuestionsByCategory = <String, List<String>>{};
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${patient.name}님 답변 요청'),
          content: SizedBox(
            width: 520,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '요청할 질문 선택',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._questionLibraryByCategory.entries.map((entry) {
                        return ExpansionTile(
                          dense: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
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
                                        title: Text('${entry.key} 직접 질문 입력'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            hintText: '예: 특정 상황에서 증상이 더 심해지나요?',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('취소'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              controller.text.trim(),
                                            ),
                                            child: const Text('추가'),
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
                                label: const Text('직접 입력하기'),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 10),
                      if (customQuestionsByCategory.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...customQuestionsByCategory.entries.map((entry) {
                          final category = entry.key;
                          final questions = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(label: Text(category)),
                                ...questions.map(
                                  (q) => Chip(
                                    label: Text(q),
                                    onDeleted: () {
                                      setDialogState(() {
                                        questions.remove(q);
                                        if (questions.isEmpty) {
                                          customQuestionsByCategory.remove(category);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '노트 (환자에게 전달할 말)',
                          hintText: '예: 이번 주에는 수면/소화 질문을 우선 답변 부탁드립니다.',
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
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final customCount = customQuestionsByCategory.values
                    .fold<int>(0, (sum, list) => sum + list.length);
                if (selectedQuestions.isEmpty && customCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('질문을 1개 이상 선택하거나 직접 추가해주세요.')),
                  );
                  return;
                }
                final questionSummary = selectedQuestions.join(' / ');
                final note = noteController.text.trim();
                final customSummary = customQuestionsByCategory.entries
                    .map((entry) => '[${entry.key}] ${entry.value.join(' / ')}')
                    .join(' | ');
                noteController.dispose();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      note.isEmpty
                          ? '${patient.name}님께 질문 전송 완료 (${[
                              if (questionSummary.isNotEmpty) questionSummary,
                              if (customSummary.isNotEmpty) customSummary,
                            ].join(' | ')})'
                          : '${patient.name}님께 질문+노트 전송 완료',
                    ),
                  ),
                );
              },
              child: const Text('전송'),
            ),
          ],
        );
      },
    );
  }

  _VisitWindowSummary _visitWindowSummary() {
    if (_selectedDateRange != null) {
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
      final totalVisits = _countVisitsInWindow(start, end);
      final days = end.difference(start).inDays + 1;
      return _VisitWindowSummary(
        days: days,
        totalVisits: totalVisits,
        fromDate: _formatDate(start),
        toDate: _formatDate(end),
        periodLabel:
            '선택 기간 (${_formatDate(start)} ~ ${_formatDate(end)}) $totalVisits명',
      );
    }

    final selected = _parseDate(_selectedDate);
    if (selected == null) {
      return _VisitWindowSummary(
        days: _selectedRangeDays,
        totalVisits: 0,
        fromDate: '-',
        toDate: '-',
        periodLabel: '지난 $_selectedRangeDays일 데이터 없음',
      );
    }

    final start = selected.subtract(Duration(days: _selectedRangeDays - 1));
    final windowStart = DateTime(start.year, start.month, start.day);
    final windowEnd = DateTime(selected.year, selected.month, selected.day);
    final totalVisits = _countVisitsInWindow(windowStart, windowEnd);

    return _VisitWindowSummary(
      days: _selectedRangeDays,
      totalVisits: totalVisits,
      fromDate: _formatDate(windowStart),
      toDate: _formatDate(windowEnd),
      periodLabel:
          '지난 $_selectedRangeDays일 (${_formatDate(windowStart)} ~ ${_formatDate(windowEnd)}) $totalVisits명',
    );
  }

  int _countVisitsInWindow(DateTime start, DateTime end) {
    var totalVisits = 0;
    for (final entry in _patientsByDate.entries) {
      final date = _parseDate(entry.key);
      if (date == null) {
        continue;
      }
      final normalized = DateTime(date.year, date.month, date.day);
      if (!normalized.isBefore(start) && !normalized.isAfter(end)) {
        totalVisits += entry.value.length;
      }
    }
    return totalVisits;
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final currentDate = _parseDate(_selectedDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 10, now.month, now.day),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) {
      return;
    }

    final selected = _formatDate(picked);
    setState(() {
      if (!_dates.contains(selected)) {
        _dates.add(selected);
        _dates.sort();
      }
      _selectedDate = selected;
      _selectedDateRange = null;
      _selectedPatientFilter = '전체 환자';
    });
  }

  Future<void> _pickDateRangeFromCalendar() async {
    final now = DateTime.now();
    final selected = _parseDate(_selectedDate) ?? now;
    final initialStart = selected.subtract(Duration(days: _selectedRangeDays - 1));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 10, now.month, now.day),
      initialDateRange: DateTimeRange(start: initialStart, end: selected),
      helpText: '기간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) {
      return;
    }

    final endDateString = _formatDate(picked.end);
    setState(() {
      if (!_dates.contains(endDateString)) {
        _dates.add(endDateString);
        _dates.sort();
      }
      _selectedDate = endDateString;
      _selectedDateRange = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      _selectedRangeDays = picked.end.difference(picked.start).inDays + 1;
      _selectedPatientFilter = '전체 환자';
    });
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

class _PatientVisitItem {
  const _PatientVisitItem({
    required this.date,
    required this.patient,
  });

  final String date;
  final PatientItem patient;
}

class PatientHistoryArgs {
  const PatientHistoryArgs({
    required this.current,
    required this.history,
  });

  final PatientItem current;
  final List<PatientVisitRecord> history;
}

class PatientVisitRecord {
  const PatientVisitRecord({
    required this.visitDate,
    required this.patient,
  });

  final String visitDate;
  final PatientItem patient;
}

class PatientItem {
  const PatientItem({
    required this.name,
    required this.time,
    required this.lastVisitDate,
    required this.daysAgo,
    required this.scheduledSinceLast,
    required this.noShowSinceLast,
    required this.intakeStatus,
    required this.previousTreatmentArea,
    required this.previousSessionNote,
    required this.qaList,
  });

  final String name;
  final String time;
  final String lastVisitDate;
  final int daysAgo;
  final int scheduledSinceLast;
  final int noShowSinceLast;
  final IntakeStatus intakeStatus;
  final String previousTreatmentArea;
  final String previousSessionNote;
  final List<QAItem> qaList;
}

class QAItem {
  const QAItem(this.category, this.question, this.answer);

  final String category;
  final String question;
  final String answer;
}

enum IntakeStatus { notStarted, inProgress, completed }

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
