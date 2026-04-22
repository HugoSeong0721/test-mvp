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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<String> _safeStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, List<String>> _safeQuestionMap(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }

    final output = <String, List<String>>{};
    for (final entry in raw.entries) {
      output[entry.key.toString()] = _safeStringList(entry.value);
    }
    return output;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final profile = _currentProfile;

        return Scaffold(
          appBar: AppBar(
            title: Text(lang.tr('Requests Inbox', '답변 요청함')),
            actions: const [LanguageMenuButton()],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('answer_requests')
                .where('patientId', isEqualTo: profile.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.tr('Could not load practitioner requests.', '답변 요청을 불러오지 못했습니다.'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              }

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
                        '이 프로필에는 아직 침술사 답변 요청이 없습니다.',
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
                  final selectedQuestions = _safeStringList(data['selectedQuestions']);
                  final customByCategory = _safeQuestionMap(data['customQuestionsByCategory']);
                  final note = (data['note'] ?? '').toString().trim();
                  final visitTime = (data['patientTime'] ?? '-').toString();
                  final lastVisitDate = (data['lastVisitDate'] ?? '-').toString();

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
                                      ? lang.tr('Completed', '확인 완료')
                                      : lang.tr('Pending', '대기 중'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${lang.tr('Visit Time', '방문 시간')}: $visitTime'),
                          Text('${lang.tr('Last Visit', '지난 방문')}: $lastVisitDate'),
                          const SizedBox(height: 12),
                          Text(
                            lang.tr('Requested Questions', '요청 질문'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          if (selectedQuestions.isEmpty && customByCategory.isEmpty)
                            Text(lang.tr('No specific questions were saved.', '저장된 세부 질문이 없습니다.')),
                          ...selectedQuestions.map(
                            (question) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('- $question'),
                            ),
                          ),
                          ...customByCategory.entries.expand(
                            (entry) => entry.value.map(
                              (question) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('- [${entry.key}] $question'),
                              ),
                            ),
                          ),
                          if (note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              lang.tr('Practitioner Note', '침술사 메모'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(note),
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
                              label: Text(lang.tr('Answer in Intake Form', '문진 화면에서 답변하기')),
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
      },
    );
  }
}
