import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/clinic_data_store.dart';
import 'app_firestore_service.dart';

class TesterFlowService {
  TesterFlowService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final ClinicDataStore _store = ClinicDataStore.instance;

  static Future<void> resetPortalData({required String patientId}) async {
    final batch = _db.batch();

    for (final collectionName in const [
      'answer_requests',
      'intake_submissions',
      'visit_record_feedback',
    ]) {
      final snapshot = await _db
          .collection(collectionName)
          .where('patientId', isEqualTo: patientId)
          .get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
    _store.resetTestingStateForPatient(patientId);
  }

  static Future<void> resetAndSeedPortalData({
    required PatientProfile profile,
  }) async {
    await resetPortalData(patientId: profile.id);

    final clinicId =
        _store.activeClinicForPatient(profile.id)?.id ??
        _store.defaultClinicIdForPatient(profile.id) ??
        'seong_acupuncture_center';

    final availableSlots = _store.availableSlotsForPatient(
      profile.id,
      clinicId: clinicId,
    );
    final sampleSlot = _pickSampleSlot(availableSlots);
    final seededFollowUpDate = sampleSlot == null
        ? DateTime.now().subtract(const Duration(days: 7))
        : DateTime.parse(sampleSlot.date).subtract(const Duration(days: 7));
    final seededBaselineDate = seededFollowUpDate.subtract(
      const Duration(days: 12),
    );
    final seededEarlierDate = seededBaselineDate.subtract(
      const Duration(days: 16),
    );

    final baselineVisit = PatientVisit(
      id: 'beta_seed_visit_baseline_${profile.id}',
      patientId: profile.id,
      clinicId: clinicId,
      date: _formatDate(seededBaselineDate),
      time: '4:00 PM',
      lastVisitDate: _formatDate(seededEarlierDate),
      daysAgo: seededBaselineDate.difference(seededEarlierDate).inDays,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Upper trapezius + medial scapular border',
      previousSessionNote:
          'Baseline visit for sleep disruption, desk-related neck tension, and right shoulder tightness.',
      qaList: const [
        QaItem(
          category: 'Sleep',
          question: 'How often are you waking during the night?',
          answer: 'Usually once around 3 AM, especially after stressful days.',
        ),
        QaItem(
          category: 'Pain',
          question: 'What area feels most stuck right now?',
          answer:
              'The inside of my right shoulder blade feels tight after computer work.',
        ),
      ],
    );
    final followUpVisit = PatientVisit(
      id: 'beta_seed_visit_follow_up_${profile.id}',
      patientId: profile.id,
      clinicId: clinicId,
      date: _formatDate(seededFollowUpDate),
      time: '3:30 PM',
      lastVisitDate: baselineVisit.date,
      daysAgo: seededFollowUpDate.difference(seededBaselineDate).inDays,
      scheduledSinceLast: 1,
      noShowSinceLast: 0,
      intakeStatus: IntakeStatus.completed,
      previousTreatmentArea: 'Right scapular region + cervical base',
      previousSessionNote:
          'Sleep improved slightly, but right shoulder blade tightness still returns after desk work.',
      qaList: const [
        QaItem(
          category: 'Sleep',
          question: 'How has your sleep been since the last visit?',
          answer:
              'Night waking is still there, but I can fall back asleep a little faster.',
        ),
        QaItem(
          category: 'Function',
          question: 'What still flares the shoulder / neck area?',
          answer:
              'Long computer sessions still trigger pulling pain around the shoulder blade.',
        ),
        QaItem(
          category: 'Guidance',
          question: 'Which home guidance was easiest to keep?',
          answer:
              'The before-bed stretch routine helped the most when I actually did it.',
        ),
      ],
    );

    _store.addTestingVisit(baselineVisit);
    _store.addTestingVisit(followUpVisit);

    final lastVisitDate = followUpVisit.date;
    final sampleVisitLabel = sampleSlot == null
        ? 'Sample follow-up visit'
        : '${sampleSlot.date} ${sampleSlot.time}';

    if (sampleSlot != null) {
      _store.requestAppointment(
        patientId: profile.id,
        clinicId: clinicId,
        date: sampleSlot.date,
        time: sampleSlot.time,
      );
    }

    final now = DateTime.now();
    await _db.collection('answer_requests').add({
      'patientId': profile.id,
      'clinicId': clinicId,
      'patientName': profile.name,
      'patientPhone': profile.phone,
      'patientEmail': profile.email,
      'patientTime': sampleVisitLabel,
      'lastVisitDate': lastVisitDate,
      'intakeStatus': 'seed_ready',
      'selectedQuestions': const [
        'How have your sleep quality and wake-ups changed this week?',
        'What feels most different in your neck / shoulder area before this visit?',
      ],
      'customQuestionsByCategory': const {
        'Daily Function': [
          'Please describe one activity that still feels limited right now.',
        ],
      },
      'note':
          'Sample follow-up request for beta testing. Please review the portal flow and continue the intake from the patient side.',
      'requestType': 'answer_request',
      'status': 'pending',
      'source': 'beta_seed_tools',
      'requestedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
    });

    await _db.collection('intake_submissions').add({
      'patientId': profile.id,
      'clinicId': clinicId,
      'patientName': profile.name,
      'visitType': 'follow_up',
      'answers': const [
        {
          'questionIndex': 1,
          'questionText': 'How has your sleep been recently?',
          'answerText':
              'I still wake up once around 3 AM, but falling back asleep is a little easier now.',
          'markedMainPain': false,
          'markedRemember': true,
        },
        {
          'questionIndex': 2,
          'questionText': 'What area feels tight or sore before this visit?',
          'answerText':
              'The right shoulder blade and the base of my neck feel tight after desk work.',
          'markedMainPain': true,
          'markedRemember': false,
        },
        {
          'questionIndex': 3,
          'questionText': 'How is your daytime energy this week?',
          'answerText':
              'Energy is a little better in the morning, but I still crash later in the afternoon.',
          'markedMainPain': false,
          'markedRemember': false,
        },
      ],
      'extraMemo':
          'Sample beta memo: I want to know whether my shoulder tension is improving enough to reduce the night waking pattern.',
      'adherence': const {
        'stretchingDone': true,
        'caffeineDone': false,
        'sleepLogDone': true,
        'percent': 0.67,
      },
      'currentQuestionIndex': 3,
      'source': 'beta_seed_tools',
      'submittedAt': Timestamp.fromDate(
        now.subtract(const Duration(days: 2, hours: 3)),
      ),
    });

    await _db
        .collection('visit_record_feedback')
        .doc(
          AppFirestoreService.visitFeedbackDocumentId(
            patientId: profile.id,
            visitId: followUpVisit.id,
          ),
        )
        .set({
          'patientId': profile.id,
          'clinicId': clinicId,
          'patientName': profile.name,
          'visitId': followUpVisit.id,
          'visitDate': followUpVisit.date,
          'visitTime': followUpVisit.time,
          'feedbackText':
              'Sample beta feedback: sleep was a little better for two nights after the last visit, but the desk-work shoulder tension returned by the weekend.',
          'status': 'reviewed',
          'patientCanEdit': false,
          'reviewedByPractitioner': true,
          'submittedAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 5, hours: 2)),
          ),
          'updatedAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 4, hours: 6)),
          ),
          'reviewedAt': Timestamp.fromDate(
            now.subtract(const Duration(days: 4, hours: 4)),
          ),
          'source': 'beta_seed_tools',
        });
  }

  static AppointmentSlot? _pickSampleSlot(List<AppointmentSlot> slots) {
    if (slots.isEmpty) {
      return null;
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    for (final slot in slots) {
      final slotDate = DateTime.parse(slot.date);
      if (!slotDate.isBefore(normalizedToday)) {
        return slot;
      }
    }
    return slots.first;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
