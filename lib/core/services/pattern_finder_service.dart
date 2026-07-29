/// Adaptive TCM pattern finder engine.
///
/// A guided, deterministic question flow: the patient answers one multiple-
/// choice question at a time, each answer adds weight to candidate TCM
/// patterns, and the next question is chosen to best separate the current
/// front-runners. After a fixed number of questions the engine returns a
/// ranked pattern direction — decision support for a licensed practitioner,
/// never an automated diagnosis.
///
/// Everything here is rule-based and reviewable on purpose (see
/// ADAPTIVE_TCM_INQUIRY_NOTES.md): no network, no model calls, and the same
/// answers always produce the same result.
library;

/// A candidate pattern direction the finder can converge on.
class TcmPattern {
  const TcmPattern({
    required this.id,
    required this.nameEn,
    required this.nameKo,
    required this.summaryEn,
    required this.summaryKo,
    required this.researchQuery,
  });

  final String id;
  final String nameEn;
  final String nameKo;
  final String summaryEn;
  final String summaryKo;

  /// Query for ResearchCorpusService.topMatches — links the result to the
  /// supporting literature in the bundled corpus.
  final String researchQuery;
}

class PatternOption {
  const PatternOption({
    required this.textEn,
    required this.textKo,
    this.weights = const {},
  });

  final String textEn;
  final String textKo;

  /// patternId -> score contribution when this option is chosen.
  final Map<String, int> weights;
}

class PatternQuestion {
  const PatternQuestion({
    required this.id,
    required this.textEn,
    required this.textKo,
    required this.options,
  });

  final String id;
  final String textEn;
  final String textKo;
  final List<PatternOption> options;
}

/// One ranked entry in the finder result.
class PatternScore {
  const PatternScore({
    required this.pattern,
    required this.score,
    required this.share,
  });

  final TcmPattern pattern;
  final int score;

  /// score / total positive score, 0..1 — used for the result bars.
  final double share;
}

class PatternFinderResult {
  const PatternFinderResult({
    required this.ranked,
    required this.answeredCount,
    required this.contributions,
  });

  /// Patterns with score > 0, best first.
  final List<PatternScore> ranked;
  final int answeredCount;

  /// For the top pattern: the chosen answers (Korean text) that added weight
  /// to it, so the patient and practitioner can see *why*.
  final List<String> contributions;

  PatternScore? get top => ranked.isEmpty ? null : ranked.first;

  /// Runner-up shown only when it is genuinely competitive.
  PatternScore? get runnerUp {
    if (ranked.length < 2) return null;
    final second = ranked[1];
    if (ranked.first.score == 0) return null;
    return second.score >= ranked.first.score * 0.6 ? second : null;
  }
}

class PatternFinderService {
  PatternFinderService._();

  /// How many questions a session asks before showing the result.
  static const int questionsPerSession = 8;

  /// The first questions every session asks, before adaptive selection
  /// starts steering toward the front-running patterns.
  static const int baselineQuestions = 3;

  static const List<TcmPattern> patterns = [
    TcmPattern(
      id: 'qi_deficiency',
      nameEn: 'Qi deficiency direction',
      nameKo: '기허(기운 부족) 방향',
      summaryEn:
          'Low energy that worsens with activity, weak voice or appetite, '
          'easy sweating on light exertion.',
      summaryKo: '움직이면 심해지는 피로, 기운 없는 목소리나 식욕 저하, 조금만 움직여도 나는 땀이 특징적인 방향입니다.',
      researchQuery: 'qi deficiency fatigue syndrome differentiation',
    ),
    TcmPattern(
      id: 'yang_deficiency',
      nameEn: 'Yang deficiency (cold) direction',
      nameKo: '양허(몸이 찬) 방향',
      summaryEn:
          'Feeling cold, cold hands and feet, preferring warmth, loose stool, '
          'low morning energy.',
      summaryKo: '추위를 많이 타고 손발이 차며, 따뜻한 것을 찾고 변이 무른 편인 방향입니다.',
      researchQuery: 'yang deficiency cold syndrome differentiation',
    ),
    TcmPattern(
      id: 'yin_deficiency',
      nameEn: 'Yin deficiency (dry heat) direction',
      nameKo: '음허(허열·건조) 방향',
      summaryEn:
          'Night sweats, dry mouth at night, flushed warmth in the evening, '
          'light restless sleep.',
      summaryKo: '밤에 나는 식은땀과 입마름, 저녁의 달아오르는 열감, 얕은 잠이 특징적인 방향입니다.',
      researchQuery: 'yin deficiency heat night sweat syndrome differentiation',
    ),
    TcmPattern(
      id: 'damp_phlegm',
      nameEn: 'Damp / phlegm direction',
      nameKo: '습담(무겁고 더부룩) 방향',
      summaryEn:
          'Heaviness of body or head, bloating after meals, sticky stool, '
          'worse in humid weather.',
      summaryKo: '몸과 머리가 무겁고 식후 더부룩하며, 변이 끈적하고 습한 날 심해지는 방향입니다.',
      researchQuery: 'damp phlegm spleen digestion syndrome differentiation',
    ),
    TcmPattern(
      id: 'liver_qi',
      nameEn: 'Liver qi constraint direction',
      nameKo: '간기울결(스트레스·긴장) 방향',
      summaryEn:
          'Symptoms flare with stress: chest or flank tightness, sighing, '
          'irritability, stress-related digestion issues.',
      summaryKo: '스트레스에 따라 증상이 오르내리고, 가슴답답함·한숨·짜증, 스트레스성 소화 문제가 특징적인 방향입니다.',
      researchQuery: 'liver qi stagnation depression stress syndrome differentiation',
    ),
    TcmPattern(
      id: 'blood_stasis',
      nameEn: 'Blood stasis direction',
      nameKo: '어혈(고정된 통증) 방향',
      summaryEn:
          'Fixed stabbing pain in one spot, worse at night, dark or dull '
          'complexion.',
      summaryKo: '한 자리에 고정된 콕콕 찌르는 통증, 밤에 심해지는 통증, 어둡고 칙칙한 안색이 특징적인 방향입니다.',
      researchQuery: 'blood stasis pain syndrome differentiation',
    ),
    TcmPattern(
      id: 'blood_deficiency',
      nameEn: 'Blood deficiency direction',
      nameKo: '혈허(어지럼·창백) 방향',
      summaryEn:
          'Dizziness on standing, pale complexion, blurry or tired eyes, '
          'hard to fall asleep with a busy mind.',
      summaryKo: '일어날 때 어지럽고 안색이 창백하며, 눈이 침침하고 잠들기 어려운 것이 특징적인 방향입니다.',
      researchQuery: 'blood deficiency dizziness insomnia syndrome differentiation',
    ),
  ];

  static final Map<String, TcmPattern> patternById = {
    for (final p in patterns) p.id: p,
  };

  static const List<PatternQuestion> questions = [
    // --- Baseline: always asked, covers energy / temperature / stress. ---
    PatternQuestion(
      id: 'energy',
      textEn: 'When is your fatigue strongest?',
      textKo: '피로감이 가장 심한 때는 언제인가요?',
      options: [
        PatternOption(
          textEn: 'From the morning, all day',
          textKo: '아침부터 하루 종일 기운이 없어요',
          weights: {'qi_deficiency': 3, 'yang_deficiency': 2, 'blood_deficiency': 1},
        ),
        PatternOption(
          textEn: 'It builds in the afternoon',
          textKo: '오후가 되면 뚝 떨어져요',
          weights: {'qi_deficiency': 2, 'damp_phlegm': 1},
        ),
        PatternOption(
          textEn: 'Evenings, with warmth or restlessness',
          textKo: '저녁에 피곤한데 몸에 열감이 있어요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Mostly after stressful days',
          textKo: '스트레스 받은 날 특히 심해요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Not really tired',
          textKo: '피로는 별로 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'temperature',
      textEn: 'How do you feel about temperature?',
      textKo: '평소 추위나 더위는 어떤가요?',
      options: [
        PatternOption(
          textEn: 'I feel cold; hands and feet are cold',
          textKo: '추위를 타고 손발이 차요',
          weights: {'yang_deficiency': 3, 'qi_deficiency': 1, 'blood_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Warm or flushed, especially at night',
          textKo: '밤이나 저녁에 얼굴이 달아오르고 더워요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Chest feels hot when stressed',
          textKo: '스트레스 받으면 가슴이 답답하고 열이 올라요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'No strong tendency',
          textKo: '특별히 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'stress',
      textEn: 'Do symptoms change with stress?',
      textKo: '증상이 스트레스와 관련이 있나요?',
      options: [
        PatternOption(
          textEn: 'Clearly worse with stress or frustration',
          textKo: '스트레스 받으면 확실히 심해져요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Worse after overwork, regardless of mood',
          textKo: '기분과 상관없이 무리하면 심해져요',
          weights: {'qi_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Worse in damp or rainy weather',
          textKo: '습하거나 비 오는 날 심해져요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'No clear connection',
          textKo: '잘 모르겠어요',
        ),
      ],
    ),
    // --- Adaptive pool. ---
    PatternQuestion(
      id: 'digestion',
      textEn: 'How is your digestion?',
      textKo: '소화는 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Bloated and heavy after meals',
          textKo: '먹고 나면 더부룩하고 몸이 무거워요',
          weights: {'damp_phlegm': 3, 'qi_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Poor appetite, food feels like a chore',
          textKo: '입맛이 없고 먹는 게 부담스러워요',
          weights: {'qi_deficiency': 2, 'yang_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Digestion locks up when stressed',
          textKo: '스트레스 받으면 체하거나 답답해요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Generally fine',
          textKo: '괜찮은 편이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'sleep',
      textEn: 'How is your sleep?',
      textKo: '잠은 어떻게 주무시나요?',
      options: [
        PatternOption(
          textEn: 'Hard to fall asleep, mind keeps running',
          textKo: '생각이 많아 잠들기 어려워요',
          weights: {'blood_deficiency': 2, 'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'Wake at dawn with sweat or dry mouth',
          textKo: '새벽에 깨고 식은땀이나 입마름이 있어요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Light sleep with many dreams',
          textKo: '잠이 얕고 꿈을 많이 꿔요',
          weights: {'blood_deficiency': 2, 'yin_deficiency': 1},
        ),
        PatternOption(
          textEn: 'I sleep heavily but wake unrefreshed',
          textKo: '많이 자도 개운하지 않아요',
          weights: {'damp_phlegm': 2, 'qi_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Sleep is fine',
          textKo: '잘 자는 편이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'pain',
      textEn: 'If you have pain, what is it like?',
      textKo: '통증이 있다면 어떤 느낌인가요?',
      options: [
        PatternOption(
          textEn: 'Stabbing, fixed in one spot, worse at night',
          textKo: '한 자리가 콕콕 찌르듯 아프고 밤에 심해요',
          weights: {'blood_stasis': 3},
        ),
        PatternOption(
          textEn: 'Tightness that moves around with stress',
          textKo: '결리는 곳이 옮겨 다니고 스트레스에 따라 달라져요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'Dull, heavy ache',
          textKo: '묵직하고 뻐근하게 아파요',
          weights: {'damp_phlegm': 2},
        ),
        PatternOption(
          textEn: 'No notable pain',
          textKo: '통증은 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'sweat',
      textEn: 'How about sweating?',
      textKo: '땀은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'I sweat easily with light activity',
          textKo: '조금만 움직여도 땀이 나요',
          weights: {'qi_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Night sweats while sleeping',
          textKo: '자는 동안 식은땀이 나요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'I rarely sweat and feel cold',
          textKo: '땀이 거의 없고 몸이 차요',
          weights: {'yang_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Normal',
          textKo: '보통이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'thirst',
      textEn: 'Mouth and thirst?',
      textKo: '입마름이나 갈증은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Dry mouth, want cool water',
          textKo: '입이 마르고 시원한 물이 당겨요',
          weights: {'yin_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Dry mouth but little desire to drink',
          textKo: '입은 마른데 물은 잘 안 마셔요',
          weights: {'damp_phlegm': 2, 'blood_stasis': 1},
        ),
        PatternOption(
          textEn: 'Prefer warm drinks',
          textKo: '따뜻한 물이나 차가 편해요',
          weights: {'yang_deficiency': 2},
        ),
        PatternOption(
          textEn: 'No particular thirst',
          textKo: '별다른 갈증은 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'stool',
      textEn: 'How is your stool, usually?',
      textKo: '대변은 평소 어떤 편인가요?',
      options: [
        PatternOption(
          textEn: 'Loose or watery, worse with cold food',
          textKo: '무른 편이고 찬 음식 먹으면 심해져요',
          weights: {'yang_deficiency': 3, 'qi_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Dry or constipated',
          textKo: '건조하고 변비 경향이 있어요',
          weights: {'yin_deficiency': 2, 'blood_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Sticky, hard to finish',
          textKo: '끈적하고 시원하지 않아요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'Irregular, changes with stress',
          textKo: '스트레스에 따라 들쭉날쭉해요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'Normal',
          textKo: '보통이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'head',
      textEn: 'Head and eyes?',
      textKo: '머리나 눈은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Dizzy when standing, eyes tire easily',
          textKo: '일어날 때 어지럽고 눈이 쉽게 피로해요',
          weights: {'blood_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Head feels heavy and foggy',
          textKo: '머리가 무겁고 멍해요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'Sharp headache in a fixed spot',
          textKo: '한 부위가 콕콕 아픈 두통이 있어요',
          weights: {'blood_stasis': 2},
        ),
        PatternOption(
          textEn: 'Temple/side headaches when stressed',
          textKo: '스트레스 받으면 옆머리가 아파요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'No issues',
          textKo: '괜찮아요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'complexion',
      textEn: 'How would you describe your complexion lately?',
      textKo: '요즘 안색은 어떤 편인가요?',
      options: [
        PatternOption(
          textEn: 'Pale, lips light in color',
          textKo: '창백하고 입술색이 옅어요',
          weights: {'blood_deficiency': 3, 'yang_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Flushed cheeks in the evening',
          textKo: '저녁에 볼이 붉어져요',
          weights: {'yin_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Dark, dull, or easily bruised',
          textKo: '칙칙하고 멍이 잘 들어요',
          weights: {'blood_stasis': 3},
        ),
        PatternOption(
          textEn: 'Normal',
          textKo: '보통이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'mood',
      textEn: 'How has your mood been?',
      textKo: '요즘 기분은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Irritable, sighing a lot, chest feels stuck',
          textKo: '짜증이 늘고 한숨이 잦고 가슴이 답답해요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Anxious with a racing mind at night',
          textKo: '불안하고 밤에 생각이 많아요',
          weights: {'blood_deficiency': 2, 'yin_deficiency': 1},
        ),
        PatternOption(
          textEn: 'Flat and unmotivated more than sad',
          textKo: '우울하다기보다 의욕이 없어요',
          weights: {'qi_deficiency': 2, 'damp_phlegm': 1},
        ),
        PatternOption(
          textEn: 'Stable',
          textKo: '안정적이에요',
        ),
      ],
    ),
  ];

  static final Map<String, PatternQuestion> questionById = {
    for (final q in questions) q.id: q,
  };
}

/// Mutable session state for one pattern-finding run.
class PatternFinderEngine {
  PatternFinderEngine();

  final Map<String, int> _scores = {
    for (final p in PatternFinderService.patterns) p.id: 0,
  };

  /// questionId -> chosen option index, in answer order.
  final List<MapEntry<String, int>> _answers = [];

  List<MapEntry<String, int>> get answers => List.unmodifiable(_answers);

  int get answeredCount => _answers.length;

  bool get isDone =>
      _answers.length >= PatternFinderService.questionsPerSession ||
      _answers.length >= PatternFinderService.questions.length;

  Set<String> get _answeredIds => {for (final a in _answers) a.key};

  /// The next question to ask, or null when the session is done.
  ///
  /// The first [PatternFinderService.baselineQuestions] follow the fixed
  /// question order to establish a broad baseline; after that, the question
  /// whose options carry the most weight toward the current top-3 patterns is
  /// chosen, so follow-ups chase whichever directions are leading.
  PatternQuestion? nextQuestion() {
    if (isDone) return null;
    final answered = _answeredIds;
    final remaining = PatternFinderService.questions
        .where((q) => !answered.contains(q.id))
        .toList();
    if (remaining.isEmpty) return null;

    if (_answers.length < PatternFinderService.baselineQuestions) {
      return remaining.first;
    }

    final topPatterns = _rankedPatternIds().take(3).toSet();
    PatternQuestion best = remaining.first;
    var bestValue = -1;
    for (final q in remaining) {
      var value = 0;
      for (final option in q.options) {
        option.weights.forEach((patternId, weight) {
          if (topPatterns.contains(patternId)) value += weight;
        });
      }
      if (value > bestValue) {
        bestValue = value;
        best = q;
      }
    }
    return best;
  }

  void answer(String questionId, int optionIndex) {
    final question = PatternFinderService.questionById[questionId];
    if (question == null) return;
    if (optionIndex < 0 || optionIndex >= question.options.length) return;
    _answers.add(MapEntry(questionId, optionIndex));
    question.options[optionIndex].weights.forEach((patternId, weight) {
      _scores[patternId] = (_scores[patternId] ?? 0) + weight;
    });
  }

  /// Removes the most recent answer (back button support).
  void undo() {
    if (_answers.isEmpty) return;
    final last = _answers.removeLast();
    final question = PatternFinderService.questionById[last.key];
    question?.options[last.value].weights.forEach((patternId, weight) {
      _scores[patternId] = (_scores[patternId] ?? 0) - weight;
    });
  }

  List<String> _rankedPatternIds() {
    final entries = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  PatternFinderResult result() {
    final total = _scores.values.where((v) => v > 0).fold<int>(0, (a, b) => a + b);
    final ranked = <PatternScore>[];
    for (final id in _rankedPatternIds()) {
      final score = _scores[id] ?? 0;
      if (score <= 0) continue;
      ranked.add(
        PatternScore(
          pattern: PatternFinderService.patternById[id]!,
          score: score,
          share: total == 0 ? 0 : score / total,
        ),
      );
    }

    final topId = ranked.isEmpty ? null : ranked.first.pattern.id;
    final contributions = <String>[];
    if (topId != null) {
      for (final a in _answers) {
        final question = PatternFinderService.questionById[a.key];
        if (question == null) continue;
        final option = question.options[a.value];
        if ((option.weights[topId] ?? 0) > 0) {
          contributions.add(option.textKo);
        }
      }
    }

    return PatternFinderResult(
      ranked: ranked,
      answeredCount: _answers.length,
      contributions: contributions,
    );
  }

  /// A summary in the same shape as AdaptiveTcmInquiryService.buildCarePicture
  /// output, so a shared result appears on the existing practitioner dashboard
  /// (signals, pattern directions, next-best questions) without any dashboard
  /// changes.
  ///
  /// [extraNextQuestions] lets callers prepend research-grounded follow-up
  /// questions (from the LLM-generated question bank) ahead of the defaults.
  Map<String, dynamic> toCarePicture({
    List<String> extraNextQuestions = const [],
  }) {
    final res = result();
    final directions = <String>[
      for (final s in res.ranked.take(2))
        '${s.pattern.nameEn} (${(s.share * 100).round()}%)',
    ];
    return {
      'version': 1,
      'basis':
          'Guided pattern finder: fixed question pool, weighted multiple-choice '
          'answers, adaptive question selection. This is not a diagnosis.',
      'notDiagnosis': true,
      'signals': [
        for (final s in res.ranked.take(4))
          {
            'domain': 'pattern',
            'label': s.pattern.nameEn,
            'weight': s.score,
            'evidence': res.contributions,
          },
      ],
      'patternDirections': directions.isEmpty
          ? ['Collect more baseline evidence before pattern direction']
          : directions,
      'nextBestQuestions': [
        ...extraNextQuestions,
        'Confirm tongue and pulse findings in person',
        'Ask how long the leading symptoms have lasted',
      ].take(5).toList(),
      'missingDomains': const <String>[],
      'updatedAtClient': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
