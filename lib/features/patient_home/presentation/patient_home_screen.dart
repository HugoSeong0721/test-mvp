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
          title: Text(lang.tr('Edit My Profile', '? ??? ??')),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: lang.tr('Name', '??')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: lang.tr('Phone', '????')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: lang.tr('Email', '???')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: birthYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: lang.tr('Birth Year', '????')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sexController,
                    decoration: InputDecoration(labelText: lang.tr('Sex / Gender', '??')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ethnicityController,
                    decoration: InputDecoration(labelText: lang.tr('Ethnicity', '??/??')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: memoController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: lang.tr('Memo', '??')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.tr('Cancel', '??')),
            ),
            FilledButton(
              onPressed: () async {
                final updated = profile.copyWith(
                  name: nameController.text.trim().isEmpty
                      ? profile.name
                      : nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  birthYear: int.tryParse(birthYearController.text.trim()) ??
                      profile.birthYear,
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
              child: Text(lang.tr('Save', '??')),
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

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final history = _history;
    final latestVisit = history.isNotEmpty ? history.first.visit : null;
    final upcomingVisits = _store.upcomingVisits(DateTime.now())
      ..retainWhere((visit) => visit.profile.id == profile.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Patient Home', '?? ?')),
        actions: [
          IconButton(
            tooltip: lang.tr('Edit profile', '??? ??'),
            onPressed: _openProfileDialog,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const LanguageMenuButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(label: Text(lang.tr('Patient View', '?? ??'))),
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

              final latestSubmission =
                  submissionDocs.isNotEmpty ? submissionDocs.first.data() : null;

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
                          lang.tr('Welcome back, ${profile.name}', '${profile.name}?, ?? ????'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'Use this home page to review requests, continue your intake, and track your visit history in one place.',
                            '? ? ???? ?? ??, ?? ????, ?? ?? ??? ? ?? ? ? ???.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                PatientIntakeScreen.routeName,
                              ),
                              icon: const Icon(Icons.edit_note),
                              label: Text(lang.tr('Continue Intake', '?? ????')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                PatientRequestsScreen.routeName,
                              ),
                              icon: const Icon(Icons.mark_email_unread_outlined),
                              label: Text(lang.tr('Open Requests', '??? ??')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                VisitHistoryScreen.routeName,
                              ),
                              icon: const Icon(Icons.history),
                              label: Text(lang.tr('Visit History', '?? ??')),
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
                          title: lang.tr('Pending Requests', '??? ??'),
                          value: '${pendingRequests.length}',
                          subtitle: pendingRequests.isEmpty
                              ? lang.tr('No pending items right now', '??? ?? ??? ???')
                              : lang.tr('Please review these before your next visit', '?? ?? ? ??? ???'),
                          icon: Icons.notifications_active_outlined,
                        ),
                        _SummaryCard(
                          title: lang.tr('Next Visit', '?? ??'),
                          value: upcomingVisits.isNotEmpty
                              ? '${upcomingVisits.first.visit.date} ${upcomingVisits.first.visit.time}'
                              : '-',
                          subtitle: upcomingVisits.isNotEmpty
                              ? lang.tr('Your next scheduled session', '?? ?? ?? ?? ??')
                              : lang.tr('No future visit is listed yet', '?? ?? ??? ???'),
                          icon: Icons.event_available_outlined,
                        ),
                        _SummaryCard(
                          title: lang.tr('Profile Ready', '??? ?? ??'),
                          value: profile.hasRequiredAlertInfo
                              ? lang.tr('Ready', '??')
                              : lang.tr('Needs Update', '?? ??'),
                          subtitle: profile.hasRequiredAlertInfo
                              ? lang.tr('Phone and email are both saved', '????? ???? ?? ???? ???')
                              : lang.tr('Please add both phone and email', '????? ???? ?? ??? ???'),
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
                            lang.tr('My Profile Snapshot', '? ??? ??'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text('${lang.tr('Phone', '????')}: ${profile.phone.isEmpty ? '-' : profile.phone}'),
                          Text('${lang.tr('Email', '???')}: ${profile.email.isEmpty ? '-' : profile.email}'),
                          Text('${lang.tr('Profile', '???')}: ${profile.sex}, ${profile.ageRange}, ${profile.ethnicity}'),
                          if (profile.memo.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('${lang.tr('Memo', '??')}: ${profile.memo}'),
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
                                  '?? ?? ??? ??? ????? ???? ?? ?????.',
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
                                  lang.tr('Today\'s To-Do', '?? ?? ? ?'),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  PatientRequestsScreen.routeName,
                                ),
                                child: Text(lang.tr('See all', '?? ??')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _TodoRow(
                            done: pendingRequests.isEmpty,
                            title: lang.tr('Check practitioner requests', '??? ?? ??'),
                            subtitle: pendingRequests.isEmpty
                                ? lang.tr('You are caught up', '?? ??? ??? ???')
                                : lang.tr('${pendingRequests.length} request(s) still need attention', '?? ??? ??? ${pendingRequests.length}? ???'),
                          ),
                          _TodoRow(
                            done: profile.hasRequiredAlertInfo,
                            title: lang.tr('Confirm contact information', '??? ??'),
                            subtitle: profile.hasRequiredAlertInfo
                                ? lang.tr('Phone and email are saved', '????? ???? ???? ???')
                                : lang.tr('Please add both phone and email', '????? ???? ?? ??? ???'),
                          ),
                          _TodoRow(
                            done: latestSubmission != null,
                            title: lang.tr('Submit your latest intake update', '?? ?? ??'),
                            subtitle: latestSubmission == null
                                ? lang.tr('No recent submission yet', '?? ?? ??? ?? ???')
                                : lang.tr('Last submitted at ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}', '??? ??: ${_formatTimestamp(latestSubmission['submittedAt'] as Timestamp?)}'),
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
                              lang.tr('Latest Practitioner Request', '?? ?? ?? ??'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${lang.tr('Status', '??')}: ${(latestRequest['status'] ?? 'pending').toString()}',
                            ),
                            Text(
                              '${lang.tr('Requested At', '?? ??')}: ${_formatTimestamp(latestRequest['requestedAt'] as Timestamp?)}',
                            ),
                            Text(
                              '${lang.tr('Requested Questions', '?? ?? ?')}: ${((latestRequest['selectedQuestions'] as List?) ?? const []).length}',
                            ),
                            if (((latestRequest['note'] ?? '') as String).trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${lang.tr('Practitioner Note', '??? ??')}: ${latestRequest['note']}',
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
                                  lang.tr('Visit History Snapshot', '?? ?? ??'),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  VisitHistoryScreen.routeName,
                                ),
                                child: Text(lang.tr('Open history', '?? ??')),
                              ),
                            ],
                          ),
                          if (latestVisit == null)
                            Text(lang.tr('No visit history is available yet.', '?? ?? ??? ????.'))
                          else ...[
                            Text('${lang.tr('Last Visit', '?? ??')}: ${latestVisit.date} ${latestVisit.time}'),
                            Text('${lang.tr('Treatment Focus', '?? ??')}: ${latestVisit.previousTreatmentArea}'),
                            Text('${lang.tr('Session Note', '?? ??')}: ${latestVisit.previousSessionNote}'),
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
                            lang.tr('Recent Submission Activity', '?? ?? ??'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (submissionDocs.isEmpty)
                            Text(lang.tr('No submissions yet.', '?? ?? ??? ????.'))
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
                                      Text('${lang.tr('Visit Type', '?? ??')}: ${data['visitType'] ?? '-'}'),
                                      Text('${lang.tr('Answered Questions', '?? ?')}: ${answers.length}'),
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
