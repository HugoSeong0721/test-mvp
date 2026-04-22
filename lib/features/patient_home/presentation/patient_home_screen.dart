import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iottie_automation/features/patient_requests/presentation/patient_requests_screen.dart';
import 'package:iottie_automation/features/visit_history/presentation/visit_history_screen.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  static const routeName = '/patient-home';

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;
  User? _authUser;

  PatientProfile get _currentProfile =>
      _authBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history => _store.historyForPatient(_currentProfile.id);

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _authUser = user;
      await _profileSubscription?.cancel();
      if (user == null) {
        if (mounted) {
          setState(() => _authBackedProfile = null);
        }
        return;
      }

      await PatientProfileService.ensureProfileForUser(user);
      _profileSubscription = PatientProfileService.watchProfile(user.uid).listen((profile) {
        if (!mounted || profile == null) {
          return;
        }
        setState(() => _authBackedProfile = profile);
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openProfileDialog() async {
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final nameController = TextEditingController(text: profile.name);
    final phoneController = TextEditingController(text: profile.phone);
    final emailController = TextEditingController(text: profile.email);
    final birthYearController = TextEditingController(
      text: profile.birthYear.toString(),
    );
    final sexController = TextEditingController(text: profile.sex);
    final ethnicityController = TextEditingController(text: profile.ethnicity);
    final memoController = TextEditingController(text: profile.memo);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.tr('Edit My Profile', '내 프로필 수정')),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: lang.tr('Name', '이름')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: lang.tr('Phone', '전화번호')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: lang.tr('Email', '이메일')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: birthYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: lang.tr('Birth Year', '출생연도')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sexController,
                    decoration: InputDecoration(labelText: lang.tr('Sex / Gender', '성별')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ethnicityController,
                    decoration: InputDecoration(labelText: lang.tr('Ethnicity', '인종/민족')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: memoController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: lang.tr('Memo', '메모')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.tr('Cancel', '취소')),
            ),
            FilledButton(
              onPressed: () async {
                final updated = profile.copyWith(
                  name: nameController.text.trim().isEmpty
                      ? profile.name
                      : nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  birthYear: int.tryParse(birthYearController.text.trim()) ?? profile.birthYear,
                  sex: sexController.text.trim().isEmpty
                      ? profile.sex
                      : sexController.text.trim(),
                  ethnicity: ethnicityController.text.trim().isEmpty
                      ? profile.ethnicity
                      : ethnicityController.text.trim(),
                  memo: memoController.text.trim(),
                );

                if (_authUser != null) {
                  await PatientProfileService.saveProfile(updated);
                } else {
                  _store.saveProfile(updated);
                  _store.setCurrentPatientProfile(updated.id);
                  setState(() {});
                }

                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
              },
              child: Text(lang.tr('Save', '저장')),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    birthYearController.dispose();
    sexController.dispose();
    ethnicityController.dispose();
    memoController.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openAppointmentDialog() async {
    final lang = AppLanguageController.instance;
    final availableSlots = _store.availableSlotsForPatient(_currentProfile.id);
    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'There are no open appointment slots right now.',
              '지금은 선택 가능한 예약 슬롯이 없습니다.',
            ),
          ),
        ),
      );
      return;
    }

    final dates = availableSlots.map((slot) => slot.date).toSet().toList()..sort();
    String selectedDate = dates.first;
    String selectedTime =
        availableSlots.firstWhere((slot) => slot.date == selectedDate).time;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(lang.tr('Book Appointment', '예약하기')),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr(
                        'Choose a date and time to add another upcoming visit.',
                        '다가오는 방문 일정을 추가할 날짜와 시간을 선택해주세요.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDate,
                      decoration: InputDecoration(
                        labelText: lang.tr('Date', '날짜'),
                        border: const OutlineInputBorder(),
                      ),
                      items: dates
                          .map(
                            (date) => DropdownMenuItem<String>(
                              value: date,
                              child: Text(date),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedDate = value;
                          selectedTime = availableSlots
                              .firstWhere((slot) => slot.date == value)
                              .time;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTime,
                      decoration: InputDecoration(
                        labelText: lang.tr('Time', '시간'),
                        border: const OutlineInputBorder(),
                      ),
                      items: availableSlots
                          .where((slot) => slot.date == selectedDate)
                          .map(
                            (slot) => DropdownMenuItem<String>(
                              value: slot.time,
                              child: Text(slot.time),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedTime = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang.tr(
                        'This only sends a request. Your practitioner will confirm it later, and you can only choose open slots.',
                        '이 단계는 예약 신청만 보내는 것입니다. 실제 확정은 침술사가 확인한 뒤에 이뤄지며, 열려 있는 슬롯만 선택할 수 있습니다.',
                      ),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.tr('Cancel', '취소')),
                ),
                FilledButton(
                  onPressed: () {
                    _store.requestAppointment(
                      patientId: _currentProfile.id,
                      date: selectedDate,
                      time: selectedTime,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang.tr(
                            'Appointment request sent for $selectedDate at $selectedTime. You will see confirmation after your practitioner reviews it.',
                            '$selectedDate $selectedTime 예약 신청을 보냈습니다. 침술사가 확인하면 상태가 업데이트됩니다.',
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text(lang.tr('Request Appointment', '예약 신청')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final profile = _currentProfile;
        final history = _history;
        final latestVisit = history.isNotEmpty ? history.first.visit : null;
        final upcomingVisits = _store.upcomingVisits(DateTime.now())
          ..retainWhere((visit) => visit.profile.id == profile.id);
        final appointmentRequests = _store.requestsForPatient(profile.id);
        final pendingAppointmentRequests = appointmentRequests
            .where((request) => request.status == AppointmentRequestStatus.pending)
            .toList();
        final nextVisit = upcomingVisits.isNotEmpty ? upcomingVisits.first.visit : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(lang.tr('Patient Home', '환자 홈')),
            actions: [
              IconButton(
                tooltip: lang.tr('Edit profile', '프로필 수정'),
                onPressed: _openProfileDialog,
                icon: const Icon(Icons.account_circle_outlined),
              ),
              const LanguageMenuButton(),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Chip(label: Text(lang.tr('Patient View', '환자 화면'))),
                ),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('answer_requests')
                .where('patientId', isEqualTo: profile.id)
                .snapshots(),
            builder: (context, requestSnapshot) {
              final requestDocs = [...?requestSnapshot.data?.docs];
              requestDocs.sort((a, b) {
                final aTime = (a.data()['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                final bTime = (b.data()['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                return bTime.compareTo(aTime);
              });

              final pendingRequests = requestDocs
                  .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
                  .toList();
              final latestRequest = requestDocs.isNotEmpty ? requestDocs.first.data() : null;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('intake_submissions')
                    .where('patientId', isEqualTo: profile.id)
                    .snapshots(),
                builder: (context, submissionSnapshot) {
                  final submissionDocs = [...?submissionSnapshot.data?.docs];
                  submissionDocs.sort((a, b) {
                    final aTime = (a.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = (b.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });

                  final latestSubmission = submissionDocs.isNotEmpty ? submissionDocs.first.data() : null;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4F2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Welcome back, ${profile.name}', '${profile.name}님, 다시 오셨네요'),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                'Use this page to review requests, continue your intake, and track your visit history.',
                                '이 페이지에서 답변 요청을 확인하고, 문진을 이어서 작성하고, 방문 기록을 확인할 수 있습니다.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _openAppointmentDialog,
                                  icon: const Icon(Icons.event_available_outlined),
                                  label: Text(lang.tr('Book Appointment', '예약하기')),
                                ),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    PatientIntakeScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.edit_note),
                                  label: Text(lang.tr('Continue Intake', '문진 이어서 작성')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    PatientRequestsScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.mark_email_unread_outlined),
                                  label: Text(lang.tr('Open Requests', '답변 요청 보기')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    VisitHistoryScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.history),
                                  label: Text(lang.tr('Visit History', '방문 기록')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 860;
                          final cards = [
                            _SummaryCard(
                              title: lang.tr('Pending Items', '대기 중 항목'),
                              value: '${pendingRequests.length + pendingAppointmentRequests.length}',
                              subtitle: pendingRequests.isEmpty
                                      && pendingAppointmentRequests.isEmpty
                                  ? lang.tr('No pending items right now', '지금 확인할 요청이 없습니다')
                                  : lang.tr('Includes answer requests and appointment confirmations', '답변 요청과 예약 확인 대기를 함께 보여줍니다'),
                              icon: Icons.notifications_active_outlined,
                            ),
                            _SummaryCard(
                              title: lang.tr('Next Visit', '다음 방문'),
                              value: nextVisit != null
                                  ? '${nextVisit.date} ${nextVisit.time}'
                                  : '-',
                              subtitle: nextVisit != null
                                  ? lang.tr('Your next scheduled session', '다음으로 예정된 세션입니다')
                                  : pendingAppointmentRequests.isNotEmpty
                                      ? lang.tr('You have a pending appointment request waiting for confirmation', '확정 대기 중인 예약 신청이 있습니다')
                                      : lang.tr('No future visit is listed yet', '아직 예정된 방문이 없습니다'),
                              icon: Icons.event_available_outlined,
                            ),
                            _SummaryCard(
                              title: lang.tr('Profile Ready', '프로필 준비 상태'),
                              value: profile.hasRequiredAlertInfo
                                  ? lang.tr('Ready', '준비됨')
                                  : lang.tr('Needs Update', '업데이트 필요'),
                              subtitle: profile.hasRequiredAlertInfo
                                  ? lang.tr('Phone and email are both saved', '전화번호와 이메일이 모두 저장되어 있습니다')
                                  : lang.tr('Please add both phone and email', '전화번호와 이메일을 모두 입력해주세요'),
                              icon: Icons.verified_user_outlined,
                            ),
                          ];

                          if (isNarrow) {
                            return Column(
                              children: cards
                                  .map((card) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: card,
                                      ))
                                  .toList(),
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i != cards.length - 1) const SizedBox(width: 12),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('My Profile Snapshot', '내 프로필 요약'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Text('${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? '-' : profile.phone}'),
                              Text('${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? '-' : profile.email}'),
                              Text('${lang.tr('Profile', '프로필')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}'),
                              if (profile.memo.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('${lang.tr('Memo', '메모')}: ${profile.memo}'),
                              ],
                              if (!profile.hasRequiredAlertInfo) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    lang.tr(
                                      'Please add both your phone number and email before real workflow testing.',
                                      '실제 워크플로우 테스트 전에는 전화번호와 이메일을 모두 입력해주세요.',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.tr('Today\'s To-Do', '오늘 할 일'),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      PatientRequestsScreen.routeName,
                                    ),
                                    child: Text(lang.tr('See all', '전체 보기')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _TodoRow(
                                done: pendingRequests.isEmpty,
                                title: lang.tr('Check practitioner requests', '침술사 요청 확인'),
                                subtitle: pendingRequests.isEmpty
                                    ? lang.tr('You are caught up', '현재 확인할 요청이 없습니다')
                                    : lang.tr('${pendingRequests.length} request(s) still need attention', '아직 확인하지 않은 요청이 ${pendingRequests.length}건 있습니다'),
                              ),
                              _TodoRow(
                                done: profile.hasRequiredAlertInfo,
                                title: lang.tr('Confirm contact information', '연락처 확인'),
                                subtitle: profile.hasRequiredAlertInfo
                                    ? lang.tr('Phone and email are saved', '전화번호와 이메일이 저장되어 있습니다')
                                    : lang.tr('Please add both phone and email', '전화번호와 이메일을 모두 입력해주세요'),
                              ),
                              _TodoRow(
                                done: latestSubmission != null,
                                title: lang.tr('Submit your latest intake update', '최신 문진 제출'),
                                subtitle: latestSubmission == null
                                    ? lang.tr('No recent submission yet', '아직 최근 제출 기록이 없습니다')
                                    : lang.tr('Last submitted at ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}', '최근 제출 시각: ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (latestRequest != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr('Latest Practitioner Request', '최근 답변 요청'),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text('${lang.tr('Status', '상태')}: ${(latestRequest['status'] ?? 'pending').toString()}'),
                                Text('${lang.tr('Requested At', '요청 시각')}: ${_formatTimestamp(latestRequest['requestedAt'] as Timestamp?)}'),
                                Text('${lang.tr('Requested Questions', '요청 질문 수')}: ${((latestRequest['selectedQuestions'] as List?) ?? const []).length}'),
                                if (((latestRequest['note'] ?? '') as String).trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('${lang.tr('Practitioner Note', '침술사 메모')}: ${latestRequest['note']}'),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (latestRequest != null) const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.tr('Appointment Requests', '예약 신청 현황'),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                    label: Text(lang.tr('Book Appointment', '예약하기')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (appointmentRequests.isEmpty)
                                Text(
                                  lang.tr(
                                    'You have not sent any appointment requests yet.',
                                    '아직 보낸 예약 신청이 없습니다.',
                                  ),
                                )
                              else
                                ...appointmentRequests.map((request) {
                                  final canCancel = request.status == AppointmentRequestStatus.pending;
                                  final statusText = switch (request.status) {
                                    AppointmentRequestStatus.pending => lang.tr('Pending Confirmation', '확정 대기'),
                                    AppointmentRequestStatus.confirmed => lang.tr('Confirmed by Practitioner', '침술사 확인 완료'),
                                    AppointmentRequestStatus.declined => lang.tr('Declined by Practitioner', '침술사가 거절함'),
                                    AppointmentRequestStatus.canceledByPatient => lang.tr('Canceled by You', '본인이 취소함'),
                                  };
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${request.date} · ${request.time}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              Chip(label: Text(statusText)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${lang.tr('Requested At', '신청 시각')}: '
                                            '${request.requestedAt.year}-${request.requestedAt.month.toString().padLeft(2, '0')}-${request.requestedAt.day.toString().padLeft(2, '0')} '
                                            '${request.requestedAt.hour.toString().padLeft(2, '0')}:${request.requestedAt.minute.toString().padLeft(2, '0')}',
                                          ),
                                          if (request.reviewedAt != null)
                                            Text(
                                              '${lang.tr('Reviewed At', '확인 시각')}: '
                                              '${request.reviewedAt!.year}-${request.reviewedAt!.month.toString().padLeft(2, '0')}-${request.reviewedAt!.day.toString().padLeft(2, '0')} '
                                              '${request.reviewedAt!.hour.toString().padLeft(2, '0')}:${request.reviewedAt!.minute.toString().padLeft(2, '0')}',
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            canCancel
                                                ? lang.tr(
                                                    'This request is not confirmed yet. You will get an update after the practitioner reviews it.',
                                                    '이 요청은 아직 확정되지 않았습니다. 침술사가 확인하면 상태가 업데이트됩니다.',
                                                  )
                                                : lang.tr(
                                                    'This request is locked because it has already been reviewed.',
                                                    '이 요청은 이미 확인되었기 때문에 수정할 수 없습니다.',
                                                  ),
                                          ),
                                          if (canCancel) ...[
                                            const SizedBox(height: 8),
                                            TextButton.icon(
                                              onPressed: () {
                                                _store.cancelAppointmentRequest(request.id);
                                              },
                                              icon: const Icon(Icons.cancel_outlined),
                                              label: Text(lang.tr('Cancel Request', '신청 취소')),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.tr('Confirmed Appointments', '확정된 예약'),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                  label: Text(lang.tr('Request Another Slot', '다른 시간 신청')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (upcomingVisits.isEmpty)
                                Text(
                                  lang.tr(
                                    'No confirmed appointments are scheduled yet.',
                                    '아직 확정된 예약이 없습니다.',
                                  ),
                                )
                              else
                                ...upcomingVisits.map((scheduledVisit) {
                                  final visit = scheduledVisit.visit;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${visit.date} · ${visit.time}',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            lang.tr(
                                              'This appointment has already been confirmed by your practitioner.',
                                              '이 예약은 침술사 확인이 끝난 확정 일정입니다.',
                                            ),
                                          ),
                                          Text(
                                            '${lang.tr('Current Intake Status', '현재 문진 상태')}: ${visit.intakeStatus.label}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.tr('Visit History Snapshot', '방문 기록 요약'),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      VisitHistoryScreen.routeName,
                                    ),
                                    child: Text(lang.tr('Open history', '기록 열기')),
                                  ),
                                ],
                              ),
                              if (latestVisit == null)
                                Text(lang.tr('No visit history is available yet.', '아직 방문 기록이 없습니다.'))
                              else ...[
                                Text('${lang.tr('Last Visit', '최근 방문')}: ${latestVisit.date} ${latestVisit.time}'),
                                Text('${lang.tr('Treatment Focus', '치료 부위')}: ${latestVisit.previousTreatmentArea}'),
                                Text('${lang.tr('Session Note', '세션 메모')}: ${latestVisit.previousSessionNote}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Recent Submission Activity', '최근 제출 활동'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (submissionDocs.isEmpty)
                                Text(lang.tr('No submissions yet.', '아직 제출 기록이 없습니다.'))
                              else
                                ...submissionDocs.take(3).map((doc) {
                                  final data = doc.data();
                                  final answers = (data['answers'] as List?) ?? const [];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatTimestamp(data['submittedAt'] as Timestamp?),
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('${lang.tr('Visit Type', '방문 유형')}: ${data['visitType'] ?? '-'}'),
                                          Text('${lang.tr('Answered Questions', '답변 수')}: ${answers.length}'),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.done,
    required this.title,
    required this.subtitle,
  });

  final bool done;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? Colors.teal : Colors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
