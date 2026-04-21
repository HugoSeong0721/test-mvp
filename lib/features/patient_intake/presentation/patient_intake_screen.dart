import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../patient_home/presentation/patient_home_screen.dart';

class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({super.key});

  static const routeName = '/intake';

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _QuestionPair {
  const _QuestionPair(this.en, this.ko);

  final String en;
  final String ko;

  String text(AppLanguageController lang) => lang.tr(en, ko);
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _extraMemoController = TextEditingController();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;
  User? _authUser;

  static const List<_QuestionPair> _initialVisitQuestions = [
    _QuestionPair(
      'Have you noticed any temperature or sweating changes? For example, do you feel unusually hot or cold, or have night sweats?',
      '체온이나 땀의 변화가 있었나요? 쉽게 덥거나 춥고, 식은땀이나 자한이 있는지도 알려주세요.',
    ),
    _QuestionPair(
      'How have your appetite and thirst been? Do you crave cold drinks, warm drinks, or find yourself drinking more often?',
      '식욕과 갈증은 어떠나요? 물을 자주 찾는지, 찬 음료나 따뜻한 물을 선호하는지도 알려주세요.',
    ),
    _QuestionPair(
      'How has your sleep been? Please include falling asleep, waking during the night, and dreams if relevant.',
      '수면은 어떠셨나요? 잠드는 시간, 자주 깨는지, 꿈이 많은지도 적어주세요.',
    ),
    _QuestionPair(
      'How has digestion been? Any bloating, reflux, heartburn, burping, or gas?',
      '소화는 어떠셨나요? 더부룩함, 속쓰림, 역류, 가스, 트림 변화를 알려주세요.',
    ),
    _QuestionPair(
      'How has urination been? Any change in frequency, urgency, color, or nighttime urination?',
      '소변은 어떠셨나요? 횟수, 색, 야간뇨, 급한 느낌이 있었는지 적어주세요.',
    ),
    _QuestionPair(
      'How have your bowel movements been? Any change in frequency, stool form, constipation, or diarrhea?',
      '배변은 어떠셨나요? 횟수, 굳기, 변비나 설사 경향을 알려주세요.',
    ),
    _QuestionPair(
      'Any menstrual changes to note? Such as cycle, volume, pain, clots, or color?',
      '생리 관련 변화가 있었나요? 주기, 양, 통증, 혈괴, 혈색이 평소와 달랐는지 적어주세요.',
    ),
    _QuestionPair(
      'Any head, eyes, ears, nose, or throat discomfort? Such as headaches, eye strain, congestion, or dryness?',
      '머리/눈/귀/코/목 쪽 불편감이 있었나요? 두통, 눈피로, 코막힘, 목 건조 등을 알려주세요.',
    ),
    _QuestionPair(
      'How have your stress and emotions been lately? Any irritability, anxiety, frustration, or low mood?',
      '감정이나 스트레스는 어땠나요? 예민함, 답답함, 불안, 짜증 변화가 있었는지 적어주세요.',
    ),
    _QuestionPair(
      'How has your overall energy been? If there is anything else you want your practitioner to know, include it here.',
      '기력과 기타 증상은 어땠나요? 꼭 말하고 싶은 증상이 있다면 함께 적어주세요.',
    ),
  ];

  static const List<_QuestionPair> _followUpQuestions = [
    _QuestionPair('How has your sleep been recently?', '최근 수면은 어떠셨나요?'),
    _QuestionPair('What feels most uncomfortable today?', '오늘 가장 불편한 부분은 어디인가요?'),
    _QuestionPair(
      'How consistently did you follow the stretching plan from the last visit?',
      '지난번에 안내한 스트레칭은 얼마나 지키셨나요?',
    ),
    _QuestionPair(
      'How have appetite and thirst changed since the last visit?',
      '식욕과 갈증은 지난 방문 이후 어떻게 변했나요?',
    ),
    _QuestionPair(
      'How has digestion been since the last visit?',
      '소화 상태는 지난 방문 이후 어땠나요?',
    ),
    _QuestionPair(
      'How often were you able to reduce caffeine after 2 PM?',
      '오후 2시 이후 카페인 줄이기는 어느 정도 지켜졌나요?',
    ),
    _QuestionPair(
      'Any changes in bowel movements or urination?',
      '배변이나 소변은 지난번보다 달라진 점이 있나요?',
    ),
    _QuestionPair(
      'How are headaches, eye strain, sinus, or other HEENT symptoms now?',
      '두통, 눈피로, 코막힘 같은 HEENT 증상은 지금 어떤가요?',
    ),
    _QuestionPair(
      'How has your stress or emotional tension been this week?',
      '이번 주 스트레스나 감정 기복은 어땠나요?',
    ),
    _QuestionPair(
      'At what time of day does your fatigue feel strongest?',
      '하루 중 언제 피로가 가장 심한가요?',
    ),
  ];

  final Map<int, String> _initialVisitAnswers = {};
  final Map<int, String> _followUpAnswers = {
    0: 'I still wake up around 3 AM on some nights.',
    1: 'My right shoulder and upper back still feel tight.',
    3: 'My mouth feels dry often and I keep reaching for cold water.',
  };

  final Set<int> _initialMainPainQuestionIndexes = <int>{};
  final Set<int> _followUpMainPainQuestionIndexes = <int>{};
  final Set<int> _initialRememberQuestionIndexes = <int>{};
  final Set<int> _followUpRememberQuestionIndexes = <int>{};

  int _currentQuestionIndex = 0;
  bool _isFirstVisitPreview = false;
  bool _stretchingDone = false;
  bool _caffeineDone = false;
  bool _sleepLogDone = true;
  bool _isSubmitting = false;

  List<_QuestionPair> get _activeQuestions =>
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

  @override
  void initState() {
    super.initState();
    _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _authUser = user;
      await _profileSubscription?.cancel();
      if (user == null) {
        if (mounted) {
          setState(() => _authBackedProfile = null);
        }
        return;
      }

      await PatientProfileService.ensureProfileForUser(user);
      _profileSubscription = PatientProfileService.watchProfile(user.uid).listen((profile) {
        if (!mounted || profile == null) {
          return;
        }
        setState(() => _authBackedProfile = profile);
      });
    });
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

  void _changeQuestion(int nextIndex) {
    _saveCurrentAnswer();
    setState(() {
      _currentQuestionIndex = nextIndex.clamp(0, _activeQuestions.length - 1);
      _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
    });
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

  double _adherencePercent() {
    var done = 0;
    if (_stretchingDone) done++;
    if (_caffeineDone) done++;
    if (_sleepLogDone) done++;
    return done / 3;
  }

  Future<void> _submitCurrentIntake() async {
    final lang = AppLanguageController.instance;
    if (_isSubmitting) {
      return;
    }

    if (!_currentProfile.hasRequiredAlertInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Please add both your phone number and email before submitting so the test flow can work properly.',
              '제출 전 전화번호와 이메일을 모두 입력해야 테스트 흐름이 정상 작동합니다.',
            ),
          ),
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
            'questionText': entry.value.text(lang),
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

      await AppFirestoreService.markPendingRequestsCompleted(
        patientId: _currentProfile.id,
        submissionId: docId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr('Submission saved: $docId', '제출이 저장되었습니다: $docId'),
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
            lang.tr('Failed to save your submission: $error', '제출 저장에 실패했습니다: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openProfileDialog() async {
    final lang = AppLanguageController.instance;
    final nameController = TextEditingController(text: _currentProfile.name);
    final phoneController = TextEditingController(text: _currentProfile.phone);
    final emailController = TextEditingController(text: _currentProfile.email);
    final birthYearController = TextEditingController(
      text: _currentProfile.birthYear.toString(),
    );
    final sexController = TextEditingController(text: _currentProfile.sex);
    final ethnicityController = TextEditingController(text: _currentProfile.ethnicity);
    final memoController = TextEditingController(text: _currentProfile.memo);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.tr('Edit My Profile', '내 프로필 수정')),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: lang.tr('Name', '이름')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: lang.tr('Phone', '전화번호')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: lang.tr('Email', '이메일')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: birthYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: lang.tr('Birth Year', '출생연도')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sexController,
                    decoration: InputDecoration(labelText: lang.tr('Sex / Gender', '성별')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ethnicityController,
                    decoration: InputDecoration(labelText: lang.tr('Ethnicity', '인종/민족')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: memoController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: lang.tr('Memo', '메모')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.tr('Cancel', '취소')),
            ),
            FilledButton(
              onPressed: () async {
                final updated = _currentProfile.copyWith(
                  name: nameController.text.trim().isEmpty
                      ? _currentProfile.name
                      : nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  birthYear: int.tryParse(birthYearController.text.trim()) ??
                      _currentProfile.birthYear,
                  sex: sexController.text.trim().isEmpty
                      ? _currentProfile.sex
                      : sexController.text.trim(),
                  ethnicity: ethnicityController.text.trim().isEmpty
                      ? _currentProfile.ethnicity
                      : ethnicityController.text.trim(),
                  memo: memoController.text.trim(),
                );

                if (_authUser != null) {
                  await PatientProfileService.saveProfile(updated);
                } else {
                  _store.saveProfile(updated);
                  _store.setCurrentPatientProfile(updated.id);
                  setState(() {});
                }

                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              },
              child: Text(lang.tr('Save', '저장')),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    birthYearController.dispose();
    sexController.dispose();
    ethnicityController.dispose();
    memoController.dispose();
  }

  List<ScheduledVisit> get _history => _store.historyForPatient(_currentProfile.id);

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final history = _history;
    final latestVisit = history.isNotEmpty ? history.first.visit : null;
    final progress = (_currentQuestionIndex + 1) / _activeQuestions.length;
    final answeredCount =
        _activeAnswers.values.where((value) => value.trim().isNotEmpty).length;
    final remainingCount = _activeQuestions.length - answeredCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Patient Intake', '환자 사전 문진')),
        actions: [
          IconButton(
            tooltip: lang.tr('Patient home', '환자 홈'),
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              PatientHomeScreen.routeName,
            ),
            icon: const Icon(Icons.home_outlined),
          ),
          IconButton(
            tooltip: lang.tr('Edit profile', '프로필 수정'),
            onPressed: _openProfileDialog,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const LanguageMenuButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(label: Text(lang.tr('Patient View', '환자 화면'))),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? '-' : profile.phone}',
                  ),
                  Text(
                    '${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? '-' : profile.email}',
                  ),
                  Text(
                    '${lang.tr('Profile', '프로필')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
                  ),
                  if (!profile.hasRequiredAlertInfo) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lang.tr(
                          'Please add both your phone number and email so your practitioner can reach you for real testing.',
                          '실제 테스트를 위해 전화번호와 이메일을 모두 입력해주세요.',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('answer_requests')
                .where('patientId', isEqualTo: profile.id)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              return Card(
                color: docs.isNotEmpty ? const Color(0xFFE8F6F4) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docs.isNotEmpty
                            ? lang.tr(
                                'New Answer Requests (${docs.length})',
                                '새 답변 요청 ${docs.length}건',
                              )
                            : lang.tr('Answer Requests', '답변 요청'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (docs.isEmpty)
                        Text(
                          lang.tr(
                            'No pending requests right now.',
                            '현재 대기 중인 요청이 없습니다.',
                          ),
                        ),
                      ...docs.take(3).map((doc) {
                        final data = doc.data();
                        final selected =
                            (data['selectedQuestions'] as List?)?.cast<String>() ??
                                const [];
                        final note = (data['note'] as String?)?.trim() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr(
                                    'Requested questions: ${selected.length}',
                                    '요청된 질문 수: ${selected.length}',
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (selected.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ...selected.take(3).map((q) => Text('• $q')),
                                ],
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('${lang.tr('Note', '메모')}: $note'),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (latestVisit != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('Last Visit Summary', '지난 방문 요약'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lang.tr('Last visit', '지난 방문')}: ${latestVisit.lastVisitDate} (${latestVisit.daysAgo} ${lang.tr('days ago', '일 전')})',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Treatment area', '치료 부위')}: ${latestVisit.previousTreatmentArea}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lang.tr('Practitioner note', '침술사 메모')}: ${latestVisit.previousSessionNote}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('This Week Checklist', '이번 주 체크리스트'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _adherencePercent()),
                  const SizedBox(height: 8),
                  Text(
                    lang.tr(
                      'Completion ${(100 * _adherencePercent()).round()}%',
                      '완료율 ${(100 * _adherencePercent()).round()}%',
                    ),
                  ),
                  CheckboxListTile(
                    value: _stretchingDone,
                    onChanged: (value) =>
                        setState(() => _stretchingDone = value ?? false),
                    title: Text(lang.tr('Bedtime stretching', '취침 전 스트레칭')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _caffeineDone,
                    onChanged: (value) =>
                        setState(() => _caffeineDone = value ?? false),
                    title:
                        Text(lang.tr('Reduce caffeine after 2 PM', '오후 카페인 조절')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: _sleepLogDone,
                    onChanged: (value) =>
                        setState(() => _sleepLogDone = value ?? false),
                    title: Text(lang.tr('Track sleep and fatigue', '수면/피로 기록')),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('Question Mode', '문진 모드'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(lang.tr('Follow-Up', '재진')),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(lang.tr('Initial Visit', '초진')),
                      ),
                    ],
                    selected: {_isFirstVisitPreview},
                    onSelectionChanged: (selection) =>
                        _switchQuestionMode(selection.first),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isFirstVisitPreview
                        ? lang.tr(
                            'Use the 10-category intake structure for a first-time patient.',
                            '처음 방문한 환자처럼 10가지 카테고리를 전체적으로 확인하는 흐름입니다.',
                          )
                        : lang.tr(
                            'Use focused follow-up questions based on the last visit and practitioner advice.',
                            '지난 방문 기록과 침술사 조언을 바탕으로 추적 질문을 확인하는 흐름입니다.',
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('Intake Progress', '문진 진행 상태'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    lang.tr(
                      'Question ${_currentQuestionIndex + 1}/${_activeQuestions.length} · $remainingCount remaining',
                      '질문 ${_currentQuestionIndex + 1}/${_activeQuestions.length} · 남은 질문 $remainingCount개',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _activeQuestions[_currentQuestionIndex].text(lang),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _answerController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: lang.tr(
                        'Write your answer here in as much detail as you want.',
                        '답변을 적어주세요. 편한 만큼 자세히 적으셔도 됩니다.',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _extraMemoController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: lang.tr(
                        'Extra note for your practitioner',
                        '침술사에게 추가로 남길 메모',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilterChip(
                        selected:
                            _activeMainPainQuestionIndexes.contains(_currentQuestionIndex),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _activeMainPainQuestionIndexes.add(_currentQuestionIndex);
                            } else {
                              _activeMainPainQuestionIndexes.remove(
                                _currentQuestionIndex,
                              );
                            }
                          });
                        },
                        avatar: _activeMainPainQuestionIndexes.contains(
                          _currentQuestionIndex,
                        )
                            ? const Icon(Icons.local_fire_department, size: 18)
                            : null,
                        label: Text(
                          lang.tr('This is my main pain', '이게 메인 통증이에요'),
                        ),
                      ),
                      FilterChip(
                        selected:
                            _activeRememberQuestionIndexes.contains(_currentQuestionIndex),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _activeRememberQuestionIndexes.add(_currentQuestionIndex);
                            } else {
                              _activeRememberQuestionIndexes.remove(
                                _currentQuestionIndex,
                              );
                            }
                          });
                        },
                        avatar: _activeRememberQuestionIndexes.contains(
                          _currentQuestionIndex,
                        )
                            ? const Icon(Icons.push_pin, size: 18)
                            : null,
                        label: Text(
                          lang.tr('Please remember this', '기억해줬으면 해요'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentQuestionIndex == 0
                              ? null
                              : () => _changeQuestion(_currentQuestionIndex - 1),
                          child: Text(
                            lang.tr('Previous Question', '이전 질문'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentQuestionIndex == _activeQuestions.length - 1
                              ? null
                              : () => _changeQuestion(_currentQuestionIndex + 1),
                          child: Text(
                            lang.tr('Next Question', '다음 질문'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitCurrentIntake,
                    child: Text(
                      _isSubmitting
                          ? lang.tr('Submitting...', '제출 중...')
                          : lang.tr('Submit Intake', '문진 제출하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('intake_submissions')
                .where('patientId', isEqualTo: profile.id)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('My Recent Submissions', '내 최근 제출 기록'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (docs.isEmpty)
                        Text(
                          lang.tr(
                            'No submissions yet.',
                            '아직 제출 기록이 없습니다.',
                          ),
                        ),
                      ...docs.take(5).map((doc) {
                        final data = doc.data();
                        final answers = (data['answers'] as List?)?.length ?? 0;
                        final visitType =
                            (data['visitType'] as String?) ?? 'follow_up';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr(
                                    visitType == 'initial'
                                        ? 'Initial visit intake'
                                        : 'Follow-up intake',
                                    visitType == 'initial' ? '초진 문진' : '재진 문진',
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang.tr(
                                    'Answered questions: $answers',
                                    '답변한 질문 수: $answers',
                                  ),
                                ),
                                Text('ID: ${doc.id}'),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
