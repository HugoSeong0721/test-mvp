import 'package:cloud_firestore/cloud_firestore.dart';

class AppFirestoreService {
  AppFirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    return doc.id;
  }
}
