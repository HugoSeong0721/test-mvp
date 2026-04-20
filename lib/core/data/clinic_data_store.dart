import 'package:flutter/foundation.dart';

enum IntakeStatus { notStarted, inProgress, completed }

extension IntakeStatusLabel on IntakeStatus {
  String get label {
    switch (this) {
      case IntakeStatus.notStarted:
        return '사전문진 응답률 0%';
      case IntakeStatus.inProgress:
        return '사전문진 응답률 50%';
      case IntakeStatus.completed:
        return '사전문진 응답률 100%';
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
    if (age < 30) return '20대';
    if (age < 40) return '30대';
    if (age < 50) return '40대';
    if (age < 60) return '50대';
    return '60대+';
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
      sex: '남성',
      ethnicity: 'Korean',
      memo: '실사용 테스트용 본인 프로필',
    ),
    const PatientProfile(
      id: 'jane_kim',
      name: 'Jane Kim',
      phone: '201-555-0101',
      email: 'jane.demo@example.com',
      birthYear: 1990,
      sex: '여성',
      ethnicity: 'Korean',
      memo: '수면/어깨 통증 추적 필요',
    ),
    const PatientProfile(
      id: 'min_park',
      name: 'Min Park',
      phone: '',
      email: '',
      birthYear: 1988,
      sex: '남성',
      ethnicity: 'Korean',
      memo: '연락처 미입력 예시',
    ),
    const PatientProfile(
      id: 'eunji_lee',
      name: 'Eunji Lee',
      phone: '646-555-0130',
      email: 'eunji.demo@example.com',
      birthYear: 1993,
      sex: '여성',
      ethnicity: 'Korean',
      memo: '소화/갈증 패턴 추적',
    ),
    const PatientProfile(
      id: 'daniel_cho',
      name: 'Daniel Cho',
      phone: '917-555-0142',
      email: '',
      birthYear: 1985,
      sex: '남성',
      ethnicity: 'Korean',
      memo: '긴장성 두통 추적',
    ),
    const PatientProfile(
      id: 'hana_yoo',
      name: 'Hana Yoo',
      phone: '718-555-0155',
      email: 'hana.demo@example.com',
      birthYear: 1997,
      sex: '여성',
      ethnicity: 'Korean',
      memo: '야간 식은땀/두통 관찰',
    ),
    const PatientProfile(
      id: 'chris_jung',
      name: 'Chris Jung',
      phone: '212-555-0170',
      email: '',
      birthYear: 1982,
      sex: '남성',
      ethnicity: 'Korean',
      memo: '허리 통증/노쇼 이력 확인',
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
      previousTreatmentArea: '경추 + 우측 견갑 주변',
      previousSessionNote: '수면과 어깨 긴장도 변화 추적 필요.',
      qaList: const [
        QaItem(category: 'Sleep', question: '최근 수면은 어떠셨나요?', answer: '중간에 한두 번 깨는 날이 있었어요.'),
        QaItem(category: 'Energy', question: '하루 중 피로는 어떤가요?', answer: '오후 늦게 집중력이 떨어져요.'),
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
      previousTreatmentArea: '승모근 상부 + 측두부',
      previousSessionNote: '긴장성 두통 패턴.',
      qaList: const [
        QaItem(category: 'HEENT', question: '두통/눈피로는?', answer: '오후에 눈이 뻑뻑하고 두통이 와요.'),
        QaItem(category: 'Emotion', question: '감정 기복은?', answer: '예민해지고 짜증이 늘었어요.'),
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
      previousTreatmentArea: '요추 주변 + 둔부 트리거포인트',
      previousSessionNote: '장시간 앉을 때 통증 악화.',
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
      previousTreatmentArea: '우측 견갑 주변 + 경추 C5-C7 주변',
      previousSessionNote: '견갑 내측 압통 강함, 새벽 각성 빈도 높음.',
      qaList: const [
        QaItem(category: 'Sleep', question: '최근 수면은 어떠셨나요?', answer: '새벽 3시에 자주 깨고 다시 잠들기 어려워요.'),
        QaItem(category: 'Energy', question: '오후 피로감은 어떤가요?', answer: '오후 2시 이후 급격히 피곤해져요.'),
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
      previousTreatmentArea: '측두부 + 흉쇄유돌근',
      previousSessionNote: '두통 빈도 추적 중.',
      qaList: const [
        QaItem(category: 'Temperature/Sweat', question: '땀/체온 변화는?', answer: '밤에 식은땀이 가끔 나요.'),
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
      previousTreatmentArea: '우측 견갑 주변 + 경추 C5-C7 주변',
      previousSessionNote: '견갑 내측 압통 강함, 새벽 각성 빈도 높음.',
      qaList: const [
        QaItem(category: 'Sleep', question: '최근 수면은 어떠셨나요?', answer: '새벽 3시에 자주 깨고 다시 잠들기 어려워요.'),
        QaItem(category: 'Energy', question: '오후 피로감은 어떤가요?', answer: '오후 2시 이후 급격히 피곤해져요.'),
        QaItem(category: 'Emotion', question: '최근 스트레스 정도는?', answer: '업무 스트레스가 높은 편이에요.'),
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
      previousTreatmentArea: '요추 주변 + 둔부 트리거포인트',
      previousSessionNote: '장시간 앉을 때 통증 악화.',
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
      previousTreatmentArea: '복부 + 비위 관련 포인트',
      previousSessionNote: '식후 복부팽만 호소.',
      qaList: const [
        QaItem(category: 'Appetite/Thirst', question: '식욕/갈증은 어떠셨나요?', answer: '입이 자주 마르고 찬물 찾게 돼요.'),
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
      previousTreatmentArea: '승모근 상부 + 측두부',
      previousSessionNote: '긴장성 두통 패턴.',
      qaList: const [
        QaItem(category: 'HEENT', question: '두통/눈피로는?', answer: '오후에 눈이 뻑뻑하고 두통이 와요.'),
        QaItem(category: 'Emotion', question: '감정 기복은?', answer: '예민해지고 짜증이 늘었어요.'),
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
      previousTreatmentArea: '측두부 + 흉쇄유돌근',
      previousSessionNote: '두통 빈도 추적 중.',
      qaList: const [
        QaItem(category: 'Temperature/Sweat', question: '땀/체온 변화는?', answer: '밤에 식은땀이 가끔 나요.'),
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
      previousTreatmentArea: '요추 기립근 + 햄스트링',
      previousSessionNote: '장시간 운전 후 악화.',
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
