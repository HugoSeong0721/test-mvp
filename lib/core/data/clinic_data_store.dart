import 'package:flutter/foundation.dart';

enum IntakeStatus { notStarted, inProgress, completed }

extension IntakeStatusLabel on IntakeStatus {
  String get label {
    switch (this) {
      case IntakeStatus.notStarted:
        return 'Pre-Visit Intake Response 0%';
      case IntakeStatus.inProgress:
        return 'Pre-Visit Intake Response 50%';
      case IntakeStatus.completed:
        return 'Pre-Visit Intake Response 100%';
    }
  }
}

class QaItem {
  const QaItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.birthYear,
    required this.sex,
    required this.ethnicity,
    required this.memo,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final int birthYear;
  final String sex;
  final String ethnicity;
  final String memo;

  bool get hasContactInfo => phone.trim().isNotEmpty || email.trim().isNotEmpty;
  bool get hasRequiredAlertInfo =>
      phone.trim().isNotEmpty && email.trim().isNotEmpty;

  String get ageRange {
    final age = DateTime.now().year - birthYear;
    if (age < 30) return '20s';
    if (age < 40) return '30s';
    if (age < 50) return '40s';
    if (age < 60) return '50s';
    return '60s+';
  }

  PatientProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? birthYear,
    String? sex,
    String? ethnicity,
    String? memo,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      birthYear: birthYear ?? this.birthYear,
      sex: sex ?? this.sex,
      ethnicity: ethnicity ?? this.ethnicity,
      memo: memo ?? this.memo,
    );
  }
}

class PatientVisit {
  const PatientVisit({
    required this.id,
    required this.patientId,
    required this.date,
    required this.time,
    required this.lastVisitDate,
    required this.daysAgo,
    required this.scheduledSinceLast,
    required this.noShowSinceLast,
    required this.intakeStatus,
    required this.previousTreatmentArea,
    required this.previousSessionNote,
    required this.qaList,
  });

  final String id;
  final String patientId;
  final String date;
  final String time;
  final String lastVisitDate;
  final int daysAgo;
  final int scheduledSinceLast;
  final int noShowSinceLast;
  final IntakeStatus intakeStatus;
  final String previousTreatmentArea;
  final String previousSessionNote;
  final List<QaItem> qaList;
}

class ScheduledVisit {
  const ScheduledVisit({
    required this.profile,
    required this.visit,
  });

  final PatientProfile profile;
  final PatientVisit visit;
}

class PatientHistoryArgs {
  const PatientHistoryArgs({
    required this.current,
    required this.history,
  });

  final ScheduledVisit current;
  final List<ScheduledVisit> history;
}

class ClinicDataStore extends ChangeNotifier {
  ClinicDataStore._();

  static final ClinicDataStore instance = ClinicDataStore._();
  String _currentPatientId = 'jane_kim';

  final List<PatientProfile> _profiles = [
    const PatientProfile(
      id: 'hugo_demo',
      name: 'Hugo Seong',
      phone: '201-555-0199',
      email: 'hugo.demo@example.com',
      birthYear: 1991,
      sex: 'Male',
      ethnicity: 'Korean',
      memo: 'My real-use test profile',
    ),
    const PatientProfile(
      id: 'jane_kim',
      name: 'Jane Kim',
      phone: '201-555-0101',
      email: 'jane.demo@example.com',
      birthYear: 1990,
      sex: 'Female',
      ethnicity: 'Korean',
      memo: 'Track sleep and shoulder pain',
    ),
    const PatientProfile(
      id: 'min_park',
      name: 'Min Park',
      phone: '',
      email: '',
      birthYear: 1988,
      sex: 'Male',
      ethnicity: 'Korean',
      memo: 'Example with missing contact info',
    ),
    const PatientProfile(
      id: 'eunji_lee',
      name: 'Eunji Lee',
      phone: '646-555-0130',
      email: 'eunji.demo@example.com',
      birthYear: 1993,
      sex: 'Female',
      ethnicity: 'Korean',
      memo: 'Track digestion and thirst patterns',
    ),
    const PatientProfile(
      id: 'daniel_cho',
      name: 'Daniel Cho',
      phone: '917-555-0142',
      email: '',
      birthYear: 1985,
      sex: 'Male',
      ethnicity: 'Korean',
      memo: 'Track tension headache pattern',
    ),
    const PatientProfile(
      id: 'hana_yoo',
      name: 'Hana Yoo',
      phone: '718-555-0155',
      email: 'hana.demo@example.com',
      birthYear: 1997,
      sex: 'Female',
      ethnicity: 'Korean',
      memo: 'Watch for night sweating and headaches',
    ),
    const PatientProfile(
      id: 'chris_jung',
      name: 'Chris Jung',
      phone: '212-555-0170',
      email: '',
      birthYear: 1982,
      sex: 'Male',
      ethnicity: 'Korean',
      memo: 'Review low back pain and no-show history',
    ),
  ];

  final List<PatientVisit> _visits = [
    PatientVisit(
      id: 'visit_000',
      patientId: 'hugo_demo',
      date: '2026-04-15',
      time: '2:30 PM',
      lastVisitDate: '2026-04-05',
      daysAgo: 10,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.inProgress,
      previousTreatmentArea: 'Cervical area + right scapular region',
      previousSessionNote: 'Track changes in sleep and shoulder tension.',
      qaList: const [
        QaItem(category: 'Sleep', question: 'How has your sleep been recently?', answer: 'There were days when I woke up once or twice during the night.'),
        QaItem(category: 'Energy', question: 'How is your fatigue during the day?', answer: 'My focus drops later in the afternoon.'),
      ],
    ),
    PatientVisit(
      id: 'visit_001',
      patientId: 'daniel_cho',
      date: '2026-04-01',
      time: '4:00 PM',
      lastVisitDate: '2026-03-18',
      daysAgo: 14,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Upper trapezius + temple area',
      previousSessionNote: 'Tension headache pattern.',
      qaList: const [
        QaItem(category: 'HEENT', question: 'How are your headaches and eye fatigue?', answer: 'My eyes feel strained in the afternoon and I get headaches.'),
        QaItem(category: 'Emotion', question: 'How have your mood swings been?', answer: 'I have been more sensitive and irritable.'),
      ],
    ),
    PatientVisit(
      id: 'visit_002',
      patientId: 'min_park',
      date: '2026-04-01',
      time: '5:30 PM',
      lastVisitDate: '2026-03-15',
      daysAgo: 17,
      scheduledSinceLast: 2,
      noShowSinceLast: 1,
      intakeStatus: IntakeStatus.notStarted,
      previousTreatmentArea: 'Lumbar area + glute trigger points',
      previousSessionNote: 'Pain gets worse when sitting for a long time.',
      qaList: const [],
    ),
    PatientVisit(
      id: 'visit_003',
      patientId: 'jane_kim',
      date: '2026-04-08',
      time: '3:30 PM',
      lastVisitDate: '2026-04-01',
      daysAgo: 7,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Right scapular region + cervical C5-C7 area',
      previousSessionNote: 'Strong tenderness along the medial scapula, frequent early waking.',
      qaList: const [
        QaItem(category: 'Sleep', question: 'How has your sleep been recently?', answer: 'I often wake up around 3 AM and have trouble falling back asleep.'),
        QaItem(category: 'Energy', question: 'How is your afternoon fatigue?', answer: 'I get much more tired after 2 PM.'),
      ],
    ),
    PatientVisit(
      id: 'visit_004',
      patientId: 'hana_yoo',
      date: '2026-04-12',
      time: '5:30 PM',
      lastVisitDate: '2026-04-08',
      daysAgo: 4,
      scheduledSinceLast: 0,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.inProgress,
      previousTreatmentArea: 'Temple area + sternocleidomastoid',
      previousSessionNote: 'Tracking headache frequency.',
      qaList: const [
        QaItem(category: 'Temperature/Sweat', question: 'How have sweating and temperature changes been?', answer: 'I sometimes get cold sweats at night.'),
      ],
    ),
    PatientVisit(
      id: 'visit_005',
      patientId: 'jane_kim',
      date: '2026-04-15',
      time: '3:30 PM',
      lastVisitDate: '2026-04-08',
      daysAgo: 7,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Right scapular region + cervical C5-C7 area',
      previousSessionNote: 'Strong tenderness along the medial scapula, frequent early waking.',
      qaList: const [
        QaItem(category: 'Sleep', question: 'How has your sleep been recently?', answer: 'I often wake up around 3 AM and have trouble falling back asleep.'),
        QaItem(category: 'Energy', question: 'How is your afternoon fatigue?', answer: 'I get much more tired after 2 PM.'),
        QaItem(category: 'Emotion', question: 'How high has your stress been recently?', answer: 'My work stress has been pretty high.'),
      ],
    ),
    PatientVisit(
      id: 'visit_006',
      patientId: 'min_park',
      date: '2026-04-15',
      time: '4:00 PM',
      lastVisitDate: '2026-03-31',
      daysAgo: 15,
      scheduledSinceLast: 2,
      noShowSinceLast: 1,
      intakeStatus: IntakeStatus.notStarted,
      previousTreatmentArea: 'Lumbar area + glute trigger points',
      previousSessionNote: 'Pain gets worse when sitting for a long time.',
      qaList: const [],
    ),
    PatientVisit(
      id: 'visit_007',
      patientId: 'eunji_lee',
      date: '2026-04-15',
      time: '4:30 PM',
      lastVisitDate: '2026-04-10',
      daysAgo: 5,
      scheduledSinceLast: 0,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.inProgress,
      previousTreatmentArea: 'Abdominal area + digestive points',
      previousSessionNote: 'Reports abdominal bloating after meals.',
      qaList: const [
        QaItem(category: 'Appetite/Thirst', question: 'How have your appetite and thirst been?', answer: 'My mouth gets dry often and I keep reaching for cold water.'),
      ],
    ),
    PatientVisit(
      id: 'visit_008',
      patientId: 'daniel_cho',
      date: '2026-04-15',
      time: '5:00 PM',
      lastVisitDate: '2026-04-01',
      daysAgo: 14,
      scheduledSinceLast: 3,
      noShowSinceLast: 1,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Upper trapezius + temple area',
      previousSessionNote: 'Tension headache pattern.',
      qaList: const [
        QaItem(category: 'HEENT', question: 'How are your headaches and eye fatigue?', answer: 'My eyes feel strained in the afternoon and I get headaches.'),
        QaItem(category: 'Emotion', question: 'How have your mood swings been?', answer: 'I have been more sensitive and irritable.'),
      ],
    ),
    PatientVisit(
      id: 'visit_009',
      patientId: 'hana_yoo',
      date: '2026-04-15',
      time: '5:30 PM',
      lastVisitDate: '2026-04-12',
      daysAgo: 3,
      scheduledSinceLast: 0,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.inProgress,
      previousTreatmentArea: 'Temple area + sternocleidomastoid',
      previousSessionNote: 'Tracking headache frequency.',
      qaList: const [
        QaItem(category: 'Temperature/Sweat', question: 'How have sweating and temperature changes been?', answer: 'I sometimes get cold sweats at night.'),
      ],
    ),
    PatientVisit(
      id: 'visit_010',
      patientId: 'chris_jung',
      date: '2026-04-15',
      time: '6:00 PM',
      lastVisitDate: '2026-03-20',
      daysAgo: 26,
      scheduledSinceLast: 2,
      noShowSinceLast: 2,
      intakeStatus: IntakeStatus.notStarted,
      previousTreatmentArea: 'Lumbar erectors + hamstrings',
      previousSessionNote: 'Worse after long periods of driving.',
      qaList: const [],
    ),
  ];

  List<PatientProfile> get profiles => List.unmodifiable(_profiles);

  PatientProfile get currentPatientProfile =>
      profileById(_currentPatientId) ?? _profiles.first;

  List<String> get allDates {
    final dates = _visits
        .map((visit) => visit.date)
        .toSet()
        .toList()
      ..sort();
    return dates;
  }

  PatientProfile? profileById(String patientId) {
    try {
      return _profiles.firstWhere((profile) => profile.id == patientId);
    } catch (_) {
      return null;
    }
  }

  void setCurrentPatientProfile(String patientId) {
    final profile = profileById(patientId);
    if (profile == null) {
      return;
    }
    _currentPatientId = patientId;
    notifyListeners();
  }

  List<ScheduledVisit> visitsForDate(String date) {
    return _visits
        .where((visit) => visit.date == date)
        .map((visit) {
          final profile = profileById(visit.patientId);
          if (profile == null) {
            return null;
          }
          return ScheduledVisit(profile: profile, visit: visit);
        })
        .whereType<ScheduledVisit>()
        .toList();
  }

  List<ScheduledVisit> visitsInRange(DateTime start, DateTime end) {
    return _visits
        .where((visit) {
          final date = DateTime.parse(visit.date);
          return !date.isBefore(DateTime(start.year, start.month, start.day)) &&
              !date.isAfter(DateTime(end.year, end.month, end.day));
        })
        .map((visit) {
          final profile = profileById(visit.patientId);
          if (profile == null) {
            return null;
          }
          return ScheduledVisit(profile: profile, visit: visit);
        })
        .whereType<ScheduledVisit>()
        .toList();
  }

  List<ScheduledVisit> historyForPatient(String patientId) {
    return _visits
        .where((visit) => visit.patientId == patientId)
        .map((visit) {
          final profile = profileById(visit.patientId);
          if (profile == null) {
            return null;
          }
          return ScheduledVisit(profile: profile, visit: visit);
        })
        .whereType<ScheduledVisit>()
        .toList()
      ..sort((a, b) => b.visit.date.compareTo(a.visit.date));
  }

  List<ScheduledVisit> upcomingVisits(DateTime fromDate) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    return _visits
        .where((visit) => DateTime.parse(visit.date).isAfter(from))
        .map((visit) {
          final profile = profileById(visit.patientId);
          if (profile == null) {
            return null;
          }
          return ScheduledVisit(profile: profile, visit: visit);
        })
        .whereType<ScheduledVisit>()
        .toList()
      ..sort((a, b) {
        final dateCompare = a.visit.date.compareTo(b.visit.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.visit.time.compareTo(b.visit.time);
      });
  }

  void saveProfile(PatientProfile profile) {
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
    notifyListeners();
  }

  void deleteProfile(String profileId) {
    _profiles.removeWhere((profile) => profile.id == profileId);
    notifyListeners();
  }
}

