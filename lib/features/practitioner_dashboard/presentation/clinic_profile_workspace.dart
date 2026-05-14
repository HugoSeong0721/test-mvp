import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/practitioner_session_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';

class ClinicProfileWorkspace extends StatefulWidget {
  const ClinicProfileWorkspace({super.key});

  @override
  State<ClinicProfileWorkspace> createState() => _ClinicProfileWorkspaceState();
}

class _ClinicProfileWorkspaceState extends State<ClinicProfileWorkspace> {
  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _practitionerController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchKeywordsController =
      TextEditingController();
  final TextEditingController _patientNoteController = TextEditingController();

  StreamSubscription<PractitionerSession?>? _sessionSubscription;
  PractitionerSession? _activeSession;
  String? _selectedClinicId;
  bool _creatingNewClinic = false;

  @override
  void initState() {
    super.initState();
    _sessionSubscription = PractitionerSessionService.watchSession().listen((
      session,
    ) {
      if (!mounted) {
        _activeSession = session;
        return;
      }

      setState(() {
        _activeSession = session;
        final clinicId = session?.clinicId;
        if (clinicId != null) {
          final clinic = _store.clinicById(clinicId);
          if (clinic != null) {
            _loadClinic(clinic);
          }
        } else if (session != null && !_creatingNewClinic) {
          _practitionerController.text = session.displayName;
        }
      });
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _nameController.dispose();
    _practitionerController.dispose();
    _locationController.dispose();
    _searchKeywordsController.dispose();
    _patientNoteController.dispose();
    super.dispose();
  }

  void _loadClinic(ClinicCenter clinic) {
    _selectedClinicId = clinic.id;
    _creatingNewClinic = false;
    _nameController.text = clinic.name;
    _practitionerController.text = clinic.practitionerName;
    _locationController.text = clinic.location;
    _searchKeywordsController.text = clinic.searchKeywords;
    _patientNoteController.text = clinic.patientNote;
  }

  void _startNewClinicDraft() {
    final session = _activeSession;
    setState(() {
      _selectedClinicId = null;
      _creatingNewClinic = true;
      _nameController.clear();
      _practitionerController.text = session?.displayName ?? '';
      _locationController.clear();
      _searchKeywordsController.clear();
      _patientNoteController.clear();
    });
  }

  String _draftClinicId() {
    final existingId = _selectedClinicId;
    if (existingId != null && existingId.trim().isNotEmpty) {
      return existingId;
    }
    return _store.suggestClinicId(_nameController.text.trim());
  }

  String _shareLink() {
    return _store.buildPatientPortalShareLink(
      _draftClinicId(),
      currentUrl: Uri.base.toString(),
    );
  }

  Future<void> _saveClinic() async {
    final lang = AppLanguageController.instance;
    final session = _activeSession;
    final clinicName = _nameController.text.trim();
    final practitionerName = _practitionerController.text.trim();
    final location = _locationController.text.trim();
    final searchKeywords = _searchKeywordsController.text.trim();
    final patientNote = _patientNoteController.text.trim();

    if (clinicName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Please enter the clinic name first.',
              '한의원 이름을 먼저 입력해주세요.',
            ),
          ),
        ),
      );
      return;
    }

    final clinic = ClinicCenter(
      id: _draftClinicId(),
      name: clinicName,
      practitionerName: practitionerName.isEmpty
          ? (session?.displayName.isNotEmpty == true
                ? session!.displayName
                : 'Practitioner')
          : practitionerName,
      location: location,
      patientNote: patientNote,
      searchKeywords: searchKeywords,
    );

    await _store.saveClinicCenter(clinic);
    if (session != null) {
      await _store.setClinicForPractitioner(
        practitionerId: session.id,
        clinicId: clinic.id,
      );
      await PractitionerSessionService.updateCurrentPractitioner(
        displayName: clinic.practitionerName,
        clinicId: clinic.id,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _loadClinic(clinic));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.tr(
            'Clinic profile saved for patient search and link sharing.',
            '환자 검색과 링크 공유에 쓰이는 한의원 정보가 저장되었습니다.',
          ),
        ),
      ),
    );
  }

  Future<void> _copyShareLink() async {
    final lang = AppLanguageController.instance;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Enter the clinic name first so the link can be created.',
              '링크를 만들기 전에 한의원 이름을 먼저 입력해주세요.',
            ),
          ),
        ),
      );
      return;
    }

    final link = _shareLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.tr('Patient access link copied.', '환자 접속 링크를 복사했습니다.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store, AppLanguageController.instance]),
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final theme = Theme.of(context);
        final clinics = _store.clinicCenters;
        final session = _activeSession;
        final sessionClinic = session == null
            ? null
            : _store.clinicForPractitioner(session.id);

        if (sessionClinic != null &&
            !_creatingNewClinic &&
            (_selectedClinicId == null ||
                _selectedClinicId != sessionClinic.id)) {
          _loadClinic(sessionClinic);
        } else if (!_creatingNewClinic &&
            (_selectedClinicId == null ||
                _store.clinicById(_selectedClinicId!) == null) &&
            clinics.isNotEmpty) {
          _loadClinic(clinics.first);
        }

        return AppPanel(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final currentClinic = _selectedClinicId == null
                  ? null
                  : _store.clinicById(_selectedClinicId!);
              final shareLink = _shareLink();

              final form = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang.tr('Clinic profile builder', '한의원 정보 설정'),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _startNewClinicDraft,
                        icon: const Icon(Icons.add_business_outlined),
                        label: Text(lang.tr('Add clinic', '한의원 추가')),
                      ),
                    ],
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      lang.tr(
                        'Signed in as ${session.displayName.isEmpty ? session.loginId : session.displayName}',
                        '${session.displayName.isEmpty ? session.loginId : session.displayName} 계정으로 로그인됨',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.copper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    lang.tr(
                      'Patients search clinics after login, choose one as their center, and can arrive through the link you generate here. The clinic name saved here is what patients will see.',
                      '환자는 로그인 후 여기 등록된 한의원을 검색하고 선택합니다. 이 화면에서 만든 링크로 바로 들어오게 할 수도 있고, 여기 저장한 한의원 이름이 환자 화면에 그대로 보입니다.',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue:
                        currentClinic?.id ??
                        (_creatingNewClinic || clinics.isEmpty
                            ? null
                            : clinics.first.id),
                    decoration: InputDecoration(
                      labelText: lang.tr('Clinic to edit', '수정할 한의원'),
                    ),
                    items: clinics
                        .map(
                          (clinic) => DropdownMenuItem<String>(
                            value: clinic.id,
                            child: Text(
                              '${clinic.name} · ${clinic.location.isEmpty ? clinic.practitionerName : clinic.location}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: clinics.isEmpty
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            final clinic = _store.clinicById(value);
                            if (clinic == null) {
                              return;
                            }
                            setState(() => _loadClinic(clinic));
                          },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _nameController,
                    label: lang.tr('Clinic name', '한의원 이름'),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _practitionerController,
                    label: lang.tr('Practitioner display name', '침술사 표시 이름'),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _locationController,
                    label: lang.tr('Location / search label', '위치 / 검색 라벨'),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _searchKeywordsController,
                    label: lang.tr('Search keywords', '검색 키워드'),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _patientNoteController,
                    label: lang.tr('Patient-facing note', '환자에게 보이는 메모'),
                    minLines: 4,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _saveClinic,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(lang.tr('Save clinic info', '한의원 정보 저장')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyShareLink,
                        icon: const Icon(Icons.link_outlined),
                        label: Text(lang.tr('Copy link', '링크 복사')),
                      ),
                    ],
                  ),
                ],
              );

              final preview = AppPanel(
                padding: const EdgeInsets.all(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    AppTheme.blush.withValues(alpha: 0.54),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.tr('Patient view preview', '환자 화면 미리보기'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty
                                ? lang.tr('Clinic name preview', '한의원 이름 미리보기')
                                : _nameController.text.trim(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _practitionerController.text.trim().isEmpty
                                ? lang.tr(
                                    'Practitioner name appears here',
                                    '침술사 이름이 여기에 보입니다',
                                  )
                                : _practitionerController.text.trim(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.72),
                            ),
                          ),
                          if (_locationController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: AppTheme.copper,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(_locationController.text.trim()),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            _patientNoteController.text.trim().isEmpty
                                ? lang.tr(
                                    'Add a short memo about what patients should know before choosing this clinic.',
                                    '환자가 이 한의원을 선택하기 전에 알아야 할 메모를 짧게 써둘 수 있습니다.',
                                  )
                                : _patientNoteController.text.trim(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      lang.tr('Generated patient link', '생성된 환자 링크'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      shareLink,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.copper,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      lang.tr(
                        'When a patient opens this link, the portal will arrive with this clinic already selected.',
                        '환자가 이 링크를 열면 이 한의원이 미리 선택된 상태로 포털에 들어오게 됩니다.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.68),
                      ),
                    ),
                    if (currentClinic != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        lang.tr('Current clinic id', '현재 한의원 ID'),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(currentClinic.id),
                    ],
                  ],
                ),
              );

              if (!wide) {
                return ListView(
                  children: [form, const SizedBox(height: 16), preview],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 11, child: form),
                  const SizedBox(width: 18),
                  Expanded(flex: 9, child: preview),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }
}
