import 'package:cloud_firestore/cloud_firestore.dart';

class AppFirestoreService {
  AppFirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String visitFeedbackDocumentId({
    required String patientId,
    required String visitId,
  }) {
    return '${patientId}_$visitId';
  }

  static Future<String> submitPatientIntake({
    required String patientId,
    required String patientName,
    required String visitType,
    required List<Map<String, dynamic>> answers,
    required String extraMemo,
    required Map<String, dynamic> adherence,
    required int currentQuestionIndex,
  }) async {
    final doc = await _db.collection('intake_submissions').add({
      'patientId': patientId,
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
    required String submissionId,
  }) async {
    final snapshot = await _db
        .collection('answer_requests')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'status': 'completed',
        'completedBySubmissionId': submissionId,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<String> sendAnswerRequest({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required String patientEmail,
    required String patientTime,
    required String lastVisitDate,
    required String intakeStatus,
    required List<String> selectedQuestions,
    required Map<String, List<String>> customQuestionsByCategory,
    required String note,
  }) async {
    final doc = await _db.collection('answer_requests').add({
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientEmail': patientEmail,
      'patientTime': patientTime,
      'lastVisitDate': lastVisitDate,
      'intakeStatus': intakeStatus,
      'selectedQuestions': selectedQuestions,
      'customQuestionsByCategory': customQuestionsByCategory,
      'note': note,
      'status': 'pending',
      'source': 'practitioner_dashboard',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    if (patientEmail.trim().isNotEmpty) {
      await _queueAnswerRequestEmail(
        patientName: patientName,
        patientEmail: patientEmail,
        patientTime: patientTime,
        lastVisitDate: lastVisitDate,
        selectedQuestions: selectedQuestions,
        customQuestionsByCategory: customQuestionsByCategory,
        note: note,
      );
    }

    return doc.id;
  }

  static Future<void> submitVisitRecordFeedback({
    required String patientId,
    required String patientName,
    required String visitId,
    required String visitDate,
    required String visitTime,
    required String feedbackText,
  }) async {
    final docId = visitFeedbackDocumentId(patientId: patientId, visitId: visitId);
    final ref = _db.collection('visit_record_feedback').doc(docId);
    final existing = await ref.get();

    if (existing.exists && (existing.data()?['status'] == 'reviewed')) {
      throw StateError('reviewed');
    }

    await ref.set({
      'patientId': patientId,
      'patientName': patientName,
      'visitId': visitId,
      'visitDate': visitDate,
      'visitTime': visitTime,
      'feedbackText': feedbackText.trim(),
      'status': 'pending',
      'patientCanEdit': true,
      'reviewedByPractitioner': false,
      'submittedAt': existing.data()?['submittedAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'source': 'visit_history_screen',
    }, SetOptions(merge: true));
  }

  static Future<void> markVisitRecordFeedbackReviewed({
    required String patientId,
    required String visitId,
  }) async {
    final docId = visitFeedbackDocumentId(patientId: patientId, visitId: visitId);
    await _db.collection('visit_record_feedback').doc(docId).set({
      'status': 'reviewed',
      'patientCanEdit': false,
      'reviewedByPractitioner': true,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _queueAnswerRequestEmail({
    required String patientName,
    required String patientEmail,
    required String patientTime,
    required String lastVisitDate,
    required List<String> selectedQuestions,
    required Map<String, List<String>> customQuestionsByCategory,
    required String note,
  }) async {
    final allQuestions = <String>[
      ...selectedQuestions,
      ...customQuestionsByCategory.entries.expand(
        (entry) => entry.value.map((question) => '[${entry.key}] $question'),
      ),
    ];

    final questionLines = allQuestions.isEmpty
        ? '- No requested questions'
        : allQuestions.map((question) => '- $question').join('\n');
    final noteLine = note.trim().isEmpty ? 'No additional note' : note.trim();
    const appLink = 'https://hugoseong0721.github.io/test-mvp/';

    final textBody = '''
Hello $patientName,

Your practitioner has requested pre-visit intake answers.

Scheduled visit time: $patientTime
Last visit date: $lastVisitDate

Requested questions:
$questionLines

Practitioner note:
$noteLine

Submission link:
$appLink

First app password: Daisy
After that, choose Friend Beta Sign Up / Login or log in with your existing account.
''';

    final htmlQuestions = allQuestions.isEmpty
        ? '<li>No requested questions</li>'
        : allQuestions.map((question) => '<li>$question</li>').join();
    final htmlBody = '''
<p>Hello <strong>$patientName</strong>,</p>
<p>Your practitioner has requested pre-visit intake answers.</p>
<p>
Scheduled visit time: <strong>$patientTime</strong><br/>
Last visit date: <strong>$lastVisitDate</strong>
</p>
<p><strong>Requested Questions</strong></p>
<ul>$htmlQuestions</ul>
<p><strong>Practitioner Note</strong><br/>$noteLine</p>
<p>
<a href="$appLink">Open the form here</a>
</p>
<p>
First app password: <strong>Daisy</strong><br/>
After that, choose Friend Beta Sign Up / Login or log in with your existing account.
</p>
''';

    await _db.collection('mail').add({
      'to': [patientEmail.trim()],
      'message': {
        'subject': '[Test MVP] Practitioner answer request',
        'text': textBody,
        'html': htmlBody,
      },
      'meta': {
        'type': 'answer_request_notification',
        'patientName': patientName,
        'queuedBy': 'practitioner_dashboard',
      },
      'queuedAt': FieldValue.serverTimestamp(),
    });
  }
}
