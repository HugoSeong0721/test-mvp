import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  static const routeName = '/patient-history';

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<PatientProfile?>? _profileSubscription;
  PatientProfile? _authBackedProfile;

  PatientProfile get _currentProfile =>
      _authBackedProfile ?? _store.currentPatientProfile;

  List<ScheduledVisit> get _history => _store.historyForPatient(_currentProfile.id);

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

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final profile = _currentProfile;
    final history = _history;
    final lastVisit = history.isNotEmpty ? history.first.visit : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Visit History', '방문 기록')),
        actions: const [LanguageMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _HistorySummaryChip(
                        label: lang.tr('Total Visits', '총 방문'),
                        value: '${history.length}',
                      ),
                      _HistorySummaryChip(
                        label: lang.tr('Last Visit', '최근 방문'),
                        value: lastVisit == null ? '-' : lastVisit.date,
                      ),
                      _HistorySummaryChip(
                        label: lang.tr('Most Recent Status', '최근 상태'),
                        value: lastVisit == null ? '-' : lastVisit.intakeStatus.label,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  lang.tr('No visit history is available yet.', '아직 방문 기록이 없습니다.'),
                ),
              ),
            )
          else
            ...history.map((scheduledVisit) {
              final visit = scheduledVisit.visit;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${visit.date} · ${visit.time}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Chip(label: Text(visit.intakeStatus.label)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${lang.tr('Last Visit Before This', '그 전 방문')}: ${visit.lastVisitDate} (${visit.daysAgo} ${lang.tr('days ago', '일 전')})'),
                        Text('${lang.tr('Treatment Focus', '치료 부위')}: ${visit.previousTreatmentArea}'),
                        const SizedBox(height: 10),
                        Text(
                          lang.tr('Session Note', '세션 메모'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(visit.previousSessionNote),
                        const SizedBox(height: 12),
                        Text(
                          lang.tr('Question / Answer Snapshot', '질문 / 답변 요약'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (visit.qaList.isEmpty)
                          Text(lang.tr('No intake answers were saved for this visit.', '이 방문에는 저장된 문진 답변이 없습니다.'))
                        else
                          ...visit.qaList.map(
                            (qa) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '[${qa.category}] ${qa.question}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(qa.answer),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _HistorySummaryChip extends StatelessWidget {
  const _HistorySummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
