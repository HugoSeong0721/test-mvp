import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_firestore_service.dart';

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

  Map<String, dynamic> toMap() {
    return {'category': category, 'question': question, 'answer': answer};
  }

  factory QaItem.fromMap(Map<String, dynamic> data) {
    return QaItem(
      category: (data['category'] ?? '').toString(),
      question: (data['question'] ?? '').toString(),
      answer: (data['answer'] ?? '').toString(),
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'birthYear': birthYear,
      'sex': sex,
      'ethnicity': ethnicity,
      'memo': memo,
    };
  }

  factory PatientProfile.fromMap(Map<String, dynamic> data) {
    return PatientProfile(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'New Patient').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      birthYear: (data['birthYear'] as num?)?.toInt() ?? 1990,
      sex: (data['sex'] ?? 'Not entered').toString(),
      ethnicity: (data['ethnicity'] ?? 'Not entered').toString(),
      memo: (data['memo'] ?? '').toString(),
    );
  }
}

class PatientVisit {
  const PatientVisit({
    required this.id,
    required this.patientId,
    required this.clinicId,
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
  final String clinicId;
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'clinicId': clinicId,
      'date': date,
      'time': time,
      'lastVisitDate': lastVisitDate,
      'daysAgo': daysAgo,
      'scheduledSinceLast': scheduledSinceLast,
      'noShowSinceLast': noShowSinceLast,
      'intakeStatus': intakeStatus.name,
      'previousTreatmentArea': previousTreatmentArea,
      'previousSessionNote': previousSessionNote,
      'qaList': qaList.map((item) => item.toMap()).toList(),
    };
  }

  factory PatientVisit.fromMap(Map<String, dynamic> data) {
    final rawStatus = (data['intakeStatus'] ?? '').toString();
    final status = IntakeStatus.values.firstWhere(
      (item) => item.name == rawStatus,
      orElse: () => IntakeStatus.notStarted,
    );
    final rawQaList = data['qaList'];
    final qaList = rawQaList is List
        ? rawQaList
              .whereType<Map>()
              .map(
                (item) => QaItem.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : <QaItem>[];
    return PatientVisit(
      id: (data['id'] ?? '').toString(),
      patientId: (data['patientId'] ?? '').toString(),
      clinicId: (data['clinicId'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      lastVisitDate: (data['lastVisitDate'] ?? '').toString(),
      daysAgo: (data['daysAgo'] as num?)?.toInt() ?? 0,
      scheduledSinceLast: (data['scheduledSinceLast'] as num?)?.toInt() ?? 0,
      noShowSinceLast: (data['noShowSinceLast'] as num?)?.toInt() ?? 0,
      intakeStatus: status,
      previousTreatmentArea: (data['previousTreatmentArea'] ?? '').toString(),
      previousSessionNote: (data['previousSessionNote'] ?? '').toString(),
      qaList: qaList,
    );
  }
}

class ScheduledVisit {
  const ScheduledVisit({required this.profile, required this.visit});

  final PatientProfile profile;
  final PatientVisit visit;
}

enum AppointmentRequestStatus {
  pending,
  confirmed,
  declined,
  canceledByPatient,
}

extension AppointmentRequestStatusLabel on AppointmentRequestStatus {
  String get englishLabel {
    switch (this) {
      case AppointmentRequestStatus.pending:
        return 'Pending Confirmation';
      case AppointmentRequestStatus.confirmed:
        return 'Confirmed';
      case AppointmentRequestStatus.declined:
        return 'Declined';
      case AppointmentRequestStatus.canceledByPatient:
        return 'Canceled by Patient';
    }
  }
}

class AppointmentSlot {
  const AppointmentSlot({
    required this.clinicId,
    required this.date,
    required this.time,
    required this.isOpen,
  });

  final String clinicId;
  final String date;
  final String time;
  final bool isOpen;

  AppointmentSlot copyWith({
    String? clinicId,
    String? date,
    String? time,
    bool? isOpen,
  }) {
    return AppointmentSlot(
      clinicId: clinicId ?? this.clinicId,
      date: date ?? this.date,
      time: time ?? this.time,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  Map<String, dynamic> toMap() {
    return {'clinicId': clinicId, 'date': date, 'time': time, 'isOpen': isOpen};
  }

  factory AppointmentSlot.fromMap(Map<String, dynamic> data) {
    return AppointmentSlot(
      clinicId: (data['clinicId'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      isOpen: data['isOpen'] == true,
    );
  }
}

class AppointmentRequest {
  const AppointmentRequest({
    required this.id,
    required this.patientId,
    required this.clinicId,
    required this.date,
    required this.time,
    required this.requestedAt,
    required this.status,
    this.reviewedAt,
    this.practitionerNote,
  });

  final String id;
  final String patientId;
  final String clinicId;
  final String date;
  final String time;
  final DateTime requestedAt;
  final AppointmentRequestStatus status;
  final DateTime? reviewedAt;
  final String? practitionerNote;

  AppointmentRequest copyWith({
    String? id,
    String? patientId,
    String? clinicId,
    String? date,
    String? time,
    DateTime? requestedAt,
    AppointmentRequestStatus? status,
    DateTime? reviewedAt,
    String? practitionerNote,
  }) {
    return AppointmentRequest(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      clinicId: clinicId ?? this.clinicId,
      date: date ?? this.date,
      time: time ?? this.time,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      practitionerNote: practitionerNote ?? this.practitionerNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'clinicId': clinicId,
      'date': date,
      'time': time,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.name,
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
      if (practitionerNote != null) 'practitionerNote': practitionerNote,
    };
  }

  factory AppointmentRequest.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is DateTime) {
        return value;
      }
      try {
        final converted = (value as dynamic).toDate();
        if (converted is DateTime) {
          return converted;
        }
      } catch (_) {}
      return null;
    }

    final rawStatus = (data['status'] ?? '').toString();
    final status = AppointmentRequestStatus.values.firstWhere(
      (item) => item.name == rawStatus,
      orElse: () => AppointmentRequestStatus.pending,
    );
    return AppointmentRequest(
      id: (data['id'] ?? '').toString(),
      patientId: (data['patientId'] ?? '').toString(),
      clinicId: (data['clinicId'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      requestedAt: parseDate(data['requestedAt']) ?? DateTime.now(),
      status: status,
      reviewedAt: parseDate(data['reviewedAt']),
      practitionerNote: data['practitionerNote']?.toString(),
    );
  }
}

class ClinicOpenRequest {
  const ClinicOpenRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.clinicName,
    required this.practitionerName,
    required this.location,
    required this.note,
    required this.requestedAt,
    this.status = 'requested',
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String clinicName;
  final String practitionerName;
  final String location;
  final String note;
  final DateTime requestedAt;
  final String status;

  ClinicOpenRequest copyWith({
    String? patientName,
    String? patientEmail,
    String? practitionerName,
    String? location,
    String? note,
    DateTime? requestedAt,
    String? status,
  }) {
    return ClinicOpenRequest(
      id: id,
      patientId: patientId,
      patientName: patientName ?? this.patientName,
      patientEmail: patientEmail ?? this.patientEmail,
      clinicName: clinicName,
      practitionerName: practitionerName ?? this.practitionerName,
      location: location ?? this.location,
      note: note ?? this.note,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'clinicName': clinicName,
      'practitionerName': practitionerName,
      'location': location,
      'note': note,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
    };
  }

  factory ClinicOpenRequest.fromMap(Map<String, dynamic> data) {
    final rawRequestedAt = data['requestedAt'];
    final requestedAt = rawRequestedAt is String
        ? DateTime.tryParse(rawRequestedAt)
        : rawRequestedAt is DateTime
        ? rawRequestedAt
        : null;
    return ClinicOpenRequest(
      id: (data['id'] ?? '').toString(),
      patientId: (data['patientId'] ?? '').toString(),
      patientName: (data['patientName'] ?? '').toString(),
      patientEmail: (data['patientEmail'] ?? '').toString(),
      clinicName: (data['clinicName'] ?? '').toString(),
      practitionerName: (data['practitionerName'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      requestedAt: requestedAt ?? DateTime.now(),
      status: (data['status'] ?? 'requested').toString(),
    );
  }
}

class PatientClinicMembershipRequest {
  const PatientClinicMembershipRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.clinicId,
    required this.clinicName,
    required this.requestedAt,
    this.status = 'pending',
    this.reviewedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String clinicId;
  final String clinicName;
  final DateTime requestedAt;
  final String status;
  final DateTime? reviewedAt;

  PatientClinicMembershipRequest copyWith({
    String? patientName,
    String? patientEmail,
    String? clinicName,
    DateTime? requestedAt,
    String? status,
    DateTime? reviewedAt,
  }) {
    return PatientClinicMembershipRequest(
      id: id,
      patientId: patientId,
      patientName: patientName ?? this.patientName,
      patientEmail: patientEmail ?? this.patientEmail,
      clinicId: clinicId,
      clinicName: clinicName ?? this.clinicName,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'clinicId': clinicId,
      'clinicName': clinicName,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    };
  }

  factory PatientClinicMembershipRequest.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is DateTime) {
        return value;
      }
      try {
        final converted = (value as dynamic).toDate();
        if (converted is DateTime) {
          return converted;
        }
      } catch (_) {}
      return null;
    }

    return PatientClinicMembershipRequest(
      id: (data['id'] ?? '').toString(),
      patientId: (data['patientId'] ?? '').toString(),
      patientName: (data['patientName'] ?? '').toString(),
      patientEmail: (data['patientEmail'] ?? '').toString(),
      clinicId: (data['clinicId'] ?? '').toString(),
      clinicName: (data['clinicName'] ?? '').toString(),
      requestedAt: parseDate(data['requestedAt']) ?? DateTime.now(),
      status: (data['status'] ?? 'pending').toString(),
      reviewedAt: parseDate(data['reviewedAt']),
    );
  }
}

class PatientHistoryArgs {
  const PatientHistoryArgs({required this.current, required this.history});

  final ScheduledVisit current;
  final List<ScheduledVisit> history;
}

class ClinicCenter {
  const ClinicCenter({
    required this.id,
    required this.name,
    required this.practitionerName,
    required this.location,
    required this.patientNote,
    required this.searchKeywords,
  });

  final String id;
  final String name;
  final String practitionerName;
  final String location;
  final String patientNote;
  final String searchKeywords;

  ClinicCenter copyWith({
    String? id,
    String? name,
    String? practitionerName,
    String? location,
    String? patientNote,
    String? searchKeywords,
  }) {
    return ClinicCenter(
      id: id ?? this.id,
      name: name ?? this.name,
      practitionerName: practitionerName ?? this.practitionerName,
      location: location ?? this.location,
      patientNote: patientNote ?? this.patientNote,
      searchKeywords: searchKeywords ?? this.searchKeywords,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'practitionerName': practitionerName,
      'location': location,
      'patientNote': patientNote,
      'searchKeywords': searchKeywords,
    };
  }

  factory ClinicCenter.fromMap(Map<String, dynamic> data) {
    return ClinicCenter(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      practitionerName: (data['practitionerName'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      patientNote: (data['patientNote'] ?? '').toString(),
      searchKeywords: (data['searchKeywords'] ?? '').toString(),
    );
  }
}

class ClinicDataStore extends ChangeNotifier {
  ClinicDataStore._() {
    _restoreClinicState();
  }

  static final ClinicDataStore instance = ClinicDataStore._();
  static const String _clinicCentersKey = 'clinic_centers_v1';
  static const String _patientSelectedClinicsKey =
      'patient_selected_clinics_v1';
  static const String _patientDefaultClinicsKey = 'patient_default_clinics_v1';
  static const String _patientProfilesKey = 'patient_profiles_v1';
  static const String _practitionerClinicIdsKey = 'practitioner_clinic_ids_v1';
  static const String _patientPortalRegisteredIdsKey =
      'patient_portal_registered_ids_v1';
  static const String _clinicOpenRequestsKey = 'clinic_open_requests_v1';
  static const String _patientClinicMembershipRequestsKey =
      'patient_clinic_membership_requests_v1';
  static const String _appointmentSlotsKey = 'appointment_slots_v1';
  static const String _appointmentRequestsKey = 'appointment_requests_v1';
  static const String _patientVisitsKey = 'patient_visits_v1';

  static String _storedDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static const List<String> _defaultClinicIds = <String>[
    'seong_acupuncture_center',
    'isaw_acu',
    'midtown_balance_clinic',
    'elm_wellness_acupuncture',
  ];

  static List<AppointmentSlot> _buildSlotsForClinic(String clinicId) {
    final today = DateTime.now();
    final anchor = DateTime(today.year, today.month, today.day);
    final dates = <DateTime>[
      anchor.add(const Duration(days: 1)),
      anchor.add(const Duration(days: 4)),
      anchor.add(const Duration(days: 8)),
    ];

    const timeTemplates = <({String time, bool isOpen})>[
      (time: '9:00 AM', isOpen: true),
      (time: '10:30 AM', isOpen: true),
      (time: '1:30 PM', isOpen: false),
      (time: '3:00 PM', isOpen: true),
      (time: '4:30 PM', isOpen: true),
    ];

    return [
      for (final date in dates)
        for (final slot in timeTemplates)
          AppointmentSlot(
            clinicId: clinicId,
            date: _storedDate(date),
            time: slot.time,
            isOpen: slot.isOpen,
          ),
    ];
  }

  static List<AppointmentSlot> _buildInitialSlots() {
    return [
      for (final clinicId in _defaultClinicIds)
        ..._buildSlotsForClinic(clinicId),
    ];
  }

  static const PatientProfile _fallbackProfile = PatientProfile(
    id: 'placeholder_patient',
    name: 'New Patient',
    phone: '',
    email: '',
    birthYear: 1990,
    sex: 'Not entered',
    ethnicity: 'Not entered',
    memo: '',
  );

  String _currentPatientId = '';

  final List<PatientProfile> _profiles = [];

  final List<PatientVisit> _visits = [];

  final List<AppointmentSlot> _slots = _buildInitialSlots();

  final List<AppointmentRequest> _appointmentRequests = [];
  final List<ClinicOpenRequest> _clinicOpenRequests = [];
  final List<PatientClinicMembershipRequest> _patientClinicMembershipRequests =
      [];

  final List<ClinicCenter> _clinicCenters = [
    const ClinicCenter(
      id: 'seong_acupuncture_center',
      name: 'Seong Acupuncture Center',
      practitionerName: 'Dr. Hugo Seong',
      location: 'Fort Lee, NJ',
      patientNote:
          'Patients see this note in search and after login. Share what to prepare before the visit and how to request a slot.',
      searchKeywords: 'fort lee sleep shoulder pain korean english',
    ),
    const ClinicCenter(
      id: 'isaw_acu',
      name: 'iSaw Acu',
      practitionerName: 'Hugo Seong',
      location: '',
      patientNote:
          'Patients who log in through this clinic can choose it as their center and continue intake here.',
      searchKeywords: 'isaw acu hugo seong beta acupuncture',
    ),
    const ClinicCenter(
      id: 'midtown_balance_clinic',
      name: 'Midtown Balance Clinic',
      practitionerName: 'Dr. Jane Kim',
      location: 'Midtown Manhattan, NY',
      patientNote:
          'This clinic focuses on sleep, stress, and shoulder tension follow-up.',
      searchKeywords: 'manhattan stress sleep neck shoulder intake',
    ),
    const ClinicCenter(
      id: 'elm_wellness_acupuncture',
      name: 'Elm Wellness Acupuncture',
      practitionerName: 'Dr. Min Park',
      location: 'Palisades Park, NJ',
      patientNote:
          'Use this clinic card when you want a patient to land in your portal first and pick up intake from there.',
      searchKeywords: 'new jersey digestion fatigue follow up portal',
    ),
  ];
  final Map<String, String> _patientSelectedClinicIds = <String, String>{};
  final Map<String, String> _patientDefaultClinicIds = <String, String>{};
  final Set<String> _patientPortalRegisteredIds = <String>{};
  final Map<String, String> _practitionerClinicIds = <String, String>{};
  SharedPreferences? _prefs;
  bool _clinicStateReady = false;

  List<PatientProfile> get profiles => List.unmodifiable(_profiles);

  PatientProfile get currentPatientProfile =>
      profileById(_currentPatientId) ??
      (_profiles.isNotEmpty ? _profiles.first : _fallbackProfile);

  List<AppointmentSlot> get slots => List.unmodifiable(_slots);
  List<AppointmentRequest> get appointmentRequests =>
      List.unmodifiable(_appointmentRequests);
  List<ClinicOpenRequest> get clinicOpenRequests {
    final items = [..._clinicOpenRequests]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return List.unmodifiable(items);
  }

  List<ClinicOpenRequest> get pendingClinicOpenRequests {
    final items =
        _clinicOpenRequests
            .where((request) => request.status == 'requested')
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return List.unmodifiable(items);
  }

  List<PatientClinicMembershipRequest> get patientClinicMembershipRequests {
    final items = [..._patientClinicMembershipRequests]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return List.unmodifiable(items);
  }

  List<PatientClinicMembershipRequest> pendingMembershipRequestsForClinic(
    String? clinicId,
  ) {
    return membershipRequestsForClinic(clinicId, statuses: {'pending'});
  }

  List<PatientClinicMembershipRequest> membershipRequestsForClinic(
    String? clinicId, {
    Set<String>? statuses,
  }) {
    final normalizedClinicId = clinicId?.trim();
    if (normalizedClinicId == null || normalizedClinicId.isEmpty) {
      return const [];
    }
    final items =
        _patientClinicMembershipRequests
            .where(
              (request) =>
                  request.clinicId == normalizedClinicId &&
                  (statuses == null || statuses.contains(request.status)),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return List.unmodifiable(items);
  }

  Future<void> mergePatientClinicMembershipRequestsFromMaps(
    Iterable<Map<String, dynamic>> items,
  ) async {
    var changed = false;
    for (final data in items) {
      final request = PatientClinicMembershipRequest.fromMap(data);
      if (request.id.trim().isEmpty) {
        continue;
      }
      final index = _patientClinicMembershipRequests.indexWhere(
        (item) => item.id == request.id,
      );
      if (index >= 0) {
        _patientClinicMembershipRequests[index] = request;
      } else {
        _patientClinicMembershipRequests.add(request);
      }
      if (request.status == 'approved') {
        _ensureMembershipProfile(request);
        _patientSelectedClinicIds[request.patientId] = request.clinicId;
        _patientPortalRegisteredIds.add(request.patientId);
      }
      changed = true;
    }
    if (!changed) {
      return;
    }
    notifyListeners();
    await _persistClinicState();
  }

  Future<void> mergeAppointmentRequestsFromMaps(
    Iterable<Map<String, dynamic>> items,
  ) async {
    var changed = false;
    for (final data in items) {
      final request = AppointmentRequest.fromMap(data);
      if (request.id.trim().isEmpty) {
        continue;
      }
      final index = _appointmentRequests.indexWhere(
        (item) => item.id == request.id,
      );
      if (index >= 0) {
        _appointmentRequests[index] = request;
      } else {
        _appointmentRequests.add(request);
      }
      changed = true;
    }
    if (!changed) {
      return;
    }
    notifyListeners();
    await _persistClinicState();
  }

  PatientClinicMembershipRequest? membershipRequestForPatientClinic({
    required String patientId,
    required String clinicId,
  }) {
    try {
      return _patientClinicMembershipRequests.firstWhere(
        (request) =>
            request.patientId == patientId && request.clinicId == clinicId,
      );
    } catch (_) {
      return null;
    }
  }

  List<ClinicCenter> get clinicCenters {
    final items = [..._clinicCenters];
    items.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(items);
  }

  List<ClinicCenter> get patientVisibleClinicCenters {
    final visibleIds = _practitionerClinicIds.values.toSet();
    final items =
        _clinicCenters
            .where((clinic) => visibleIds.contains(clinic.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(items);
  }

  bool get clinicStateReady => _clinicStateReady;

  List<String> get allDates {
    final dates = _visits.map((visit) => visit.date).toSet().toList()..sort();
    return dates;
  }

  List<AppointmentSlot> slotsForClinic(String? clinicId) {
    final normalizedClinicId = clinicId?.trim();
    if (normalizedClinicId == null || normalizedClinicId.isEmpty) {
      return const [];
    }
    final items = _slots.where((slot) => slot.clinicId == normalizedClinicId);
    return items.toList()..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.time.compareTo(b.time);
    });
  }

  List<AppointmentRequest> appointmentRequestsForClinic(String? clinicId) {
    final normalizedClinicId = clinicId?.trim();
    if (normalizedClinicId == null || normalizedClinicId.isEmpty) {
      return const [];
    }
    final items = _appointmentRequests.where(
      (request) => request.clinicId == normalizedClinicId,
    );
    return items.toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  List<String> allDatesForClinic(String? clinicId) {
    final dates = <String>{
      ...slotsForClinic(clinicId).map((slot) => slot.date),
      ..._visits
          .where(
            (visit) =>
                clinicId == null ||
                clinicId.trim().isEmpty ||
                visit.clinicId == clinicId,
          )
          .map((visit) => visit.date),
    }.toList()..sort();
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

  List<ScheduledVisit> visitsForDate(String date, {String? clinicId}) {
    return _visits
        .where(
          (visit) =>
              visit.date == date &&
              (clinicId == null ||
                  clinicId.trim().isEmpty ||
                  visit.clinicId == clinicId),
        )
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

  List<ScheduledVisit> visitsInRange(
    DateTime start,
    DateTime end, {
    String? clinicId,
  }) {
    return _visits
        .where((visit) {
          final date = DateTime.parse(visit.date);
          return (clinicId == null ||
                  clinicId.trim().isEmpty ||
                  visit.clinicId == clinicId) &&
              !date.isBefore(DateTime(start.year, start.month, start.day)) &&
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

  List<ScheduledVisit> historyForPatient(String patientId, {String? clinicId}) {
    return _visits
        .where(
          (visit) =>
              visit.patientId == patientId &&
              (clinicId == null ||
                  clinicId.trim().isEmpty ||
                  visit.clinicId == clinicId),
        )
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

  List<ScheduledVisit> upcomingVisits(DateTime fromDate, {String? clinicId}) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    return _visits
        .where(
          (visit) =>
              DateTime.parse(visit.date).isAfter(from) &&
              (clinicId == null ||
                  clinicId.trim().isEmpty ||
                  visit.clinicId == clinicId),
        )
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

  List<AppointmentSlot> availableSlotsForPatient(
    String patientId, {
    String? clinicId,
  }) {
    final effectiveClinicId =
        clinicId ??
        activeClinicForPatient(patientId)?.id ??
        _patientDefaultClinicIds[patientId];
    if (effectiveClinicId == null || effectiveClinicId.trim().isEmpty) {
      return const [];
    }

    final reservedSlots = appointmentRequestsForClinic(effectiveClinicId)
        .where(
          (request) =>
              request.status == AppointmentRequestStatus.pending ||
              request.status == AppointmentRequestStatus.confirmed,
        )
        .map((request) => '${request.date}|${request.time}')
        .toSet();

    final confirmedVisits = _visits
        .where((visit) => visit.clinicId == effectiveClinicId)
        .map((visit) => '${visit.date}|${visit.time}')
        .toSet();

    return slotsForClinic(effectiveClinicId)
        .where((slot) => slot.isOpen)
        .where((slot) => !reservedSlots.contains('${slot.date}|${slot.time}'))
        .where((slot) => !confirmedVisits.contains('${slot.date}|${slot.time}'))
        .toList()
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.time.compareTo(b.time);
      });
  }

  List<AppointmentRequest> requestsForPatient(
    String patientId, {
    String? clinicId,
  }) {
    final items =
        appointmentRequestsForClinic(
            clinicId,
          ).where((request) => request.patientId == patientId).toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return items;
  }

  ScheduledVisit? scheduledVisitForSlot(
    String date,
    String time, {
    String? clinicId,
  }) {
    try {
      final visit = _visits.firstWhere(
        (item) =>
            item.date == date &&
            item.time == time &&
            (clinicId == null ||
                clinicId.trim().isEmpty ||
                item.clinicId == clinicId),
      );
      final profile = profileById(visit.patientId);
      if (profile == null) {
        return null;
      }
      return ScheduledVisit(profile: profile, visit: visit);
    } catch (_) {
      return null;
    }
  }

  AppointmentRequest? latestActiveRequestForSlot(
    String date,
    String time, {
    String? clinicId,
  }) {
    final activeRequests =
        appointmentRequestsForClinic(clinicId)
            .where(
              (request) =>
                  request.date == date &&
                  request.time == time &&
                  (request.status == AppointmentRequestStatus.pending ||
                      request.status == AppointmentRequestStatus.confirmed),
            )
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    if (activeRequests.isEmpty) {
      return null;
    }
    return activeRequests.first;
  }

  void requestAppointment({
    required String patientId,
    required String clinicId,
    required String date,
    required String time,
  }) {
    _ensureSlotsForClinic(clinicId);
    final slot = _slots.where(
      (slot) =>
          slot.clinicId == clinicId &&
          slot.date == date &&
          slot.time == time &&
          slot.isOpen,
    );
    if (slot.isEmpty) {
      return;
    }

    final alreadyReserved =
        _appointmentRequests.any(
          (request) =>
              request.clinicId == clinicId &&
              request.date == date &&
              request.time == time &&
              (request.status == AppointmentRequestStatus.pending ||
                  request.status == AppointmentRequestStatus.confirmed),
        ) ||
        _visits.any(
          (visit) =>
              visit.clinicId == clinicId &&
              visit.date == date &&
              visit.time == time,
        );

    if (alreadyReserved) {
      return;
    }

    final alreadyRequestedByPatient = _appointmentRequests.any(
      (request) =>
          request.patientId == patientId &&
          request.clinicId == clinicId &&
          request.date == date &&
          request.time == time &&
          (request.status == AppointmentRequestStatus.pending ||
              request.status == AppointmentRequestStatus.confirmed),
    );
    if (alreadyRequestedByPatient) {
      return;
    }

    final request = AppointmentRequest(
      id: 'appointment_request_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patientId,
      clinicId: clinicId,
      date: date,
      time: time,
      requestedAt: DateTime.now(),
      status: AppointmentRequestStatus.pending,
    );
    _appointmentRequests.add(request);
    notifyListeners();
    unawaited(_persistClinicState());
    unawaited(AppFirestoreService.saveAppointmentRequest(request.toMap()));
  }

  void cancelAppointmentRequest(String requestId) {
    final index = _appointmentRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) return;
    final request = _appointmentRequests[index];
    if (request.status != AppointmentRequestStatus.pending) {
      return;
    }
    _appointmentRequests[index] = request.copyWith(
      status: AppointmentRequestStatus.canceledByPatient,
      reviewedAt: DateTime.now(),
    );
    notifyListeners();
    unawaited(_persistClinicState());
    unawaited(
      AppFirestoreService.saveAppointmentRequest(
        _appointmentRequests[index].toMap(),
      ),
    );
  }

  void confirmAppointmentRequest(String requestId) {
    final index = _appointmentRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) return;
    final request = _appointmentRequests[index];
    if (request.status != AppointmentRequestStatus.pending) {
      return;
    }

    _appointmentRequests[index] = request.copyWith(
      status: AppointmentRequestStatus.confirmed,
      reviewedAt: DateTime.now(),
    );
    unawaited(
      AppFirestoreService.saveAppointmentRequest(
        _appointmentRequests[index].toMap(),
      ),
    );
    addAppointment(
      patientId: request.patientId,
      clinicId: request.clinicId,
      date: request.date,
      time: request.time,
    );
  }

  void declineAppointmentRequest(String requestId, {String? note}) {
    final index = _appointmentRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) return;
    final request = _appointmentRequests[index];
    if (request.status != AppointmentRequestStatus.pending) {
      return;
    }
    _appointmentRequests[index] = request.copyWith(
      status: AppointmentRequestStatus.declined,
      reviewedAt: DateTime.now(),
      practitionerNote: note,
    );
    notifyListeners();
    unawaited(_persistClinicState());
    unawaited(
      AppFirestoreService.saveAppointmentRequest(
        _appointmentRequests[index].toMap(),
      ),
    );
  }

  void setSlotOpen({
    required String clinicId,
    required String date,
    required String time,
    required bool isOpen,
  }) {
    final normalizedClinicId = clinicId.trim();
    if (normalizedClinicId.isEmpty) {
      return;
    }
    final index = _slots.indexWhere(
      (slot) =>
          slot.clinicId == normalizedClinicId &&
          slot.date == date &&
          slot.time == time,
    );
    if (index < 0) return;
    _slots[index] = _slots[index].copyWith(isOpen: isOpen);
    notifyListeners();
    unawaited(_persistClinicState());
  }

  void saveProfile(PatientProfile profile) {
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      _profiles[index] = profile;
    } else {
      _profiles.add(profile);
    }
    notifyListeners();
    unawaited(_persistClinicState());
  }

  void deleteProfile(String profileId) {
    _profiles.removeWhere((profile) => profile.id == profileId);
    _appointmentRequests.removeWhere(
      (request) => request.patientId == profileId,
    );
    _visits.removeWhere((visit) => visit.patientId == profileId);
    _patientSelectedClinicIds.remove(profileId);
    _patientDefaultClinicIds.remove(profileId);
    _patientPortalRegisteredIds.remove(profileId);
    if (_currentPatientId == profileId) {
      _currentPatientId = _profiles.isNotEmpty ? _profiles.first.id : '';
    }
    notifyListeners();
    unawaited(_persistClinicState());
  }

  void resetTestingStateForPatient(String patientId) {
    _appointmentRequests.removeWhere(
      (request) => request.patientId == patientId,
    );
    _visits.removeWhere((visit) => visit.patientId == patientId);
    notifyListeners();
    unawaited(_persistClinicState());
  }

  void addTestingVisit(PatientVisit visit) {
    _visits.removeWhere((item) => item.id == visit.id);
    _visits.removeWhere(
      (item) =>
          item.patientId == visit.patientId &&
          item.date == visit.date &&
          item.time == visit.time,
    );
    _visits.add(visit);
    _visits.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.time.compareTo(b.time);
    });
    notifyListeners();
    unawaited(_persistClinicState());
  }

  void addAppointment({
    required String patientId,
    required String clinicId,
    required String date,
    required String time,
  }) {
    _ensureSlotsForClinic(clinicId);
    final existingCount = _visits
        .where((visit) => visit.patientId == patientId)
        .length;
    final history = historyForPatient(patientId, clinicId: clinicId);
    final latestVisit = history.isNotEmpty ? history.first.visit : null;

    final selectedDate = DateTime.parse(date);
    final daysAgo = latestVisit == null
        ? 0
        : selectedDate.difference(DateTime.parse(latestVisit.date)).inDays;

    final visit = PatientVisit(
      id: 'visit_${DateTime.now().millisecondsSinceEpoch}_$existingCount',
      patientId: patientId,
      clinicId: clinicId,
      date: date,
      time: time,
      lastVisitDate: latestVisit?.date ?? date,
      daysAgo: daysAgo < 0 ? 0 : daysAgo,
      scheduledSinceLast: latestVisit == null
          ? 0
          : latestVisit.scheduledSinceLast + 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.notStarted,
      previousTreatmentArea:
          latestVisit?.previousTreatmentArea ?? 'To be updated after visit',
      previousSessionNote:
          latestVisit?.previousSessionNote ??
          'New appointment booked by patient.',
      qaList: const [],
    );

    _visits.add(visit);
    _visits.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.time.compareTo(b.time);
    });
    notifyListeners();
    unawaited(_persistClinicState());
  }

  ClinicCenter? clinicById(String clinicId) {
    try {
      return _clinicCenters.firstWhere((clinic) => clinic.id == clinicId);
    } catch (_) {
      return null;
    }
  }

  String? selectedClinicIdForPatient(String patientId) {
    final clinicId = _patientSelectedClinicIds[patientId];
    return clinicById(clinicId ?? '') == null ? null : clinicId;
  }

  String? defaultClinicIdForPatient(String patientId) {
    final clinicId = _patientDefaultClinicIds[patientId];
    return clinicById(clinicId ?? '') == null ? null : clinicId;
  }

  ClinicCenter? activeClinicForPatient(String patientId) {
    final selectedClinicId = selectedClinicIdForPatient(patientId);
    if (selectedClinicId != null) {
      return clinicById(selectedClinicId);
    }
    final defaultClinicId = defaultClinicIdForPatient(patientId);
    if (defaultClinicId != null) {
      return clinicById(defaultClinicId);
    }
    return null;
  }

  String? clinicIdForPractitioner(String practitionerId) {
    final clinicId = _practitionerClinicIds[practitionerId];
    return clinicById(clinicId ?? '') == null ? null : clinicId;
  }

  ClinicCenter? clinicForPractitioner(String practitionerId) {
    final clinicId = clinicIdForPractitioner(practitionerId);
    if (clinicId == null) {
      return null;
    }
    return clinicById(clinicId);
  }

  List<PatientProfile> profilesForClinic(String? clinicId) {
    final normalizedClinicId = clinicId?.trim();
    if (normalizedClinicId == null || normalizedClinicId.isEmpty) {
      return profiles
          .where((profile) => isPatientPortalRegistered(profile.id))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    final items = _profiles.where((profile) {
      if (!isPatientPortalRegistered(profile.id)) {
        return false;
      }
      final selectedClinicId = selectedClinicIdForPatient(profile.id);
      final defaultClinicId = defaultClinicIdForPatient(profile.id);
      final hasVisit = _visits.any(
        (visit) =>
            visit.patientId == profile.id &&
            visit.clinicId == normalizedClinicId,
      );
      final hasRequest = _appointmentRequests.any(
        (request) =>
            request.patientId == profile.id &&
            request.clinicId == normalizedClinicId,
      );
      return selectedClinicId == normalizedClinicId ||
          defaultClinicId == normalizedClinicId ||
          hasVisit ||
          hasRequest;
    }).toList();

    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  bool isPatientPortalRegistered(String patientId) {
    return _patientPortalRegisteredIds.contains(patientId);
  }

  Future<void> markPatientPortalRegistered(String patientId) async {
    final normalizedPatientId = patientId.trim();
    if (normalizedPatientId.isEmpty ||
        _patientPortalRegisteredIds.contains(normalizedPatientId)) {
      return;
    }
    _patientPortalRegisteredIds.add(normalizedPatientId);
    notifyListeners();
    await _persistClinicState();
  }

  Future<bool> requestClinicOpen({
    required PatientProfile patient,
    required String clinicName,
    required String practitionerName,
    required String location,
    required String note,
  }) async {
    final normalizedName = clinicName.trim();
    if (normalizedName.isEmpty) {
      return false;
    }
    final normalizedPractitioner = practitionerName.trim();
    final normalizedLocation = location.trim();
    final existingIndex = _clinicOpenRequests.indexWhere((request) {
      return request.patientId == patient.id &&
          request.clinicName.toLowerCase() == normalizedName.toLowerCase();
    });

    final request = existingIndex >= 0
        ? _clinicOpenRequests[existingIndex].copyWith(
            patientName: patient.name,
            patientEmail: patient.email,
            practitionerName: normalizedPractitioner,
            location: normalizedLocation,
            note: note.trim(),
            requestedAt: DateTime.now(),
            status: 'requested',
          )
        : ClinicOpenRequest(
            id: 'clinic_open_request_${DateTime.now().millisecondsSinceEpoch}',
            patientId: patient.id,
            patientName: patient.name,
            patientEmail: patient.email,
            clinicName: normalizedName,
            practitionerName: normalizedPractitioner,
            location: normalizedLocation,
            note: note.trim(),
            requestedAt: DateTime.now(),
          );
    if (existingIndex >= 0) {
      _clinicOpenRequests[existingIndex] = request;
    } else {
      _clinicOpenRequests.add(request);
    }
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.saveClinicOpenRequest(request.toMap());
    } catch (_) {}
    return true;
  }

  Future<void> markClinicOpenRequestReviewed(String requestId) async {
    final index = _clinicOpenRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) {
      return;
    }
    _clinicOpenRequests[index] = _clinicOpenRequests[index].copyWith(
      status: 'reviewed',
    );
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.markClinicOpenRequestReviewed(requestId);
    } catch (_) {}
  }

  List<ClinicCenter> searchClinics(String query) {
    final normalized = query.trim().toLowerCase();
    final items = patientVisibleClinicCenters;
    if (normalized.isEmpty) {
      return items;
    }
    return items.where((clinic) {
      final haystack = [
        clinic.name,
        clinic.practitionerName,
        clinic.location,
        clinic.patientNote,
        clinic.searchKeywords,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  Future<void> selectClinicForPatient({
    required String patientId,
    required String clinicId,
  }) async {
    final clinic = clinicById(clinicId);
    final patient = profileById(patientId);
    if (clinic == null || patient == null) {
      return;
    }
    final existingIndex = _patientClinicMembershipRequests.indexWhere(
      (request) =>
          request.patientId == patientId && request.clinicId == clinicId,
    );
    final request = existingIndex >= 0
        ? _patientClinicMembershipRequests[existingIndex].copyWith(
            patientName: patient.name,
            patientEmail: patient.email,
            clinicName: clinic.name,
            requestedAt: DateTime.now(),
            status: 'pending',
          )
        : PatientClinicMembershipRequest(
            id: 'membership_${patientId}_$clinicId',
            patientId: patientId,
            patientName: patient.name,
            patientEmail: patient.email,
            clinicId: clinicId,
            clinicName: clinic.name,
            requestedAt: DateTime.now(),
          );
    if (existingIndex >= 0) {
      _patientClinicMembershipRequests[existingIndex] = request;
    } else {
      _patientClinicMembershipRequests.add(request);
    }
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePatientClinicMembershipRequest(
        request.toMap(),
      );
    } catch (_) {}
  }

  Future<void> continueWithClinicForPatient({
    required String patientId,
    required String clinicId,
  }) async {
    if (clinicById(clinicId) == null || profileById(patientId) == null) {
      return;
    }
    _patientSelectedClinicIds[patientId] = clinicId;
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePatientClinicLink(
        patientId: patientId,
        selectedClinicId: clinicId,
      );
    } catch (_) {}
  }

  Future<void> setDefaultClinicForPatient({
    required String patientId,
    required String clinicId,
  }) async {
    if (clinicById(clinicId) == null ||
        selectedClinicIdForPatient(patientId) != clinicId) {
      return;
    }
    _patientDefaultClinicIds[patientId] = clinicId;
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePatientClinicLink(
        patientId: patientId,
        selectedClinicId: clinicId,
        defaultClinicId: clinicId,
      );
    } catch (_) {}
  }

  Future<void> approvePatientClinicMembership(String requestId) async {
    final index = _patientClinicMembershipRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) {
      return;
    }
    final request = _patientClinicMembershipRequests[index];
    final reviewedAt = DateTime.now();
    _patientClinicMembershipRequests[index] = request.copyWith(
      status: 'approved',
      reviewedAt: reviewedAt,
    );
    _ensureMembershipProfile(_patientClinicMembershipRequests[index]);
    _patientSelectedClinicIds[request.patientId] = request.clinicId;
    _patientPortalRegisteredIds.add(request.patientId);
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePatientClinicMembershipRequest(
        _patientClinicMembershipRequests[index].toMap(),
      );
      await AppFirestoreService.savePatientClinicLink(
        patientId: request.patientId,
        selectedClinicId: request.clinicId,
      );
    } catch (_) {}
  }

  void _ensureMembershipProfile(PatientClinicMembershipRequest request) {
    if (profileById(request.patientId) != null) {
      return;
    }
    _profiles.add(
      PatientProfile(
        id: request.patientId,
        name: request.patientName.trim().isEmpty
            ? 'New Patient'
            : request.patientName.trim(),
        phone: '',
        email: request.patientEmail.trim(),
        birthYear: 1990,
        sex: 'Not entered',
        ethnicity: 'Not entered',
        memo: '',
      ),
    );
  }

  Future<void> declinePatientClinicMembership(String requestId) async {
    final index = _patientClinicMembershipRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index < 0) {
      return;
    }
    _patientClinicMembershipRequests[index] =
        _patientClinicMembershipRequests[index].copyWith(
          status: 'declined',
          reviewedAt: DateTime.now(),
        );
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePatientClinicMembershipRequest(
        _patientClinicMembershipRequests[index].toMap(),
      );
    } catch (_) {}
  }

  Future<void> clearDefaultClinicForPatient(String patientId) async {
    _patientDefaultClinicIds.remove(patientId);
    notifyListeners();
    await _persistClinicState();
  }

  Future<void> applyPreferredClinicForPatient({
    required String patientId,
    String? linkedClinicId,
  }) async {
    if (linkedClinicId != null && clinicById(linkedClinicId) != null) {
      if (_patientSelectedClinicIds[patientId] == linkedClinicId) {
        return;
      }
      await selectClinicForPatient(
        patientId: patientId,
        clinicId: linkedClinicId,
      );
      await continueWithClinicForPatient(
        patientId: patientId,
        clinicId: linkedClinicId,
      );
      return;
    }

    final selectedClinicId = selectedClinicIdForPatient(patientId);
    if (selectedClinicId != null) {
      return;
    }

    final defaultClinicId = defaultClinicIdForPatient(patientId);
    if (defaultClinicId != null) {
      _patientSelectedClinicIds[patientId] = defaultClinicId;
      notifyListeners();
      await _persistClinicState();
    }
  }

  Future<void> saveClinicCenter(ClinicCenter clinic) async {
    final index = _clinicCenters.indexWhere((item) => item.id == clinic.id);
    if (index >= 0) {
      _clinicCenters[index] = clinic;
    } else {
      _clinicCenters.add(clinic);
    }
    _ensureSlotsForClinic(clinic.id);
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.saveClinicCenter(clinic.toMap());
    } catch (_) {}
  }

  Future<void> setClinicForPractitioner({
    required String practitionerId,
    required String clinicId,
  }) async {
    if (practitionerId.trim().isEmpty || clinicById(clinicId) == null) {
      return;
    }
    _practitionerClinicIds[practitionerId] = clinicId;
    notifyListeners();
    await _persistClinicState();
    try {
      await AppFirestoreService.savePractitionerClinicLink(
        practitionerId: practitionerId,
        clinicId: clinicId,
      );
    } catch (_) {}
  }

  String suggestClinicId(String rawName) {
    final normalized = rawName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final seed = normalized.isEmpty ? 'clinic' : normalized;
    var candidate = seed;
    var suffix = 2;
    while (_clinicCenters.any((clinic) => clinic.id == candidate)) {
      candidate = '${seed}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String buildPatientPortalRoute(String clinicId) {
    final encodedId = Uri.encodeQueryComponent(clinicId);
    return '/patient?clinic=$encodedId';
  }

  String buildPatientPortalShareLink(String clinicId, {String? currentUrl}) {
    final route = '#${buildPatientPortalRoute(clinicId)}';
    if (currentUrl == null || currentUrl.trim().isEmpty) {
      return route;
    }

    final base = Uri.tryParse(currentUrl);
    if (base == null || !base.hasScheme) {
      return route;
    }

    final portLabel = base.hasPort ? ':${base.port}' : '';
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return '${base.scheme}://${base.host}$portLabel$path$route';
  }

  Future<void> _restoreClinicState() async {
    _prefs = await SharedPreferences.getInstance();

    final savedClinics = _prefs?.getString(_clinicCentersKey);
    if (savedClinics != null && savedClinics.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedClinics);
        if (decoded is List) {
          final restored = decoded
              .whereType<Map>()
              .map(
                (item) => ClinicCenter.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((clinic) => clinic.id.trim().isNotEmpty)
              .toList();
          if (restored.isNotEmpty) {
            _clinicCenters
              ..clear()
              ..addAll(restored);
          }
        }
      } catch (_) {}
    }

    _patientSelectedClinicIds
      ..clear()
      ..addAll(_readPersistedMap(_patientSelectedClinicsKey));
    _patientDefaultClinicIds
      ..clear()
      ..addAll(_readPersistedMap(_patientDefaultClinicsKey));
    _restoreList(
      key: _patientProfilesKey,
      onRestore: (items) {
        _profiles
          ..clear()
          ..addAll(
            items
                .map(PatientProfile.fromMap)
                .where((profile) => profile.id.trim().isNotEmpty),
          );
      },
    );
    _restoreList(
      key: _appointmentSlotsKey,
      onRestore: (items) {
        _slots
          ..clear()
          ..addAll(
            items
                .map(AppointmentSlot.fromMap)
                .where(
                  (slot) =>
                      slot.clinicId.trim().isNotEmpty &&
                      slot.date.trim().isNotEmpty &&
                      slot.time.trim().isNotEmpty,
                ),
          );
      },
    );
    _restoreList(
      key: _appointmentRequestsKey,
      onRestore: (items) {
        _appointmentRequests
          ..clear()
          ..addAll(
            items
                .map(AppointmentRequest.fromMap)
                .where(
                  (request) =>
                      request.id.trim().isNotEmpty &&
                      request.patientId.trim().isNotEmpty &&
                      request.clinicId.trim().isNotEmpty,
                ),
          );
      },
    );
    _restoreList(
      key: _patientVisitsKey,
      onRestore: (items) {
        _visits
          ..clear()
          ..addAll(
            items
                .map(PatientVisit.fromMap)
                .where(
                  (visit) =>
                      visit.id.trim().isNotEmpty &&
                      visit.patientId.trim().isNotEmpty &&
                      visit.clinicId.trim().isNotEmpty,
                ),
          );
      },
    );
    _patientPortalRegisteredIds
      ..clear()
      ..addAll(
        _prefs?.getStringList(_patientPortalRegisteredIdsKey) ?? const [],
      );
    _practitionerClinicIds
      ..clear()
      ..addAll(_readPersistedMap(_practitionerClinicIdsKey));
    final savedOpenRequests = _prefs?.getString(_clinicOpenRequestsKey);
    if (savedOpenRequests != null && savedOpenRequests.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedOpenRequests);
        if (decoded is List) {
          _clinicOpenRequests
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (item) => ClinicOpenRequest.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
            );
        }
      } catch (_) {}
    }
    final savedMembershipRequests = _prefs?.getString(
      _patientClinicMembershipRequestsKey,
    );
    if (savedMembershipRequests != null &&
        savedMembershipRequests.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedMembershipRequests);
        if (decoded is List) {
          _patientClinicMembershipRequests
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (item) => PatientClinicMembershipRequest.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
            );
        }
      } catch (_) {}
    }

    await _restoreRemoteClinicState();

    _applySeedClinicAssignments();
    _ensureSlotsForExistingClinics();
    await _syncSeedOpenClinicsToFirestore();

    _clinicStateReady = true;
    notifyListeners();
  }

  Future<void> _restoreRemoteClinicState() async {
    try {
      final remoteClinics = await AppFirestoreService.fetchClinicCenters();
      for (final data in remoteClinics) {
        final clinic = ClinicCenter.fromMap(data);
        if (clinic.id.trim().isEmpty) {
          continue;
        }
        final index = _clinicCenters.indexWhere((item) => item.id == clinic.id);
        if (index >= 0) {
          _clinicCenters[index] = clinic;
        } else {
          _clinicCenters.add(clinic);
        }
      }

      final remotePractitionerLinks =
          await AppFirestoreService.fetchPractitionerClinicLinks();
      _practitionerClinicIds.addAll(remotePractitionerLinks);

      final remotePatientLinks =
          await AppFirestoreService.fetchPatientClinicLinks();
      for (final entry in remotePatientLinks.entries) {
        final patientId = entry.key;
        final selectedClinicId = (entry.value['selectedClinicId'] ?? '')
            .toString();
        final defaultClinicId = (entry.value['defaultClinicId'] ?? '')
            .toString();
        if (selectedClinicId.trim().isNotEmpty) {
          _patientSelectedClinicIds[patientId] = selectedClinicId;
        }
        if (defaultClinicId.trim().isNotEmpty) {
          _patientDefaultClinicIds[patientId] = defaultClinicId;
        }
      }

      final remoteOpenRequests =
          await AppFirestoreService.fetchClinicOpenRequests();
      for (final data in remoteOpenRequests) {
        final request = ClinicOpenRequest.fromMap(data);
        if (request.id.trim().isEmpty) {
          continue;
        }
        final index = _clinicOpenRequests.indexWhere(
          (item) => item.id == request.id,
        );
        if (index >= 0) {
          _clinicOpenRequests[index] = request;
        } else {
          _clinicOpenRequests.add(request);
        }
      }

      final remoteMembershipRequests =
          await AppFirestoreService.fetchPatientClinicMembershipRequests();
      for (final data in remoteMembershipRequests) {
        final request = PatientClinicMembershipRequest.fromMap(data);
        if (request.id.trim().isEmpty) {
          continue;
        }
        final index = _patientClinicMembershipRequests.indexWhere(
          (item) => item.id == request.id,
        );
        if (index >= 0) {
          _patientClinicMembershipRequests[index] = request;
        } else {
          _patientClinicMembershipRequests.add(request);
        }
      }

      final remoteAppointmentRequests =
          await AppFirestoreService.fetchAppointmentRequests();
      await mergeAppointmentRequestsFromMaps(remoteAppointmentRequests);
    } catch (_) {
      // Keep the demo usable offline or when Firestore rules are still being tuned.
    }
  }

  void _applySeedClinicAssignments() {
    _practitionerClinicIds.putIfAbsent(
      'beta_seong_acupuncture_center',
      () => 'seong_acupuncture_center',
    );
    _practitionerClinicIds.putIfAbsent('beta_isaw_acu', () => 'isaw_acu');
  }

  Future<void> _syncSeedOpenClinicsToFirestore() async {
    try {
      for (final clinicId in const ['seong_acupuncture_center', 'isaw_acu']) {
        final clinic = clinicById(clinicId);
        if (clinic != null) {
          await AppFirestoreService.saveClinicCenter(clinic.toMap());
        }
      }
      await AppFirestoreService.savePractitionerClinicLink(
        practitionerId: 'beta_seong_acupuncture_center',
        clinicId: 'seong_acupuncture_center',
      );
      await AppFirestoreService.savePractitionerClinicLink(
        practitionerId: 'beta_isaw_acu',
        clinicId: 'isaw_acu',
      );
    } catch (_) {}
  }

  void _ensureSlotsForExistingClinics() {
    for (final clinic in _clinicCenters) {
      _ensureSlotsForClinic(clinic.id);
    }
  }

  void _ensureSlotsForClinic(String clinicId) {
    final existing = _slots.where((slot) => slot.clinicId == clinicId);
    if (existing.isNotEmpty) {
      return;
    }
    _slots.addAll(_buildSlotsForClinic(clinicId));
  }

  Map<String, String> _readPersistedMap(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, String>{};
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  void _restoreList({
    required String key,
    required void Function(List<Map<String, dynamic>> items) onRestore,
  }) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final items = decoded
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
      onRestore(items);
    } catch (_) {}
  }

  Future<void> _persistClinicState() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _clinicCentersKey,
      jsonEncode(_clinicCenters.map((clinic) => clinic.toMap()).toList()),
    );
    await prefs.setString(
      _patientSelectedClinicsKey,
      jsonEncode(_patientSelectedClinicIds),
    );
    await prefs.setString(
      _patientDefaultClinicsKey,
      jsonEncode(_patientDefaultClinicIds),
    );
    await prefs.setString(
      _patientProfilesKey,
      jsonEncode(_profiles.map((profile) => profile.toMap()).toList()),
    );
    await prefs.setString(
      _appointmentSlotsKey,
      jsonEncode(_slots.map((slot) => slot.toMap()).toList()),
    );
    await prefs.setString(
      _appointmentRequestsKey,
      jsonEncode(
        _appointmentRequests.map((request) => request.toMap()).toList(),
      ),
    );
    await prefs.setString(
      _patientVisitsKey,
      jsonEncode(_visits.map((visit) => visit.toMap()).toList()),
    );
    await prefs.setString(
      _practitionerClinicIdsKey,
      jsonEncode(_practitionerClinicIds),
    );
    await prefs.setStringList(
      _patientPortalRegisteredIdsKey,
      _patientPortalRegisteredIds.toList()..sort(),
    );
    await prefs.setString(
      _clinicOpenRequestsKey,
      jsonEncode(
        _clinicOpenRequests.map((request) => request.toMap()).toList(),
      ),
    );
    await prefs.setString(
      _patientClinicMembershipRequestsKey,
      jsonEncode(
        _patientClinicMembershipRequests
            .map((request) => request.toMap())
            .toList(),
      ),
    );
  }
}
