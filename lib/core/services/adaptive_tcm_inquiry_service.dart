class AdaptiveTcmInquiryService {
  AdaptiveTcmInquiryService._();

  static Map<String, dynamic> buildCarePicture({
    required List<Map<String, dynamic>> answers,
    required Map<String, dynamic> profile,
  }) {
    final text = answers
        .map(
          (answer) =>
              '${answer['questionText'] ?? ''} ${answer['answerText'] ?? ''}',
        )
        .join(' ')
        .toLowerCase();
    final signals = <Map<String, dynamic>>[];

    void addSignal({
      required String domain,
      required String label,
      required int weight,
      required List<String> evidence,
    }) {
      signals.add({
        'domain': domain,
        'label': label,
        'weight': weight,
        'evidence': evidence,
      });
    }

    final coldEvidence = _hits(text, const [
      'cold',
      'chilly',
      'cold hands',
      'cold feet',
      'prefer warm',
      'warm drink',
    ]);
    if (coldEvidence.isNotEmpty) {
      addSignal(
        domain: 'temperature',
        label: 'Cold tendency',
        weight: coldEvidence.length,
        evidence: coldEvidence,
      );
    }

    final heatEvidence = _hits(text, const [
      'hot',
      'warm',
      'night sweat',
      'thirsty',
      'dry mouth',
      'prefer cold',
      'cold water',
    ]);
    if (heatEvidence.isNotEmpty) {
      addSignal(
        domain: 'temperature',
        label: 'Heat or dryness tendency',
        weight: heatEvidence.length,
        evidence: heatEvidence,
      );
    }

    final sleepEvidence = _hits(text, const [
      'wake',
      '3 am',
      'insomnia',
      'dream',
      'restless',
      'hard to fall asleep',
      'light sleep',
    ]);
    if (sleepEvidence.isNotEmpty) {
      addSignal(
        domain: 'sleep',
        label: 'Sleep disruption',
        weight: sleepEvidence.length,
        evidence: sleepEvidence,
      );
    }

    final digestionEvidence = _hits(text, const [
      'bloat',
      'full',
      'heavy',
      'reflux',
      'heartburn',
      'gas',
      'burp',
      'nausea',
      'slow',
    ]);
    if (digestionEvidence.isNotEmpty) {
      addSignal(
        domain: 'digestion',
        label: 'Digestive burden',
        weight: digestionEvidence.length,
        evidence: digestionEvidence,
      );
    }

    final fatigueEvidence = _hits(text, const [
      'fatigue',
      'tired',
      'low energy',
      'exhausted',
      'afternoon crash',
      'weak',
    ]);
    if (fatigueEvidence.isNotEmpty) {
      addSignal(
        domain: 'energy',
        label: 'Low or unstable energy',
        weight: fatigueEvidence.length,
        evidence: fatigueEvidence,
      );
    }

    final emotionEvidence = _hits(text, const [
      'stress',
      'anxious',
      'anxiety',
      'irritable',
      'frustrated',
      'tense',
      'worried',
    ]);
    if (emotionEvidence.isNotEmpty) {
      addSignal(
        domain: 'emotion',
        label: 'Emotional tension',
        weight: emotionEvidence.length,
        evidence: emotionEvidence,
      );
    }

    final painEvidence = _hits(text, const [
      'pain',
      'ache',
      'sharp',
      'dull',
      'fixed',
      'moving',
      'tension',
      'stiff',
    ]);
    if (painEvidence.isNotEmpty) {
      addSignal(
        domain: 'body',
        label: 'Pain or tension pattern',
        weight: painEvidence.length,
        evidence: painEvidence,
      );
    }

    signals.sort((a, b) => (b['weight'] as int).compareTo(a['weight'] as int));
    final domains = signals.map((signal) => signal['domain']).toSet();
    final patternDirections = _patternDirections(domains);
    final nextQuestions = _nextQuestions(domains);

    return {
      'version': 1,
      'basis':
          'Rule-based adaptive inquiry inspired by decision-tree symptom selection, active inquiry, and KG-style signal accumulation. This is not a diagnosis.',
      'notDiagnosis': true,
      'profileContext': profile,
      'signals': signals.take(8).toList(),
      'patternDirections': patternDirections,
      'nextBestQuestions': nextQuestions,
      'missingDomains': _missingDomains(domains),
      'updatedAtClient': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static List<String> _hits(String text, List<String> keywords) {
    return keywords.where((keyword) => text.contains(keyword)).toList();
  }

  /// Maps a pattern direction produced by [_patternDirections] to a search
  /// query for the bundled research corpus (see ResearchCorpusService), so the
  /// practitioner can jump from a suggested direction to the literature that
  /// motivates it. Falls back to a general syndrome-differentiation query for
  /// unrecognized directions.
  static String researchQueryForDirection(String direction) {
    final d = direction.toLowerCase();
    if (d.contains('spleen') || d.contains('damp')) {
      return 'spleen deficiency damp digestion syndrome differentiation';
    }
    if (d.contains('cold-heat') || d.contains('deficiency/excess')) {
      return 'cold heat deficiency excess syndrome differentiation classification';
    }
    if (d.contains('shen') || d.contains('liver')) {
      return 'insomnia emotion liver depression syndrome differentiation';
    }
    if (d.contains('pain')) {
      return 'pain syndrome differentiation acupuncture inquiry';
    }
    return 'syndrome differentiation adaptive inquiry question';
  }

  static List<String> _patternDirections(Set<dynamic> domains) {
    final directions = <String>[];
    if (domains.contains('digestion') && domains.contains('energy')) {
      directions.add('Clarify Spleen qi / damp tendency');
    }
    if (domains.contains('temperature') && domains.contains('energy')) {
      directions.add('Clarify cold-heat and deficiency/excess direction');
    }
    if (domains.contains('sleep') && domains.contains('emotion')) {
      directions.add('Clarify shen disturbance and Liver constraint signals');
    }
    if (domains.contains('body') && domains.contains('emotion')) {
      directions.add('Clarify pain quality, movement, and stress relationship');
    }
    if (directions.isEmpty) {
      directions.add('Collect more baseline evidence before pattern direction');
    }
    return directions;
  }

  static List<String> _nextQuestions(Set<dynamic> domains) {
    final questions = <String>[];
    if (domains.contains('digestion')) {
      questions.add(
        'After which meals does bloating or heaviness feel strongest?',
      );
      questions.add('Is stool more loose, dry, sticky, or irregular?');
    }
    if (domains.contains('sleep')) {
      questions.add(
        'What time do you wake most often, and what do you feel then?',
      );
      questions.add('Do dreams, heat, urination, or stress wake you?');
    }
    if (domains.contains('temperature')) {
      questions.add(
        'Do you prefer warmth or cold, and where do you feel it most?',
      );
      questions.add('Any night sweats, dry mouth, or cold hands and feet?');
    }
    if (domains.contains('energy')) {
      questions.add('When does fatigue peak: morning, afternoon, or evening?');
    }
    if (domains.contains('emotion')) {
      questions.add('Do symptoms get worse with stress or frustration?');
    }
    if (domains.contains('body')) {
      questions.add('Is the pain sharp/fixed, dull/heavy, or moving?');
    }
    if (questions.isEmpty) {
      questions.add('What changed most since your last visit?');
      questions.add('What symptom should your practitioner focus on first?');
    }
    return questions.take(5).toList();
  }

  static List<String> _missingDomains(Set<dynamic> domains) {
    const allDomains = [
      'sleep',
      'digestion',
      'temperature',
      'energy',
      'emotion',
      'body',
    ];
    return allDomains.where((domain) => !domains.contains(domain)).toList();
  }
}
