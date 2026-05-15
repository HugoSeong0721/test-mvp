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

  Future<void> _showSavedPractitionerAccounts() async {
    final lang = AppLanguageController.instance;
    final accounts = await PractitionerSessionService.localAccountSummaries();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('Saved practitioner IDs', '저장된 침술사 아이디')),
        content: SizedBox(
          width: 420,
          child: accounts.isEmpty
              ? Text(lang.tr('No saved account.', '저장된 계정 없음'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account.loginId),
                      subtitle: Text(
                        '${account.displayName}${account.clinicId == null ? '' : ' · ${account.clinicId}'}',
                      ),
                      onTap: () {
                        _idController.text = account.loginId;
                        Navigator.pop(context);
                        setState(() => _isPractitionerRegisterMode = false);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.tr('Close', '닫기')),
          ),
        ],
      ),
    );
  }

  Future<void> _showPractitionerPasswordResetDialog() async {
    final lang = AppLanguageController.instance;
    final idController = TextEditingController(text: _idController.text.trim());
    final passwordController = TextEditingController();
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                lang.tr('Reset practitioner password', '침술사 비밀번호 재설정'),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: lang.tr('Login ID', '로그인 아이디'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: lang.tr('New password', '새 비밀번호'),
                        helperText: lang.tr(
                          'Local browser accounts only',
                          '이 브라우저 로컬 계정만 가능',
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBanner(context, error!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.tr('Cancel', '취소')),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await PractitionerSessionService.resetLocalPassword(
                        loginId: idController.text.trim(),
                        newPassword: passwordController.text.trim(),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      _idController.text = idController.text.trim();
                      _passwordController.clear();
                      Navigator.pop(context);
                      _showMessage(
                        lang.tr(
                          'Local practitioner password was reset.',
                          '로컬 침술사 비밀번호를 재설정했습니다.',
                        ),
                      );
                      setState(() => _isPractitionerRegisterMode = false);
                    } on LocalPractitionerAuthException catch (e) {
                      setDialogState(
                        () => error = _friendlyPractitionerAuthMessage(e),
                      );
                    }
                  },
                  child: Text(lang.tr('Reset', '재설정')),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      idController.dispose();
      passwordController.dispose();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(String role) async {
    final lang = AppLanguageController.instance;
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    _setFormError(null);

    if (id.isEmpty || password.isEmpty) {
      _setFormError(lang.tr('Enter ID and password.', '아이디와 비밀번호 필요'));
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

  String _friendlyPractitionerAuthMessage(
    LocalPractitionerAuthException error,
  ) {
    final lang = AppLanguageController.instance;
    switch (error.code) {
      case 'invalid-login-id':
        return lang.tr('ID needs 3+ letters or numbers.', '아이디는 3자 이상');
      case 'weak-password':
        return lang.tr('Password needs 4+ characters.', '비밀번호는 4자 이상');
      case 'missing-display-name':
        return lang.tr('Enter practitioner name.', '침술사 이름 필요');
      case 'missing-clinic-name':
        return lang.tr('Enter clinic name.', '한의원 이름 필요');
      case 'login-id-already-in-use':
        return lang.tr(
          'This practitioner login ID is already being used in this browser.',
          '이 침술사 로그인 아이디는 이 브라우저에서 이미 사용 중입니다.',
        );
      case 'user-not-found':
        return lang.tr('No saved account. Create first.', '저장된 계정 없음');
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
                              label: Text(lang.tr('Create', '가입')),
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
                            labelText: lang.tr('Practitioner name', '침술사 이름'),
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
                            prefixIcon: const Icon(
                              Icons.local_hospital_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                              : lang.tr('Enter your ID', '아이디를 입력해주세요'),
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
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
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
                      if (isPractitioner)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _showSavedPractitionerAccounts,
                              child: Text(lang.tr('Find ID', '아이디 찾기')),
                            ),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _showPractitionerPasswordResetDialog,
                              child: Text(lang.tr('Reset', '재설정')),
                            ),
                          ],
                        ),
                      if (isPractitioner) const SizedBox(height: 4),
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
}
