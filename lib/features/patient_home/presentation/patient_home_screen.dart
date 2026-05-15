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
  Timer? _loadTimeoutTimer;
  PatientProfile? _sessionBackedProfile;
  PatientSession? _activeSession;
  bool _sessionResolved = false;
  bool _loadTimedOut = false;
  bool _loadedRouteArgs = false;
  Object? _loadError;
  String? _linkedClinicId;
  String? _lastClinicSyncKey;
  String? _lastAutoPromptedClinicPatientId;

  PatientProfile get _currentProfile {
    if (_sessionBackedProfile != null) {
      return _sessionBackedProfile!;
    }
    final session = _activeSession;
    if (session != null) {
      // Always synthesize a profile from session info immediately so the
      // screen renders without waiting for Firestore. Firestore data
      // populates _sessionBackedProfile in the background when it arrives.
      return PatientProfile(
        id: session.id,
        name: session.displayName.isNotEmpty
            ? session.displayName
            : (session.email.isNotEmpty
                  ? session.email.split('@').first
                  : 'New Patient'),
        phone: '',
        email: session.email,
        birthYear: 1990,
        sex: 'Not entered',
        ethnicity: 'Not entered',
        memo: '',
      );
    }
    return _store.currentPatientProfile;
  }

  List<ScheduledVisit> get _history =>
      _store.activeClinicForPatient(_currentProfile.id) == null
      ? const []
      : _store.historyForPatient(
          _currentProfile.id,
          clinicId: _store.activeClinicForPatient(_currentProfile.id)!.id,
        );

  bool get _waitingForRealProfile {
    return !_sessionResolved;
  }

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
    unawaited(_initializeProfile());
  }

  Future<void> _initializeProfile() async {
    final session =
        BetaSessionService.currentSession ??
        await BetaSessionService.currentSessionAsync();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeSession = session;
      _sessionResolved = true;
      _loadTimedOut = false;
      _loadError = null;
    });
    _loadTimeoutTimer?.cancel();

    if (session == null) {
      setState(() => _sessionBackedProfile = null);
      return;
    }

    try {
      final localProfile = await PatientProfileService.loadLocalProfile(
        session.id,
      );
      if (mounted && localProfile != null) {
        setState(() {
          _sessionBackedProfile = localProfile;
        });
      }
    } catch (_) {}

    unawaited(
      PatientProfileService.ensureProfileForSession(session)
          .timeout(_profileLoadTimeout)
          .then((_) async {
            final refreshed = await PatientProfileService.loadLocalProfile(
              session.id,
            );
            if (!mounted || refreshed == null) {
              return;
            }
            setState(() {
              _sessionBackedProfile = refreshed;
              _loadError = null;
            });
          })
          .catchError((error) {
            if (!mounted) {
              return;
            }
            setState(() => _loadError = error);
          }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedRouteArgs) {
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final clinicId = args['clinicId']?.toString().trim();
      if (clinicId != null && clinicId.isNotEmpty) {
        _linkedClinicId = clinicId;
      }
    }
    _loadedRouteArgs = true;
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
    unawaited(_initializeProfile());
  }

  Future<void> _syncClinicContextForProfile(PatientProfile profile) async {
    await _store.applyPreferredClinicForPatient(
      patientId: profile.id,
      linkedClinicId: _linkedClinicId,
    );
    _linkedClinicId = null;

    if (!_store.clinicStateReady) {
      return;
    }

    if (_store.activeClinicForPatient(profile.id) == null &&
        _lastAutoPromptedClinicPatientId != profile.id &&
        mounted) {
      _lastAutoPromptedClinicPatientId = profile.id;
      await _openClinicPicker(autoPrompt: true);
    }
  }

  void _ensureClinicContext(PatientProfile profile) {
    final syncKey =
        '${profile.id}|${_linkedClinicId ?? ''}|${_store.clinicStateReady}';
    if (_lastClinicSyncKey == syncKey) {
      return;
    }
    _lastClinicSyncKey = syncKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_syncClinicContextForProfile(profile));
    });
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
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

  Future<void> _openClinicPicker({bool autoPrompt = false}) async {
    final lang = AppLanguageController.instance;
    final patientId = _currentProfile.id;
    final searchController = TextEditingController();
    final requestClinicNameController = TextEditingController();
    final requestPractitionerController = TextEditingController();
    final requestLocationController = TextEditingController();
    final requestNoteController = TextEditingController();
    String query = '';
    bool isSendingClinicOpenRequest = false;
    String? sentClinicOpenRequestName;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentClinic = _store.activeClinicForPatient(patientId);
            final defaultClinicId = _store.defaultClinicIdForPatient(patientId);
            final results = _store.searchClinics(query);
            final canRequestClinic =
                requestClinicNameController.text.trim().isNotEmpty &&
                !isSendingClinicOpenRequest;
            if (requestClinicNameController.text.trim().isEmpty &&
                query.trim().isNotEmpty) {
              requestClinicNameController.text = query.trim();
            }

            return AlertDialog(
              title: Text(
                lang.tr('Choose your acupuncture center', '한의원을 선택해주세요'),
              ),
              content: SizedBox(
                width: 720,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: lang.tr('Search clinic', '한의원 검색'),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => query = value.trim()),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 420,
                      child: SingleChildScrollView(
                        child: Column(
                          children:
                              results.map((clinic) {
                                final isCurrent =
                                    currentClinic?.id == clinic.id;
                                final isDefault = defaultClinicId == clinic.id;
                                final membershipRequest = _store
                                    .membershipRequestForPatientClinic(
                                      patientId: patientId,
                                      clinicId: clinic.id,
                                    );
                                final isPendingApproval =
                                    membershipRequest?.status == 'pending';
                                final isDeclined =
                                    membershipRequest?.status == 'declined';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? AppTheme.mint.withValues(alpha: 0.2)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppTheme.copper.withValues(
                                              alpha: 0.52,
                                            )
                                          : AppTheme.border.withValues(
                                              alpha: 0.45,
                                            ),
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
                                              clinic.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          if (isCurrent)
                                            _buildClinicStatusChip(
                                              context,
                                              lang.tr('Current', '현재 선택'),
                                            ),
                                          if (isPendingApproval) ...[
                                            const SizedBox(width: 8),
                                            _buildClinicStatusChip(
                                              context,
                                              lang.tr(
                                                'Pending approval',
                                                '승인 대기',
                                              ),
                                              accent: AppTheme.copper,
                                            ),
                                          ],
                                          if (isDefault) ...[
                                            const SizedBox(width: 8),
                                            _buildClinicStatusChip(
                                              context,
                                              lang.tr('Default', '기본 한의원'),
                                              accent: AppTheme.copper,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${clinic.practitionerName}${clinic.location.isEmpty ? '' : ' · ${clinic.location}'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.ink.withValues(
                                                alpha: 0.72,
                                              ),
                                            ),
                                      ),
                                      if (clinic.patientNote
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          clinic.patientNote,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(height: 1.5),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilledButton.tonalIcon(
                                            onPressed:
                                                isCurrent || isPendingApproval
                                                ? null
                                                : () async {
                                                    await _store
                                                        .selectClinicForPatient(
                                                          patientId: patientId,
                                                          clinicId: clinic.id,
                                                        );
                                                    await _store
                                                        .continueWithClinicForPatient(
                                                          patientId: patientId,
                                                          clinicId: clinic.id,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    setDialogState(() {});
                                                    ScaffoldMessenger.of(
                                                      this.context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          lang.tr(
                                                            'Request sent.',
                                                            '요청 완료',
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            icon: const Icon(
                                              Icons.outgoing_mail,
                                            ),
                                            label: Text(
                                              isDeclined
                                                  ? lang.tr('Again', '다시')
                                                  : lang.tr('Join', '가입'),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed:
                                                isCurrent || isPendingApproval
                                                ? () async {
                                                    await _store
                                                        .continueWithClinicForPatient(
                                                          patientId: patientId,
                                                          clinicId: clinic.id,
                                                        );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    Navigator.pop(context);
                                                  }
                                                : null,
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                            ),
                                            label: Text(
                                              lang.tr(
                                                'Continue here',
                                                '여기로 계속하기',
                                              ),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: isDefault || !isCurrent
                                                ? null
                                                : () async {
                                                    await _store
                                                        .setDefaultClinicForPatient(
                                                          patientId: patientId,
                                                          clinicId: clinic.id,
                                                        );
                                                    if (!mounted) {
                                                      return;
                                                    }
                                                    setDialogState(() {});
                                                    ScaffoldMessenger.of(
                                                      this.context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          lang.tr(
                                                            'Default set.',
                                                            '기본값 저장됨',
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            icon: const Icon(
                                              Icons.push_pin_outlined,
                                            ),
                                            label: Text(
                                              lang.tr('Default', '기본값'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList()..add(
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.blush.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppTheme.copper.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.tr('Can’t find it?', '없나요?'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: requestClinicNameController,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          labelText: lang.tr(
                                            'Clinic name',
                                            '한의원 이름',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller:
                                            requestPractitionerController,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          labelText: lang.tr(
                                            'Practitioner name',
                                            '침술사 이름',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: requestLocationController,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          labelText: lang.tr('Location', '위치'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: requestNoteController,
                                        onChanged: (_) => setDialogState(() {}),
                                        minLines: 1,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          labelText: lang.tr(
                                            'Optional note',
                                            '추가 메모',
                                          ),
                                        ),
                                      ),
                                      if (sentClinicOpenRequestName !=
                                          null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.mint.withValues(
                                              alpha: 0.42,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.pine.withValues(
                                                alpha: 0.28,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            lang.tr(
                                              '$sentClinicOpenRequestName request sent.',
                                              '$sentClinicOpenRequestName 요청 완료',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.pine,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: canRequestClinic
                                            ? () async {
                                                final requestedName =
                                                    requestClinicNameController
                                                        .text
                                                        .trim();
                                                setDialogState(() {
                                                  isSendingClinicOpenRequest =
                                                      true;
                                                  sentClinicOpenRequestName =
                                                      null;
                                                });
                                                final didSave = await _store
                                                    .requestClinicOpen(
                                                      patient: _currentProfile,
                                                      clinicName: requestedName,
                                                      practitionerName:
                                                          requestPractitionerController
                                                              .text,
                                                      location:
                                                          requestLocationController
                                                              .text,
                                                      note:
                                                          requestNoteController
                                                              .text,
                                                    );
                                                if (!mounted) {
                                                  return;
                                                }
                                                setDialogState(() {
                                                  isSendingClinicOpenRequest =
                                                      false;
                                                  sentClinicOpenRequestName =
                                                      didSave
                                                      ? requestedName
                                                      : null;
                                                });
                                                final message = didSave
                                                    ? lang.tr(
                                                        'Request sent.',
                                                        '요청 완료',
                                                      )
                                                    : lang.tr(
                                                        'Enter clinic name.',
                                                        '한의원 이름 필요',
                                                      );
                                                ScaffoldMessenger.of(
                                                  this.context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(message),
                                                  ),
                                                );
                                                if (didSave) {
                                                  requestClinicNameController
                                                      .clear();
                                                  requestPractitionerController
                                                      .clear();
                                                  requestLocationController
                                                      .clear();
                                                  requestNoteController.clear();
                                                }
                                              }
                                            : null,
                                        icon: Icon(
                                          isSendingClinicOpenRequest
                                              ? Icons.hourglass_top
                                              : Icons.outgoing_mail,
                                        ),
                                        label: Text(lang.tr('Request', '신청')),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    autoPrompt
                        ? lang.tr('Choose later', '나중에 선택')
                        : lang.tr('Close', '닫기'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    requestClinicNameController.dispose();
    requestPractitionerController.dispose();
    requestLocationController.dispose();
    requestNoteController.dispose();
  }

  Widget _buildClinicStatusChip(
    BuildContext context,
    String label, {
    Color accent = AppTheme.pine,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildClinicSelectionPanel(
    BuildContext context, {
    required PatientProfile profile,
  }) {
    final lang = AppLanguageController.instance;
    final activeClinic = _store.activeClinicForPatient(profile.id);
    final defaultClinic = _store.defaultClinicIdForPatient(profile.id) == null
        ? null
        : _store.clinicById(_store.defaultClinicIdForPatient(profile.id)!);

    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('Clinic', '한의원'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openClinicPicker(),
                    icon: const Icon(Icons.search),
                    label: Text(
                      activeClinic == null
                          ? lang.tr('Search clinic', '한의원 검색')
                          : lang.tr('Change clinic', '한의원 변경'),
                    ),
                  ),
                  if (activeClinic != null)
                    OutlinedButton.icon(
                      onPressed: defaultClinic?.id == activeClinic.id
                          ? null
                          : () async {
                              await _store.setDefaultClinicForPatient(
                                patientId: profile.id,
                                clinicId: activeClinic.id,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    lang.tr(
                                      '${activeClinic.name} is now your default clinic.',
                                      '${activeClinic.name} 이(가) 기본 한의원으로 저장되었습니다.',
                                    ),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.push_pin_outlined),
                      label: Text(
                        defaultClinic?.id == activeClinic.id
                            ? lang.tr('Default saved', '기본 저장됨')
                            : lang.tr('Set as default', '기본 한의원 저장'),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeClinic == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                lang.tr('No clinic selected', '선택된 한의원 없음'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.52),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeClinic.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${activeClinic.practitionerName}${activeClinic.location.isEmpty ? '' : ' · ${activeClinic.location}'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.72),
                    ),
                  ),
                  if (activeClinic.patientNote.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      activeClinic.patientNote,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                  if (defaultClinic != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      defaultClinic.id == activeClinic.id
                          ? lang.tr('Default clinic', '기본 한의원')
                          : lang.tr(
                              'Default: ${defaultClinic.name}',
                              '기본: ${defaultClinic.name}',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.copper,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
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
    final activeClinic = _store.activeClinicForPatient(_currentProfile.id);
    if (activeClinic == null) {
      await _openClinicPicker();
      return;
    }
    final availableSlots = _store.availableSlotsForPatient(
      _currentProfile.id,
      clinicId: activeClinic.id,
    );
    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.tr('No open slots.', '예약 가능 슬롯 없음'))),
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
                        'Choose date and time.',
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
                      clinicId: activeClinic.id,
                      date: selectedDate,
                      time: selectedTime,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang.tr(
                            'Request sent.',
                            '${_formatVisitSlot(selectedDate, selectedTime)} 예약 신청을 보냈습니다. 침술사가 추가 정보가 필요하면 문진 폼이 포털에 표시됩니다.',
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text(lang.tr('Request', '신청')),
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
      animation: Listenable.merge([AppLanguageController.instance, _store]),
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
        _ensureClinicContext(profile);
        final history = _history;
        final latestVisit = history.isNotEmpty ? history.first.visit : null;
        final activeClinic = _store.activeClinicForPatient(profile.id);
        final activeClinicId = activeClinic?.id;
        bool matchesActiveClinic(Map<String, dynamic> data) {
          if (activeClinicId == null || activeClinicId.isEmpty) {
            return false;
          }
          final docClinicId = (data['clinicId'] ?? '').toString();
          return docClinicId == activeClinicId;
        }

        final upcomingVisits = activeClinicId == null
            ? <ScheduledVisit>[]
            : (_store.upcomingVisits(DateTime.now(), clinicId: activeClinicId)
                ..retainWhere((visit) => visit.profile.id == profile.id));
        final appointmentRequests = activeClinicId == null
            ? const <AppointmentRequest>[]
            : _store.requestsForPatient(profile.id, clinicId: activeClinicId);
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
              tooltip: lang.tr('Search clinic', '한의원 검색'),
              onPressed: () => _openClinicPicker(),
              icon: const Icon(Icons.local_hospital_outlined),
            ),
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
              final scopedRequestDocs = requestDocs
                  .where((doc) => matchesActiveClinic(doc.data()))
                  .toList();

              final pendingRequests = scopedRequestDocs
                  .where(
                    (doc) => (doc.data()['status'] ?? 'pending') == 'pending',
                  )
                  .toList();
              final latestRequest = scopedRequestDocs.isNotEmpty
                  ? scopedRequestDocs.first.data()
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
                  final scopedSubmissionDocs = submissionDocs
                      .where((doc) => matchesActiveClinic(doc.data()))
                      .toList();

                  final latestSubmission = scopedSubmissionDocs.isNotEmpty
                      ? scopedSubmissionDocs.first.data()
                      : null;
                  final needsRequestsFirst = pendingRequests.isNotEmpty;
                  final needsProfileFirst = !profile.hasRequiredAlertInfo;
                  final needsIntakeFirst = latestSubmission == null;
                  final needsAppointmentFirst =
                      nextVisit == null && pendingAppointmentRequests.isEmpty;

                  late final String nextStepTitle;
                  late final String nextStepButton;
                  late final VoidCallback nextStepAction;

                  if (needsRequestsFirst) {
                    nextStepTitle = lang.tr('Reply needed', '먼저 침술사 요청에 답하기');
                    nextStepButton = lang.tr('Requests', '요청함');
                    nextStepAction = () => Navigator.pushNamed(
                      context,
                      PatientRequestsScreen.routeName,
                    );
                  } else if (needsProfileFirst) {
                    nextStepTitle = lang.tr('Contact missing', '먼저 연락처 입력하기');
                    nextStepButton = lang.tr('Profile', '프로필');
                    nextStepAction = _openProfileDialog;
                  } else if (needsIntakeFirst) {
                    nextStepTitle = lang.tr('Intake due', '오늘 상태 문진 보내기');
                    nextStepButton = lang.tr('Intake', '문진');
                    nextStepAction = () => Navigator.pushNamed(
                      context,
                      PatientIntakeScreen.routeName,
                    );
                  } else if (needsAppointmentFirst) {
                    nextStepTitle = lang.tr('Book next visit', '다음 예약 신청하기');
                    nextStepButton = lang.tr('Book', '예약');
                    nextStepAction = _openAppointmentDialog;
                  } else {
                    nextStepTitle = lang.tr('All set', '지금은 할 일을 거의 마쳤어요');
                    nextStepButton = lang.tr('History', '기록');
                    nextStepAction = () => Navigator.pushNamed(
                      context,
                      VisitHistoryScreen.routeName,
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildClinicSelectionPanel(context, profile: profile),
                      const SizedBox(height: 16),
                      AppPanel(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Today', 'Today'),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.58),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              profile.name,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(color: AppTheme.ink),
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
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
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
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.verified_user_outlined,
                                  label: lang.tr('Profile', '프로필'),
                                  value: profile.hasRequiredAlertInfo
                                      ? lang.tr('Ready', '준비됨')
                                      : lang.tr('Needs update', '업데이트 필요'),
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.mint.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.border.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lang.tr('Next', '다음'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(color: AppTheme.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    nextStepTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppTheme.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: nextStepAction,
                                        icon: const Icon(Icons.arrow_forward),
                                        label: Text(nextStepButton),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          PatientRequestsScreen.routeName,
                                        ),
                                        icon: const Icon(
                                          Icons.mark_email_unread_outlined,
                                        ),
                                        label: Text(
                                          lang.tr('Requests', '요청함'),
                                          style: const TextStyle(
                                            color: AppTheme.ink,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppTheme.border,
                                          ),
                                          foregroundColor: AppTheme.ink,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          PatientIntakeScreen.routeName,
                                        ),
                                        icon: const Icon(Icons.edit_note),
                                        label: Text(
                                          lang.tr('Intake', '문진'),
                                          style: const TextStyle(
                                            color: AppTheme.ink,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppTheme.border,
                                          ),
                                          foregroundColor: AppTheme.ink,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _openAppointmentDialog,
                                        icon: const Icon(
                                          Icons.event_available_outlined,
                                        ),
                                        label: Text(
                                          lang.tr('Book', '예약'),
                                          style: const TextStyle(
                                            color: AppTheme.ink,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppTheme.border,
                                          ),
                                          foregroundColor: AppTheme.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (latestRequest != null) const SizedBox(height: 16),
                      if (latestRequest != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr('Latest request', '최근 답변 요청'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    AppMetricChip(
                                      icon: Icons.flag_outlined,
                                      label: lang.tr('Status', '상태'),
                                      value:
                                          (latestRequest['status'] ?? 'pending')
                                              .toString(),
                                      backgroundColor: AppTheme.surface,
                                    ),
                                    AppMetricChip(
                                      icon: Icons.quiz_outlined,
                                      label: lang.tr('Questions', '질문'),
                                      value:
                                          '${((latestRequest['selectedQuestions'] as List?) ?? const []).length}',
                                      backgroundColor: AppTheme.surface,
                                    ),
                                    AppMetricChip(
                                      icon: Icons.schedule_outlined,
                                      label: lang.tr('Requested', '요청'),
                                      value: _formatTimestamp(
                                        latestRequest['requestedAt']
                                            as Timestamp?,
                                      ),
                                      backgroundColor: AppTheme.surface,
                                    ),
                                  ],
                                ),
                                if (((latestRequest['note'] ?? '') as String)
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    '${lang.tr('Note', '메모')}: ${latestRequest['note']}',
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
                                      lang.tr('Appointments', '예약 신청 현황'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                    label: Text(lang.tr('Book', '예약')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (appointmentRequests.isEmpty)
                                Text(lang.tr('No requests', '신청 없음'))
                              else
                                ...appointmentRequests.map((request) {
                                  final canCancel =
                                      request.status ==
                                      AppointmentRequestStatus.pending;
                                  final statusText = switch (request.status) {
                                    AppointmentRequestStatus.pending => lang.tr(
                                      'Pending',
                                      '대기',
                                    ),
                                    AppointmentRequestStatus.confirmed =>
                                      lang.tr('Confirmed', '확정'),
                                    AppointmentRequestStatus.declined =>
                                      lang.tr('Declined', '거절'),
                                    AppointmentRequestStatus
                                        .canceledByPatient =>
                                      lang.tr('Canceled', '취소'),
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
                                            '${lang.tr('Requested', '신청')}: '
                                            '${_formatDateTime(request.requestedAt)}',
                                          ),
                                          if (request.reviewedAt != null)
                                            Text(
                                              '${lang.tr('Reviewed At', '확인 시각')}: '
                                              '${_formatDateTime(request.reviewedAt!)}',
                                            ),
                                          const SizedBox(height: 6),
                                          if (canCancel) ...[
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
                                                lang.tr('Cancel', '취소'),
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
                                      lang.tr('Confirmed', '확정'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _openAppointmentDialog,
                                    icon: const Icon(Icons.add),
                                    label: Text(lang.tr('Request', '다른 시간 신청')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (upcomingVisits.isEmpty)
                                Text(lang.tr('No confirmed visits', '확정 예약 없음'))
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
                                          Text(
                                            '${lang.tr('Intake', '문진')}: ${visit.intakeStatus.label}',
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
                                      lang.tr('History', '기록'),
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
                                    child: Text(lang.tr('History', '기록')),
                                  ),
                                ],
                              ),
                              if (latestVisit == null)
                                Text(lang.tr('No visits', '방문 없음'))
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
                                Text(lang.tr('No submissions', '제출 없음'))
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
                  lang.tr('Could not load your profile.', '프로필을 불러오지 못했습니다.'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  lang.tr(
                    'Check network or VPN, then retry.',
                    '네트워크 또는 VPN이 Firebase 호출을 막고 있는 경우가 많습니다. VPN을 끄고 연결을 확인한 뒤 다시 시도해주세요.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
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
                      label: Text(lang.tr('Entry', '시작')),
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
