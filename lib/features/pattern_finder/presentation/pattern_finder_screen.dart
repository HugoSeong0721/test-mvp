import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/services/pattern_finder_service.dart';
import '../../../core/services/question_bank_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/patient_shell.dart';

/// Guided TCM pattern finder: the patient answers one question at a time and
/// the flow converges on a pattern *direction* for their practitioner to
/// review. Deliberately not a chat — a fixed, reviewable question pool with
/// adaptive ordering (see PatternFinderService).
class PatternFinderScreen extends StatefulWidget {
  const PatternFinderScreen({super.key});

  static const routeName = '/pattern-finder';

  @override
  State<PatternFinderScreen> createState() => _PatternFinderScreenState();
}

enum _Stage { intro, basicInfo, questions, result }

class _PatternFinderScreenState extends State<PatternFinderScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  PatternFinderEngine _engine = PatternFinderEngine();
  _Stage _stage = _Stage.intro;
  PatternQuestion? _currentQuestion;
  PatientProfile? _sessionProfile;
  bool _isSharing = false;
  bool _shared = false;

  /// Optional baseline info collected before the questions. Never scored —
  /// passed to the practitioner as context (see toCarePicture docs).
  double? _heightCm;
  double? _weightKg;

  /// Optional tongue photo the patient attaches on the result screen. Not
  /// analysed by the app — sent to the practitioner for in-person review
  /// (see ADAPTIVE_TCM_INQUIRY_NOTES.md; ref: TongueVLM).
  Uint8List? _tongueBytes;

  Future<void> _pickTonguePhoto(ImageSource source) async {
    final lang = AppLanguageController.instance;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _tongueBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr('Could not add the photo.', '사진을 추가하지 못했어요.'),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final session =
        BetaSessionService.currentSession ??
        await BetaSessionService.currentSessionAsync();
    if (session == null || !mounted) return;
    try {
      final profile = await PatientProfileService.loadLocalProfile(session.id);
      if (mounted && profile != null) {
        setState(() => _sessionProfile = profile);
      }
    } catch (_) {}
  }

  PatientProfile get _profile =>
      _sessionProfile ?? _store.currentPatientProfile;

  String? get _clinicId => _store.activeClinicForPatient(_profile.id)?.id;

  void _start() {
    setState(() {
      _engine = PatternFinderEngine();
      _shared = false;
      _heightCm = null;
      _weightKg = null;
      _tongueBytes = null;
      _stage = _Stage.basicInfo;
    });
  }

  void _startQuestions({double? heightCm, double? weightKg}) {
    setState(() {
      _heightCm = heightCm;
      _weightKg = weightKg;
      _currentQuestion = _engine.nextQuestion();
      _stage = _Stage.questions;
    });
  }

  Map<String, dynamic> _profileContext() {
    final bmi = (_heightCm != null && _weightKg != null && _heightCm! > 0)
        ? _weightKg! / ((_heightCm! / 100) * (_heightCm! / 100))
        : null;
    final profile = _profile;
    return {
      'birthYear': profile.birthYear,
      'ageRange': profile.ageRange,
      'sex': profile.sex,
      'ethnicity': profile.ethnicity,
      if (_heightCm != null) 'heightCm': _heightCm,
      if (_weightKg != null) 'weightKg': _weightKg,
      if (bmi != null) 'bmi': double.parse(bmi.toStringAsFixed(1)),
    };
  }

  void _choose(int optionIndex) {
    final question = _currentQuestion;
    if (question == null) return;
    setState(() {
      _engine.answer(question.id, optionIndex);
      _advance();
    });
  }

  void _chooseFreeText(String text) {
    final question = _currentQuestion;
    if (question == null || text.trim().isEmpty) return;
    setState(() {
      _engine.answerFreeText(question.id, text);
      _advance();
    });
  }

  void _advance() {
    final next = _engine.nextQuestion();
    if (next == null) {
      _stage = _Stage.result;
      _currentQuestion = null;
    } else {
      _currentQuestion = next;
    }
  }

  void _back() {
    setState(() {
      if (_engine.answeredCount == 0) {
        _stage = _Stage.basicInfo;
        _currentQuestion = null;
      } else {
        _engine.undo();
        _currentQuestion = _engine.nextQuestion();
      }
    });
  }

  Future<void> _share() async {
    final lang = AppLanguageController.instance;
    final clinicId = _clinicId;
    if (clinicId == null || clinicId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Connect with a clinic first to share this result.',
              '결과를 공유하려면 먼저 한의원과 연결해 주세요.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _isSharing = true);
    try {
      final pairs = _engine.answeredPairs();
      final answers = <Map<String, dynamic>>[];
      for (var i = 0; i < pairs.length; i++) {
        final (question, option) = pairs[i];
        final typed = _engine.isFreeText(question.id);
        answers.add({
          'questionIndex': i + 1,
          'questionText': question.textKo,
          'answerText': typed ? '(직접 입력) ${option.textKo}' : option.textKo,
          'markedMainPain': false,
          'markedRemember': false,
        });
      }
      // Research-grounded follow-ups for the leading pattern (LLM question
      // bank) ride along in the shared summary so the practitioner sees them
      // on the dashboard.
      final topPattern = _engine.result().top?.pattern;
      var extraQuestions = const <String>[];
      if (topPattern != null) {
        final bank =
            await QuestionBankService.instance.forPattern(topPattern.id);
        if (bank != null) {
          extraQuestions = [for (final q in bank.questions) q.questionKo];
        }
      }
      await AppFirestoreService.submitPatientIntake(
        patientId: _profile.id,
        clinicId: clinicId,
        patientName: _profile.name,
        visitType: 'pattern_finder',
        answers: answers,
        extraMemo: '',
        adherence: const {},
        currentQuestionIndex: 0,
        adaptiveTcmSummary: _engine.toCarePicture(
          extraNextQuestions: extraQuestions,
          profile: _profileContext(),
        ),
        tongueImageBase64:
            _tongueBytes == null ? null : base64Encode(_tongueBytes!),
      );
      if (!mounted) return;
      setState(() => _shared = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Shared with your practitioner for review.',
              '한의사 검토용으로 공유되었습니다.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Could not share right now. Please try again.',
              '지금은 공유할 수 없어요. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return PatientShell(
      currentItem: PatientNavItem.home,
      title: lang.tr('Pattern Finder', '내 몸 패턴 찾기'),
      actions: const [LanguageMenuButton()],
      body: switch (_stage) {
        _Stage.intro => _IntroView(onStart: _start),
        _Stage.basicInfo => _BasicInfoView(
          onContinue: (h, w) => _startQuestions(heightCm: h, weightKg: w),
          onBack: () => setState(() => _stage = _Stage.intro),
        ),
        _Stage.questions => _QuestionView(
          key: ValueKey(_currentQuestion!.id),
          question: _currentQuestion!,
          answered: _engine.answeredCount,
          total: PatternFinderService.questionsPerSession,
          chapter: _engine.currentChapter,
          isChapterStart: _engine.answeredCount ==
              PatternFinderService.commonQuestionCount,
          onChoose: _choose,
          onChooseFreeText: _chooseFreeText,
          onBack: _back,
        ),
        _Stage.result => _ResultView(
          result: _engine.result(),
          answeredPairs: _engine.answeredPairs(),
          tongueBytes: _tongueBytes,
          onPickTongue: _pickTonguePhoto,
          onRemoveTongue: () => setState(() => _tongueBytes = null),
          isSharing: _isSharing,
          shared: _shared,
          onShare: _share,
          onRetry: _start,
        ),
      },
    );
  }
}

class _NotDiagnosisBanner extends StatelessWidget {
  const _NotDiagnosisBanner();

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang.tr(
                'This is not a diagnosis. Your practitioner reviews and '
                'confirms everything in person.',
                '이 결과는 진단이 아니에요. 최종 판단은 한의사 선생님이 직접 진료로 확인합니다.',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  const _IntroView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr(
                    'Find your body pattern in ${PatternFinderService.questionsPerSession} questions',
                    '${PatternFinderService.questionsPerSession}개의 질문으로 내 몸의 패턴 방향을 찾아봐요',
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  lang.tr(
                    'Answer one question at a time. Each answer decides the '
                    'next question, and at the end you get the pattern '
                    'direction your answers point to — with the research '
                    'behind it.',
                    '한 번에 하나씩만 답하면 돼요. 답할 때마다 다음 질문이 달라지고, '
                    '마지막에 내 답변이 가리키는 패턴 방향과 그 근거 연구를 보여드려요.',
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(lang.tr('Start', '시작하기')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _NotDiagnosisBanner(),
      ],
    );
  }
}

/// Optional baseline info (height/weight) collected before the questions.
/// Both fields are skippable; values are context for the practitioner only
/// and never affect scoring.
class _BasicInfoView extends StatefulWidget {
  const _BasicInfoView({required this.onContinue, required this.onBack});

  final void Function(double? heightCm, double? weightKg) onContinue;
  final VoidCallback onBack;

  @override
  State<_BasicInfoView> createState() => _BasicInfoViewState();
}

class _BasicInfoViewState extends State<_BasicInfoView> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? _parse(String raw, double min, double max) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value < min || value > max) return null;
    return value;
  }

  void _continue() {
    widget.onContinue(
      _parse(_heightController.text, 80, 250),
      _parse(_weightController.text, 20, 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: lang.tr('Back', '이전'),
            ),
            Expanded(
              child: Text(
                lang.tr('Basic info (optional)', '기본 정보 (선택)'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          lang.tr(
            'Height and weight help your practitioner read the result. '
            'Feel free to skip — they never affect the pattern score.',
            '키와 몸무게는 한의사 선생님이 결과를 볼 때 참고돼요. '
            '적기 부담스러우면 건너뛰어도 되고, 패턴 점수에는 영향을 주지 않아요.',
          ),
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppTheme.ink.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: lang.tr('Height (cm)', '키 (cm)'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: lang.tr('Weight (kg)', '몸무게 (kg)'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(lang.tr('Start questions', '질문 시작하기')),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => widget.onContinue(null, null),
              child: Text(lang.tr('Skip', '건너뛰기')),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionView extends StatefulWidget {
  const _QuestionView({
    super.key,
    required this.question,
    required this.answered,
    required this.total,
    required this.chapter,
    required this.isChapterStart,
    required this.onChoose,
    required this.onChooseFreeText,
    required this.onBack,
  });

  final PatternQuestion question;
  final int answered;
  final int total;
  final int chapter;
  final bool isChapterStart;
  final ValueChanged<int> onChoose;
  final ValueChanged<String> onChooseFreeText;
  final VoidCallback onBack;

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  final _freeTextController = TextEditingController();
  bool _showFreeText = false;

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  void _submitFreeText() {
    final text = _freeTextController.text.trim();
    if (text.isEmpty) return;
    widget.onChooseFreeText(text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final question = widget.question;
    final chapterLabel = widget.chapter == 1
        ? lang.tr('Chapter 1 · Common questions', '1장 · 공통 문진')
        : lang.tr('Chapter 2 · Personalized questions', '2장 · 맞춤 심화 문진');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: lang.tr('Back', '이전'),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: widget.answered / widget.total,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceSoft,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${widget.answered + 1}/${widget.total}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          chapterLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: widget.chapter == 1
                ? AppTheme.sky
                : const Color(0xFF0F766E),
          ),
        ),
        if (widget.isChapterStart) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0F766E).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF0F766E),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang.tr(
                      "Based on your answers, we'll now ask a few questions "
                      'tailored to you.',
                      '지금까지 답변에 맞춰, 이제 나에게 맞는 질문을 몇 가지 더 여쭤볼게요.',
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          lang.tr(question.textEn, question.textKo),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionButton(
              text: lang.tr(question.options[i].textEn, question.options[i].textKo),
              onTap: () => widget.onChoose(i),
            ),
          ),
        if (!_showFreeText)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showFreeText = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                lang.tr('Write my own answer', '직접 입력할게요'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
        else ...[
          TextField(
            controller: _freeTextController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitFreeText(),
            decoration: InputDecoration(
              hintText: lang.tr(
                'Describe it in your own words',
                '내 상태를 편하게 적어주세요',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _submitFreeText,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(lang.tr('Use this answer', '이 답변으로 할게요')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _showFreeText = false),
                child: Text(lang.tr('Cancel', '취소')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.answeredPairs,
    required this.tongueBytes,
    required this.onPickTongue,
    required this.onRemoveTongue,
    required this.isSharing,
    required this.shared,
    required this.onShare,
    required this.onRetry,
  });

  final PatternFinderResult result;
  final List<(PatternQuestion, PatternOption)> answeredPairs;
  final Uint8List? tongueBytes;
  final ValueChanged<ImageSource> onPickTongue;
  final VoidCallback onRemoveTongue;
  final bool isSharing;
  final bool shared;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final top = result.top;
    final runnerUp = result.runnerUp;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _NotDiagnosisBanner(),
        const SizedBox(height: 12),
        if (top == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lang.tr(
                  'Your answers did not point to a clear pattern yet. Your '
                  'practitioner can explore this with you in person.',
                  '아직 뚜렷한 패턴 방향이 나오지 않았어요. 한의사 선생님과 진료에서 함께 살펴보면 좋아요.',
                ),
              ),
            ),
          )
        else ...[
          _ConfidenceBanner(
            confidence: result.confidence,
            isCombined: result.isCombined,
            secondaryName: runnerUp == null
                ? null
                : lang.tr(runnerUp.pattern.nameEn, runnerUp.pattern.nameKo),
          ),
          const SizedBox(height: 12),
          _PatternCard(score: top, isPrimary: true),
          if (runnerUp != null) ...[
            const SizedBox(height: 10),
            _PatternCard(score: runnerUp, isPrimary: false),
          ],
          if (result.contributions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              lang.tr('Answers that pointed this way', '이 방향을 가리킨 내 답변'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in result.contributions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('· '),
                            Expanded(
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
        if (answeredPairs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AnswerRecapSection(answeredPairs: answeredPairs),
        ],
        const SizedBox(height: 16),
        _TonguePhotoSection(
          bytes: tongueBytes,
          onPick: onPickTongue,
          onRemove: onRemoveTongue,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: shared || isSharing ? null : onShare,
              icon: isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(shared ? Icons.check_rounded : Icons.send_rounded),
              label: Text(
                shared
                    ? lang.tr('Shared', '공유 완료')
                    : lang.tr('Share with my practitioner', '한의사에게 공유하기'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(lang.tr('Start over', '다시 하기')),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                foregroundColor: AppTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Honest read of how strong the leading signal is, plus a combined-pattern
/// (兼證) note when the top two directions are close.
class _ConfidenceBanner extends StatelessWidget {
  const _ConfidenceBanner({
    required this.confidence,
    required this.isCombined,
    required this.secondaryName,
  });

  final PatternConfidence confidence;
  final bool isCombined;
  final String? secondaryName;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final (IconData icon, Color color, String textEn, String textKo) =
        switch (confidence) {
      PatternConfidence.clear => (
        Icons.check_circle_rounded,
        const Color(0xFF0F766E),
        'One direction stands out clearly.',
        '한 방향이 뚜렷하게 나타났어요.',
      ),
      PatternConfidence.moderate => (
        Icons.trending_up_rounded,
        AppTheme.sun,
        'A leading direction is emerging, worth confirming in person.',
        '앞서는 방향이 보이지만, 진료에서 확인하면 좋아요.',
      ),
      PatternConfidence.unclear => (
        Icons.help_outline_rounded,
        AppTheme.sky,
        'No single direction is clear yet — your practitioner will explore it.',
        '아직 한 방향으로 뚜렷하진 않아요 — 진료에서 함께 살펴봐요.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.tr(textEn, textKo),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (isCombined && secondaryName != null) ...[
            const SizedBox(height: 6),
            Text(
              lang.tr(
                'Two directions appear together — your practitioner may treat '
                'this as a combined pattern with $secondaryName.',
                '두 방향이 함께 나타나요 — 한의사 선생님이 $secondaryName와(과) 겹친 '
                '복합 패턴(겸증)으로 볼 수 있어요.',
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppTheme.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.score, required this.isPrimary});

  final PatternScore score;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final percent = (score.share * 100).round();
    return Card(
      color: isPrimary ? null : AppTheme.surfaceSoft,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lang.tr(score.pattern.nameEn, score.pattern.nameKo),
                    style: TextStyle(
                      fontSize: isPrimary ? 19 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: isPrimary ? 19 : 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: score.share,
                minHeight: 8,
                backgroundColor: AppTheme.border.withValues(alpha: 0.4),
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang.tr(score.pattern.summaryEn, score.pattern.summaryKo),
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// Optional tongue photo the patient can attach for the practitioner to review
/// in person. The app never analyses it — it is decision support, not
/// automated tongue diagnosis (ref: TongueVLM in the corpus).
class _TonguePhotoSection extends StatelessWidget {
  const _TonguePhotoSection({
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.tr('Tongue photo (optional)', '혀 사진 (선택)'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          lang.tr(
            'A clear photo of your tongue helps your practitioner. It is '
            'only reviewed in person — the app does not analyse it.',
            '혀를 밝은 곳에서 찍어 첨부하면 한의사 선생님 진료에 도움이 돼요. '
            '앱이 분석하지 않고, 선생님이 직접 확인만 합니다.',
          ),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppTheme.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        if (bytes != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes!,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF0F766E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lang.tr('Photo added', '사진 첨부됨'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(lang.tr('Remove', '삭제')),
                  ),
                ],
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(lang.tr('Take photo', '사진 찍기')),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  foregroundColor: AppTheme.ink,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(lang.tr('Choose photo', '앨범에서 선택')),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  foregroundColor: AppTheme.ink,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Collapsible recap of every question asked and the answer chosen, so the
/// patient can review exactly what they said before sharing.
class _AnswerRecapSection extends StatelessWidget {
  const _AnswerRecapSection({required this.answeredPairs});

  final List<(PatternQuestion, PatternOption)> answeredPairs;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            lang.tr(
              'Review my ${answeredPairs.length} answers',
              '내가 답한 내용 모두 보기 (${answeredPairs.length}개)',
            ),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          children: [
            for (var i = 0; i < answeredPairs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q${i + 1}. ${lang.tr(answeredPairs[i].$1.textEn, answeredPairs[i].$1.textKo)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lang.tr(
                        answeredPairs[i].$2.textEn,
                        answeredPairs[i].$2.textKo,
                      ),
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
