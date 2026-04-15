import 'package:flutter/material.dart';

import '../../practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';

class PatientBriefScreen extends StatefulWidget {
  const PatientBriefScreen({super.key});

  static const routeName = '/brief';

  @override
  State<PatientBriefScreen> createState() => _PatientBriefScreenState();
}

class _PatientBriefScreenState extends State<PatientBriefScreen> {
  static const List<String> _categoryOrder = [
    'Temperature/Sweat',
    'Appetite/Thirst',
    'Sleep',
    'Digestion',
    'Urine',
    'Stool',
    'Menses',
    'HEENT',
    'Emotion',
    'Energy',
  ];

  final TextEditingController _thisSessionTreatmentAreaController =
      TextEditingController();
  final TextEditingController _thisSessionMemoController = TextEditingController();
  final TextEditingController _nextObservationController = TextEditingController();
  final TextEditingController _adviceGivenController = TextEditingController();
  final TextEditingController _adherenceFollowupController =
      TextEditingController();

  final TextEditingController _patientAlertController = TextEditingController();
  final TextEditingController _weeklyMustDoController = TextEditingController();
  final TextEditingController _currentStatusController = TextEditingController();
  final TextEditingController _actionGuideController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    _adviceGivenController.text = '수면 전 카페인 줄이고, 어깨 스트레칭 5분.';
    _adherenceFollowupController.text = '다음 방문 시 스트레칭 실천 횟수 확인.';
    _patientAlertController.text = '이번 주는 수면/피로 변화가 핵심 관찰 포인트입니다.';
    _weeklyMustDoController.text = '주중 최소 4일, 취침 1시간 전 스트레칭.';
    _currentStatusController.text = '현재는 수면 질 저하와 어깨 긴장이 함께 보입니다.';
    _actionGuideController.text = '무리한 운동보다 강도 낮은 이완 루틴을 우선하세요.';
  }

  @override
  void dispose() {
    _thisSessionTreatmentAreaController.dispose();
    _thisSessionMemoController.dispose();
    _nextObservationController.dispose();
    _adviceGivenController.dispose();
    _adherenceFollowupController.dispose();
    _patientAlertController.dispose();
    _weeklyMustDoController.dispose();
    _currentStatusController.dispose();
    _actionGuideController.dispose();
    super.dispose();
  }

  void _saveMemos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장 완료 (임시): 다음 단계에서 DB 연결 예정')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final historyArgs = arg is PatientHistoryArgs ? arg : null;
    final patient = historyArgs?.current ??
        (arg is PatientItem
            ? arg
            : const PatientItem(
                name: 'Jane Kim',
                time: '3:30 PM',
                lastVisitDate: '2026-04-08',
                daysAgo: 7,
                scheduledSinceLast: 1,
                noShowSinceLast: 0,
                intakeStatus: IntakeStatus.completed,
                previousTreatmentArea: '우측 견갑 주변 + 경추 C5-C7 주변',
                previousSessionNote: '견갑 내측 압통 강함, 새벽 각성 빈도 높음.',
                qaList: [
                  QAItem('Sleep', '최근 수면은 어떠셨나요?', '새벽 3시에 자주 깨고 다시 잠들기 어려워요.'),
                  QAItem('Energy', '오후 피로감은 어떤가요?', '오후 2시 이후 급격히 피곤해져요.'),
                ],
              ));
    final history = historyArgs?.history ??
        <PatientVisitRecord>[
          PatientVisitRecord(visitDate: '2026-04-08', patient: patient),
        ];

    final grouped = _buildGroupedMap(patient.qaList);
    final coveredCount = grouped.values.where((e) => e.isNotEmpty).length;
    final unasked =
        _categoryOrder.where((category) => grouped[category]!.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('환자 상세 브리핑'),
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
          Text(
            '${patient.name} · ${patient.time}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '지난 방문: ${patient.lastVisitDate} (${patient.daysAgo}일 전)',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 방문 기록 (${history.length}회)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((record) {
                    final p = record.patient;
                    final preview = p.qaList.isEmpty
                        ? '문진 기록 없음'
                        : '${p.qaList.first.question} / ${p.qaList.first.answer}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                              '${record.visitDate} · ${p.time}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('치료 부위: ${p.previousTreatmentArea}'),
                            Text('기록: ${p.previousSessionNote}'),
                            Text('요약: $preview'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '카테고리 커버리지: $coveredCount / ${_categoryOrder.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('총 질문 수: ${patient.qaList.length}개'),
                  if (unasked.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '아직 안 물어본 카테고리: ${unasked.join(', ')}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '10 카테고리 문진',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._categoryOrder.map((category) {
            final list = grouped[category]!;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category (${list.length}개 질문)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (list.isEmpty)
                      const Text(
                        '아직 질문 없음',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ...list.asMap().entries.map((entry) {
                      final qa = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('- Q: ${qa.question}'),
                            Text('  A: ${qa.answer}'),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '지난 방문 기록 (비공유)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('지난 치료 부위: ${patient.previousTreatmentArea}'),
                  const SizedBox(height: 6),
                  Text('지난 노트: ${patient.previousSessionNote}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이번 세션 기록 (비공유)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _thisSessionTreatmentAreaController,
                    decoration: const InputDecoration(
                      labelText: '이번 치료 부위',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _thisSessionMemoController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '이번 세션 메모',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nextObservationController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '다음 방문 관찰 포인트 (기대 변화)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adviceGivenController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '내가 준 조언',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adherenceFollowupController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '조언 이행 팔로업 체크',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '공유 메모 (환자에게 보임)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _patientAlertController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '환자 알림',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weeklyMustDoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '주중 꼭 지켜야 할 내용',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _currentStatusController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '지금 상태 설명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _actionGuideController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '어떻게 해야 하는지 안내',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveMemos,
              child: const Text('기록 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<QAItem>> _buildGroupedMap(List<QAItem> list) {
    final map = <String, List<QAItem>>{
      for (final category in _categoryOrder) category: <QAItem>[],
    };
    for (final item in list) {
      if (map.containsKey(item.category)) {
        map[item.category]!.add(item);
      }
    }
    return map;
  }
}
