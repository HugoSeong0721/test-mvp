import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
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

  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _patientFilterController =
      TextEditingController();

  late String _selectedDate;
  String _selectedPatientFilter = '전체 환자';
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
        final dropdownFiltered = _selectedPatientFilter == '전체 환자'
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
            title: const Text('침술사 대시보드'),
            actions: [
              TextButton.icon(
                onPressed: () => _openPatientManagement(context),
                icon: const Icon(Icons.people_outline),
                label: const Text('환자 정보 관리'),
              ),
              IconButton(
                tooltip: '유사증상 추세 보기',
                onPressed: () =>
                    Navigator.pushNamed(context, SymptomTrendScreen.routeName),
                icon: const Icon(Icons.insights_outlined),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(child: Chip(label: Text('침술사 화면'))),
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
                          ? '$_selectedDate 환자 ${filteredVisits.length}명'
                          : '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} 환자 ${filteredVisits.length}명',
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
                              _selectedPatientFilter == '전체 환자'
                          ? _selectedPatientFilter
                          : '전체 환자',
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
                          value: '전체 환자',
                          child: Text('전체 환자'),
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
                  hintText: '환자 이름 직접 검색',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedDateRange == null
                    ? '총 내원 집계: ${summary.periodLabel}'
                    : '선택 기간 집계: ${summary.periodLabel}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (filteredVisits.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('선택한 조건에 맞는 환자가 없습니다.'),
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
              '현황표 (침술사 인사이트)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniKpi(
                  title: '총 내원 (${summary.days}일)',
                  value: '${summary.totalVisits}명',
                ),
                _MiniKpi(title: '등록 환자', value: '${profiles.length}명'),
                _MiniKpi(
                  title: '알림 가능',
                  value:
                      '${profiles.where((p) => p.hasRequiredAlertInfo).length}명',
                ),
                const _MiniKpi(title: '재내원율', value: '63%'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '집계 기간: ${summary.fromDate} ~ ${summary.toDate}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text(
              '성별 구성: ${sexCounts.entries.map((e) => '${e.key} ${e.value}명').join(' · ')}',
            ),
            const SizedBox(height: 8),
            const Text(
              '증상 추세 Top3',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('1) 수면/새벽 각성  2) 목/어깨 통증  3) 소화 불편'),
            const SizedBox(height: 8),
            const Text('자주 준 조언: 취침 전 스트레칭 · 카페인 시간 조절 · 식후 10분 걷기'),
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
              '날짜별 환자 보기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text('기간 선택', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  label: const Text('기간 선택'),
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
                  label: Text('$date  $count명'),
                  onSelected: (_) {
                    setState(() {
                      _selectedDate = date;
                      _selectedDateRange = null;
                      _selectedPatientFilter = '전체 환자';
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
                  label: const Text('날짜 선택'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDateRange == null
                        ? '선택 날짜: ${_formatDate(selectedDate)}'
                        : '선택 기간: ${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)}',
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
      label: Text('최근 $days일'),
      onSelected: (_) {
        setState(() {
          _selectedRangeDays = days;
          _selectedDateRange = null;
          _selectedPatientFilter = '전체 환자';
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
              '다가오는 환자 보드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...upcoming.map((scheduledVisit) {
              final profile = scheduledVisit.profile;
              final visit = scheduledVisit.visit;
              final preview = visit.qaList.isEmpty
                  ? '문진 미작성'
                  : '${visit.qaList.first.question} / ${visit.qaList.first.answer}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${visit.date} · ${visit.time} · ${profile.name}'),
                subtitle: Text(
                  '$preview\n연락처: ${profile.phone.isEmpty ? '미입력' : profile.phone}',
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
        ? '문진 미제출 - 세션 전 직접 확인 필요'
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
                      Text('지난 방문: ${visit.lastVisitDate} (${visit.daysAgo}일 전)'),
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
                        '연락처: ${profile.phone.isEmpty ? '미입력' : profile.phone} / ${profile.email.isEmpty ? '이메일 미입력' : profile.email}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '환자 정보: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
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
                  label: Text(canSendRequest ? '답변 요청' : '연락처 필요'),
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
                  label: const Text('상세 보기'),
                ),
              ],
            ),
            if (!canSendRequest) ...[
              const SizedBox(height: 8),
              const Text(
                '환자 정보 관리에서 전화번호와 이메일을 모두 입력해야 답변 요청 전송이 가능합니다.',
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
            '${_formatDate(_selectedDateRange!.start)} ~ ${_formatDate(_selectedDateRange!.end)} ${visits.length}명',
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
      periodLabel: '${_formatDate(start)} ~ ${_formatDate(selected)} ${visits.length}명',
    );
  }

  String _visitTrailLabel(PatientVisit visit) {
    if (visit.scheduledSinceLast == 0 && visit.noShowSinceLast == 0) {
      return '지난 방문 이후 추가 예약 없음 -> 이번 방문이 첫 재내원';
    }
    return '지난 방문 이후 추가 예약 ${visit.scheduledSinceLast}건, 노쇼 ${visit.noShowSinceLast}건';
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
          title: Text('${profile.name}님 답변 요청'),
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
                          '전송 대상 연락처: ${profile.phone.isEmpty ? '전화번호 없음' : profile.phone}${profile.email.isEmpty ? ' / 이메일 없음' : ' / ${profile.email}'}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '요청할 질문 선택',
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
                                        title: Text('${entry.key} 직접 질문 입력'),
                                        content: TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            hintText:
                                                '예: 특정 상황에서 증상이 더 심해지나요?',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
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
                          labelText: '노트 (환자에게 전달할 말)',
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
              child: const Text('취소'),
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
                            content: Text('질문을 1개 이상 선택하거나 직접 추가해주세요.'),
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
                            content: Text('${profile.name}님 답변 요청 저장 완료: $docId'),
                          ),
                        );
                      } catch (error) {
                        if (!mounted || !dialogContext.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('답변 요청 저장 실패: $error')),
                        );
                      }
                    },
              child: const Text('전송'),
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
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = _formatDate(picked);
      _selectedDateRange = null;
      _selectedPatientFilter = '전체 환자';
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
              title: const Text('기간 선택'),
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
                          helpText: '시작일 선택',
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
                      child: Text('시작일: ${_formatDate(start)}'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: end,
                          firstDate: DateTime(2020, 1, 1),
                          lastDate: DateTime(now.year + 10, now.month, now.day),
                          helpText: '종료일 선택',
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
                      child: Text('종료일: ${_formatDate(end)}'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선택 범위: ${_formatDate(start)} ~ ${_formatDate(end)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = _formatDate(end);
                      _selectedDateRange = DateTimeRange(start: start, end: end);
                      _selectedRangeDays = end.difference(start).inDays + 1;
                      _selectedPatientFilter = '전체 환자';
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('적용'),
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
                '실시간 활동을 불러오지 못했습니다.',
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
                    '실시간 앱 활동',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (latestRequest == null)
                    const Text('최근 답변 요청 없음')
                  else
                    Text(
                      '최근 답변 요청: ${selectedQuestions.length}개 질문 · ${_formatDateTime(requestAt)}',
                    ),
                  const SizedBox(height: 4),
                  if (latestSubmission == null)
                    const Text('최근 제출 없음')
                  else
                    Text(
                      '최근 환자 제출: ${answers.length}개 답변 · ${_formatDateTime(submissionAt)}',
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
      return '방금 전';
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
              '지인 베타 제출함',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '이메일/비밀번호로 가입한 지인들의 최근 제출을 확인합니다.',
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
                    '베타 제출함을 불러오지 못했습니다.',
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
                  return const Text('아직 베타 가입자의 제출이 없습니다.');
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
                        '${visitType == 'initial' ? '초진' : '재진'} · 답변 $answers개 · ${_formatDateTime(submittedAt)}',
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
      return '방금 전';
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
              '지인 베타 가입자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '회원가입만 한 사람, 연락처가 빠진 사람, 이미 제출까지 한 사람을 여기서 바로 확인합니다.',
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
                    '베타 가입자 목록을 불러오지 못했습니다.',
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
                        '베타 제출 데이터를 불러오지 못했습니다.',
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
                      return const Text('아직 가입한 베타 사용자가 없습니다.');
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _BetaOverviewChip(
                                label: '가입자',
                                value: '${patientDocs.length}명',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: '연락처 완성',
                                value:
                                    '${patientDocs.where((doc) => _hasRequiredInfo(doc.data())).length}명',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _BetaOverviewChip(
                                label: '제출 완료',
                                value:
                                    '${patientDocs.where((doc) => (submissionsByPatient[doc.id] ?? const []).isNotEmpty).length}명',
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
                                            ? '연락처 준비됨'
                                            : '필수 정보 부족',
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
                                      ? '연락처 없음'
                                      : '${phone.isEmpty ? '전화번호 없음' : phone} · ${email.isEmpty ? '이메일 없음' : email}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${birthYear?.toString() ?? '출생연도 미입력'} · ${sex.isEmpty ? '성별 미입력' : sex} · ${ethnicity.isEmpty ? '인종/민족 미입력' : ethnicity}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatusTag(
                                      label: submissions.isEmpty
                                          ? '아직 제출 없음'
                                          : '제출 ${submissions.length}회',
                                      color: submissions.isEmpty
                                          ? const Color(0xFFF6E9C9)
                                          : const Color(0xFFDDF0E8),
                                    ),
                                    _StatusTag(
                                      label:
                                          '가입: ${_formatDateTime(createdAt)}',
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    _StatusTag(
                                      label:
                                          '프로필 수정: ${_formatDateTime(updatedAt)}',
                                      color: const Color(0xFFEAECEF),
                                    ),
                                    if (latestSubmissionAt != null)
                                      _StatusTag(
                                        label:
                                            '최근 제출: ${_formatDateTime(latestSubmissionAt)}',
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
      return '기록 없음';
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
      title: const Text('환자 정보 관리'),
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
                        sex: '여성',
                        ethnicity: 'Unknown',
                        memo: '',
                      );
                      _store.saveProfile(newProfile);
                      setState(() => _selectedProfileId = newProfile.id);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('환자 추가'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final isSelected = selected?.id == profile.id;
                        final missingFields = <String>[
                          if (profile.phone.trim().isEmpty) '????',
                          if (profile.email.trim().isEmpty) '???',
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
                  ? const Center(child: Text('관리할 환자를 선택하세요.'))
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
          child: const Text('닫기'),
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
            '등록된 환자 정보가 있어야 대시보드와 답변 요청에서 사용됩니다.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '이름',
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
                    labelText: '전화번호',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
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
                    labelText: '출생연도',
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
                    labelText: '성별',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ethnicityController,
                  decoration: const InputDecoration(
                    labelText: '인종/민족',
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
              labelText: '관리 메모',
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
                const SnackBar(content: Text('환자 정보 저장 완료')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('환자 정보 저장'),
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
