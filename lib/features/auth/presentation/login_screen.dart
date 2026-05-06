import 'package:flutter/material.dart';

import '../../../core/services/practitioner_session_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../home/presentation/role_home_screen.dart';
import '../../auth/presentation/patient_beta_auth_screen.dart';
import '../../practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _practitionerNameController =
      TextEditingController();
  final TextEditingController _clinicNameController = TextEditingController();

  bool _showPassword = false;
  bool _isSubmitting = false;
  bool _isPractitionerRegisterMode = false;
  bool _appliedRouteMode = false;
  String? _formError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedRouteMode) {
      return;
    }

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      final role = routeArgs['role']?.toString();
      final loginMode = routeArgs['loginMode']?.toString();
      if (role == 'practitioner' && loginMode == 'register') {
        _isPractitionerRegisterMode = true;
      }
    }
    _appliedRouteMode = true;
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _practitionerNameController.dispose();
    _clinicNameController.dispose();
    super.dispose();
  }

  void _setFormError(String? message) {
    if (!mounted) {
      return;
    }
    setState(() => _formError = message);
  }

  void _clearFormErrorOnChange() {
    if (_formError != null) {
      _setFormError(null);
    }
  }

  Future<void> _submit(String role) async {
    final lang = AppLanguageController.instance;
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    _setFormError(null);

    if (id.isEmpty || password.isEmpty) {
      _setFormError(
        lang.tr(
          'Please enter your ID and password.',
          '아이디와 비밀번호를 입력해주세요.',
        ),
      );
      return;
    }

    if (role == 'practitioner') {
      setState(() => _isSubmitting = true);
      try {
        if (_isPractitionerRegisterMode) {
          final displayName = _practitionerNameController.text.trim();
          final clinicName = _clinicNameController.text.trim();
          await PractitionerSessionService.signUpLocally(
            loginId: id,
            password: password,
            displayName: displayName,
            clinicName: clinicName,
          );
        } else {
          await PractitionerSessionService.logInLocally(
            loginId: id,
            password: password,
          );
        }

        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          PractitionerDashboardScreen.routeName,
        );
      } on LocalPractitionerAuthException catch (error) {
        _setFormError(_friendlyPractitionerAuthMessage(error));
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
      return;
    }

    Navigator.pushReplacementNamed(context, PatientBetaAuthScreen.routeName);
  }

  String _friendlyPractitionerAuthMessage(LocalPractitionerAuthException error) {
    final lang = AppLanguageController.instance;
    switch (error.code) {
      case 'invalid-login-id':
        return lang.tr(
          'Use a simple login ID with at least 3 letters or numbers.',
          '로그인 아이디는 3자 이상 영문/숫자로 입력해주세요.',
        );
      case 'weak-password':
        return lang.tr(
          'Use a password with at least 4 characters.',
          '비밀번호는 4자 이상으로 입력해주세요.',
        );
      case 'missing-display-name':
        return lang.tr(
          'Please enter the practitioner name.',
          '침술사 이름을 입력해주세요.',
        );
      case 'missing-clinic-name':
        return lang.tr(
          'Please enter the clinic name.',
          '한의원 이름을 입력해주세요.',
        );
      case 'login-id-already-in-use':
        return lang.tr(
          'This practitioner login ID is already being used in this browser.',
          '이 침술사 로그인 아이디는 이 브라우저에서 이미 사용 중입니다.',
        );
      case 'user-not-found':
        return lang.tr(
          'No saved practitioner account was found. Create an account first.',
          '저장된 침술사 계정을 찾지 못했습니다. 먼저 계정을 만들어주세요.',
        );
      case 'wrong-password':
        return lang.tr(
          'The practitioner password does not match.',
          '침술사 비밀번호가 일치하지 않습니다.',
        );
      default:
        return lang.tr(
          'The practitioner account could not be opened right now.',
          '침술사 계정을 지금 열 수 없습니다.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    String role = 'patient';
    if (routeArgs is Map) {
      role = (routeArgs['role'] as String?) ?? 'patient';
    } else if (routeArgs is String) {
      role = routeArgs;
    }

    final isPractitioner = role == 'practitioner';
    final accent = isPractitioner ? AppTheme.pine : AppTheme.copper;
    final roleLabel = isPractitioner
        ? lang.tr('Practitioner', '침술사')
        : lang.tr('Patient', '환자');
    final helperText = isPractitioner
        ? (_isPractitionerRegisterMode
              ? lang.tr(
                  'Create your own practitioner account and seed your clinic name into the patient-facing clinic list.',
                  '침술사 계정을 만들고, 환자가 보게 될 한의원 이름을 바로 등록할 수 있습니다.',
                )
              : lang.tr(
                  'Log in with a practitioner account created in this browser.',
                  '이 브라우저에서 만든 침술사 계정으로 로그인할 수 있습니다.',
                ))
        : lang.tr(
            'Patient sign-in now starts from the patient portal page.',
            '환자 로그인은 이제 환자 포털 화면에서 시작합니다.',
          );
    final submitLabel = isPractitioner && _isPractitionerRegisterMode
        ? lang.tr('Create account', '계정 만들기')
        : lang.tr('Login', '로그인');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(lang.tr('$roleLabel Login', '$roleLabel 로그인')),
        actions: const [LanguageMenuButton()],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppPanel(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.tr('$roleLabel Login', '$roleLabel 로그인'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        helperText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.66),
                        ),
                      ),
                      if (isPractitioner) ...[
                        const SizedBox(height: 18),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text(lang.tr('Login', '로그인')),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text(lang.tr('Create Account', '계정 만들기')),
                            ),
                          ],
                          selected: {_isPractitionerRegisterMode},
                          onSelectionChanged: _isSubmitting
                              ? null
                              : (selection) {
                                  setState(() {
                                    _isPractitionerRegisterMode =
                                        selection.first;
                                    _formError = null;
                                  });
                                },
                        ),
                      ],
                      if (_formError != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(context, _formError!),
                      ],
                      const SizedBox(height: 22),
                      if (isPractitioner && _isPractitionerRegisterMode) ...[
                        TextField(
                          controller: _practitionerNameController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearFormErrorOnChange(),
                          decoration: InputDecoration(
                            labelText: lang.tr(
                              'Practitioner name',
                              '침술사 이름',
                            ),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _clinicNameController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearFormErrorOnChange(),
                          decoration: InputDecoration(
                            labelText: lang.tr('Clinic name', '한의원 이름'),
                            helperText: lang.tr(
                              'This clinic name will appear in the patient clinic search right away.',
                              '이 한의원 이름은 환자 한의원 검색 목록에 바로 나타납니다.',
                            ),
                            prefixIcon: const Icon(Icons.local_hospital_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isPractitioner) ...[
                        _buildFieldHintCard(
                          context,
                          accent: accent,
                          message: _isPractitionerRegisterMode
                              ? lang.tr(
                                  'Create a login ID for this clinic. Patients do not see this ID.',
                                  '이 한의원에서 쓸 로그인 아이디를 만들어주세요. 환자에게는 보이지 않습니다.',
                                )
                              : lang.tr(
                                  'Enter the practitioner login ID you created for this clinic.',
                                  '이 한의원용으로 만든 침술사 로그인 아이디를 입력해주세요.',
                                ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _idController,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearFormErrorOnChange(),
                        onSubmitted: (_) => _submit(role),
                        decoration: InputDecoration(
                          labelText: isPractitioner
                              ? lang.tr('Login ID', '로그인 아이디')
                              : lang.tr('ID', '아이디'),
                          hintText: isPractitioner
                              ? lang.tr(
                                  'Enter your practitioner login ID',
                                  '침술사 로그인 아이디를 입력해주세요',
                                )
                              : lang.tr(
                                  'Enter your ID',
                                  '아이디를 입력해주세요',
                                ),
                          helperText: isPractitioner && _isPractitionerRegisterMode
                              ? lang.tr(
                                  'Use at least 3 letters or numbers.',
                                  '3자 이상 영문/숫자를 사용해주세요.',
                                )
                              : null,
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _clearFormErrorOnChange(),
                        onSubmitted: (_) => _submit(role),
                        decoration: InputDecoration(
                          labelText: lang.tr('Password', '비밀번호'),
                          helperText: isPractitioner && _isPractitionerRegisterMode
                              ? lang.tr(
                                  'Use at least 4 characters.',
                                  '4자 이상으로 입력해주세요.',
                                )
                              : null,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : () => _submit(role),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        icon: Icon(
                          isPractitioner && _isPractitionerRegisterMode
                              ? Icons.person_add_alt_1_outlined
                              : Icons.login,
                        ),
                        label: Text(
                          _isSubmitting
                              ? lang.tr('Working...', '처리 중...')
                              : submitLabel,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          RoleHomeScreen.routeName,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text(lang.tr('Back', '뒤로')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: errorColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: errorColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHintCard(
    BuildContext context, {
    required Color accent,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.72),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
