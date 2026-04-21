import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';

class PatientRequestsScreen extends StatefulWidget {
  const PatientRequestsScreen({super.key});

  static const routeName = '/patient-requests';

  @override
  State<PatientRequestsScreen> createState() => _PatientRequestsScreenState();
}

class _PatientRequestsScreenState extends State<PatientRequestsScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;

  PatientProfile get _currentProfile =>
      _authBackedProfile ?? _store.currentPatientProfile;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Requests Inbox', '???')),
        actions: const [LanguageMenuButton()],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('answer_requests')
            .where('patientId', isEqualTo: profile.id)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aTime = (a.data()['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime = (b.data()['requestedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });

          if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  lang.tr(
                    'There are no practitioner requests for this profile yet.',
                    '? ????? ?? ?? ??? ????.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final status = (data['status'] ?? 'pending').toString();
              final selectedQuestions =
                  ((data['selectedQuestions'] as List?) ?? const []).cast<dynamic>();
              final customByCategory =
                  ((data['customQuestionsByCategory'] as Map?) ?? const <String, dynamic>{})
                      .map((key, value) => MapEntry(key.toString(), (value as List).cast<dynamic>()));

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatTimestamp(data['requestedAt'] as Timestamp?),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Chip(
                            label: Text(
                              status == 'completed'
                                  ? lang.tr('Completed', '?? ??')
                                  : lang.tr('Pending', '???'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${lang.tr('Visit Time', '?? ??')}: ${data['patientTime'] ?? '-'}'),
                      Text('${lang.tr('Last Visit', '?? ??')}: ${data['lastVisitDate'] ?? '-'}'),
                      const SizedBox(height: 12),
                      Text(
                        lang.tr('Requested Questions', '?? ??'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (selectedQuestions.isEmpty && customByCategory.isEmpty)
                        Text(lang.tr('No specific questions were saved.', '??? ??? ????.')),
                      ...selectedQuestions.map((question) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('- $question'),
                          )),
                      ...customByCategory.entries.expand(
                        (entry) => entry.value.map(
                          (question) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('- [${entry.key}] $question'),
                          ),
                        ),
                      ),
                      if (((data['note'] ?? '') as String).trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          lang.tr('Practitioner Note', '??? ??'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text((data['note'] ?? '').toString()),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            PatientIntakeScreen.routeName,
                          ),
                          icon: const Icon(Icons.edit_note),
                          label: Text(lang.tr('Answer in Intake Form', '?? ???? ????')),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
