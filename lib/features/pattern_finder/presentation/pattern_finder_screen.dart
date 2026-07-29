import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/app_firestore_service.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/services/pattern_finder_service.dart';
import '../../../core/services/question_bank_service.dart';
import '../../../core/services/research_corpus_service.dart';
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

enum _Stage { intro, questions, result }

class _PatternFinderScreenState extends State<PatternFinderScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  PatternFinderEngine _engine = PatternFinderEngine();
  _Stage _stage = _Stage.intro;
  PatternQuestion? _currentQuestion;
  PatientProfile? _sessionProfile;
  bool _isSharing = false;
  bool _shared = false;

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
      _currentQuestion = _engine.nextQuestion();
      _stage = _Stage.questions;
    });
  }

  void _choose(int optionIndex) {
    final question = _currentQuestion;
    if (question == null) return;
    setState(() {
      _engine.answer(question.id, optionIndex);
      final next = _engine.nextQuestion();
      if (next == null) {
        _stage = _Stage.result;
        _currentQuestion = null;
      } else {
        _currentQuestion = next;
      }
    });
  }

  void _back() {
    setState(() {
      if (_engine.answeredCount == 0) {
        _stage = _Stage.intro;
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
      final answers = <Map<String, dynamic>>[];
      for (var i = 0; i < _engine.answers.length; i++) {
        final entry = _engine.answers[i];
        final question = PatternFinderService.questionById[entry.key]!;
        answers.add({
          'questionIndex': i + 1,
          'questionText': question.textKo,
          'answerText': question.options[entry.value].textKo,
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
        adaptiveTcmSummary:
            _engine.toCarePicture(extraNextQuestions: extraQuestions),
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
        _Stage.questions => _QuestionView(
          question: _currentQuestion!,
          answered: _engine.answeredCount,
          total: PatternFinderService.questionsPerSession,
          onChoose: _choose,
          onBack: _back,
        ),
        _Stage.result => _ResultView(
          result: _engine.result(),
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

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.answered,
    required this.total,
    required this.onChoose,
    required this.onBack,
  });

  final PatternQuestion question;
  final int answered;
  final int total;
  final ValueChanged<int> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: lang.tr('Back', '이전'),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: answered / total,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceSoft,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${answered + 1}/$total',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
              onTap: () => onChoose(i),
            ),
          ),
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
    required this.isSharing,
    required this.shared,
    required this.onShare,
    required this.onRetry,
  });

  final PatternFinderResult result;
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
          const SizedBox(height: 16),
          _BankQuestionsSection(patternId: top.pattern.id),
          _ResearchEvidenceSection(query: top.pattern.researchQuery),
        ],
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

/// Research-grounded follow-up questions for the leading pattern, drafted by
/// the daily LLM step from collected paper abstracts. Hidden until the
/// question bank has been generated at least once.
class _BankQuestionsSection extends StatelessWidget {
  const _BankQuestionsSection({required this.patternId});

  final String patternId;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return FutureBuilder<PatternQuestionBank?>(
      future: QuestionBankService.instance.forPattern(patternId),
      builder: (context, snapshot) {
        final bank = snapshot.data;
        if (bank == null || bank.questions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr(
                'Questions your practitioner may ask next',
                '진료에서 이어질 수 있는 질문',
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              lang.tr(
                'Drafted from ${bank.sources.length} research papers — your '
                'practitioner reviews these in person.',
                '수집된 논문 ${bank.sources.length}편을 근거로 작성되었어요. '
                '실제 질문 여부는 한의사 선생님이 판단합니다.',
              ),
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            for (final q in bank.questions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr(q.questionEn, q.questionKo),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      if (q.rationaleKo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          q.rationaleKo,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.ink.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _ResearchEvidenceSection extends StatelessWidget {
  const _ResearchEvidenceSection({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return FutureBuilder<List<ResearchPaper>>(
      future: ResearchCorpusService.instance.topMatches(query, limit: 3),
      builder: (context, snapshot) {
        final papers = snapshot.data ?? const <ResearchPaper>[];
        if (papers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr('Related research', '관련 연구'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final p in papers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (p.year.isNotEmpty) p.year,
                          if (p.source.isNotEmpty) p.source,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
