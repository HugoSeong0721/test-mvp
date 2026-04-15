import 'package:flutter/material.dart';

class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({super.key});

  static const routeName = '/intake';

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen> {
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _extraMemoController = TextEditingController();

  final List<String> _questions = const [
    '최근 수면은 어떠셨나요?',
    '오늘 가장 불편한 부위는 어디인가요?',
    '식욕/갈증은 어떤 변화가 있었나요?',
    '소화(더부룩함/속쓰림/역류)는 어떠셨나요?',
    '소변 횟수/야간뇨 변화가 있었나요?',
    '배변(변비/설사/형태) 변화가 있었나요?',
    '땀/체온 변화(더위/추위 민감도)는 어땠나요?',
    '두통/눈피로/코막힘 등 HEENT 증상이 있었나요?',
    '감정 기복/스트레스 수준은 어땠나요?',
    '하루 중 피로가 심해지는 시간은 언제인가요?',
  ];

  final Map<int, String> _answers = {
    0: '새벽 3시에 자주 깨고 다시 잠들기 어려워요.',
    1: '오른쪽 어깨 통증이 가장 심해요.',
    2: '입이 자주 마르고 찬물을 찾게 돼요.',
  };

  int _currentQuestionIndex = 2;

  bool _stretchingDone = false;
  bool _caffeineDone = false;
  bool _sleepLogDone = true;
  int? _mainPainQuestionIndex;
  int? _rememberQuestionIndex;

  static const List<_VisitHistoryItem> _visitHistory = [
    _VisitHistoryItem(
      date: '2026-04-08',
      summary: '우측 어깨, 목 긴장 완화 치료',
      advice: '취침 전 스트레칭, 카페인 조절',
    ),
    _VisitHistoryItem(
      date: '2026-04-01',
      summary: '견갑 내측 압통/수면 질 저하 상담',
      advice: '수면 기록 시작, 야간 각성 체크',
    ),
    _VisitHistoryItem(
      date: '2026-03-24',
      summary: '피로/두통 패턴 점검',
      advice: '오후 피로 시간대 메모',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _answerController.text = _answers[_currentQuestionIndex] ?? '';
  }

  @override
  void dispose() {
    _answerController.dispose();
    _extraMemoController.dispose();
    super.dispose();
  }

  void _saveCurrentAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _answers.remove(_currentQuestionIndex);
      return;
    }
    _answers[_currentQuestionIndex] = text;
  }

  void _moveQuestion(int direction) {
    _saveCurrentAnswer();
    final nextIndex = (_currentQuestionIndex + direction).clamp(0, _questions.length - 1);
    if (nextIndex == _currentQuestionIndex) {
      return;
    }
    setState(() {
      _currentQuestionIndex = nextIndex;
      _answerController.text = _answers[_currentQuestionIndex] ?? '';
    });
  }

  String _thisWeekRangeLabel() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return '${_formatDate(start)} ~ ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _adherencePercent() {
    var done = 0;
    if (_stretchingDone) done++;
    if (_caffeineDone) done++;
    if (_sleepLogDone) done++;
    return ((done / 3) * 100).round();
  }

  void _openVisitHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '전체 방문 히스토리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._visitHistory.map((item) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.date, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('기록: ${item.summary}'),
                      const SizedBox(height: 4),
                      Text('조언: ${item.advice}'),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _questions.length;
    final answeredQuestions = _answers.length;
    final remaining = totalQuestions - answeredQuestions;
    final progress = answeredQuestions / totalQuestions;
    final adherence = _adherencePercent();

    return Scaffold(
      appBar: AppBar(
        title: const Text('환자 사전 문진'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '계정 메뉴',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value 선택')),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Profile', child: Text('Profile')),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'Log out', child: Text('Log out')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('환자 화면'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '지난 방문 요약',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('지난 방문일: 2026-04-08 (7일 전)'),
                  const SizedBox(height: 6),
                  const Text('그날 치료/기록: 우측 어깨, 목 주변 긴장 완화 치료 진행'),
                  const SizedBox(height: 6),
                  const Text('침술사 코멘트: 새벽 각성과 어깨 통증이 같이 나타나는 패턴 관찰'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openVisitHistorySheet,
                    icon: const Icon(Icons.history_outlined, size: 18),
                    label: const Text('전체 히스토리 보기'),
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
                  Text(
                    '침술사 조언 / 이번 주 해야할 것 (${_thisWeekRangeLabel()})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('1) 취침 1시간 전 스트레칭 5분'),
                  const Text('2) 오후 2시 이후 카페인 줄이기'),
                  const Text('3) 수면/피로 변화 간단 기록'),
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
                  Text(
                    '내가 지킨 항목 체크 ($adherence%)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: adherence / 100),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('취침 전 스트레칭'),
                    value: _stretchingDone,
                    onChanged: (value) => setState(() => _stretchingDone = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('오후 카페인 조절'),
                    value: _caffeineDone,
                    onChanged: (value) => setState(() => _caffeineDone = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('수면/피로 기록 작성'),
                    value: _sleepLogDone,
                    onChanged: (value) => setState(() => _sleepLogDone = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '문진 진행 상태',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('진행률 $answeredQuestions/$totalQuestions · 남은 질문 $remaining개'),
          const SizedBox(height: 4),
          Text(
            answeredQuestions >= 7
                ? '좋아요, 거의 다 왔어요. 조금만 더 입력하면 돼요.'
                : '천천히 괜찮아요. 지금처럼 하나씩만 답해도 충분해요.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '현재 질문 (${_currentQuestionIndex + 1}/$totalQuestions): ${_questions[_currentQuestionIndex]}',
                        ),
                      ),
                      if (_mainPainQuestionIndex == _currentQuestionIndex)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.local_fire_department, color: Colors.orange),
                        ),
                      if (_rememberQuestionIndex == _currentQuestionIndex)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin, color: Colors.indigo),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _answerController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '답변을 입력해주세요.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraMemoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '추가 메모 (침술사에게 전달)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _currentQuestionIndex == 0 ? null : () => _moveQuestion(-1),
                        child: const Text('이전 질문'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _currentQuestionIndex == totalQuestions - 1
                            ? null
                            : () => _moveQuestion(1),
                        child: const Text('다음 질문'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _mainPainQuestionIndex = _mainPainQuestionIndex == _currentQuestionIndex
                      ? null
                      : _currentQuestionIndex;
                }),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _mainPainQuestionIndex == _currentQuestionIndex
                      ? const Color(0x1A0F766E)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mainPainQuestionIndex == _currentQuestionIndex)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.local_fire_department, size: 16),
                      ),
                    Text(
                      _mainPainQuestionIndex == _currentQuestionIndex
                          ? '메인 통증으로 표시됨'
                          : '이게 메인 통증이에요',
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _rememberQuestionIndex = _rememberQuestionIndex == _currentQuestionIndex
                      ? null
                      : _currentQuestionIndex;
                }),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _rememberQuestionIndex == _currentQuestionIndex
                      ? const Color(0x1A0F766E)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_rememberQuestionIndex == _currentQuestionIndex)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin, size: 16),
                      ),
                    Text(
                      _rememberQuestionIndex == _currentQuestionIndex
                          ? '기억 요청 표시됨'
                          : '기억해줬으면 해요',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _saveCurrentAnswer();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('임시 저장 완료')),
                    );
                  },
                  child: const Text('임시 저장'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    _saveCurrentAnswer();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('문진 제출 완료')),
                    );
                  },
                  child: const Text('제출하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitHistoryItem {
  const _VisitHistoryItem({
    required this.date,
    required this.summary,
    required this.advice,
  });

  final String date;
  final String summary;
  final String advice;
}
