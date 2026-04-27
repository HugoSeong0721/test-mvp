import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iottie_automation/features/patient_requests/presentation/patient_requests_screen.dart';
import 'package:iottie_automation/features/visit_history/presentation/visit_history_screen.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/patient_shell.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  static const routeName = '/patient-home';

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  static const Duration _profileLoadTimeout = Duration(seconds: 10);

  final ClinicDataStore _store = ClinicDataStore.instance;
  StreamSubscription<PatientSession?>? _sessionSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  Timer? _loadTimeoutTimer;
  PatientProfile? _sessionBackedProfile;
  PatientSession? _activeSession;
  bool _sessionResolved = false;
  bool _showStartGuide = true;
  bool _loadTimedOut = false;
  Object? _loadError;

  PatientProfile get _currentProfile =>
      _sessionBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history =>
      _store.historyForPatient(_currentProfile.id);

  bool get _waitingForRealProfile {
    if (!_sessionResolved) {
      return true;
    }
    if (_activeSession == null) {
      return false;
    }
    return _activeSession!.usesFirebaseAuth && _sessionBackedProfile == null;
  }

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
    _sessionSubscription = BetaSessionService.watchSession().listen((
      session,
    ) async {
      _activeSession = session;
      if (mounted) {
        setState(() => _sessionResolved = true);
      } else {
        _sessionResolved = true;
      }
      await _profileSubscription?.cancel();
      if (session == null) {
        if (mounted) {
          setState(() => _sessionBackedProfile = null);
        }
        return;
      }

      try {
        await PatientProfileService.ensureProfileForSession(session)
            .timeout(_profileLoadTimeout);
        _profileSubscription =
            PatientProfileService.watchProfileForSession(session).listen((
              profile,
            ) {
              if (!mounted || profile == null) {
                return;
              }
              _loadTimeoutTimer?.cancel();
              setState(() {
                _sessionBackedProfile = profile;
                _loadTimedOut = false;
                _loadError = null;
              });
            });
      } catch (error) {
        if (!mounted) return;
        setState(() => _loadError = error);
      }
    });
  }

  void _startLoadTimer() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_profileLoadTimeout, () {
      if (!mounted) return;
      if (_sessionBackedProfile == null && _waitingForRealProfile) {
        setState(() => _loadTimedOut = true);
      }
    });
  }

  void _retryLoad() {
    setState(() {
      _loadTimedOut = false;
      _loadError = null;
    });
    _startLoadTimer();
    final session = _activeSession;
    if (session != null) {
      _sessionSubscription?.cancel();
      _sessionSubscription = BetaSessionService.watchSession().listen((s) async {
        _activeSession = s;
        if (s == null) return;
        try {
          await PatientProfileService.ensureProfileForSession(s)
              .timeout(_profileLoadTimeout);
          _profileSubscription?.cancel();
          _profileSubscription =
              PatientProfileService.watchProfileForSession(s).listen((profile) {
                if (!mounted || profile == null) return;
                _loadTimeoutTimer?.cancel();
                setState(() {
                  _sessionBackedProfile = profile;
                  _loadTimedOut = false;
                  _loadError = null;
                });
              });
        } catch (error) {
          if (!mounted) return;
          setState(() => _loadError = error);
        }
      });
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _sessionSubscription?.cancel();
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
                    decoration: InputDecoration(
                      labelText: lang.tr('Name', '이름'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Phone', '전화번호'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Email', '이메일'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: birthYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lang.tr('Birth Year', '출생연도'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sexController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Sex / Gender', '성별'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ethnicityController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Ethnicity', '인종/민족'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: memoController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: lang.tr('Memo', '메모'),
                    ),
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
                  birthYear:
                      int.tryParse(birthYearController.text.trim()) ??
                      profile.birthYear,
                  sex: sexController.text.trim().isEmpty
                      ? profile.sex
                      : sexController.text.trim(),
                  ethnicity: ethnicityController.text.trim().isEmpty
                      ? profile.ethnicity
                      : ethnicityController.text.trim(),
                  memo: memoController.text.trim(),
                );

                if (_activeSession != null) {
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

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseStoredDate(String value) {
    try {
      final parts = value.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _weekdayShort(DateTime date) {
    const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const korean = ['월', '화', '수', '목', '금', '토', '일'];
    return AppLanguageController.instance.tr(
      english[date.weekday - 1],
      korean[date.weekday - 1],
    );
  }

  String _formatDateWithWeekday(DateTime date, {bool compact = false}) {
    final base = compact
        ? '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : _formatDate(date);
    return '$base (${_weekdayShort(date)})';
  }

  String _formatStoredDateWithWeekday(String value, {bool compact = false}) {
    final parsed = _parseStoredDate(value);
    if (parsed == null) {
      return value;
    }
    return _formatDateWithWeekday(parsed, compact: compact);
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_formatDateWithWeekday(value)} $hour:$minute';
  }

  String _formatVisitSlot(String date, String time) {
    return '${_formatStoredDateWithWeekday(date)} · $time';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '-';
    }
    return _formatDateTime(timestamp.toDate());
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

    final dates = availableSlots.map((slot) => slot.date).toSet().toList()
      ..sort();
    String selectedDate = dates.first;
    String selectedTime = availableSlots
        .firstWhere((slot) => slot.date == selectedDate)
        .time;

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
                              child: Text(_formatStoredDateWithWeekday(date)),
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
                            'Appointment request sent for ${_formatVisitSlot(selectedDate, selectedTime)}. You will see confirmation after your practitioner reviews it.',
                            '${_formatVisitSlot(selectedDate, selectedTime)} 예약 신청을 보냈습니다. 침술사가 확인하면 상태가 업데이트됩니다.',
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

        if (_waitingForRealProfile) {
          return PatientShell(
            currentItem: PatientNavItem.home,
            title: lang.tr('Patient Home', '환자 홈'),
            actions: const [LanguageMenuButton()],
            body: _buildLoadingOrErrorBody(context, lang),
          );
        }

        final profile = _currentProfile;
        final history = _history;
        final latestVisit = history.isNotEmpty ? history.first.visit : null;
        final upcomingVisits = _store.upcomingVisits(DateTime.now())
          ..retainWhere((visit) => visit.profile.id == profile.id);
        final appointmentRequests = _store.requestsForPatient(profile.id);
        final pendingAppointmentRequests = appointmentRequests
            .where(
              (request) => request.status == AppointmentRequestStatus.pending,
            )
            .toList();
        final nextVisit = upcomingVisits.isNotEmpty
            ? upcomingVisits.first.visit
            : null;

        return PatientShell(
          currentItem: PatientNavItem.home,
          title: lang.tr('Patient Home', '환자 홈'),
          actions: [
            IconButton(
              tooltip: lang.tr('Edit profile', '프로필 수정'),
              onPressed: _openProfileDialog,
              icon: const Icon(Icons.account_circle_outlined),
            ),
            const LanguageMenuButton(),
          ],
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('answer_requests')
                .where('patientId', isEqualTo: profile.id)
                .snapshots(),
            builder: (context, requestSnapshot) {
              final requestDocs = [...?requestSnapshot.data?.docs];
              requestDocs.sort((a, b) {
                final aTime =
                    (a.data()['requestedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                final bTime =
                    (b.data()['requestedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0;
                return bTime.compareTo(aTime);
              });

              final pendingRequests = requestDocs
                  .where(
                    (doc) => (doc.data()['status'] ?? 'pending') == 'pending',
                  )
                  .toList();
              final latestRequest = requestDocs.isNotEmpty
                  ? requestDocs.first.data()
                  : null;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('intake_submissions')
                    .where('patientId', isEqualTo: profile.id)
                    .snapshots(),
                builder: (context, submissionSnapshot) {
                  final submissionDocs = [...?submissionSnapshot.data?.docs];
                  submissionDocs.sort((a, b) {
                    final aTime =
                        (a.data()['submittedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bTime =
                        (b.data()['submittedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bTime.compareTo(aTime);
                  });

                  final latestSubmission = submissionDocs.isNotEmpty
                      ? submissionDocs.first.data()
                      : null;
                  final pendingItemCount =
                      pendingRequests.length +
                      pendingAppointmentRequests.length;
                  final intakeStatusLabel = latestSubmission == null
                      ? lang.tr('Needs update', '업데이트 필요')
                      : lang.tr('Recently saved', '최근 저장됨');
                  final intakeStatusBody = latestSubmission == null
                      ? lang.tr(
                          'Open the intake form and send your latest condition before the next visit.',
                          '다음 방문 전 현재 상태를 문진으로 먼저 보내주세요.',
                        )
                      : lang.tr(
                          'Your latest intake was saved on ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}.',
                          '최근 문진은 ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}에 저장되었습니다.',
                        );
                  final nextVisitLabel = nextVisit != null
                      ? _formatVisitSlot(nextVisit.date, nextVisit.time)
                      : pendingAppointmentRequests.isNotEmpty
                      ? lang.tr('Waiting for confirmation', '확정 대기 중')
                      : lang.tr('Not booked yet', '아직 예약 없음');
                  final nextVisitBody = nextVisit != null
                      ? lang.tr(
                          'Your next confirmed visit is already visible here.',
                          '다음 확정 방문이 여기 바로 보입니다.',
                        )
                      : pendingAppointmentRequests.isNotEmpty
                      ? lang.tr(
                          'Your practitioner still needs to review the requested slot.',
                          '침술사가 신청한 시간을 아직 검토 중입니다.',
                        )
                      : lang.tr(
                          'Request a slot so your next visit shows up in your portal home.',
                          '예약을 신청하면 다음 방문이 이 홈 화면에 바로 보이게 됩니다.',
                        );
                  final profileStatusLabel = profile.hasRequiredAlertInfo
                      ? lang.tr('Ready', '준비됨')
                      : lang.tr('Needs update', '업데이트 필요');
                  final profileStatusBody = profile.hasRequiredAlertInfo
                      ? lang.tr(
                          'Phone and email are both saved for follow-up requests.',
                          '전화번호와 이메일이 모두 저장되어 있어 후속 요청을 받을 수 있습니다.',
                        )
                      : lang.tr(
                          'Please add both phone and email before sharing this beta with others.',
                          '이 beta를 제대로 테스트하려면 전화번호와 이메일을 모두 넣어주세요.',
                        );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppPanel(
                        padding: const EdgeInsets.all(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.pine,
                            AppTheme.jade,
                            Color(0xFF2A7A66),
                          ],
                        ),
                        borderColor: Colors.white24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Patient command center', '환자 시작 허브'),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lang.tr(
                                'Welcome back, ${profile.name}',
                                '${profile.name}님, 다시 오셨네요',
                              ),
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lang.tr(
                                'This page is for checking requests, continuing your intake, and keeping your next visit organized. Start from the steps below and move downward.',
                                '이 화면은 답변 요청 확인, 문진 이어쓰기, 다음 방문 정리를 위한 곳입니다. 아래 순서대로 위에서부터 보면 됩니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AppMetricChip(
                                  icon: Icons.notifications_active_outlined,
                                  label: lang.tr('Pending items', '대기 항목'),
                                  value:
                                      '${pendingRequests.length + pendingAppointmentRequests.length}',
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                  valueColor: Colors.white,
                                ),
                                AppMetricChip(
                                  icon: Icons.event_available_outlined,
                                  label: lang.tr('Next visit', '다음 방문'),
                                  value: nextVisit != null
                                      ? _formatVisitSlot(
                                          nextVisit.date,
                                          nextVisit.time,
                                        )
                                      : lang.tr('Not booked', '미예약'),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                  valueColor: Colors.white,
                                ),
                                AppMetricChip(
                                  icon: Icons.verified_user_outlined,
                                  label: lang.tr('Profile', '프로필'),
                                  value: profile.hasRequiredAlertInfo
                                      ? lang.tr('Ready', '준비됨')
                                      : lang.tr('Needs update', '업데이트 필요'),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.14,
                                  ),
                                  labelColor: Colors.white.withValues(
                                    alpha: 0.72,
                                  ),
                                  valueColor: Colors.white,
                                ),
                              ],
                            ),
                            if (_showStartGuide) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang.tr('Start here', '여기부터 시작'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: lang.tr('Hide guide', '가이드 숨기기'),
                                    onPressed: () {
                                      setState(() => _showStartGuide = false);
                                    },
                                    icon: const Icon(Icons.close),
                                    color: Colors.white.withValues(alpha: 0.9),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  AppGuideStep(
                                    dark: true,
                                    step: '1',
                                    title: lang.tr(
                                      'Check requests first',
                                      '먼저 요청 확인',
                                    ),
                                    description: pendingRequests.isEmpty
                                        ? lang.tr(
                                            'No urgent practitioner questions are waiting right now.',
                                            '지금 바로 확인할 침술사 요청은 없습니다.',
                                          )
                                        : lang.tr(
                                            '${pendingRequests.length} practitioner request(s) need your attention.',
                                            '확인할 침술사 요청이 ${pendingRequests.length}건 있습니다.',
                                          ),
                                  ),
                                  AppGuideStep(
                                    dark: true,
                                    step: '2',
                                    title: lang.tr(
                                      'Continue or update intake',
                                      '문진 이어서 작성',
                                    ),
                                    description: latestSubmission == null
                                        ? lang.tr(
                                            'Open the intake form to submit your latest condition.',
                                            '문진 화면을 열어 현재 상태를 먼저 제출해보세요.',
                                          )
                                        : lang.tr(
                                            'You can reopen the intake form whenever your condition changed.',
                                            '몸 상태가 달라졌다면 언제든 문진을 다시 열어 업데이트할 수 있습니다.',
                                          ),
                                  ),
                                  AppGuideStep(
                                    dark: true,
                                    step: '3',
                                    title: lang.tr(
                                      'Review schedule and history',
                                      '일정과 기록 확인',
                                    ),
                                    description: lang.tr(
                                      'After requests and intake, check appointments and your recent visit notes.',
                                      '요청과 문진을 본 뒤에는 예약 상태와 최근 방문 기록을 확인하세요.',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    PatientRequestsScreen.routeName,
                                  ),
                                  icon: const Icon(
                                    Icons.mark_email_unread_outlined,
                                  ),
                                  label: Text(
                                    lang.tr('Open Requests', '답변 요청 보기'),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    PatientIntakeScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.edit_note),
                                  label: Text(
                                    lang.tr('Continue Intake', '문진 이어서 작성'),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openAppointmentDialog,
                                  icon: const Icon(
                                    Icons.event_available_outlined,
                                  ),
                                  label: Text(
                                    lang.tr('Book Appointment', '예약하기'),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    VisitHistoryScreen.routeName,
                                  ),
                                  icon: const Icon(Icons.history),
                                  label: Text(
                                    lang.tr('Visit History', '방문 기록'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('What needs attention now', '지금 먼저 볼 것'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                'Like Practice Better and athena-style portals, the first actions stay above history so you can move without hunting through menus.',
                                'Practice Better나 athena 계열 포털처럼, 먼저 해야 할 작업을 기록보다 위에 두어 메뉴를 헤매지 않게 했습니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.72),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 920;
                                final cards = [
                                  _ActionHubCard(
                                    icon: Icons.mark_email_unread_outlined,
                                    eyebrow: lang.tr('Requests first', '요청 먼저'),
                                    title: lang.tr(
                                      pendingRequests.isEmpty
                                          ? 'Inbox is clear'
                                          : '${pendingRequests.length} request(s) waiting',
                                      pendingRequests.isEmpty
                                          ? '요청함 비어 있음'
                                          : '${pendingRequests.length}건 대기 중',
                                    ),
                                    body: pendingRequests.isEmpty
                                        ? lang.tr(
                                            'No practitioner follow-up is waiting right now, but this is still the first place to check.',
                                            '지금은 대기 중인 침술사 요청이 없지만, 가장 먼저 확인할 곳은 여전히 여기입니다.',
                                          )
                                        : lang.tr(
                                            'Open your inbox, read the newest follow-up request, and continue from the linked intake form.',
                                            '요청함을 열어 최신 후속 질문을 읽고, 연결된 문진으로 바로 이어가세요.',
                                          ),
                                    actionLabel: lang.tr(
                                      'Open requests',
                                      '요청함 열기',
                                    ),
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      PatientRequestsScreen.routeName,
                                    ),
                                  ),
                                  _ActionHubCard(
                                    icon: Icons.assignment_turned_in_outlined,
                                    eyebrow: lang.tr('Intake next', '문진 다음'),
                                    title: intakeStatusLabel,
                                    body: intakeStatusBody,
                                    actionLabel: lang.tr(
                                      'Continue intake',
                                      '문진 이어쓰기',
                                    ),
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      PatientIntakeScreen.routeName,
                                    ),
                                  ),
                                  _ActionHubCard(
                                    icon: Icons.event_available_outlined,
                                    eyebrow: lang.tr('Visit context', '방문 맥락'),
                                    title: nextVisitLabel,
                                    body: nextVisitBody,
                                    actionLabel: nextVisit != null
                                        ? lang.tr('Review history', '기록 보기')
                                        : lang.tr(
                                            'Request appointment',
                                            '예약 신청',
                                          ),
                                    onTap: nextVisit != null
                                        ? () => Navigator.pushNamed(
                                            context,
                                            VisitHistoryScreen.routeName,
                                          )
                                        : _openAppointmentDialog,
                                  ),
                                  _ActionHubCard(
                                    icon: Icons.verified_user_outlined,
                                    eyebrow: lang.tr('Profile check', '프로필 점검'),
                                    title: profileStatusLabel,
                                    body: profileStatusBody,
                                    actionLabel: lang.tr(
                                      'Edit profile',
                                      '프로필 수정',
                                    ),
                                    onTap: _openProfileDialog,
                                  ),
                                ];

                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < cards.length;
                                        i++
                                      ) ...[
                                        cards[i],
                                        if (i != cards.length - 1)
                                          const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                                }

                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: cards
                                      .map(
                                        (card) => SizedBox(
                                          width:
                                              (constraints.maxWidth - 12) / 2,
                                          child: card,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.92),
                            AppTheme.mint.withValues(alpha: 0.36),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Portal home base', '포털 홈베이스'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                'These four markers match what strong client portals keep near the top: what is waiting, what was already sent, what is scheduled, and whether your account is ready.',
                                '좋은 client portal들이 상단에 두는 네 가지를 그대로 모았습니다. 지금 대기 중인 것, 이미 보낸 것, 예정된 것, 그리고 계정 준비 상태입니다.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.72),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 860;
                                final tiles = [
                                  _HomeBaseTile(
                                    label: lang.tr('Waiting now', '지금 대기'),
                                    value: '$pendingItemCount',
                                    detail: pendingItemCount == 0
                                        ? lang.tr(
                                            'No open requests or confirmations',
                                            '열린 요청이나 확인 대기가 없습니다',
                                          )
                                        : lang.tr(
                                            'Requests + appointment confirmations',
                                            '요청 + 예약 확인 대기',
                                          ),
                                    icon: Icons.notifications_active_outlined,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      PatientRequestsScreen.routeName,
                                    ),
                                  ),
                                  _HomeBaseTile(
                                    label: lang.tr('Latest intake', '최근 문진'),
                                    value: latestSubmission == null
                                        ? lang.tr('Not sent', '미제출')
                                        : _formatTimestamp(
                                            latestSubmission['submittedAt']
                                                as Timestamp?,
                                          ),
                                    detail: latestSubmission == null
                                        ? lang.tr(
                                            'Send your current condition',
                                            '현재 상태를 보내주세요',
                                          )
                                        : lang.tr(
                                            '${((latestSubmission['answers'] as List?) ?? const []).length} answers saved',
                                            '${((latestSubmission['answers'] as List?) ?? const []).length}개 답변 저장',
                                          ),
                                    icon: Icons.fact_check_outlined,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      PatientIntakeScreen.routeName,
                                    ),
                                  ),
                                  _HomeBaseTile(
                                    label: lang.tr(
                                      'Next confirmed visit',
                                      '다음 확정 방문',
                                    ),
                                    value: nextVisit != null
                                        ? _formatVisitSlot(
                                            nextVisit.date,
                                            nextVisit.time,
                                          )
                                        : lang.tr('No visit yet', '아직 없음'),
                                    detail: nextVisit != null
                                        ? lang.tr(
                                            nextVisit.intakeStatus.label,
                                            nextVisit.intakeStatus.label,
                                          )
                                        : lang.tr(
                                            'Book or request a slot',
                                            '예약을 잡아주세요',
                                          ),
                                    icon: Icons.event_note_outlined,
                                    onTap: nextVisit != null
                                        ? () => Navigator.pushNamed(
                                            context,
                                            VisitHistoryScreen.routeName,
                                          )
                                        : _openAppointmentDialog,
                                  ),
                                  _HomeBaseTile(
                                    label: lang.tr(
                                      'Contact readiness',
                                      '연락 준비',
                                    ),
                                    value: profile.hasRequiredAlertInfo
                                        ? lang.tr('Ready', '준비됨')
                                        : lang.tr('Missing fields', '정보 부족'),
                                    detail: profile.hasRequiredAlertInfo
                                        ? lang.tr(
                                            'Phone + email saved',
                                            '전화번호 + 이메일 저장됨',
                                          )
                                        : lang.tr(
                                            'Add phone and email',
                                            '전화번호와 이메일 추가',
                                          ),
                                    icon: Icons.badge_outlined,
                                    onTap: _openProfileDialog,
                                  ),
                                ];

                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < tiles.length;
                                        i++
                                      ) ...[
                                        tiles[i],
                                        if (i != tiles.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    for (var i = 0; i < tiles.length; i++) ...[
                                      Expanded(child: tiles[i]),
                                      if (i != tiles.length - 1)
                                        const SizedBox(width: 10),
                                    ],
                                  ],
                                );
                              },
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
                              value:
                                  '${pendingRequests.length + pendingAppointmentRequests.length}',
                              subtitle:
                                  pendingRequests.isEmpty &&
                                      pendingAppointmentRequests.isEmpty
                                  ? lang.tr(
                                      'No pending items right now',
                                      '지금 확인할 요청이 없습니다',
                                    )
                                  : lang.tr(
                                      'Includes answer requests and appointment confirmations',
                                      '답변 요청과 예약 확인 대기를 함께 보여줍니다',
                                    ),
                              icon: Icons.notifications_active_outlined,
                            ),
                            _SummaryCard(
                              title: lang.tr('Next Visit', '다음 방문'),
                              value: nextVisit != null
                                  ? _formatVisitSlot(
                                      nextVisit.date,
                                      nextVisit.time,
                                    )
                                  : '-',
                              subtitle: nextVisit != null
                                  ? lang.tr(
                                      'Your next scheduled session',
                                      '다음으로 예정된 세션입니다',
                                    )
                                  : pendingAppointmentRequests.isNotEmpty
                                  ? lang.tr(
                                      'You have a pending appointment request waiting for confirmation',
                                      '확정 대기 중인 예약 신청이 있습니다',
                                    )
                                  : lang.tr(
                                      'No future visit is listed yet',
                                      '아직 예정된 방문이 없습니다',
                                    ),
                              icon: Icons.event_available_outlined,
                            ),
                            _SummaryCard(
                              title: lang.tr('Profile Ready', '프로필 준비 상태'),
                              value: profile.hasRequiredAlertInfo
                                  ? lang.tr('Ready', '준비됨')
                                  : lang.tr('Needs Update', '업데이트 필요'),
                              subtitle: profile.hasRequiredAlertInfo
                                  ? lang.tr(
                                      'Phone and email are both saved',
                                      '전화번호와 이메일이 모두 저장되어 있습니다',
                                    )
                                  : lang.tr(
                                      'Please add both phone and email',
                                      '전화번호와 이메일을 모두 입력해주세요',
                                    ),
                              icon: Icons.verified_user_outlined,
                            ),
                          ];

                          if (isNarrow) {
                            return Column(
                              children: cards
                                  .map(
                                    (card) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: card,
                                    ),
                                  )
                                  .toList(),
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                Expanded(child: cards[i]),
                                if (i != cards.length - 1)
                                  const SizedBox(width: 12),
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${lang.tr('Phone', '전화번호')}: ${profile.phone.isEmpty ? '-' : profile.phone}',
                              ),
                              Text(
                                '${lang.tr('Email', '이메일')}: ${profile.email.isEmpty ? '-' : profile.email}',
                              ),
                              Text(
                                '${lang.tr('Profile', '프로필')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}',
                              ),
                              if (profile.memo.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${lang.tr('Memo', '메모')}: ${profile.memo}',
                                ),
                              ],
                              if (!profile.hasRequiredAlertInfo) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(
                                      alpha: 0.10,
                                    ),
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
                                      lang.tr('Quick Checklist', '빠른 체크리스트'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
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
                                title: lang.tr(
                                  'Check practitioner requests',
                                  '침술사 요청 확인',
                                ),
                                subtitle: pendingRequests.isEmpty
                                    ? lang.tr(
                                        'You are caught up',
                                        '현재 확인할 요청이 없습니다',
                                      )
                                    : lang.tr(
                                        '${pendingRequests.length} request(s) still need attention',
                                        '아직 확인하지 않은 요청이 ${pendingRequests.length}건 있습니다',
                                      ),
                              ),
                              _TodoRow(
                                done: profile.hasRequiredAlertInfo,
                                title: lang.tr(
                                  'Confirm contact information',
                                  '연락처 확인',
                                ),
                                subtitle: profile.hasRequiredAlertInfo
                                    ? lang.tr(
                                        'Phone and email are saved',
                                        '전화번호와 이메일이 저장되어 있습니다',
                                      )
                                    : lang.tr(
                                        'Please add both phone and email',
                                        '전화번호와 이메일을 모두 입력해주세요',
                                      ),
                              ),
                              _TodoRow(
                                done: latestSubmission != null,
                                title: lang.tr(
                                  'Submit your latest intake update',
                                  '최신 문진 제출',
                                ),
                                subtitle: latestSubmission == null
                                    ? lang.tr(
                                        'No recent submission yet',
                                        '아직 최근 제출 기록이 없습니다',
                                      )
                                    : lang.tr(
                                        'Last submitted at ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}',
                                        '최근 제출 시각: ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}',
                                      ),
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
                                  lang.tr(
                                    'Latest Practitioner Request',
                                    '최근 답변 요청',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${lang.tr('Status', '상태')}: ${(latestRequest['status'] ?? 'pending').toString()}',
                                ),
                                Text(
                                  '${lang.tr('Requested At', '요청 시각')}: ${_formatTimestamp(latestRequest['requestedAt'] as Timestamp?)}',
                                ),
                                Text(
                                  '${lang.tr('Requested Questions', '요청 질문 수')}: ${((latestRequest['selectedQuestions'] as List?) ?? const []).length}',
                                ),
                                if (((latestRequest['note'] ?? '') as String)
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${lang.tr('Practitioner Note', '침술사 메모')}: ${latestRequest['note']}',
                                  ),
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
                                      lang.tr(
                                        'Appointment Requests',
                                        '예약 신청 현황',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      lang.tr('Book Appointment', '예약하기'),
                                    ),
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
                                  final canCancel =
                                      request.status ==
                                      AppointmentRequestStatus.pending;
                                  final statusText = switch (request.status) {
                                    AppointmentRequestStatus.pending => lang.tr(
                                      'Pending Confirmation',
                                      '확정 대기',
                                    ),
                                    AppointmentRequestStatus.confirmed =>
                                      lang.tr(
                                        'Confirmed by Practitioner',
                                        '침술사 확인 완료',
                                      ),
                                    AppointmentRequestStatus.declined =>
                                      lang.tr(
                                        'Declined by Practitioner',
                                        '침술사가 거절함',
                                      ),
                                    AppointmentRequestStatus
                                        .canceledByPatient =>
                                      lang.tr('Canceled by You', '본인이 취소함'),
                                  };
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _formatVisitSlot(
                                                    request.date,
                                                    request.time,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Chip(label: Text(statusText)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${lang.tr('Requested At', '신청 시각')}: '
                                            '${_formatDateTime(request.requestedAt)}',
                                          ),
                                          if (request.reviewedAt != null)
                                            Text(
                                              '${lang.tr('Reviewed At', '확인 시각')}: '
                                              '${_formatDateTime(request.reviewedAt!)}',
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
                                                _store.cancelAppointmentRequest(
                                                  request.id,
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.cancel_outlined,
                                              ),
                                              label: Text(
                                                lang.tr(
                                                  'Cancel Request',
                                                  '신청 취소',
                                                ),
                                              ),
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
                                      lang.tr(
                                        'Confirmed Appointments',
                                        '확정된 예약',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      lang.tr(
                                        'Request Another Slot',
                                        '다른 시간 신청',
                                      ),
                                    ),
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
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatVisitSlot(
                                              visit.date,
                                              visit.time,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                      lang.tr(
                                        'Visit History Snapshot',
                                        '방문 기록 요약',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      VisitHistoryScreen.routeName,
                                    ),
                                    child: Text(
                                      lang.tr('Open history', '기록 열기'),
                                    ),
                                  ),
                                ],
                              ),
                              if (latestVisit == null)
                                Text(
                                  lang.tr(
                                    'No visit history is available yet.',
                                    '아직 방문 기록이 없습니다.',
                                  ),
                                )
                              else ...[
                                Text(
                                  '${lang.tr('Last Visit', '최근 방문')}: ${_formatVisitSlot(latestVisit.date, latestVisit.time)}',
                                ),
                                Text(
                                  '${lang.tr('Treatment Focus', '치료 부위')}: ${latestVisit.previousTreatmentArea}',
                                ),
                                Text(
                                  '${lang.tr('Session Note', '세션 메모')}: ${latestVisit.previousSessionNote}',
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
                              Text(
                                lang.tr(
                                  'Recent Submission Activity',
                                  '최근 제출 활동',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (submissionDocs.isEmpty)
                                Text(
                                  lang.tr(
                                    'No submissions yet.',
                                    '아직 제출 기록이 없습니다.',
                                  ),
                                )
                              else
                                ...submissionDocs.take(3).map((doc) {
                                  final data = doc.data();
                                  final answers =
                                      (data['answers'] as List?) ?? const [];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatTimestamp(
                                              data['submittedAt'] as Timestamp?,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${lang.tr('Visit Type', '방문 유형')}: ${data['visitType'] ?? '-'}',
                                          ),
                                          Text(
                                            '${lang.tr('Answered Questions', '답변 수')}: ${answers.length}',
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

  Widget _buildLoadingOrErrorBody(
    BuildContext context,
    AppLanguageController lang,
  ) {
    final hasError = _loadError != null;
    final timedOut = _loadTimedOut;
    final showProblem = hasError || timedOut;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!showProblem) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  lang.tr(
                    'Loading your patient profile...',
                    '환자 프로필을 불러오는 중...',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(
                  lang.tr(
                    'Could not load your profile.',
                    '프로필을 불러오지 못했습니다.',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  lang.tr(
                    'This usually means your network or VPN is blocking Firebase. Please turn off VPN, check your connection, then retry.',
                    '네트워크 또는 VPN이 Firebase 호출을 막고 있는 경우가 많습니다. VPN을 끄고 연결을 확인한 뒤 다시 시도해주세요.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _retryLoad,
                      icon: const Icon(Icons.refresh),
                      label: Text(lang.tr('Retry', '다시 시도')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (_) => false),
                      icon: const Icon(Icons.home_outlined),
                      label: Text(lang.tr('Back to entry', '진입 화면으로')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.pine),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionHubCard extends StatelessWidget {
  const _ActionHubCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                AppTheme.blush.withValues(alpha: 0.22),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.pine.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.pine),
              ),
              const SizedBox(height: 14),
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.pine,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppTheme.pine,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBaseTile extends StatelessWidget {
  const _HomeBaseTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.pine, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done
            ? AppTheme.mint.withValues(alpha: 0.38)
            : AppTheme.blush.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? AppTheme.jade : AppTheme.copper,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
