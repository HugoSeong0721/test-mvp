import 'package:cloud_firestore/cloud_firestore.dart';

class AppFirestoreService {
  AppFirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> fetchClinicCenters() async {
    final snapshot = await _db.collection('clinic_centers').get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  static Future<Map<String, String>> fetchPractitionerClinicLinks() async {
    final snapshot = await _db.collection('practitioner_clinic_links').get();
    return {
      for (final doc in snapshot.docs)
        doc.id: (doc.data()['clinicId'] ?? '').toString(),
    }..removeWhere((_, clinicId) => clinicId.trim().isEmpty);
  }

  static Future<Map<String, Map<String, dynamic>>>
  fetchPatientClinicLinks() async {
    final snapshot = await _db.collection('patient_clinic_links').get();
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  static Future<List<Map<String, dynamic>>> fetchClinicOpenRequests() async {
    final snapshot = await _db.collection('clinic_open_requests').get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  static Future<List<Map<String, dynamic>>>
  fetchPatientClinicMembershipRequests() async {
    final snapshot = await _db
        .collection('patient_clinic_membership_requests')
        .get();
    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  static Future<void> saveClinicCenter(Map<String, dynamic> clinic) async {
    final id = (clinic['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return;
    }
    await _db.collection('clinic_centers').doc(id).set({
      ...clinic,
      'id': id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> savePractitionerClinicLink({
    required String practitionerId,
    required String clinicId,
  }) async {
    if (practitionerId.trim().isEmpty || clinicId.trim().isEmpty) {
      return;
    }
    await _db.collection('practitioner_clinic_links').doc(practitionerId).set({
      'practitionerId': practitionerId,
      'clinicId': clinicId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> savePatientClinicLink({
    required String patientId,
    required String selectedClinicId,
    String? defaultClinicId,
  }) async {
    if (patientId.trim().isEmpty || selectedClinicId.trim().isEmpty) {
      return;
    }
    final payload = <String, dynamic>{
      'patientId': patientId,
      'selectedClinicId': selectedClinicId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (defaultClinicId != null) {
      payload['defaultClinicId'] = defaultClinicId;
    }
    await _db
        .collection('patient_clinic_links')
        .doc(patientId)
        .set(payload, SetOptions(merge: true));
  }

  static Future<void> saveClinicOpenRequest(
    Map<String, dynamic> request,
  ) async {
    final id = (request['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return;
    }
    await _db.collection('clinic_open_requests').doc(id).set({
      ...request,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> savePatientClinicMembershipRequest(
    Map<String, dynamic> request,
  ) async {
    final id = (request['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return;
    }
    await _db.collection('patient_clinic_membership_requests').doc(id).set({
      ...request,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markClinicOpenRequestReviewed(String requestId) async {
    if (requestId.trim().isEmpty) {
      return;
    }
    await _db.collection('clinic_open_requests').doc(requestId).set({
      'status': 'reviewed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String visitFeedbackDocumentId({
    required String patientId,
    required String visitId,
  }) {
    return '${patientId}_$visitId';
  }

  static Future<String> submitPatientIntake({
    required String patientId,
    required String clinicId,
    required String patientName,
    required String visitType,
    required List<Map<String, dynamic>> answers,
    required String extraMemo,
    required Map<String, dynamic> adherence,
    required int currentQuestionIndex,
  }) async {
    final doc = await _db.collection('intake_submissions').add({
      'patientId': patientId,
      'clinicId': clinicId,
      'patientName': patientName,
      'visitType': visitType,
      'answers': answers,
      'extraMemo': extraMemo,
      'adherence': adherence,
      'currentQuestionIndex': currentQuestionIndex,
      'source': 'patient_intake_screen',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> markPendingRequestsCompleted({
    required String patientId,
    required String clinicId,
    required String submissionId,
  }) async {
    final snapshot = await _db
        .collection('answer_requests')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snapshot.docs) {
      final docClinicId = (doc.data()['clinicId'] ?? '').toString();
      if (docClinicId != clinicId) {
        continue;
      }
      final requestType = (doc.data()['requestType'] ?? 'answer_request')
          .toString();
      if (requestType == 'note') {
        continue;
      }
      await doc.reference.update({
        'status': 'completed',
        'completedBySubmissionId': submissionId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<String> sendAnswerRequest({
    required String patientId,
    required String clinicId,
    required String patientName,
    required String patientPhone,
    required String patientEmail,
    required String patientTime,
    required String lastVisitDate,
    required String intakeStatus,
    required List<String> selectedQuestions,
    required Map<String, List<String>> customQuestionsByCategory,
    required String note,
    String requestType = 'answer_request',
  }) async {
    final doc = await _db.collection('answer_requests').add({
      'patientId': patientId,
      'clinicId': clinicId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientEmail': patientEmail,
      'patientTime': patientTime,
      'lastVisitDate': lastVisitDate,
      'intakeStatus': intakeStatus,
      'selectedQuestions': selectedQuestions,
      'customQuestionsByCategory': customQuestionsByCategory,
      'note': note,
      'requestType': requestType,
      'status': 'pending',
      'source': 'practitioner_dashboard',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    if (patientEmail.trim().isNotEmpty) {
      await _queuePortalEmail(
        patientName: patientName,
        patientEmail: patientEmail,
        patientTime: patientTime,
        lastVisitDate: lastVisitDate,
        selectedQuestions: selectedQuestions,
        customQuestionsByCategory: customQuestionsByCategory,
        note: note,
        requestType: requestType,
      );
    }

    return doc.id;
  }

  static Future<String> sendPractitionerNote({
    required String patientId,
    required String clinicId,
    required String patientName,
    required String patientPhone,
    required String patientEmail,
    required String patientTime,
    required String lastVisitDate,
    required String intakeStatus,
    required String note,
  }) {
    return sendAnswerRequest(
      patientId: patientId,
      clinicId: clinicId,
      patientName: patientName,
      patientPhone: patientPhone,
      patientEmail: patientEmail,
      patientTime: patientTime,
      lastVisitDate: lastVisitDate,
      intakeStatus: intakeStatus,
      selectedQuestions: const [],
      customQuestionsByCategory: const {},
      note: note,
      requestType: 'note',
    );
  }

  static Future<void> submitVisitRecordFeedback({
    required String patientId,
    required String clinicId,
    required String patientName,
    required String visitId,
    required String visitDate,
    required String visitTime,
    required String feedbackText,
  }) async {
    final docId = visitFeedbackDocumentId(
      patientId: patientId,
      visitId: visitId,
    );
    final ref = _db.collection('visit_record_feedback').doc(docId);
    final existing = await ref.get();

    if (existing.exists && (existing.data()?['status'] == 'reviewed')) {
      throw StateError('reviewed');
    }

    await ref.set({
      'patientId': patientId,
      'clinicId': clinicId,
      'patientName': patientName,
      'visitId': visitId,
      'visitDate': visitDate,
      'visitTime': visitTime,
      'feedbackText': feedbackText.trim(),
      'status': 'pending',
      'patientCanEdit': true,
      'reviewedByPractitioner': false,
      'submittedAt':
          existing.data()?['submittedAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'source': 'visit_history_screen',
    }, SetOptions(merge: true));
  }

  static Future<void> markVisitRecordFeedbackReviewed({
    required String patientId,
    required String visitId,
  }) async {
    final docId = visitFeedbackDocumentId(
      patientId: patientId,
      visitId: visitId,
    );
    await _db.collection('visit_record_feedback').doc(docId).set({
      'status': 'reviewed',
      'patientCanEdit': false,
      'reviewedByPractitioner': true,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendTesterFeedback({
    required String category,
    required String routeName,
    required String summary,
    required String details,
    required String reporterName,
    required String reporterEmail,
  }) async {
    const feedbackInbox = 'mg.seong0721@gmail.com';
    final feedbackRef = _db.collection('tester_feedback').doc();
    final screenLabel = routeName.trim().isEmpty ? 'unknown_screen' : routeName;
    final summaryLine = summary.trim().isEmpty ? 'No summary' : summary.trim();
    final detailsLine = details.trim().isEmpty
        ? 'No extra detail added'
        : details.trim();
    final nameLine = reporterName.trim().isEmpty
        ? 'Anonymous tester'
        : reporterName.trim();
    final emailLine = reporterEmail.trim().isEmpty
        ? 'No email provided'
        : reporterEmail.trim();
    final submittedAt = DateTime.now().toIso8601String();

    final textBody =
        '''
Tester feedback was submitted from Test MVP.

Category: $category
Screen: $screenLabel
Submitted at: $submittedAt
Tester: $nameLine
Email: $emailLine

What they were trying to do:
$summaryLine

What happened / what should change:
$detailsLine
''';

    final htmlBody =
        '''
<p><strong>Tester feedback was submitted from Test MVP.</strong></p>
<p>
Category: <strong>$category</strong><br/>
Screen: <strong>$screenLabel</strong><br/>
Submitted at: <strong>$submittedAt</strong><br/>
Tester: <strong>$nameLine</strong><br/>
Email: <strong>$emailLine</strong>
</p>
<p><strong>What they were trying to do</strong><br/>$summaryLine</p>
<p><strong>What happened / what should change</strong><br/>$detailsLine</p>
''';

    await feedbackRef.set({
      'category': category,
      'routeName': screenLabel,
      'summary': summaryLine,
      'details': detailsLine,
      'reporterName': reporterName.trim(),
      'reporterEmail': reporterEmail.trim(),
      'status': 'open',
      'source': 'global_feedback_launcher',
      'submittedAt': FieldValue.serverTimestamp(),
      'submittedAtIso': submittedAt,
      'reviewedAt': null,
    });

    await _db.collection('mail').add({
      'to': [feedbackInbox],
      'message': {
        'subject': '[Test MVP Feedback] $category · $screenLabel',
        'text': textBody,
        'html': htmlBody,
      },
      'meta': {
        'type': 'tester_feedback',
        'category': category,
        'routeName': screenLabel,
        'reporterName': reporterName.trim(),
        'reporterEmail': reporterEmail.trim(),
        'feedbackId': feedbackRef.id,
        'queuedBy': 'global_feedback_launcher',
      },
      'queuedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markTesterFeedbackReviewed({
    required String feedbackId,
  }) async {
    await _db.collection('tester_feedback').doc(feedbackId).set({
      'status': 'reviewed',
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> reopenTesterFeedback({required String feedbackId}) async {
    await _db.collection('tester_feedback').doc(feedbackId).set({
      'status': 'open',
      'reviewedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> queueChecklistReminder({
    required String patientId,
    required String clinicId,
    required String patientName,
    required String patientEmail,
    required String dateLabel,
    required List<String> missingItems,
  }) async {
    if (patientEmail.trim().isEmpty || missingItems.isEmpty) {
      return;
    }

    final textItems = missingItems.map((item) => '- $item').join('\n');
    final htmlItems = missingItems.map((item) => '<li>$item</li>').join();
    const appLink = 'https://hugoseong0721.github.io/test-mvp/#/intake';

    await _db.collection('mail').add({
      'to': [patientEmail.trim()],
      'message': {
        'subject': '[Test MVP] Today checklist reminder',
        'text':
            '''
Hello $patientName,

Today is $dateLabel. Please check your visit prep items for today:

$textItems

Open your intake checklist:
$appLink
''',
        'html':
            '''
<p>Hello <strong>$patientName</strong>,</p>
<p>Today is <strong>$dateLabel</strong>. Please check your visit prep items for today:</p>
<ul>$htmlItems</ul>
<p><a href="$appLink">Open your intake checklist</a></p>
''',
      },
      'meta': {
        'type': 'daily_checklist_reminder',
        'patientId': patientId,
        'clinicId': clinicId,
        'patientName': patientName,
        'dateLabel': dateLabel,
        'missingItems': missingItems,
        'queuedBy': 'patient_intake_screen',
      },
      'queuedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _queuePortalEmail({
    required String patientName,
    required String patientEmail,
    required String patientTime,
    required String lastVisitDate,
    required List<String> selectedQuestions,
    required Map<String, List<String>> customQuestionsByCategory,
    required String note,
    required String requestType,
  }) async {
    final isNote = requestType == 'note';
    final allQuestions = <String>[
      ...selectedQuestions,
      ...customQuestionsByCategory.entries.expand(
        (entry) => entry.value.map((question) => '[${entry.key}] $question'),
      ),
    ];

    final questionLines = allQuestions.isEmpty
        ? '- No requested questions'
        : allQuestions.map((question) => '- $question').join('\n');
    final noteLine = note.trim().isEmpty
        ? isNote
              ? 'No note text was added'
              : 'No additional note'
        : note.trim();
    const appLink = 'https://hugoseong0721.github.io/test-mvp/';
    final introLine = isNote
        ? 'Your practitioner sent you a portal note.'
        : 'Your practitioner has requested pre-visit intake answers.';
    final subject = isNote
        ? '[Test MVP] Practitioner note'
        : '[Test MVP] Practitioner answer request';

    final textRequestSection = isNote
        ? ''
        : '''
Requested questions:
$questionLines

''';
    final htmlRequestSection = isNote
        ? ''
        : '''
<p><strong>Requested Questions</strong></p>
<ul>${allQuestions.isEmpty ? '<li>No requested questions</li>' : allQuestions.map((question) => '<li>$question</li>').join()}</ul>
''';

    final textBody =
        '''
Hello $patientName,

$introLine

Scheduled visit time: $patientTime
Last visit date: $lastVisitDate

$textRequestSection
Practitioner note:
$noteLine

Portal link:
$appLink

First app password: Daisy
After that, choose Friend Beta Sign Up / Login or log in with your existing account.
''';

    final htmlBody =
        '''
<p>Hello <strong>$patientName</strong>,</p>
<p>$introLine</p>
<p>
Scheduled visit time: <strong>$patientTime</strong><br/>
Last visit date: <strong>$lastVisitDate</strong>
</p>
$htmlRequestSection
<p><strong>Practitioner Note</strong><br/>$noteLine</p>
<p>
<a href="$appLink">Open the portal here</a>
</p>
<p>
First app password: <strong>Daisy</strong><br/>
After that, choose Friend Beta Sign Up / Login or log in with your existing account.
</p>
''';

    await _db.collection('mail').add({
      'to': [patientEmail.trim()],
      'message': {'subject': subject, 'text': textBody, 'html': htmlBody},
      'meta': {
        'type': isNote
            ? 'practitioner_note_notification'
            : 'answer_request_notification',
        'patientName': patientName,
        'queuedBy': 'practitioner_dashboard',
      },
      'queuedAt': FieldValue.serverTimestamp(),
    });
  }
}
