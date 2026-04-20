import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';

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
  final TextEditingController _thisSessionMemoController =
      TextEditingController();
  final TextEditingController _nextObservationController =
      TextEditingController();
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

    if (historyArgs == null) {
      return const Scaffold(
        body: Center(child: Text('환자 기록을 불러오지 못했습니다.')),
      );
    }

    final current = historyArgs.current;
    final patient = current.profile;
    final visit = current.visit;
    final history = historyArgs.history;
    final grouped = _buildGroupedMap(visit.qaList);
    final coveredCount = grouped.values.where((items) => items.isNotEmpty).length;
    final unasked =
        _categoryOrder.where((category) => grouped[category]!.isEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('환자 상세 브리핑'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('침술사 화면'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${patient.name} · ${visit.time}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '지난 방문: ${visit.lastVisitDate} (${visit.daysAgo}일 전)',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            '환자 정보: ${patient.sex}, ${patient.ageRange}, ${patient.ethnicity}',
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
                  ...history.map((item) {
                    final preview = item.visit.qaList.isEmpty
                        ? '문진 기록 없음'
                        : '${item.visit.qaList.first.question} / ${item.visit.qaList.first.answer}';
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
                              '${item.visit.date} · ${item.visit.time}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('치료 부위: ${item.visit.previousTreatmentArea}'),
                            Text('기록: ${item.visit.previousSessionNote}'),
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
                  Text('총 질문 수: ${visit.qaList.length}개'),
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
                    ...list.map(
                      (qa) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('- Q: ${qa.question}'),
                            Text('  A: ${qa.answer}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          _buildMemoCard(
            title: '지난 방문 기록 (비공유)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지난 치료 부위: ${visit.previousTreatmentArea}'),
                const SizedBox(height: 6),
                Text('지난 노트: ${visit.previousSessionNote}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: '이번 방문 메모',
            child: Column(
              children: [
                TextField(
                  controller: _thisSessionTreatmentAreaController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '이번 치료 부위',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _thisSessionMemoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '이번 세션 메모',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nextObservationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '다음 방문 때 관찰할 것',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: '조언 / 팔로업',
            child: Column(
              children: [
                TextField(
                  controller: _adviceGivenController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '이번에 준 조언',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adherenceFollowupController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '다음 방문에서 확인할 이행 사항',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildMemoCard(
            title: '공유 메모 (환자에게 보임)',
            child: Column(
              children: [
                TextField(
                  controller: _patientAlertController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '환자 알림',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weeklyMustDoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '이번 주 꼭 지켜줬으면 하는 것',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentStatusController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '지금 상태 안내',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _actionGuideController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '어떻게 해야 하는지 안내',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saveMemos,
            icon: const Icon(Icons.save_outlined),
            label: const Text('메모 저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Map<String, List<QaItem>> _buildGroupedMap(List<QaItem> qaList) {
    final grouped = {
      for (final category in _categoryOrder) category: <QaItem>[],
    };
    for (final qa in qaList) {
      grouped.putIfAbsent(qa.category, () => <QaItem>[]).add(qa);
    }
    return grouped;
  }
}
