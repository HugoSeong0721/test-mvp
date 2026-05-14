import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/patient_shell.dart';
import '../../../core/widgets/patient_clinic_context_panel.dart';
import '../../patient_home/presentation/patient_home_screen.dart';
import '../../patient_requests/presentation/patient_requests_screen.dart';
import '../../visit_history/presentation/visit_history_screen.dart';

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
  final TextEditingController _stretchingNoteController =
      TextEditingController();
  final TextEditingController _caffeineNoteController = TextEditingController();
  final TextEditingController _sleepNoteController = TextEditingController();

  PatientProfile? _sessionBackedProfile;
  PatientSession? _activeSession;

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
    _QuestionPair(
      'What feels most uncomfortable today?',
      '오늘 가장 불편한 부분은 어디인가요?',
    ),
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
  static const List<String> _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri'];
  final List<bool> _stretchingWeek = List<bool>.filled(5, false);
  final List<bool> _caffeineWeek = List<bool>.filled(5, false);
  final List<bool> _sleepWeek = List<bool>.filled(5, false);
  bool _isSubmitting = false;
  bool _showStartGuide = true;
  String? _lastChecklistReminderKey;

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
      _sessionBackedProfile ?? _store.currentPatientProfile;

  String? get _activeClinicId =>
      _store.activeClinicForPatient(_currentProfile.id)?.id;

  @override
  void initState() {
    super.initState();
    _answerController.text = _activeAnswers[_currentQuestionIndex] ?? '';
    unawaited(_initializeProfile());
  }

  @override
  void dispose() {
    _answerController.dispose();
    _extraMemoController.dispose();
    _stretchingNoteController.dispose();
    _caffeineNoteController.dispose();
    _sleepNoteController.dispose();
    super.dispose();
  }

  Future<void> _initializeProfile() async {
    final session =
        BetaSessionService.currentSession ??
        await BetaSessionService.currentSessionAsync();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeSession = session;
    });

    if (session == null) {
      setState(() => _sessionBackedProfile = null);
      return;
    }

    try {
      final localProfile = await PatientProfileService.loadLocalProfile(
        session.id,
      );
      if (mounted && localProfile != null) {
        setState(() {
          _sessionBackedProfile = localProfile;
        });
        unawaited(_loadChecklistDraft());
      }
    } catch (_) {}

    unawaited(
      PatientProfileService.ensureProfileForSession(session)
          .then((_) async {
            final refreshed = await PatientProfileService.loadLocalProfile(
              session.id,
            );
            if (!mounted || refreshed == null) {
              return;
            }
            setState(() {
              _sessionBackedProfile = refreshed;
            });
            unawaited(_loadChecklistDraft());
          })
          .catchError((_) {}),
    );
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
    final totalChecked =
        _stretchingWeek.where((done) => done).length +
        _caffeineWeek.where((done) => done).length +
        _sleepWeek.where((done) => done).length;
    return totalChecked / (_weekdayKeys.length * 3);
  }

  int _weekDoneCount(List<bool> values) => values.where((done) => done).length;

  bool _taskHasAnyCheck(List<bool> values) => values.any((done) => done);

  int? _todayChecklistIndex() {
    final weekday = DateTime.now().weekday;
    if (weekday < DateTime.monday || weekday > DateTime.friday) {
      return null;
    }
    return weekday - DateTime.monday;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _checklistDraftKey() {
    final clinicId = _activeClinicId ?? 'no_clinic';
    return 'patient_checklist_draft_v1_${_currentProfile.id}_$clinicId';
  }

  String _todayChecklistLabel(AppLanguageController lang) {
    final now = DateTime.now();
    final index = _todayChecklistIndex();
    final weekday = index == null
        ? lang.tr('Weekend', '주말')
        : _weekdayLabel(lang, index);
    return '${_dateKey(now)} ($weekday)';
  }

  List<String> _missingTodayChecklistItems(AppLanguageController lang) {
    final index = _todayChecklistIndex();
    if (index == null) {
      return const [];
    }
    final items = <String>[];
    if (!_stretchingWeek[index]) {
      items.add(lang.tr('Bedtime stretching', '취침 전 스트레칭'));
    }
    if (!_caffeineWeek[index]) {
      items.add(lang.tr('Reduce caffeine after 2 PM', '오후 카페인 조절'));
    }
    if (!_sleepWeek[index]) {
      items.add(lang.tr('Track sleep and fatigue', '수면/피로 기록'));
    }
    return items;
  }

  void _queueChecklistReminderIfNeeded() {
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final clinicId = _activeClinicId;
    final todayIndex = _todayChecklistIndex();
    if (todayIndex == null ||
        clinicId == null ||
        profile.email.trim().isEmpty) {
      return;
    }

    final missingItems = _missingTodayChecklistItems(lang);
    if (missingItems.isEmpty) {
      return;
    }

    final reminderKey =
        'checklist_reminder_${profile.id}_${clinicId}_${_dateKey(DateTime.now())}';
    if (_lastChecklistReminderKey == reminderKey) {
      return;
    }
    _lastChecklistReminderKey = reminderKey;

    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) async {
            if (prefs.getBool(reminderKey) == true) {
              return;
            }
            await prefs.setBool(reminderKey, true);
            await AppFirestoreService.queueChecklistReminder(
              patientId: profile.id,
              clinicId: clinicId,
              patientName: profile.name,
              patientEmail: profile.email,
              dateLabel: _todayChecklistLabel(lang),
              missingItems: missingItems,
            );
          })
          .catchError((_) {}),
    );
  }

  Map<String, dynamic> _checklistDraftData() {
    return {
      'stretchingWeekdays': List<bool>.from(_stretchingWeek),
      'caffeineWeekdays': List<bool>.from(_caffeineWeek),
      'sleepWeekdays': List<bool>.from(_sleepWeek),
      'dailyNotes': {
        'date': _dateKey(DateTime.now()),
        'stretching': _stretchingNoteController.text.trim(),
        'caffeine': _caffeineNoteController.text.trim(),
        'sleep': _sleepNoteController.text.trim(),
      },
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _loadChecklistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checklistDraftKey());
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final data = decoded.map((key, value) => MapEntry(key.toString(), value));
      final dailyNotes = data['dailyNotes'] is Map
          ? (data['dailyNotes'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceWeekValues(
          _stretchingWeek,
          _restoreWeekdayChecks(data['stretchingWeekdays'], fallback: false),
        );
        _replaceWeekValues(
          _caffeineWeek,
          _restoreWeekdayChecks(data['caffeineWeekdays'], fallback: false),
        );
        _replaceWeekValues(
          _sleepWeek,
          _restoreWeekdayChecks(data['sleepWeekdays'], fallback: false),
        );
        if (dailyNotes['date'] == _dateKey(DateTime.now())) {
          _stretchingNoteController.text = (dailyNotes['stretching'] ?? '')
              .toString();
          _caffeineNoteController.text = (dailyNotes['caffeine'] ?? '')
              .toString();
          _sleepNoteController.text = (dailyNotes['sleep'] ?? '').toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _saveChecklistDraft({bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _checklistDraftKey(),
      jsonEncode(_checklistDraftData()),
    );
    if (!mounted || !showMessage) {
      return;
    }
    final lang = AppLanguageController.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.tr(
            'Checklist saved. You can leave and come back without losing it.',
            '체크리스트가 저장되었습니다. 다른 화면에 갔다 와도 유지됩니다.',
          ),
        ),
      ),
    );
  }

  List<bool> _restoreWeekdayChecks(dynamic raw, {required bool fallback}) {
    final restored = List<bool>.filled(_weekdayKeys.length, false);
    if (raw is List) {
      for (var i = 0; i < _weekdayKeys.length; i++) {
        restored[i] = i < raw.length && raw[i] == true;
      }
      return restored;
    }
    if (fallback) {
      restored[0] = true;
    }
    return restored;
  }

  void _replaceWeekValues(List<bool> target, List<bool> source) {
    for (var i = 0; i < target.length; i++) {
      target[i] = source[i];
    }
  }

  String _weekdayLabel(AppLanguageController lang, int index) {
    switch (index) {
      case 0:
        return lang.tr('Mon', '월');
      case 1:
        return lang.tr('Tue', '화');
      case 2:
        return lang.tr('Wed', '수');
      case 3:
        return lang.tr('Thu', '목');
      case 4:
        return lang.tr('Fri', '금');
    }
    return '';
  }

  int _savedWeekCount(
    Map<String, dynamic> adherence,
    String weekKey,
    String boolKey,
  ) {
    final restored = _restoreWeekdayChecks(
      adherence[weekKey],
      fallback: adherence[boolKey] == true,
    );
    return restored.where((done) => done).length;
  }

  Widget _buildWeekdayChecklistRow(
    BuildContext context, {
    required AppLanguageController lang,
    required String labelEn,
    required String labelKo,
    required List<bool> values,
    required TextEditingController noteController,
  }) {
    final theme = Theme.of(context);
    final todayIndex = _todayChecklistIndex();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lang.tr(labelEn, labelKo),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${_weekDoneCount(values)}/5',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.64),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(_weekdayKeys.length, (index) {
            final isToday = todayIndex == index;
            final isWeekend = todayIndex == null;
            final canEdit = isToday;
            final chip = FilterChip(
              label: Text(_weekdayLabel(lang, index)),
              selected: values[index],
              onSelected: canEdit
                  ? (selected) {
                      setState(() => values[index] = selected);
                      unawaited(_saveChecklistDraft(showMessage: false));
                    }
                  : null,
              showCheckmark: true,
              selectedColor: AppTheme.pine.withValues(alpha: 0.14),
              disabledColor: values[index]
                  ? AppTheme.pine.withValues(alpha: 0.08)
                  : AppTheme.surfaceSoft,
              checkmarkColor: AppTheme.pine,
              side: BorderSide(
                color: values[index] ? AppTheme.pine : AppTheme.border,
              ),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: canEdit
                    ? (values[index] ? AppTheme.pine : AppTheme.ink)
                    : AppTheme.ink.withValues(
                        alpha: values[index] ? 0.62 : 0.36,
                      ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            );
            final message = isWeekend
                ? lang.tr(
                    'Weekday checks open Monday through Friday.',
                    '체크는 월요일부터 금요일까지만 가능합니다.',
                  )
                : isToday
                ? lang.tr('You can check today only.', '오늘 요일만 체크할 수 있습니다.')
                : lang.tr(
                    'This day can be checked only when that weekday arrives.',
                    '이 요일은 해당 날짜가 되었을 때만 체크할 수 있습니다.',
                  );
            return Tooltip(message: message, child: chip);
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: noteController,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => unawaited(_saveChecklistDraft(showMessage: false)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.sticky_note_2_outlined),
            labelText: lang.tr('Today note for this item', '오늘 이 항목에 대한 메모'),
            helperText: _todayChecklistIndex() == null
                ? lang.tr(
                    'Notes save with today but weekday checks are locked.',
                    '메모는 저장되지만 오늘은 요일 체크일이 아닙니다.',
                  )
                : lang.tr(
                    'Example: done after dinner, skipped due to headache, felt easier today.',
                    '예: 저녁 후 완료, 두통 때문에 못함, 오늘은 더 쉬웠음.',
                  ),
          ),
        ),
      ],
    );
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

    final answers = _activeQuestions
        .asMap()
        .entries
        .where((entry) => (_activeAnswers[entry.key] ?? '').trim().isNotEmpty)
        .map(
          (entry) => <String, dynamic>{
            'questionIndex': entry.key + 1,
            'questionText': entry.value.text(lang),
            'answerText': (_activeAnswers[entry.key] ?? '').trim(),
            'markedMainPain': _activeMainPainQuestionIndexes.contains(
              entry.key,
            ),
            'markedRemember': _activeRememberQuestionIndexes.contains(
              entry.key,
            ),
          },
        )
        .toList();

    setState(() => _isSubmitting = true);

    try {
      final clinicId = _activeClinicId;
      if (clinicId == null || clinicId.isEmpty) {
        throw StateError('missing-clinic-selection');
      }

      final docId = await AppFirestoreService.submitPatientIntake(
        patientId: _currentProfile.id,
        clinicId: clinicId,
        patientName: _currentProfile.name,
        visitType: _isFirstVisitPreview ? 'initial' : 'follow_up',
        answers: answers,
        extraMemo: _extraMemoController.text.trim(),
        adherence: {
          'stretchingDone': _taskHasAnyCheck(_stretchingWeek),
          'caffeineDone': _taskHasAnyCheck(_caffeineWeek),
          'sleepLogDone': _taskHasAnyCheck(_sleepWeek),
          'stretchingWeekdays': List<bool>.from(_stretchingWeek),
          'caffeineWeekdays': List<bool>.from(_caffeineWeek),
          'sleepWeekdays': List<bool>.from(_sleepWeek),
          'dailyNotes': {
            'date': _dateKey(DateTime.now()),
            'stretching': _stretchingNoteController.text.trim(),
            'caffeine': _caffeineNoteController.text.trim(),
            'sleep': _sleepNoteController.text.trim(),
          },
          'percent': _adherencePercent(),
          'patientPhone': _currentProfile.phone,
          'patientEmail': _currentProfile.email,
        },
        currentQuestionIndex: _currentQuestionIndex + 1,
      );

      await AppFirestoreService.markPendingRequestsCompleted(
        patientId: _currentProfile.id,
        clinicId: clinicId,
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
            lang.tr(
              'Failed to save your submission: $error',
              '제출 저장에 실패했습니다: $error',
            ),
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
    final ethnicityController = TextEditingController(
      text: _currentProfile.ethnicity,
    );
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
                    decoration: InputDecoration(
                      labelText: lang.tr('Name', '이름'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Phone', '전화번호'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Email', '이메일'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: birthYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lang.tr('Birth Year', '출생연도'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sexController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Sex / Gender', '성별'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ethnicityController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Ethnicity', '인종/민족'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: memoController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: lang.tr('Memo', '메모'),
                    ),
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
                  birthYear:
                      int.tryParse(birthYearController.text.trim()) ??
                      _currentProfile.birthYear,
                  sex: sexController.text.trim().isEmpty
                      ? _currentProfile.sex
                      : sexController.text.trim(),
                  ethnicity: ethnicityController.text.trim().isEmpty
                      ? _currentProfile.ethnicity
                      : ethnicityController.text.trim(),
                  memo: memoController.text.trim(),
                );

                if (_activeSession != null) {
                  await PatientProfileService.saveProfile(updated);
                  if (mounted) {
                    setState(() {
                      _sessionBackedProfile = updated;
                    });
                  }
                } else {
                  _store.saveProfile(updated);
                  _store.setCurrentPatientProfile(updated.id);
                  if (mounted) {
                    setState(() {});
                  }
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

  List<ScheduledVisit> get _history => _activeClinicId == null
      ? const []
      : _store.historyForPatient(_currentProfile.id, clinicId: _activeClinicId);

  bool _matchesActiveClinicDoc(Map<String, dynamic> data) {
    final activeClinicId = _activeClinicId;
    if (activeClinicId == null || activeClinicId.isEmpty) {
      return false;
    }
    final clinicId = (data['clinicId'] ?? '').toString();
    return clinicId == activeClinicId;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<String> _safeStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Map<String, dynamic>> _safeAnswerItems(dynamic raw) {
    if (raw is! Iterable) {
      return const [];
    }
    return raw.map((item) => _safeMap(item)).toList();
  }

  Future<void> _openSubmissionDetail(Map<String, dynamic> data) async {
    final lang = AppLanguageController.instance;
    final answers = _safeAnswerItems(data['answers']);
    final adherence = _safeMap(data['adherence']);
    final extraMemo = (data['extraMemo'] ?? '').toString().trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(lang.tr('Previous Submission', '이전 제출 내용')),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lang.tr('Submitted at', '제출 시각')}: ${_formatTimestamp(data['submittedAt'] as Timestamp?)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${lang.tr('Visit type', '문진 유형')}: ${((data['visitType'] ?? 'follow_up').toString() == 'initial') ? lang.tr('Initial visit intake', '초진 문진') : lang.tr('Follow-up intake', '재진 문진')}',
                  ),
                  const SizedBox(height: 12),
                  if (extraMemo.isNotEmpty) ...[
                    Text(
                      lang.tr('Extra memo', '추가 메모'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(extraMemo),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    lang.tr('Saved answers', '저장된 답변'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (answers.isEmpty)
                    Text(
                      lang.tr(
                        'No answer details were saved for this submission.',
                        '이 제출에는 저장된 답변 상세가 없습니다.',
                      ),
                    )
                  else
                    ...answers.map((item) {
                      final question = (item['questionText'] ?? '')
                          .toString()
                          .trim();
                      final answer = (item['answerText'] ?? '')
                          .toString()
                          .trim();
                      final tags = <String>[
                        if (item['markedMainPain'] == true)
                          lang.tr('Main concern', '중요 통증'),
                        if (item['markedRemember'] == true)
                          lang.tr('Remember', '기억할 것'),
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.ink,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question.isEmpty
                                    ? lang.tr('Saved question', '저장된 질문')
                                    : question,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(answer.isEmpty ? '-' : answer),
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  tags.join(' · '),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.64,
                                        ),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  if (adherence.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      lang.tr('Checklist snapshot', '체크리스트 상태'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${lang.tr('Completion', '완료율')}: ${((((adherence['percent'] as num?)?.toDouble() ?? 0) * 100).round())}%',
                    ),
                    Text(
                      '${lang.tr('Stretching', '스트레칭')}: ${_savedWeekCount(adherence, 'stretchingWeekdays', 'stretchingDone')}/5 ${lang.tr('days', '일')}',
                    ),
                    Text(
                      '${lang.tr('Reduce caffeine', '카페인 조절')}: ${_savedWeekCount(adherence, 'caffeineWeekdays', 'caffeineDone')}/5 ${lang.tr('days', '일')}',
                    ),
                    Text(
                      '${lang.tr('Sleep log', '수면 기록')}: ${_savedWeekCount(adherence, 'sleepWeekdays', 'sleepLogDone')}/5 ${lang.tr('days', '일')}',
                    ),
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
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restoreSubmissionDraft(data);
              },
              icon: const Icon(Icons.refresh_outlined),
              label: Text(lang.tr('Load into form', '문진으로 다시 불러오기')),
            ),
          ],
        );
      },
    );
  }

  void _restoreSubmissionDraft(Map<String, dynamic> data) {
    final lang = AppLanguageController.instance;
    final isInitial =
        (data['visitType'] ?? 'follow_up').toString() == 'initial';
    final answers = _safeAnswerItems(data['answers']);
    final targetAnswers = isInitial ? _initialVisitAnswers : _followUpAnswers;
    final targetMainPain = isInitial
        ? _initialMainPainQuestionIndexes
        : _followUpMainPainQuestionIndexes;
    final targetRemember = isInitial
        ? _initialRememberQuestionIndexes
        : _followUpRememberQuestionIndexes;
    final questionCount = isInitial
        ? _initialVisitQuestions.length
        : _followUpQuestions.length;

    targetAnswers.clear();
    targetMainPain.clear();
    targetRemember.clear();

    for (final item in answers) {
      final index = ((item['questionIndex'] as num?)?.toInt() ?? 1) - 1;
      if (index < 0 || index >= questionCount) {
        continue;
      }
      final answer = (item['answerText'] ?? '').toString().trim();
      if (answer.isNotEmpty) {
        targetAnswers[index] = answer;
      }
      if (item['markedMainPain'] == true) {
        targetMainPain.add(index);
      }
      if (item['markedRemember'] == true) {
        targetRemember.add(index);
      }
    }

    final adherence = _safeMap(data['adherence']);
    final restoredIndex =
        (((data['currentQuestionIndex'] as num?)?.toInt() ?? 1) - 1).clamp(
          0,
          questionCount - 1,
        );

    setState(() {
      _isFirstVisitPreview = isInitial;
      _currentQuestionIndex = restoredIndex;
      _answerController.text = targetAnswers[_currentQuestionIndex] ?? '';
      _extraMemoController.text = (data['extraMemo'] ?? '').toString().trim();
      _replaceWeekValues(
        _stretchingWeek,
        _restoreWeekdayChecks(
          adherence['stretchingWeekdays'],
          fallback: adherence['stretchingDone'] == true,
        ),
      );
      _replaceWeekValues(
        _caffeineWeek,
        _restoreWeekdayChecks(
          adherence['caffeineWeekdays'],
          fallback: adherence['caffeineDone'] == true,
        ),
      );
      _replaceWeekValues(
        _sleepWeek,
        _restoreWeekdayChecks(
          adherence['sleepWeekdays'],
          fallback: adherence['sleepLogDone'] == true,
        ),
      );
      final dailyNotes = adherence['dailyNotes'] is Map
          ? (adherence['dailyNotes'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      _stretchingNoteController.text = (dailyNotes['stretching'] ?? '')
          .toString();
      _caffeineNoteController.text = (dailyNotes['caffeine'] ?? '').toString();
      _sleepNoteController.text = (dailyNotes['sleep'] ?? '').toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.tr(
            'Loaded your previous submission back into the form.',
            '이전에 제출한 내용을 현재 문진으로 다시 불러왔습니다.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCompetitorStyleScreen(context);
    /*
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final history = _history;
    final latestVisit = history.isNotEmpty ? history.first.visit : null;
    final progress = (_currentQuestionIndex + 1) / _activeQuestions.length;
    final answeredCount =
        _activeAnswers.values.where((value) => value.trim().isNotEmpty).length;
    final remainingCount = _activeQuestions.length - answeredCount;
    return PatientShell(
      currentItem: PatientNavItem.intake,
      title: lang.tr('Patient Intake', '환자 사전 문진'),
      actions: [
        IconButton(
          tooltip: lang.tr('Edit profile', '프로필 수정'),
          onPressed: _openProfileDialog,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const LanguageMenuButton(),
      ],
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
    */
  }

  Widget _buildCompetitorStyleScreen(BuildContext context) {
    final lang = AppLanguageController.instance;
    final theme = Theme.of(context);
    final profile = _currentProfile;
    final activeClinic = _store.activeClinicForPatient(profile.id);
    final history = _history;
    final latestVisit = history.isNotEmpty ? history.first.visit : null;
    final progress = (_currentQuestionIndex + 1) / _activeQuestions.length;
    final answeredCount = _activeAnswers.values
        .where((value) => value.trim().isNotEmpty)
        .length;
    final remainingCount = _activeQuestions.length - answeredCount;
    final modeLabel = _isFirstVisitPreview
        ? lang.tr('Initial visit', '초진')
        : lang.tr('Follow-up', '재진');

    _queueChecklistReminderIfNeeded();

    return PatientShell(
      currentItem: PatientNavItem.intake,
      title: lang.tr('Patient Intake', '환자 사전 문진'),
      actions: [
        IconButton(
          tooltip: lang.tr('Edit profile', '프로필 수정'),
          onPressed: _openProfileDialog,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        const LanguageMenuButton(),
      ],
      body: SingleChildScrollView(
        primary: true,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('answer_requests')
              .where('patientId', isEqualTo: profile.id)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, requestSnapshot) {
            final requestDocs = [...?requestSnapshot.data?.docs];
            requestDocs.sort((a, b) {
              final aTime =
                  (a.data()['requestedAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              final bTime =
                  (b.data()['requestedAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              return bTime.compareTo(aTime);
            });
            requestDocs.removeWhere(
              (doc) => !_matchesActiveClinicDoc(doc.data()),
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('intake_submissions')
                  .where('patientId', isEqualTo: profile.id)
                  .snapshots(),
              builder: (context, submissionSnapshot) {
                final submissionDocs = [...?submissionSnapshot.data?.docs];
                submissionDocs.sort((a, b) {
                  final aTime =
                      (a.data()['submittedAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  final bTime =
                      (b.data()['submittedAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  return bTime.compareTo(aTime);
                });
                submissionDocs.removeWhere(
                  (doc) => !_matchesActiveClinicDoc(doc.data()),
                );

                final latestSubmission = submissionDocs.isNotEmpty
                    ? submissionDocs.first.data()
                    : null;

                final hero = AppPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Patient intake workspace', '환자 문진 작업 화면'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        lang.tr(
                          'Tell your practitioner what changed before the visit',
                          '방문 전 현재 상태 변화를 바로 전달하세요',
                        ),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        lang.tr(
                          'This page is for finishing your intake in one clear flow. Start with the steps below, then answer the current question in the main panel.',
                          '이 화면은 한 흐름 안에서 문진을 끝내기 위한 곳입니다. 아래 순서부터 확인한 뒤, 메인 패널에서 현재 질문에 답하면 됩니다.',
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PatientClinicContextPanel(
                        clinic: activeClinic,
                        onChooseClinic: () => Navigator.pushNamed(
                          context,
                          PatientHomeScreen.routeName,
                        ),
                      ),
                      if (_showStartGuide) const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          AppMetricChip(
                            icon: Icons.assignment_outlined,
                            label: lang.tr('Mode', '모드'),
                            value: modeLabel,
                            backgroundColor: AppTheme.surface,
                            labelColor: AppTheme.ink.withValues(alpha: 0.58),
                            valueColor: AppTheme.ink,
                          ),
                          AppMetricChip(
                            icon: Icons.stacked_line_chart_outlined,
                            label: lang.tr('Progress', '진행도'),
                            value:
                                '$answeredCount / ${_activeQuestions.length}',
                            backgroundColor: AppTheme.surface,
                            labelColor: AppTheme.ink.withValues(alpha: 0.58),
                            valueColor: AppTheme.ink,
                          ),
                          AppMetricChip(
                            icon: Icons.mark_email_unread_outlined,
                            label: lang.tr('Pending requests', '대기 요청'),
                            value: '${requestDocs.length}',
                            backgroundColor: AppTheme.surface,
                            labelColor: AppTheme.ink.withValues(alpha: 0.58),
                            valueColor: AppTheme.ink,
                          ),
                          AppMetricChip(
                            icon: Icons.verified_user_outlined,
                            label: lang.tr('Profile', '프로필'),
                            value: profile.hasRequiredAlertInfo
                                ? lang.tr('Ready', '준비됨')
                                : lang.tr('Needs update', '업데이트 필요'),
                            backgroundColor: AppTheme.surface,
                            labelColor: AppTheme.ink.withValues(alpha: 0.58),
                            valueColor: AppTheme.ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_showStartGuide)
                        Text(
                          lang.tr('Start here', '여기부터 시작'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      if (_showStartGuide)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: lang.tr('Hide guide', '가이드 숨기기'),
                            onPressed: () {
                              setState(() => _showStartGuide = false);
                            },
                            icon: const Icon(Icons.close),
                            color: AppTheme.ink.withValues(alpha: 0.72),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      if (_showStartGuide) const SizedBox(height: 12),
                      if (_showStartGuide)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            AppGuideStep(
                              dark: false,
                              step: '1',
                              title: lang.tr(
                                'Review requests first',
                                '먼저 요청 확인',
                              ),
                              description: requestDocs.isEmpty
                                  ? lang.tr(
                                      'There are no pending practitioner requests right now.',
                                      '현재 대기 중인 침술사 요청은 없습니다.',
                                    )
                                  : lang.tr(
                                      '${requestDocs.length} request(s) are waiting in the support panel.',
                                      '지원 패널에 확인할 요청이 ${requestDocs.length}건 있습니다.',
                                    ),
                            ),
                            AppGuideStep(
                              dark: false,
                              step: '2',
                              title: lang.tr(
                                'Answer the current question',
                                '현재 질문에 답변',
                              ),
                              description: lang.tr(
                                'The main panel keeps the question, extra note, and navigation together so you can move top to bottom without guessing.',
                                '메인 패널 안에 질문, 추가 메모, 이동 버튼을 함께 두어 위에서 아래로 자연스럽게 진행할 수 있게 했습니다.',
                              ),
                            ),
                            AppGuideStep(
                              dark: false,
                              step: '3',
                              title: lang.tr('Submit when ready', '준비되면 제출'),
                              description: profile.hasRequiredAlertInfo
                                  ? lang.tr(
                                      'Your contact info is saved, so you can submit as soon as you finish answering.',
                                      '연락처가 저장되어 있으므로 답변을 마치면 바로 제출할 수 있습니다.',
                                    )
                                  : lang.tr(
                                      'Add both your phone number and email first, then submit the intake.',
                                      '전화번호와 이메일을 먼저 모두 입력한 뒤 문진을 제출하세요.',
                                    ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              PatientRequestsScreen.routeName,
                            ),
                            icon: const Icon(Icons.mark_email_unread_outlined),
                            label: Text(lang.tr('Open Requests', '답변 요청 보기')),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openProfileDialog,
                            icon: const Icon(Icons.account_circle_outlined),
                            label: Text(lang.tr('Edit Profile', '프로필 수정')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              VisitHistoryScreen.routeName,
                            ),
                            icon: const Icon(Icons.history),
                            label: Text(lang.tr('Visit History', '방문 기록')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final formPanel = AppPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Current intake form', '현재 문진 작성'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isFirstVisitPreview
                            ? lang.tr(
                                'Use the full 10-category structure for a first visit.',
                                '초진은 10개 카테고리를 모두 확인하는 전체 구조를 사용합니다.',
                              )
                            : lang.tr(
                                'Use focused follow-up questions based on the last visit and practitioner guidance.',
                                '재진은 지난 방문 기록과 침술사 안내를 바탕으로 한 추적 질문 흐름을 사용합니다.',
                              ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.74),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lang.tr('Question mode', '문진 모드'),
                        style: theme.textTheme.titleLarge,
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
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Intake progress', '문진 진행 상태'),
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lang.tr(
                                'Question ${_currentQuestionIndex + 1}/${_activeQuestions.length} | $remainingCount remaining',
                                '질문 ${_currentQuestionIndex + 1}/${_activeQuestions.length} | 남은 질문 $remainingCount개',
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.tr(
                                '$answeredCount answered so far',
                                '지금까지 $answeredCount개 답변 완료',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.68),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (requestDocs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            lang.tr(
                              '${requestDocs.length} practitioner request(s) are still pending. Keep those follow-up points in mind while answering this form.',
                              '아직 ${requestDocs.length}건의 침술사 요청이 남아 있습니다. 아래 문진에 답할 때 그 후속 질문들을 함께 참고하세요.',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr(
                                'Question ${_currentQuestionIndex + 1}',
                                '질문 ${_currentQuestionIndex + 1}',
                              ),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.62),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _activeQuestions[_currentQuestionIndex].text(
                                lang,
                              ),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _answerController,
                              minLines: 5,
                              maxLines: 8,
                              decoration: InputDecoration(
                                hintText: lang.tr(
                                  'Write your answer here in as much detail as you want.',
                                  '답변을 적어주세요. 편한 만큼 자세히 적어도 됩니다.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _extraMemoController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: lang.tr(
                                  'Extra note for your practitioner',
                                  '침술사에게 추가로 남길 메모',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilterChip(
                                  selected: _activeMainPainQuestionIndexes
                                      .contains(_currentQuestionIndex),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _activeMainPainQuestionIndexes.add(
                                          _currentQuestionIndex,
                                        );
                                      } else {
                                        _activeMainPainQuestionIndexes.remove(
                                          _currentQuestionIndex,
                                        );
                                      }
                                    });
                                  },
                                  avatar:
                                      _activeMainPainQuestionIndexes.contains(
                                        _currentQuestionIndex,
                                      )
                                      ? const Icon(
                                          Icons.local_fire_department,
                                          size: 18,
                                        )
                                      : null,
                                  label: Text(
                                    lang.tr(
                                      'This is my main pain',
                                      '이게 메인 통증이에요',
                                    ),
                                  ),
                                ),
                                FilterChip(
                                  selected: _activeRememberQuestionIndexes
                                      .contains(_currentQuestionIndex),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _activeRememberQuestionIndexes.add(
                                          _currentQuestionIndex,
                                        );
                                      } else {
                                        _activeRememberQuestionIndexes.remove(
                                          _currentQuestionIndex,
                                        );
                                      }
                                    });
                                  },
                                  avatar:
                                      _activeRememberQuestionIndexes.contains(
                                        _currentQuestionIndex,
                                      )
                                      ? const Icon(Icons.push_pin, size: 18)
                                      : null,
                                  label: Text(
                                    lang.tr(
                                      'Please remember this',
                                      '기억해줬으면 해요',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, buttonConstraints) {
                                final stacked =
                                    buttonConstraints.maxWidth < 540;
                                if (stacked) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _currentQuestionIndex == 0
                                            ? null
                                            : () => _changeQuestion(
                                                _currentQuestionIndex - 1,
                                              ),
                                        child: Text(
                                          lang.tr('Previous Question', '이전 질문'),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed:
                                            _currentQuestionIndex ==
                                                _activeQuestions.length - 1
                                            ? null
                                            : () => _changeQuestion(
                                                _currentQuestionIndex + 1,
                                              ),
                                        child: Text(
                                          lang.tr('Next Question', '다음 질문'),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _currentQuestionIndex == 0
                                            ? null
                                            : () => _changeQuestion(
                                                _currentQuestionIndex - 1,
                                              ),
                                        child: Text(
                                          lang.tr('Previous Question', '이전 질문'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed:
                                            _currentQuestionIndex ==
                                                _activeQuestions.length - 1
                                            ? null
                                            : () => _changeQuestion(
                                                _currentQuestionIndex + 1,
                                              ),
                                        child: Text(
                                          lang.tr('Next Question', '다음 질문'),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : _submitCurrentIntake,
                              icon: Icon(
                                _isSubmitting
                                    ? Icons.hourglass_top
                                    : Icons.task_alt,
                              ),
                              label: Text(
                                _isSubmitting
                                    ? lang.tr('Submitting...', '제출 중...')
                                    : lang.tr('Submit Intake', '문진 제출하기'),
                              ),
                            ),
                            if (!profile.hasRequiredAlertInfo) ...[
                              const SizedBox(height: 12),
                              Text(
                                lang.tr(
                                  'Add both your phone number and email before submitting.',
                                  '제출 전에 전화번호와 이메일을 모두 입력해주세요.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF8A4B10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                final checklistPanel = AppPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('This week checklist', '이번 주 체크리스트'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'Keep the visit prep items visible while you complete the intake, and check off each weekday you followed through.',
                          '문진을 작성하는 동안 방문 준비 항목을 함께 보고, 실제로 지킨 요일만 월-금으로 체크해둘 수 있습니다.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.56),
                          ),
                        ),
                        child: Text(
                          _todayChecklistIndex() == null
                              ? lang.tr(
                                  'Weekday tracking is locked today. Come back Monday through Friday to check the matching day.',
                                  '오늘은 주중 체크일이 아닙니다. 월요일부터 금요일 사이에 해당 요일만 체크할 수 있습니다.',
                                )
                              : _missingTodayChecklistItems(lang).isEmpty
                              ? lang.tr(
                                  'Today is complete. Older and future weekdays stay locked.',
                                  '오늘 체크는 완료되었습니다. 지난 요일과 앞으로 올 요일은 잠겨 있습니다.',
                                )
                              : lang.tr(
                                  'Today only: ${_todayChecklistLabel(lang)}. Please check only the items you completed today.',
                                  '오늘만 체크 가능: ${_todayChecklistLabel(lang)}. 오늘 실제로 한 항목만 체크해주세요.',
                                ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _adherencePercent(),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'Completion ${(100 * _adherencePercent()).round()}%',
                          '완료율 ${(100 * _adherencePercent()).round()}%',
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildWeekdayChecklistRow(
                        context,
                        lang: lang,
                        labelEn: 'Bedtime stretching',
                        labelKo: '취침 전 스트레칭',
                        values: _stretchingWeek,
                        noteController: _stretchingNoteController,
                      ),
                      const SizedBox(height: 16),
                      _buildWeekdayChecklistRow(
                        context,
                        lang: lang,
                        labelEn: 'Reduce caffeine after 2 PM',
                        labelKo: '오후 카페인 조절',
                        values: _caffeineWeek,
                        noteController: _caffeineNoteController,
                      ),
                      const SizedBox(height: 16),
                      _buildWeekdayChecklistRow(
                        context,
                        lang: lang,
                        labelEn: 'Track sleep and fatigue',
                        labelKo: '수면/피로 기록',
                        values: _sleepWeek,
                        noteController: _sleepNoteController,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _saveChecklistDraft(),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(lang.tr('Save checklist', '체크리스트 저장')),
                          ),
                          Text(
                            lang.tr(
                              'Saved checks and notes stay here when you leave this screen.',
                              '체크와 메모는 다른 화면에 갔다 와도 유지됩니다.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final statusPanel = AppPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Before you submit', '제출 전 확인'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'Use this support column to quickly verify profile details, latest activity, and any open tasks before you submit.',
                          '이 지원 영역에서 제출 전에 프로필, 최근 활동, 열려 있는 작업을 빠르게 확인할 수 있습니다.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          InkWell(
                            onTap: _openProfileDialog,
                            borderRadius: BorderRadius.circular(18),
                            child: AppMetricChip(
                              icon: Icons.person_outline,
                              label: lang.tr('Profile', '프로필'),
                              value: profile.hasRequiredAlertInfo
                                  ? lang.tr('Ready', '준비됨')
                                  : lang.tr('Incomplete', '미완성'),
                              backgroundColor: AppTheme.surfaceSoft.withValues(
                                alpha: 0.7,
                              ),
                              valueColor: profile.hasRequiredAlertInfo
                                  ? AppTheme.pine
                                  : AppTheme.copper,
                            ),
                          ),
                          AppMetricChip(
                            icon: Icons.assignment_turned_in_outlined,
                            label: lang.tr('Latest intake', '최근 문진'),
                            value: latestSubmission == null
                                ? lang.tr('None yet', '아직 없음')
                                : ((latestSubmission['visitType'] as String?) ==
                                          'initial'
                                      ? lang.tr('Initial', '초진')
                                      : lang.tr('Follow-up', '재진')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${lang.tr('Name', '이름')}: ${profile.name}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? '-' : profile.phone}',
                      ),
                      Text(
                        '${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? '-' : profile.email}',
                      ),
                      Text(
                        '${lang.tr('Profile', '프로필')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
                      ),
                      if (latestSubmission != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          lang.tr(
                            'Last submitted at ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}',
                            '최근 제출 시각: ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                      if (!profile.hasRequiredAlertInfo) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            lang.tr(
                              'Please add both your phone number and email so your practitioner can reach you for real testing.',
                              '실제 테스트를 위해 전화번호와 이메일을 모두 입력해주세요.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openProfileDialog,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(lang.tr('Update Profile', '프로필 업데이트')),
                        ),
                      ],
                    ],
                  ),
                );

                final requestPanel = AppPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requestDocs.isNotEmpty
                            ? lang.tr(
                                'Practitioner requests (${requestDocs.length})',
                                '침술사 요청 ${requestDocs.length}건',
                              )
                            : lang.tr('Practitioner requests', '침술사 요청'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'This is the request inbox for follow-up questions tied to your next visit.',
                          '다음 방문과 연결된 후속 질문 요청을 확인하는 영역입니다.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (requestDocs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            lang.tr(
                              'No pending requests right now.',
                              '현재 대기 중인 요청이 없습니다.',
                            ),
                          ),
                        ),
                      ...requestDocs.take(3).map((doc) {
                        final data = doc.data();
                        final selected = _safeStringList(
                          data['selectedQuestions'],
                        );
                        final note = (data['note'] as String?)?.trim() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr(
                                    'Requested at ${_formatTimestamp(data['requestedAt'] as Timestamp?)}',
                                    '요청 시각 ${_formatTimestamp(data['requestedAt'] as Timestamp?)}',
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.62),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lang.tr(
                                    'Requested questions: ${selected.length}',
                                    '요청된 질문 수: ${selected.length}',
                                  ),
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (selected.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...selected
                                      .take(3)
                                      .map(
                                        (question) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text('- $question'),
                                        ),
                                      ),
                                ],
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${lang.tr('Note', '메모')}: $note',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          PatientRequestsScreen.routeName,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          lang.tr('Open full request inbox', '전체 요청함 열기'),
                        ),
                      ),
                    ],
                  ),
                );

                final visitPanel = latestVisit == null
                    ? const SizedBox.shrink()
                    : AppPanel(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Last visit summary', '지난 방문 요약'),
                              style: theme.textTheme.titleLarge,
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
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                VisitHistoryScreen.routeName,
                              ),
                              icon: const Icon(Icons.history),
                              label: Text(
                                lang.tr('Review visit history', '방문 기록 보기'),
                              ),
                            ),
                          ],
                        ),
                      );

                final submissionPanel = AppPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Recent submissions', '최근 제출 기록'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'Use this list to confirm what you already sent most recently.',
                          '가장 최근에 어떤 문진을 보냈는지 빠르게 확인하는 영역입니다.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      if (submissionDocs.isEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            lang.tr('No submissions yet.', '아직 제출 기록이 없습니다.'),
                          ),
                        ),
                      ],
                      ...submissionDocs.take(3).map((doc) {
                        final data = doc.data();
                        final answers = (data['answers'] as List?)?.length ?? 0;
                        final visitType =
                            (data['visitType'] as String?) ?? 'follow_up';
                        final extraMemo = (data['extraMemo'] as String? ?? '')
                            .trim();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.border),
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
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lang.tr(
                                    'Answered questions: $answers',
                                    '답변한 질문 수: $answers',
                                  ),
                                ),
                                Text(
                                  lang.tr(
                                    'Submitted at ${_formatTimestamp(data['submittedAt'] as Timestamp?)}',
                                    '제출 시각 ${_formatTimestamp(data['submittedAt'] as Timestamp?)}',
                                  ),
                                ),
                                if (extraMemo.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${lang.tr('Memo', '메모')}: $extraMemo',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openSubmissionDetail(data),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: Text(lang.tr('Review', '다시 보기')),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () =>
                                          _restoreSubmissionDraft(data),
                                      icon: const Icon(Icons.refresh_outlined),
                                      label: Text(
                                        lang.tr('Load into form', '문진으로 불러오기'),
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
                );

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 980;

                          final mainColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              formPanel,
                              const SizedBox(height: 16),
                              checklistPanel,
                            ],
                          );

                          final sideColumn = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              statusPanel,
                              const SizedBox(height: 16),
                              requestPanel,
                              if (latestVisit != null) ...[
                                const SizedBox(height: 16),
                                visitPanel,
                              ],
                              const SizedBox(height: 16),
                              submissionPanel,
                            ],
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              hero,
                              const SizedBox(height: 16),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: mainColumn),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 5, child: sideColumn),
                                  ],
                                )
                              else ...[
                                mainColumn,
                                const SizedBox(height: 16),
                                sideColumn,
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
