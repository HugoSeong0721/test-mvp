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
        ? '- 확인 요청 질문 없음'
        : allQuestions.map((question) => '- $question').join('\n');
    final noteLine = note.trim().isEmpty ? '추가 메모 없음' : note.trim();
    const appLink = 'https://hugoseong0721.github.io/test-mvp/';

    final textBody = '''
$patientName님 안녕하세요.

침술사님이 사전 문진 답변을 요청했습니다.

방문 예정 시간: $patientTime
지난 방문일: $lastVisitDate

확인 요청 질문:
$questionLines

침술사 메모:
$noteLine

작성 링크:
$appLink

앱 첫 화면 비밀번호: Daisy
그 다음에는 지인 베타 회원가입/로그인 또는 기존 계정 로그인으로 들어가시면 됩니다.
''';

    final htmlQuestions = allQuestions.isEmpty
        ? '<li>확인 요청 질문 없음</li>'
        : allQuestions.map((question) => '<li>$question</li>').join();
    final htmlBody = '''
<p><strong>$patientName</strong>님 안녕하세요.</p>
<p>침술사님이 사전 문진 답변을 요청했습니다.</p>
<p>
방문 예정 시간: <strong>$patientTime</strong><br/>
지난 방문일: <strong>$lastVisitDate</strong>
</p>
<p><strong>확인 요청 질문</strong></p>
<ul>$htmlQuestions</ul>
<p><strong>침술사 메모</strong><br/>$noteLine</p>
<p>
<a href="$appLink">여기서 작성하기</a>
</p>
<p>
앱 첫 화면 비밀번호: <strong>Daisy</strong><br/>
그 다음에는 지인 베타 회원가입/로그인 또는 기존 계정 로그인으로 들어가시면 됩니다.
</p>
''';

    await _db.collection('mail').add({
      'to': [patientEmail.trim()],
      'message': {
        'subject': '[Test MVP] 침술사 답변 요청이 도착했습니다',
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
