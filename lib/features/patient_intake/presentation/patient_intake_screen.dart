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
    'ì²´ì˜¨ì´ë‚˜ ë•€ì˜ ë³€í™”ê°€ ìžˆì—ˆë‚˜ìš”? ì‰½ê²Œ ë¥ê±°ë‚˜ ì¶¥ê³ , ì‹ì€ë•€ì´ë‚˜ ìží•œì´ ìžˆì—ˆëŠ”ì§€ë„ ì•Œë ¤ì£¼ì„¸ìš”.',
    'ì‹ìš•ê³¼ ê°ˆì¦ì€ ì–´ë• ë‚˜ìš”? ë¬¼ì„ ìžì£¼ ì°¾ëŠ”ì§€, ì°¨ê°€ìš´ ìŒë£Œë¥¼ ì„ í˜¸í•˜ëŠ”ì§€ë„ ì•Œë ¤ì£¼ì„¸ìš”.',
    'ìˆ˜ë©´ì€ ì–´ë– ì…¨ë‚˜ìš”? ìž ë“œëŠ” ì‹œê°„, ìžì£¼ ê¹¨ëŠ”ì§€, ê¿ˆì´ ë§Žì€ì§€ë„ ì ì–´ì£¼ì„¸ìš”.',
    'ì†Œí™”ëŠ” ì–´ë– ì…¨ë‚˜ìš”? ë”ë¶€ë£©í•¨, ì†ì“°ë¦¼, ì—­ë¥˜, ê°€ìŠ¤, íŠ¸ë¦¼ ë³€í™”ë¥¼ ì•Œë ¤ì£¼ì„¸ìš”.',
    'ì†Œë³€ì€ ì–´ë– ì…¨ë‚˜ìš”? íšŸìˆ˜, ìƒ‰, ì•¼ê°„ë‡¨, ê¸‰í•œ ëŠë‚Œì´ ìžˆì—ˆëŠ”ì§€ ì ì–´ì£¼ì„¸ìš”.',
    'ë°°ë³€ì€ ì–´ë– ì…¨ë‚˜ìš”? íšŸìˆ˜, êµ³ê¸°, ë³€ë¹„ë‚˜ ì„¤ì‚¬ ê²½í–¥ì„ ì•Œë ¤ì£¼ì„¸ìš”.',
    'ìƒë¦¬ ê´€ë ¨ ë³€í™”ê°€ ìžˆì—ˆë‚˜ìš”? ì£¼ê¸°, ì–‘, í†µì¦, í˜ˆìƒ‰ì´ í‰ì†Œì™€ ë‹¬ëžëŠ”ì§€ ì ì–´ì£¼ì„¸ìš”.',
    'ë¨¸ë¦¬/ëˆˆ/ê·€/ì½”/ëª© ìª½ ë¶ˆíŽ¸ê°ì´ ìžˆì—ˆë‚˜ìš”? ë‘í†µ, ëˆˆí”¼ë¡œ, ì½”ë§‰íž˜, ëª© ê±´ì¡° ë“±ì„ ì•Œë ¤ì£¼ì„¸ìš”.',
    'ê°ì •ì´ë‚˜ ìŠ¤íŠ¸ë ˆìŠ¤ëŠ” ì–´ë• ë‚˜ìš”? ì˜ˆë¯¼í•¨, ë‹µë‹µí•¨, ë¶ˆì•ˆ, ì§œì¦ ë³€í™”ê°€ ìžˆì—ˆëŠ”ì§€ ì ì–´ì£¼ì„¸ìš”.',
    'ê¸°ë ¥ê³¼ ê¸°íƒ€ ì¦ìƒì€ ì–´ë• ë‚˜ìš”? í•˜ë£¨ ì¤‘ íŠ¹ížˆ íž˜ë“  ì‹œê°„ê³¼ ê¼­ ë§í•˜ê³  ì‹¶ì€ ì¦ìƒì„ ì ì–´ì£¼ì„¸ìš”.',
  ];

  static const List<String> _followUpQuestions = [
    'ìµœê·¼ ìˆ˜ë©´ì€ ì–´ë– ì…¨ë‚˜ìš”?',
    'ì˜¤ëŠ˜ ê°€ìž¥ ë¶ˆíŽ¸í•œ ë¶€ìœ„ëŠ” ì–´ë””ì¸ê°€ìš”?',
    'ì§€ë‚œë²ˆì— ì•ˆë‚´í•œ ìŠ¤íŠ¸ë ˆì¹­ì€ ì–¼ë§ˆë‚˜ ì§€í‚¤ì…¨ë‚˜ìš”?',
    'ì‹ìš•ê³¼ ê°ˆì¦ì€ ì§€ë‚œ ë°©ë¬¸ ì´í›„ ì–´ë–»ê²Œ ë³€í–ˆë‚˜ìš”?',
    'ì†Œí™” ìƒíƒœëŠ” ì–´ë• ë‚˜ìš”? ë”ë¶€ë£©í•¨ì´ë‚˜ ì†ì“°ë¦¼ì´ ìžˆì—ˆë‚˜ìš”?',
    'ì˜¤í›„ 2ì‹œ ì´í›„ ì¹´íŽ˜ì¸ ì¤„ì´ê¸°ëŠ” ì–´ëŠ ì •ë„ ì§€ì¼œì¡Œë‚˜ìš”?',
    'ë°°ë³€ì´ë‚˜ ì†Œë³€ì€ ì§€ë‚œë²ˆë³´ë‹¤ ë‹¬ë¼ì§„ ì ì´ ìžˆì—ˆë‚˜ìš”?',
    'ë‘í†µ, ëˆˆí”¼ë¡œ, ì½”ë§‰íž˜ ê°™ì€ HEENT ì¦ìƒì€ ì–´ë• ë‚˜ìš”?',
    'ìŠ¤íŠ¸ë ˆìŠ¤ë‚˜ ê°ì • ê¸°ë³µì€ ì–´ë• ë‚˜ìš”?',
    'í•˜ë£¨ ì¤‘ í”¼ë¡œê°€ ê°€ìž¥ ì‹¬í•´ì§€ëŠ” ì‹œê°„ì€ ì–¸ì œì¸ê°€ìš”?',
  ];

  final Map<int, String> _initialVisitAnswers = {};
  final Map<int, String> _followUpAnswers = {
    0: 'ìƒˆë²½ 3ì‹œì— ìžì£¼ ê¹¨ê³  ë‹¤ì‹œ ìž ë“¤ê¸° ì–´ë ¤ì›Œìš”.',
    1: 'ì˜¤ë¥¸ìª½ ì–´ê¹¨ í†µì¦ì´ ê°€ìž¥ ì‹¬í•´ìš”.',
    3: 'ìž…ì´ ìžì£¼ ë§ˆë¥´ê³  ì°¬ë¬¼ì„ ì°¾ê²Œ ë¼ìš”.',
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

  String get _questionModeTitle => _isFirstVisitPreview ? 'ì´ˆì§„ 10ì¹´í…Œê³ ë¦¬ ë¬¸ì§„' : 'ìž¬ì§„ ì¶”ì  ë¬¸ì§„';

  String get _questionModeDescription => _isFirstVisitPreview
      ? 'ì²˜ìŒ ë°©ë¬¸í•œ í™˜ìžì²˜ëŸ¼ 10ê°€ì§€ ê¸°ë³¸ ì¹´í…Œê³ ë¦¬ë¥¼ ì „ì²´ì ìœ¼ë¡œ í™•ì¸í•˜ëŠ” íë¦„ìž…ë‹ˆë‹¤.'
      : 'ì§€ë‚œ ë°©ë¬¸ ê¸°ë¡ê³¼ ì¹¨ìˆ ì‚¬ ì¡°ì–¸ì„ ë°”íƒ•ìœ¼ë¡œ ì¶”ì  ê´€ì°°ì´ í•„ìš”í•œ ë¶€ë¶„ì„ ì¤‘ì‹¬ìœ¼ë¡œ ë¬»ëŠ” íë¦„ìž…ë‹ˆë‹¤.';

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
          content: Text('ì „í™”ë²ˆí˜¸ì™€ ì´ë©”ì¼ì„ ëª¨ë‘ ìž…ë ¥í•´ì•¼ ì‹¤ì œ í…ŒìŠ¤íŠ¸ íë¦„ì„ í™•ì¸í•  ìˆ˜ ìžˆì–´ìš”.'),
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
        SnackBar(content: Text('ë¬¸ì§„ ì œì¶œ ì™„ë£Œ: $docId')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ë¬¸ì§„ ì €ìž¥ ì‹¤íŒ¨: $error')),
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
        title: const Text('í™˜ìž ì‚¬ì „ ë¬¸ì§„'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'ê³„ì • ë©”ë‰´',
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
                SnackBar(content: Text('$value ì¤€ë¹„ ì¤‘ìž…ë‹ˆë‹¤.')),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('ë‚´ í”„ë¡œí•„ ìˆ˜ì •')),
              PopupMenuItem(value: 'settings', child: Text('ì„¤ì •')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('í™˜ìž í™”ë©´'))),
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
                const Text('ë‚´ í”„ë¡œí•„', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${profile.name} Â· ${profile.sex} Â· ${profile.ageRange} Â· ${profile.ethnicity}'),
                const SizedBox(height: 6),
                Text('ì „í™”ë²ˆí˜¸: ${profile.phone.isEmpty ? 'ë¯¸ìž…ë ¥' : profile.phone}'),
                Text('ì´ë©”ì¼: ${profile.email.isEmpty ? 'ë¯¸ìž…ë ¥' : profile.email}'),
                const SizedBox(height: 8),
                Text(
                  'í˜„ìž¬ ë°ëª¨ í™˜ìž ê³„ì •ì€ ì´ í”„ë¡œí•„ì— ì—°ê²°ë©ë‹ˆë‹¤. ì´ë¦„, ì „í™”ë²ˆí˜¸, ì´ë©”ì¼ì„ ë³¸ì¸ ì •ë³´ë¡œ ë°”ê¾¸ë©´ ë‹µë³€ ìš”ì²­ í…ŒìŠ¤íŠ¸ë¥¼ ì§ì ‘ í™•ì¸í•  ìˆ˜ ìžˆì–´ìš”.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusPill(
                      label: profile.phone.isEmpty ? 'ì „í™”ë²ˆí˜¸ í•„ìš”' : 'ì „í™”ë²ˆí˜¸ ìž…ë ¥ ì™„ë£Œ',
                      good: profile.phone.isNotEmpty,
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: profile.email.isEmpty ? 'ì´ë©”ì¼ í•„ìš”' : 'ì´ë©”ì¼ ìž…ë ¥ ì™„ë£Œ',
                      good: profile.email.isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  profile.hasRequiredAlertInfo
                      ? 'ì•Œë¦¼ í…ŒìŠ¤íŠ¸ ì¤€ë¹„ ì™„ë£Œ: ì „í™”ë²ˆí˜¸ì™€ ì´ë©”ì¼ì´ ëª¨ë‘ ìž…ë ¥ë˜ì–´ ìžˆìŠµë‹ˆë‹¤.'
                      : 'ë‹µë³€ ìš”ì²­ì„ ì§„ì§œì²˜ëŸ¼ í…ŒìŠ¤íŠ¸í•˜ë ¤ë©´ ì „í™”ë²ˆí˜¸ì™€ ì´ë©”ì¼ì„ ëª¨ë‘ ìž…ë ¥í•´ ì£¼ì„¸ìš”.',
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
                  label: const Text('ë‚´ í”„ë¡œí•„ ìžì„¸ížˆ ìˆ˜ì •'),
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
                const Text('ì¹¨ìˆ ì‚¬ ë‹µë³€ ìš”ì²­', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'ì¹¨ìˆ ì‚¬ê°€ ë³´ë‚¸ ì§ˆë¬¸ ìš”ì²­ì´ ì—¬ê¸° ìŒ“ìž…ë‹ˆë‹¤. ì‹¤ì œ ì´ë©”ì¼/SMS ë°œì†¡ì€ ì•„ì§ ì—°ê²° ì „ì´ê³ , ì§€ê¸ˆì€ Firestore ì €ìž¥ê³¼ í™”ë©´ ë°˜ì˜ê¹Œì§€ í…ŒìŠ¤íŠ¸í•˜ëŠ” ë‹¨ê³„ì˜ˆìš”.',
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
                const Text('ë‚´ ìµœê·¼ ì œì¶œ ê¸°ë¡', style: TextStyle(fontWeight: FontWeight.w700)),
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
                const Text('ë¬¸ì§„ ëª¨ë“œ', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('ì´ˆì§„ ì˜ˆì‹œ'),
                      selected: _isFirstVisitPreview,
                      onSelected: (_) => _switchQuestionMode(true),
                    ),
                    ChoiceChip(
                      label: const Text('ìž¬ì§„ ì˜ˆì‹œ'),
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
                const Text('ì§€ë‚œ ë°©ë¬¸ ìš”ì•½', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (latestVisit == null)
                  const Text('ì•„ì§ ì €ìž¥ëœ ë°©ë¬¸ ê¸°ë¡ì´ ì—†ìŠµë‹ˆë‹¤.')
                else ...[
                  Text('ì§€ë‚œ ë°©ë¬¸ì¼: ${latestVisit.visit.date} (${latestVisit.visit.daysAgo}ì¼ ì „)'),
                  const SizedBox(height: 4),
                  Text('ê·¸ë‚  ì¹˜ë£Œ/ê¸°ë¡: ${latestVisit.visit.previousTreatmentArea}'),
                  const SizedBox(height: 4),
                  Text('ì¹¨ìˆ ì‚¬ ì½”ë©˜íŠ¸: ${latestVisit.visit.previousSessionNote}'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ì „ì²´ ížˆìŠ¤í† ë¦¬ ${history.length}ê±´',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openVisitHistorySheet(context, history),
                      child: const Text('ì „ì²´ ížˆìŠ¤í† ë¦¬ ë³´ê¸°'),
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
                  'ì´ë²ˆ ì£¼ í•´ì•¼í•  ê²ƒ (${_thisWeekRangeLabel()})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('1) ì·¨ì¹¨ 1ì‹œê°„ ì „ ìŠ¤íŠ¸ë ˆì¹­ 5ë¶„'),
                const Text('2) ì˜¤í›„ 2ì‹œ ì´í›„ ì¹´íŽ˜ì¸ ì¤„ì´ê¸°'),
                const Text('3) ìˆ˜ë©´/í”¼ë¡œ ë³€í™” ê°„ë‹¨ ê¸°ë¡'),
                const SizedBox(height: 12),
                Text('ë‚´ê°€ ì§€í‚¨ í•­ëª© ì²´í¬ ($adherence%)', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: adherence / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFD5F0EE),
                  color: const Color(0xFF0F766E),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ì·¨ì¹¨ ì „ ìŠ¤íŠ¸ë ˆì¹­'),
                  value: _stretchingDone,
                  onChanged: (value) => setState(() => _stretchingDone = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ì˜¤í›„ ì¹´íŽ˜ì¸ ì¡°ì ˆ'),
                  value: _caffeineDone,
                  onChanged: (value) => setState(() => _caffeineDone = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ìˆ˜ë©´/í”¼ë¡œ ê¸°ë¡ ìž‘ì„±'),
                  value: _sleepLogDone,
                  onChanged: (value) => setState(() => _sleepLogDone = value ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('ë¬¸ì§„ ì§„í–‰ ìƒíƒœ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFD5F0EE),
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          Text('ì§„í–‰ë¥  $answeredQuestions/$totalQuestions Â· ë‚¨ì€ ì§ˆë¬¸ $remainingê°œ'),
          const SizedBox(height: 4),
          Text(
            'ì²œì²œížˆ ê´œì°®ì•„ìš”. ì§€ê¸ˆì²˜ëŸ¼ í•˜ë‚˜ì”© ë‹µí•´ë„ ì¶©ë¶„í•´ìš”.',
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
                        'í˜„ìž¬ ì§ˆë¬¸ (${_currentQuestionIndex + 1}/$totalQuestions): ${_activeQuestions[_currentQuestionIndex]}',
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
                    hintText: 'ë‹µë³€ì„ ì ì–´ì£¼ì„¸ìš”.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _extraMemoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ì¶”ê°€ ë©”ëª¨ (ì¹¨ìˆ ì‚¬ì—ê²Œ ì „ë‹¬)',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _currentQuestionIndex == 0 ? null : () => _moveQuestion(-1),
                      child: const Text('ì´ì „ ì§ˆë¬¸'),
                    ),
                    OutlinedButton(
                      onPressed: _currentQuestionIndex == totalQuestions - 1
                          ? null
                          : () => _moveQuestion(1),
                      child: const Text('ë‹¤ìŒ ì§ˆë¬¸'),
                    ),
                    FilterChip(
                      label: Text(
                        isMainPainSelected ? 'ë©”ì¸ í†µì¦ìœ¼ë¡œ í‘œì‹œë¨' : 'ë©”ì¸ í†µì¦ì´ì—ìš”',
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
                        isRememberSelected ? 'ê¸°ì–µí•´ì¤¬ìœ¼ë©´ í‘œì‹œë¨' : 'ê¸°ì–µí•´ì¤¬ìœ¼ë©´ í•´ìš”',
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
                      const SnackBar(content: Text('ìž„ì‹œ ì €ìž¥ ì™„ë£Œ')),
                    );
                  },
                  child: const Text('ìž„ì‹œ ì €ìž¥'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitCurrentIntake,
                  child: Text(_isSubmitting ? 'ì œì¶œ ì¤‘...' : 'ì œì¶œí•˜ê¸°'),
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
              'ì „ì²´ ë°©ë¬¸ ížˆìŠ¤í† ë¦¬',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text('ì•„ì§ ë°©ë¬¸ ê¸°ë¡ì´ ì—†ìŠµë‹ˆë‹¤.')
            else
              ...history.map((item) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.visit.date} Â· ${item.visit.time}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('ì¹˜ë£Œ ë¶€ìœ„: ${item.visit.previousTreatmentArea}'),
                        const SizedBox(height: 4),
                        Text('ê¸°ë¡: ${item.visit.previousSessionNote}'),
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
        final pendingDocs = docs
            .where((doc) => (doc.data()['status'] as String? ?? 'pending') == 'pending')
            .toList();

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

        final latest = (pendingDocs.isNotEmpty ? pendingDocs.first : docs.first).data();
        final selectedQuestions =
            (latest['selectedQuestions'] as List<dynamic>? ?? const []);
        final note = (latest['note'] as String? ?? '').trim();
        final hasPending = pendingDocs.isNotEmpty;

        return Card(
          color: hasPending ? const Color(0xFFFFF3D6) : const Color(0xFFE9F7F4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasPending
                          ? Icons.campaign_outlined
                          : Icons.notifications_active_outlined,
                      color: hasPending
                          ? const Color(0xFF9A6700)
                          : const Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasPending
                          ? '새 답변 요청 ${pendingDocs.length}건'
                          : '침술사 답변 요청 ${docs.length}건',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: hasPending
                            ? const Color(0xFF9A6700)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasPending
                      ? '지금 확인할 질문 ${selectedQuestions.length}개'
                      : '가장 최근 요청 질문 수: ${selectedQuestions.length}개',
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('최근 메모: $note'),
                ],
                if (hasPending) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '아래 답변 요청 섹션에서 요청 내용을 확인하고 제출해 주세요.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
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

        final pendingDocs = docs
            .where((doc) => (doc.data()['status'] as String? ?? 'pending') == 'pending')
            .toList();
        final completedDocs = docs
            .where((doc) => (doc.data()['status'] as String? ?? '') == 'completed')
            .toList();
        final orderedDocs = [...pendingDocs, ...completedDocs];

        return Column(
          children: orderedDocs.take(3).map((doc) {
            final data = doc.data();
            final selectedQuestions =
                (data['selectedQuestions'] as List<dynamic>? ?? []).cast<String>();
            final note = (data['note'] as String? ?? '').trim();
            final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
            final status = (data['status'] as String? ?? 'pending');

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            requestedAt == null
                                ? '최근 답변 요청'
                                : '요청 시각: ${requestedAt.year}-${requestedAt.month.toString().padLeft(2, '0')}-${requestedAt.day.toString().padLeft(2, '0')} ${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _StatusPill(
                          label: status == 'completed' ? '응답 완료' : '새 요청',
                          good: status == 'completed',
                        ),
                      ],
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
          return Text('ì œì¶œ ê¸°ë¡ì„ ë¶ˆëŸ¬ì˜¤ì§€ ëª»í–ˆìŠµë‹ˆë‹¤: ${snapshot.error}');
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
          return const Text('ì•„ì§ ì œì¶œí•œ ë¬¸ì§„ì´ ì—†ìŠµë‹ˆë‹¤. ì œì¶œí•˜ë©´ ì—¬ê¸° ë°”ë¡œ ìŒ“ìž…ë‹ˆë‹¤.');
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
                          ? 'ë°©ê¸ˆ ì €ìž¥ëœ ë¬¸ì§„'
                          : 'ì œì¶œ ì‹œê°: ${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('ë¬¸ì§„ ìœ í˜•: ${visitType == 'initial' ? 'ì´ˆì§„' : 'ìž¬ì§„'}'),
                    Text('ì €ìž¥ëœ ë‹µë³€ ìˆ˜: ${answers.length}ê°œ'),
                    Text('ë¬¸ì„œ ID: ${doc.id}'),
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
      title: const Text('ë‚´ í”„ë¡œí•„ ìˆ˜ì •'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(_nameController, 'ì´ë¦„', required: true),
                const SizedBox(height: 10),
                _buildField(
                  _phoneController,
                  'ì „í™”ë²ˆí˜¸',
                  required: true,
                  hint: 'ì˜ˆ: 201-555-0101',
                ),
                const SizedBox(height: 10),
                _buildField(
                  _emailController,
                  'ì´ë©”ì¼',
                  required: true,
                  hint: 'ì˜ˆ: me@example.com',
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'ì´ë©”ì¼ì„ ìž…ë ¥í•´ ì£¼ì„¸ìš”.';
                    }
                    if (!text.contains('@')) {
                      return 'ì´ë©”ì¼ í˜•ì‹ìœ¼ë¡œ ìž…ë ¥í•´ ì£¼ì„¸ìš”.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _buildField(
                  _birthYearController,
                  'ì¶œìƒì—°ë„',
                  required: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildField(_sexController, 'ì„±ë³„', required: true),
                const SizedBox(height: 10),
                _buildField(_ethnicityController, 'ì¸ì¢…/ë¯¼ì¡±', required: true),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _memoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ë©”ëª¨',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ì „í™”ë²ˆí˜¸ì™€ ì´ë©”ì¼ì€ ì•žìœ¼ë¡œ ì‹¤ì œ ì´ë©”ì¼/SMS ì•Œë¦¼ ì—°ê²° í…ŒìŠ¤íŠ¸ë¥¼ ìœ„í•´ í•„ìˆ˜ë¡œ ë°›ìŠµë‹ˆë‹¤. ì§€ê¸ˆ ë‹¨ê³„ì—ì„œëŠ” Firestore ì €ìž¥ê³¼ í™”ë©´ ë°˜ì˜ê¹Œì§€ ë¨¼ì € í™•ì¸í•©ë‹ˆë‹¤.',
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
          child: const Text('ì·¨ì†Œ'),
        ),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            final birthYear = int.tryParse(_birthYearController.text.trim());
            if (birthYear == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ì¶œìƒì—°ë„ëŠ” ìˆ«ìžë¡œ ìž…ë ¥í•´ ì£¼ì„¸ìš”.')),
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
                  SnackBar(content: Text('í”„ë¡œí•„ ì €ìž¥ ì‹¤íŒ¨: $error')),
                );
              }
              return;
            }

            ClinicDataStore.instance.saveProfile(updated);
            Navigator.of(context).pop();
          },
          child: const Text('ì €ìž¥'),
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
              return '$label ìž…ë ¥ì´ í•„ìš”í•©ë‹ˆë‹¤.';
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

