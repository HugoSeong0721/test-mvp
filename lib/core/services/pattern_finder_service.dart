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

  /// How separated the leading pattern is from the rest — drives whether the
  /// result is presented as a clear direction, a tentative one, or "not yet
  /// clear". Deliberately conservative: this is screening, not diagnosis.
  PatternConfidence get confidence {
    final leader = top;
    if (leader == null) return PatternConfidence.unclear;
    final second = ranked.length > 1 ? ranked[1] : null;
    final gap = leader.share - (second?.share ?? 0);
    // A leader that barely leads, or that itself holds little of the total
    // weight (answers pointed in many directions), is not a clear signal.
    if (leader.share < 0.30 || gap < 0.07) return PatternConfidence.unclear;
    if (gap < 0.15) return PatternConfidence.moderate;
    return PatternConfidence.clear;
  }

  /// True when the top two directions are close enough to read as a combined
  /// pattern (兼證) rather than a single one — common in real presentations.
  bool get isCombined {
    final leader = top;
    final second = runnerUp;
    if (leader == null || second == null) return false;
    return second.score >= leader.score * 0.75;
  }
}

enum PatternConfidence { clear, moderate, unclear }

class PatternFinderService {
  PatternFinderService._();

  /// How many questions a session asks before showing the result.
  static const int questionsPerSession = 8;

  /// Chapter 1 — common questions everyone answers (energy, temperature,
  /// stress, digestion). These establish the broad picture.
  static const List<String> commonQuestionIds = [
    'energy',
    'temperature',
    'stress',
    'digestion',
  ];
  static const int commonQuestionCount = 4;

  /// Chapter 2 — how many personalized deep-dive questions follow, chosen to
  /// drill into whichever direction Chapter 1 pointed to.
  static const int deepDiveCount = 4;

  /// Maximum Chapter 2 questions asked when the patient opts to keep answering
  /// at the checkpoint. The deeper they go, the more the picture sharpens.
  static const int deepDiveCap = 6;

  /// Chapter 2 pool: per-pattern deep-dive question ids. When a pattern leads
  /// after Chapter 1, its questions are asked to confirm/refine that direction
  /// — so two patients with different answers get different Chapter 2s. The
  /// last id in each list is a second-tier refinement question, reached only
  /// when the patient chooses to keep answering.
  static const Map<String, List<String>> deepDiveIdsByPattern = {
    'qi_deficiency': ['sweat', 'qi_deep_appetite', 'qi_deep_recovery', 'qi_deep_voice'],
    'yang_deficiency': ['stool', 'yang_deep_cold_area', 'yang_deep_urine', 'yang_deep_digest_cold'],
    'yin_deficiency': ['thirst', 'sleep', 'yin_deep_five_heart', 'yin_deep_night_sweat'],
    'damp_phlegm': ['head', 'damp_deep_heaviness', 'damp_deep_weather', 'damp_deep_mouth'],
    'liver_qi': ['mood', 'liver_deep_chest', 'liver_deep_variability', 'liver_deep_neck'],
    'blood_stasis': ['pain', 'stasis_deep_night', 'stasis_deep_bruise', 'stasis_deep_dark'],
    'blood_deficiency': ['complexion', 'blood_deep_palpitation', 'blood_deep_vision', 'blood_deep_dryness'],
  };

  /// Kept for the transitional call sites; Chapter 1 length.
  static const int baselineQuestions = commonQuestionCount;

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

    // ── Chapter 2 · deep-dive questions (asked only when their pattern leads) ──
    PatternQuestion(
      id: 'qi_deep_appetite',
      textEn: 'How is your appetite and energy after eating?',
      textKo: '식사 후 기운과 입맛은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Sleepy and drained right after meals',
          textKo: '먹고 나면 졸리고 축 처져요',
          weights: {'qi_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Little appetite, get full quickly',
          textKo: '입맛이 없고 조금만 먹어도 배불러요',
          weights: {'qi_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Fine after eating',
          textKo: '식후에 괜찮아요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'qi_deep_recovery',
      textEn: 'After exertion, how do you recover?',
      textKo: '무리한 뒤 회복은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Wiped out for a long time; catch colds easily',
          textKo: '오래 지치고 감기에 잘 걸려요',
          weights: {'qi_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Short of breath or sweaty from light effort',
          textKo: '조금만 움직여도 숨차거나 땀이 나요',
          weights: {'qi_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Recover normally',
          textKo: '보통은 금방 회복해요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'yang_deep_cold_area',
      textEn: 'Where do you feel cold the most?',
      textKo: '주로 어디가 차게 느껴지나요?',
      options: [
        PatternOption(
          textEn: 'Lower belly, lower back, or knees',
          textKo: '아랫배·허리·무릎이 시려요',
          weights: {'yang_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Hands and feet, all over',
          textKo: '손발과 온몸이 전반적으로 차요',
          weights: {'yang_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Not especially cold anywhere',
          textKo: '특별히 찬 곳은 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'yang_deep_urine',
      textEn: 'How is your urination?',
      textKo: '소변은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Frequent, clear, worse at night or when cold',
          textKo: '자주 마렵고 맑으며 밤이나 추울 때 심해요',
          weights: {'yang_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Normal',
          textKo: '보통이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'yin_deep_five_heart',
      textEn: 'Do your palms, soles, or chest feel warm — especially evenings?',
      textKo: '손바닥·발바닥·가슴에 열감이 있나요? (특히 저녁)',
      options: [
        PatternOption(
          textEn: 'Yes, they feel hot and I want to cool them',
          textKo: '네, 화끈거려서 시원하게 하고 싶어요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Cheeks flush in the late afternoon',
          textKo: '늦은 오후에 볼이 붉어져요',
          weights: {'yin_deficiency': 2},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'damp_deep_heaviness',
      textEn: 'Where does the heaviness sit?',
      textKo: '몸의 무거움은 어디에 느껴지나요?',
      options: [
        PatternOption(
          textEn: 'Head feels foggy, limbs heavy',
          textKo: '머리가 멍하고 팔다리가 무거워요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'Chest or stomach feels stuffed, phlegmy throat',
          textKo: '가슴·명치가 답답하고 가래가 껴요',
          weights: {'damp_phlegm': 2},
        ),
        PatternOption(
          textEn: 'No particular heaviness',
          textKo: '특별한 무거움은 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'damp_deep_weather',
      textEn: 'Do damp or rainy days make it worse?',
      textKo: '습하거나 비 오는 날 더 심해지나요?',
      options: [
        PatternOption(
          textEn: 'Clearly worse — heavier and more sluggish',
          textKo: '확실히 더 무겁고 처져요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'Not really',
          textKo: '별로 관계없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'liver_deep_chest',
      textEn: 'Do you get chest or flank tightness, or sighing?',
      textKo: '가슴·옆구리가 답답하거나 한숨이 나오나요?',
      options: [
        PatternOption(
          textEn: 'Yes, chest feels stuck and I sigh a lot',
          textKo: '네, 가슴이 막힌 듯하고 한숨이 잦아요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Tightness in the ribs/flank',
          textKo: '옆구리·갈비뼈 쪽이 결려요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'liver_deep_variability',
      textEn: 'Do your symptoms rise and fall with mood or the day?',
      textKo: '증상이 기분이나 그날그날에 따라 오르내리나요?',
      options: [
        PatternOption(
          textEn: 'Yes, they clearly change with stress and mood',
          textKo: '네, 스트레스·기분 따라 확 달라져요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'Fairly steady day to day',
          textKo: '대체로 일정한 편이에요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'stasis_deep_night',
      textEn: 'Is the pain fixed in one spot and worse at night?',
      textKo: '통증이 한 자리에 고정되고 밤에 심한가요?',
      options: [
        PatternOption(
          textEn: 'Yes, stabbing and always the same spot',
          textKo: '네, 콕콕 찌르고 늘 같은 자리예요',
          weights: {'blood_stasis': 3},
        ),
        PatternOption(
          textEn: 'Worse at night but moves around',
          textKo: '밤에 심하지만 자리가 옮겨 다녀요',
          weights: {'blood_stasis': 1, 'liver_qi': 1},
        ),
        PatternOption(
          textEn: 'No fixed pain',
          textKo: '고정된 통증은 없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'stasis_deep_bruise',
      textEn: 'Do you bruise easily or have dark/purplish spots?',
      textKo: '멍이 잘 들거나 어둡고 자줏빛 반점이 있나요?',
      options: [
        PatternOption(
          textEn: 'Yes, bruise easily; dark lips or complexion',
          textKo: '네, 멍이 잘 들고 입술·안색이 어두워요',
          weights: {'blood_stasis': 3},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'blood_deep_palpitation',
      textEn: 'Do you notice palpitations or a racing mind at rest?',
      textKo: '쉬는데도 가슴이 두근거리거나 생각이 많나요?',
      options: [
        PatternOption(
          textEn: 'Yes, heart flutters and mind won\'t settle',
          textKo: '네, 두근거리고 생각이 가라앉질 않아요',
          weights: {'blood_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Sometimes, mostly when tired',
          textKo: '가끔, 주로 피곤할 때요',
          weights: {'blood_deficiency': 1},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'blood_deep_vision',
      textEn: 'Any dizziness on standing, blurry vision, or numb limbs?',
      textKo: '일어설 때 어지럽거나 눈이 침침하고 손발이 저리나요?',
      options: [
        PatternOption(
          textEn: 'Yes, dizzy standing up and eyes tire/blur',
          textKo: '네, 일어설 때 어지럽고 눈이 침침해요',
          weights: {'blood_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Hands or feet go numb/tingly',
          textKo: '손발이 저리거나 무감각할 때가 있어요',
          weights: {'blood_deficiency': 2},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    // ── Chapter 2, second tier — connected only when the patient chooses to
    // keep answering at the checkpoint, to refine the leading direction. ──
    PatternQuestion(
      id: 'qi_deep_voice',
      textEn: 'How are your voice and energy when talking or active?',
      textKo: '말하거나 활동할 때 목소리·기력은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'My voice trails off and gets quiet',
          textKo: '말끝이 힘없고 목소리가 작아져요',
          weights: {'qi_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Energy drops sharply as the day goes on',
          textKo: '오후로 갈수록 기운이 뚝 떨어져요',
          weights: {'qi_deficiency': 2},
        ),
        PatternOption(
          textEn: 'About the same as usual',
          textKo: '평소와 비슷해요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'yang_deep_digest_cold',
      textEn: 'What happens when you eat or drink cold things?',
      textKo: '찬 음식·찬 물을 먹으면 어떤가요?',
      options: [
        PatternOption(
          textEn: 'I get belly pain or loose stools',
          textKo: '배가 아프거나 설사를 해요',
          weights: {'yang_deficiency': 3},
        ),
        PatternOption(
          textEn: 'I need something warm to feel settled',
          textKo: '따뜻한 걸 먹어야 속이 편해요',
          weights: {'yang_deficiency': 2},
        ),
        PatternOption(
          textEn: 'No real difference',
          textKo: '별로 상관없어요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'yin_deep_night_sweat',
      textEn: 'Night sweats or a dry mouth/throat before dawn?',
      textKo: '잘 때 땀이 나거나 새벽에 입·목이 마르나요?',
      options: [
        PatternOption(
          textEn: 'I sweat in my sleep and wake with a dry mouth',
          textKo: '자다가 땀이 나고 새벽에 입이 말라요',
          weights: {'yin_deficiency': 3},
        ),
        PatternOption(
          textEn: 'I reach for water often at night',
          textKo: '밤에 물을 자주 찾아요',
          weights: {'yin_deficiency': 2},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'damp_deep_mouth',
      textEn: 'How are your mouth and appetite?',
      textKo: '입안과 식욕은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Mouth feels sticky/coated, food goes down poorly',
          textKo: '입이 끈적하고 텁텁하며 잘 안 넘어가요',
          weights: {'damp_phlegm': 3},
        ),
        PatternOption(
          textEn: 'I crave sweets and swell up easily',
          textKo: '단 게 당기고 잘 붓는 편이에요',
          weights: {'damp_phlegm': 2},
        ),
        PatternOption(
          textEn: 'Nothing unusual',
          textKo: '특별하지 않아요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'liver_deep_neck',
      textEn: 'Do your neck, shoulders, or jaw tense up often?',
      textKo: '목·어깨·턱이 자주 뭉치거나 뻐근한가요?',
      options: [
        PatternOption(
          textEn: 'Yes, my neck/shoulders tighten when stressed',
          textKo: '네, 긴장하면 목·어깨가 뻐근해요',
          weights: {'liver_qi': 3},
        ),
        PatternOption(
          textEn: 'I clench my jaw or get headaches',
          textKo: '이를 악물거나 두통이 와요',
          weights: {'liver_qi': 2},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'stasis_deep_dark',
      textEn: 'Is the pain/blood dark, clotted, or purplish? (incl. periods)',
      textKo: '통증·혈색이 검붉거나 덩어리가 있나요? (생리 포함)',
      options: [
        PatternOption(
          textEn: 'Yes, dark, clotted, and stabbing',
          textKo: '네, 어둡고 덩어리지며 콕콕 찔러요',
          weights: {'blood_stasis': 3},
        ),
        PatternOption(
          textEn: 'Sometimes',
          textKo: '가끔 그런 편이에요',
          weights: {'blood_stasis': 1},
        ),
        PatternOption(
          textEn: 'No',
          textKo: '아니요',
        ),
      ],
    ),
    PatternQuestion(
      id: 'blood_deep_dryness',
      textEn: 'How dry are your hair, nails, and skin?',
      textKo: '머릿결·손톱·피부 건조함은 어떤가요?',
      options: [
        PatternOption(
          textEn: 'Hair sheds, nails split, skin is dry',
          textKo: '머리 잘 빠지고 손톱이 잘 갈라지며 건조해요',
          weights: {'blood_deficiency': 3},
        ),
        PatternOption(
          textEn: 'Skin looks dull and pale',
          textKo: '피부가 푸석하고 창백한 편이에요',
          weights: {'blood_deficiency': 2},
        ),
        PatternOption(
          textEn: 'Fine',
          textKo: '괜찮아요',
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

  /// Sentinel option index meaning "the patient typed their own answer".
  static const int freeTextOption = -1;

  final Map<String, int> _scores = {
    for (final p in PatternFinderService.patterns) p.id: 0,
  };

  /// questionId -> chosen option index (or [freeTextOption]), in answer order.
  final List<MapEntry<String, int>> _answers = [];

  /// questionId -> the patient's typed answer, for free-text entries.
  final Map<String, String> _freeTexts = {};

  /// Whether the patient chose to continue into Chapter 2 at the checkpoint.
  /// null = not asked yet, true = keep answering, false = stop after Chapter 1.
  bool? _deepOptIn;

  List<MapEntry<String, int>> get answers => List.unmodifiable(_answers);

  int get answeredCount => _answers.length;

  /// The patient's checkpoint choice (null until they decide).
  bool? get deepDiveChoice => _deepOptIn;

  /// True when Chapter 1 is complete and the patient hasn't yet chosen whether
  /// to keep going — the moment to show the "answer more?" checkpoint.
  bool get atDeepCheckpoint =>
      _answers.length == PatternFinderService.commonQuestionCount &&
      _deepOptIn == null;

  /// Records the checkpoint decision.
  void chooseDeepDive(bool keepGoing) => _deepOptIn = keepGoing;

  /// Re-opens the checkpoint (used when the patient steps back to it).
  void clearDeepDiveChoice() => _deepOptIn = null;

  /// Total questions the current path plans to ask — Chapter 1 only until the
  /// patient opts in, then Chapter 1 + the deep-dive cap.
  int get plannedTotal => _deepOptIn == true
      ? PatternFinderService.commonQuestionCount +
          PatternFinderService.deepDiveCap
      : PatternFinderService.commonQuestionCount;

  bool get isDone {
    if (_answers.length >= PatternFinderService.questions.length) return true;
    if (currentChapter == 1) return false;
    // Chapter 2 runs only when the patient opted in, capped at deepDiveCap.
    if (_deepOptIn != true) return true;
    return _answers.length - PatternFinderService.commonQuestionCount >=
        PatternFinderService.deepDiveCap;
  }

  Set<String> get _answeredIds => {for (final a in _answers) a.key};

  /// Which chapter the *next* question belongs to: 1 (common) or 2 (deep-dive).
  int get currentChapter =>
      _answers.length < PatternFinderService.commonQuestionCount ? 1 : 2;

  /// The next question to ask, or null when the session is done.
  ///
  /// **Chapter 1 (common):** the fixed [PatternFinderService.commonQuestionIds]
  /// in order, so everyone answers the same broad questions first.
  ///
  /// **Chapter 2 (deep-dive):** the leading pattern's own questions
  /// ([PatternFinderService.deepDiveIdsByPattern]) are asked to confirm and
  /// refine that direction; once its questions run out, the runner-up's are
  /// used. Two patients with different Chapter 1 answers get different
  /// Chapter 2 questions — that's where the picture sharpens.
  PatternQuestion? nextQuestion() {
    if (isDone) return null;
    final answered = _answeredIds;

    if (currentChapter == 1) {
      for (final id in PatternFinderService.commonQuestionIds) {
        if (!answered.contains(id)) return PatternFinderService.questionById[id];
      }
    }

    // Chapter 2: walk the ranked patterns, serving each one's deep-dive
    // questions before moving to the next.
    for (final patternId in _rankedPatternIds()) {
      if ((_scores[patternId] ?? 0) <= 0) break; // no signal below here
      for (final id
          in PatternFinderService.deepDiveIdsByPattern[patternId] ?? const []) {
        if (!answered.contains(id)) return PatternFinderService.questionById[id];
      }
    }

    // Fallback (e.g. all-neutral Chapter 1): any unasked deep-dive question.
    for (final ids in PatternFinderService.deepDiveIdsByPattern.values) {
      for (final id in ids) {
        if (!answered.contains(id)) return PatternFinderService.questionById[id];
      }
    }
    return null;
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

  /// Records a typed answer instead of a multiple-choice option. Free-text
  /// answers carry no pattern weights — scoring stays predictable and
  /// reviewable — but they are kept verbatim for the recap and for sharing
  /// with the practitioner.
  void answerFreeText(String questionId, String text) {
    final question = PatternFinderService.questionById[questionId];
    final trimmed = text.trim();
    if (question == null || trimmed.isEmpty) return;
    _answers.add(MapEntry(questionId, freeTextOption));
    _freeTexts[questionId] = trimmed;
  }

  /// Every question asked so far with the chosen answer, in order — for the
  /// "review my answers" section on the result screen and for sharing.
  /// Each entry is (question, chosen option).
  List<(PatternQuestion, PatternOption)> answeredPairs() {
    final pairs = <(PatternQuestion, PatternOption)>[];
    for (final entry in _answers) {
      final question = PatternFinderService.questionById[entry.key];
      if (question == null) continue;
      if (entry.value == freeTextOption) {
        final text = _freeTexts[entry.key] ?? '';
        pairs.add((
          question,
          PatternOption(textEn: text, textKo: text),
        ));
      } else {
        pairs.add((question, question.options[entry.value]));
      }
    }
    return pairs;
  }

  /// Whether the answer at [questionId] was typed by the patient.
  bool isFreeText(String questionId) => _freeTexts.containsKey(questionId);

  /// Removes the most recent answer (back button support).
  void undo() {
    if (_answers.isEmpty) return;
    final last = _answers.removeLast();
    if (last.value == freeTextOption) {
      _freeTexts.remove(last.key);
      return;
    }
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
        if (question == null || a.value == freeTextOption) continue;
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
  ///
  /// [profile] carries baseline patient context (age range, sex, ethnicity,
  /// height/weight/BMI). It is surfaced to the practitioner verbatim and never
  /// used for scoring — constitution-classification studies in the corpus use
  /// demographics as practitioner-reviewed context, and BMI evidence there is
  /// too thin to justify automatic weighting.
  Map<String, dynamic> toCarePicture({
    List<String> extraNextQuestions = const [],
    Map<String, dynamic> profile = const {},
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
      'confidence': res.confidence.name,
      'isCombined': res.isCombined,
      'profileContext': profile,
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
