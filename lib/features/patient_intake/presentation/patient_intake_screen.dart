import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/patient_profile_service.dart';

class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({super.key});

  static const routeName = '/intake';

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _extraMemoController = TextEditingController();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;

  static const List<String> _initialVisitQuestions = [
    '체온이나 땀의 변화가 있었나요? 쉽게 덥거나 춥고, 식은땀이나 자한이 있었는지도 알려주세요.',
    '식욕과 갈증은 어땠나요? 물을 자주 찾는지, 차가운 음료를 선호하는지도 알려주세요.',
    '수면은 어떠셨나요? 잠드는 시간, 자주 깨는지, 꿈이 많은지도 적어주세요.',
    '소화는 어떠셨나요? 더부룩함, 속쓰림, 역류, 가스, 트림 변화를 알려주세요.',
    '소변은 어떠셨나요? 횟수, 색, 야간뇨, 급한 느낌이 있었는지 적어주세요.',
    '배변은 어떠셨나요? 횟수, 굳기, 변비나 설사 경향을 알려주세요.',
    '생리 관련 변화가 있었나요? 주기, 양, 통증, 혈색이 평소와 달랐는지 적어주세요.',
    '머리/눈/귀/코/목 쪽 불편감이 있었나요? 두통, 눈피로, 코막힘, 목 건조 등을 알려주세요.',
    '감정이나 스트레스는 어땠나요? 예민함, 답답함, 불안, 짜증 변화가 있었는지 적어주세요.',
    '기력과 기타 증상은 어땠나요? 하루 중 특히 힘든 시간과 꼭 말하고 싶은 증상을 적어주세요.',
  ];

  static const List<String> _followUpQuestions = [
    '최근 수면은 어떠셨나요?',
    '오늘 가장 불편한 부위는 어디인가요?',
    '지난번에 안내한 스트레칭은 얼마나 지키셨나요?',
    '식욕과 갈증은 지난 방문 이후 어떻게 변했나요?',
    '소화 상태는 어땠나요? 더부룩함이나 속쓰림이 있었나요?',
    '오후 2시 이후 카페인 줄이기는 어느 정도 지켜졌나요?',
    '배변이나 소변은 지난번보다 달라진 점이 있었나요?',
    '두통, 눈피로, 코막힘 같은 HEENT 증상은 어땠나요?',
    '스트레스나 감정 기복은 어땠나요?',
    '하루 중 피로가 가장 심해지는 시간은 언제인가요?',
  ];

  final Map<int, String> _initialVisitAnswers = {};
  final Map<int, String> _followUpAnswers = {
    0: '새벽 3시에 자주 깨고 다시 잠들기 어려워요.',
    1: '오른쪽 어깨 통증이 가장 심해요.',
    3: '입이 자주 마르고 찬물을 찾게 돼요.',
  };

  int _currentQuestionIndex = 0;
  bool _isFirstVisitPreview = false;
  bool _stretchingDone = false;
  bool _caffeineDone = false;
  bool _sleepLogDone = true;
  bool _isSubmitting = false;

  final Set<int> _initialMainPainQuestionIndexes = <int>{};
  final Set<int> _followUpMainPainQuestionIndexes = <int>{};
  final Set<int> _initialRememberQuestionIndexes = <int>{};
  final Set<int> _followUpRememberQuestionIndexes = <int>{};

  List<String> get _activeQuestions =>
      _isFirstVisitPreview ? _initialVisitQuestions : _followUpQuestions;

  Map<int, String> get _activeAnswers =>
      _isFirstVisitPreview ? _initialVisitAnswers : _followUpAnswers;

  Set<int> get _activeMainPainQuestionIndexes => _isFirstVisitPreview
      ? _initialMainPainQuestionIndexes
      : _followUpMainPainQuestionIndexes;

  Set<int> get _activeRememberQuestionIndexes => _isFirstVisitPreview
      ? _initialRememberQuestionIndexes
      : _followUpRememberQuestionIndexes;

  PatientProfile get _currentProfile =>
      _authBackedProfile ?? _store.currentPatientProfile;

  String get _questionModeTitle => _isFirstVisitPreview ? '초진 10카테고리 문진' : '재진 추적 문진';

  String get _questionModeDescription => _isFirstVisitPreview
      ? '처음 방문한 환자처럼 10가지 기본 카테고리를 전체적으로 확인하는 흐름입니다.'
      : '지난 방문 기록과 침술사 조언을 바탕으로 추적 관찰이 필요한 부분을 중심으로 묻는 흐름입니다.';

  @override
  void initState() {
    super.initState();
    _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        await _profileSubscription?.cancel();
        if (user == null) {
          if (mounted) {
            setState(() => _authBackedProfile = null);
          }
          return;
        }

        await PatientProfileService.ensureProfileForUser(user);
        _profileSubscription = PatientProfileService.watchProfile(user.uid).listen(
          (profile) {
            if (!mounted || profile == null) {
              return;
            }
            setState(() => _authBackedProfile = profile);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _answerController.dispose();
    _extraMemoController.dispose();
    super.dispose();
  }

  void _saveCurrentAnswer() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      _activeAnswers.remove(_currentQuestionIndex);
      return;
    }
    _activeAnswers[_currentQuestionIndex] = text;
  }

  Future<void> _submitCurrentIntake() async {
    if (_isSubmitting) {
      return;
    }

    if (!_currentProfile.hasRequiredAlertInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호와 이메일을 모두 입력해야 실제 테스트 흐름을 확인할 수 있어요.'),
        ),
      );
      _openProfileDialog();
      return;
    }

    _saveCurrentAnswer();

    final answers = _activeQuestions.asMap().entries
        .where((entry) => (_activeAnswers[entry.key] ?? '').trim().isNotEmpty)
        .map(
          (entry) => <String, dynamic>{
            'questionIndex': entry.key + 1,
            'questionText': entry.value,
            'answerText': (_activeAnswers[entry.key] ?? '').trim(),
            'markedMainPain': _activeMainPainQuestionIndexes.contains(entry.key),
            'markedRemember': _activeRememberQuestionIndexes.contains(entry.key),
          },
        )
        .toList();

    setState(() => _isSubmitting = true);

    try {
      final docId = await AppFirestoreService.submitPatientIntake(
        patientId: _currentProfile.id,
        patientName: _currentProfile.name,
        visitType: _isFirstVisitPreview ? 'initial' : 'follow_up',
        answers: answers,
        extraMemo: _extraMemoController.text.trim(),
        adherence: {
          'stretchingDone': _stretchingDone,
          'caffeineDone': _caffeineDone,
          'sleepLogDone': _sleepLogDone,
          'percent': _adherencePercent(),
          'patientPhone': _currentProfile.phone,
          'patientEmail': _currentProfile.email,
        },
        currentQuestionIndex: _currentQuestionIndex + 1,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문진 제출 완료: $docId')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문진 저장 실패: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _switchQuestionMode(bool isFirstVisit) {
    _saveCurrentAnswer();
    setState(() {
      _isFirstVisitPreview = isFirstVisit;
      _currentQuestionIndex = 0;
      _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
      _extraMemoController.clear();
    });
  }

  void _moveQuestion(int direction) {
    _saveCurrentAnswer();
    final nextIndex =
        (_currentQuestionIndex + direction).clamp(0, _activeQuestions.length - 1);
    if (nextIndex == _currentQuestionIndex) {
      return;
    }
    setState(() {
      _currentQuestionIndex = nextIndex;
      _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
    });
  }

  int _adherencePercent() {
    var done = 0;
    if (_stretchingDone) done++;
    if (_caffeineDone) done++;
    if (_sleepLogDone) done++;
    return ((done / 3) * 100).round();
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

  Future<void> _openProfileDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PatientProfileDialog(profile: _currentProfile),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _activeQuestions.length;
    final answeredQuestions = _activeAnswers.length;
    final remaining = totalQuestions - answeredQuestions;
    final progress = answeredQuestions / totalQuestions;
    final adherence = _adherencePercent();
    final isMainPainSelected =
        _activeMainPainQuestionIndexes.contains(_currentQuestionIndex);
    final isRememberSelected =
        _activeRememberQuestionIndexes.contains(_currentQuestionIndex);
    final profile = _currentProfile;
    final history = _store.historyForPatient(profile.id);
    final latestVisit = history.isNotEmpty ? history.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('환자 사전 문진'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '계정 메뉴',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) async {
              final navigator = Navigator.of(context);
              if (value == 'profile') {
                _openProfileDialog();
                return;
              }
              if (value == 'logout') {
                if (FirebaseAuth.instance.currentUser != null) {
                  await PatientProfileService.signOut();
                }
                if (!mounted) {
                  return;
                }
                navigator.popUntil((route) => route.isFirst);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value 준비 중입니다.')),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('내 프로필 수정')),
              PopupMenuItem(value: 'settings', child: Text('설정')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
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
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 프로필', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${profile.name} · ${profile.sex} · ${profile.ageRange} · ${profile.ethnicity}'),
                const SizedBox(height: 6),
                Text('전화번호: ${profile.phone.isEmpty ? '미입력' : profile.phone}'),
                Text('이메일: ${profile.email.isEmpty ? '미입력' : profile.email}'),
                const SizedBox(height: 8),
                Text(
                  '현재 데모 환자 계정은 이 프로필에 연결됩니다. 이름, 전화번호, 이메일을 본인 정보로 바꾸면 답변 요청 테스트를 직접 확인할 수 있어요.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusPill(
                      label: profile.phone.isEmpty ? '전화번호 필요' : '전화번호 입력 완료',
                      good: profile.phone.isNotEmpty,
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: profile.email.isEmpty ? '이메일 필요' : '이메일 입력 완료',
                      good: profile.email.isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  profile.hasRequiredAlertInfo
                      ? '알림 테스트 준비 완료: 전화번호와 이메일이 모두 입력되어 있습니다.'
                      : '답변 요청을 진짜처럼 테스트하려면 전화번호와 이메일을 모두 입력해 주세요.',
                  style: TextStyle(
                    color: profile.hasRequiredAlertInfo
                        ? const Color(0xFF0F766E)
                        : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openProfileDialog,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('내 프로필 자세히 수정'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PatientAlertSummary(patientId: profile.id),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('침술사 답변 요청', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  '침술사가 보낸 질문 요청이 여기 쌓입니다. 실제 이메일/SMS 발송은 아직 연결 전이고, 지금은 Firestore 저장과 화면 반영까지 테스트하는 단계예요.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                _AnswerRequestsSection(patientId: profile.id),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 최근 제출 기록', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _RecentSubmissionsSection(patientId: profile.id),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('문진 모드', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('초진 예시'),
                      selected: _isFirstVisitPreview,
                      onSelected: (_) => _switchQuestionMode(true),
                    ),
                    ChoiceChip(
                      label: const Text('재진 예시'),
                      selected: !_isFirstVisitPreview,
                      onSelected: (_) => _switchQuestionMode(false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _questionModeTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _questionModeDescription,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('지난 방문 요약', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (latestVisit == null)
                  const Text('아직 저장된 방문 기록이 없습니다.')
                else ...[
                  Text('지난 방문일: ${latestVisit.visit.date} (${latestVisit.visit.daysAgo}일 전)'),
                  const SizedBox(height: 4),
                  Text('그날 치료/기록: ${latestVisit.visit.previousTreatmentArea}'),
                  const SizedBox(height: 4),
                  Text('침술사 코멘트: ${latestVisit.visit.previousSessionNote}'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '전체 히스토리 ${history.length}건',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openVisitHistorySheet(context, history),
                      child: const Text('전체 히스토리 보기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주 해야할 것 (${_thisWeekRangeLabel()})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('1) 취침 1시간 전 스트레칭 5분'),
                const Text('2) 오후 2시 이후 카페인 줄이기'),
                const Text('3) 수면/피로 변화 간단 기록'),
                const SizedBox(height: 12),
                Text('내가 지킨 항목 체크 ($adherence%)', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: adherence / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFD5F0EE),
                  color: const Color(0xFF0F766E),
                ),
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
          const SizedBox(height: 12),
          const Text('문진 진행 상태', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFD5F0EE),
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          Text('진행률 $answeredQuestions/$totalQuestions · 남은 질문 $remaining개'),
          const SizedBox(height: 4),
          Text(
            '천천히 괜찮아요. 지금처럼 하나씩 답해도 충분해요.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '현재 질문 (${_currentQuestionIndex + 1}/$totalQuestions): ${_activeQuestions[_currentQuestionIndex]}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isMainPainSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.local_fire_department_outlined, color: Colors.deepOrange),
                      ),
                    if (isRememberSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.push_pin_outlined, color: Color(0xFF0F766E)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _answerController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '답변을 적어주세요.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _extraMemoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '추가 메모 (침술사에게 전달)',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _currentQuestionIndex == 0 ? null : () => _moveQuestion(-1),
                      child: const Text('이전 질문'),
                    ),
                    OutlinedButton(
                      onPressed: _currentQuestionIndex == totalQuestions - 1
                          ? null
                          : () => _moveQuestion(1),
                      child: const Text('다음 질문'),
                    ),
                    FilterChip(
                      label: Text(
                        isMainPainSelected ? '메인 통증으로 표시됨' : '메인 통증이에요',
                      ),
                      selected: isMainPainSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _activeMainPainQuestionIndexes.add(_currentQuestionIndex);
                          } else {
                            _activeMainPainQuestionIndexes.remove(_currentQuestionIndex);
                          }
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(
                        isRememberSelected ? '기억해줬으면 표시됨' : '기억해줬으면 해요',
                      ),
                      selected: isRememberSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _activeRememberQuestionIndexes.add(_currentQuestionIndex);
                          } else {
                            _activeRememberQuestionIndexes.remove(_currentQuestionIndex);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitCurrentIntake,
                  child: Text(_isSubmitting ? '제출 중...' : '제출하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openVisitHistorySheet(BuildContext context, List<ScheduledVisit> history) {
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
            if (history.isEmpty)
              const Text('아직 방문 기록이 없습니다.')
            else
              ...history.map((item) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.visit.date} · ${item.visit.time}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('치료 부위: ${item.visit.previousTreatmentArea}'),
                        const SizedBox(height: 4),
                        Text('기록: ${item.visit.previousSessionNote}'),
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FCFB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFDDF4F1) : const Color(0xFFFFE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: good ? const Color(0xFF0F766E) : Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PatientAlertSummary extends StatelessWidget {
  const _PatientAlertSummary({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('answer_requests')
          .where('patientId', isEqualTo: patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(minHeight: 4),
            ),
          );
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aDate = (a.data()['requestedAt'] as Timestamp?)?.toDate();
            final bDate = (b.data()['requestedAt'] as Timestamp?)?.toDate();
            return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
          });

        if (docs.isEmpty) {
          return Card(
            color: const Color(0xFFF7FBFA),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.notifications_none_outlined),
                  SizedBox(width: 10),
                  Expanded(child: Text('새로운 답변 요청은 아직 없습니다.')),
                ],
              ),
            ),
          );
        }

        final latest = docs.first.data();
        final selectedQuestions =
            (latest['selectedQuestions'] as List<dynamic>? ?? const []);
        final note = (latest['note'] as String? ?? '').trim();

        return Card(
          color: const Color(0xFFE9F7F4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '침술사 답변 요청 ${docs.length}건',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('가장 최근 요청 질문 수: ${selectedQuestions.length}개'),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('최근 메모: $note'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnswerRequestsSection extends StatelessWidget {
  const _AnswerRequestsSection({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('answer_requests')
          .where('patientId', isEqualTo: patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('답변 요청을 불러오지 못했습니다: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aDate = (a.data()['requestedAt'] as Timestamp?)?.toDate();
            final bDate = (b.data()['requestedAt'] as Timestamp?)?.toDate();
            return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
          });

        if (docs.isEmpty) {
          return const Text('아직 들어온 답변 요청이 없습니다.');
        }

        return Column(
          children: docs.take(3).map((doc) {
            final data = doc.data();
            final selectedQuestions =
                (data['selectedQuestions'] as List<dynamic>? ?? []).cast<String>();
            final note = (data['note'] as String? ?? '').trim();
            final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestedAt == null
                          ? '최근 답변 요청'
                          : '요청 시각: ${requestedAt.year}-${requestedAt.month.toString().padLeft(2, '0')}-${requestedAt.day.toString().padLeft(2, '0')} ${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (selectedQuestions.isNotEmpty) ...[
                      const Text('요청 질문'),
                      const SizedBox(height: 4),
                      ...selectedQuestions.map(Text.new),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('메모: $note'),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RecentSubmissionsSection extends StatelessWidget {
  const _RecentSubmissionsSection({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('intake_submissions')
          .where('patientId', isEqualTo: patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('제출 기록을 불러오지 못했습니다: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aDate = (a.data()['submittedAt'] as Timestamp?)?.toDate();
            final bDate = (b.data()['submittedAt'] as Timestamp?)?.toDate();
            return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
          });

        if (docs.isEmpty) {
          return const Text('아직 제출한 문진이 없습니다. 제출하면 여기 바로 쌓입니다.');
        }

        return Column(
          children: docs.take(3).map((doc) {
            final data = doc.data();
            final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
            final visitType = (data['visitType'] as String? ?? 'follow_up');
            final answers = (data['answers'] as List<dynamic>? ?? []);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submittedAt == null
                          ? '방금 저장된 문진'
                          : '제출 시각: ${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('문진 유형: ${visitType == 'initial' ? '초진' : '재진'}'),
                    Text('저장된 답변 수: ${answers.length}개'),
                    Text('문서 ID: ${doc.id}'),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PatientProfileDialog extends StatefulWidget {
  const _PatientProfileDialog({required this.profile});

  final PatientProfile profile;

  @override
  State<_PatientProfileDialog> createState() => _PatientProfileDialogState();
}

class _PatientProfileDialogState extends State<_PatientProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _birthYearController;
  late final TextEditingController _sexController;
  late final TextEditingController _ethnicityController;
  late final TextEditingController _memoController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile.name);
    _phoneController = TextEditingController(text: profile.phone);
    _emailController = TextEditingController(text: profile.email);
    _birthYearController = TextEditingController(text: profile.birthYear.toString());
    _sexController = TextEditingController(text: profile.sex);
    _ethnicityController = TextEditingController(text: profile.ethnicity);
    _memoController = TextEditingController(text: profile.memo);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthYearController.dispose();
    _sexController.dispose();
    _ethnicityController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('내 프로필 수정'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameController, '이름', required: true),
                const SizedBox(height: 10),
                _buildField(
                  _phoneController,
                  '전화번호',
                  required: true,
                  hint: '예: 201-555-0101',
                ),
                const SizedBox(height: 10),
                _buildField(
                  _emailController,
                  '이메일',
                  required: true,
                  hint: '예: me@example.com',
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return '이메일을 입력해 주세요.';
                    }
                    if (!text.contains('@')) {
                      return '이메일 형식으로 입력해 주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildField(
                  _birthYearController,
                  '출생연도',
                  required: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildField(_sexController, '성별', required: true),
                const SizedBox(height: 10),
                _buildField(_ethnicityController, '인종/민족', required: true),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '전화번호와 이메일은 앞으로 실제 이메일/SMS 알림 연결 테스트를 위해 필수로 받습니다. 지금 단계에서는 Firestore 저장과 화면 반영까지 먼저 확인합니다.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            final birthYear = int.tryParse(_birthYearController.text.trim());
            if (birthYear == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('출생연도는 숫자로 입력해 주세요.')),
              );
              return;
            }

            final updated = widget.profile.copyWith(
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              birthYear: birthYear,
              sex: _sexController.text.trim(),
              ethnicity: _ethnicityController.text.trim(),
              memo: _memoController.text.trim(),
            );

            final isAuthProfile =
                FirebaseAuth.instance.currentUser?.uid == widget.profile.id;

            if (isAuthProfile) {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await PatientProfileService.saveProfile(updated);
                if (!mounted) {
                  return;
                }
                navigator.pop();
              } catch (error) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('프로필 저장 실패: $error')),
                );
              }
              return;
            }

            ClinicDataStore.instance.saveProfile(updated);
            Navigator.of(context).pop();
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (required && (value ?? '').trim().isEmpty) {
              return '$label 입력이 필요합니다.';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
