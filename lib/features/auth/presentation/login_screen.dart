import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../home/presentation/role_home_screen.dart';
import '../../patient_home/presentation/patient_home_screen.dart';
import '../../practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _sharedTestId = '123';
  static const _sharedTestPassword = '123';
  static const _hugoId = 'hugo';
  static const _hugoPassword = 'hugo';

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _applyCredentials(String id, String password) {
    _idController.text = id;
    _passwordController.text = password;
  }

  void _submit(String role) {
    final lang = AppLanguageController.instance;
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    final isPractitionerLogin =
        role == 'practitioner' &&
        id == _sharedTestId &&
        password == _sharedTestPassword;

    final isPatientDefaultLogin =
        role == 'patient' &&
        id == _sharedTestId &&
        password == _sharedTestPassword;

    final isPatientHugoLogin =
        role == 'patient' && id == _hugoId && password == _hugoPassword;

    if (!isPractitionerLogin && !isPatientDefaultLogin && !isPatientHugoLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'The ID or password is incorrect.',
              '아이디 또는 비밀번호가 올바르지 않습니다.',
            ),
          ),
        ),
      );
      return;
    }

    if (isPractitionerLogin) {
      Navigator.pushReplacementNamed(
        context,
        PractitionerDashboardScreen.routeName,
      );
      return;
    }

    if (isPatientHugoLogin) {
      ClinicDataStore.instance.setCurrentPatientProfile('hugo_demo');
    } else {
      ClinicDataStore.instance.setCurrentPatientProfile('jane_kim');
    }

    Navigator.pushReplacementNamed(context, PatientHomeScreen.routeName);
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
        ? lang.tr('Demo account: 123 / 123', '데모 계정: 123 / 123')
        : lang.tr(
            'Demo accounts: 123 / 123 or hugo / hugo',
            '데모 계정: 123 / 123 또는 hugo / hugo',
          );

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
                constraints: const BoxConstraints(maxWidth: 420),
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
                      const SizedBox(height: 22),
                      TextField(
                        controller: _idController,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _submit(role),
                        decoration: InputDecoration(
                          labelText: lang.tr('ID', '아이디'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(role),
                        decoration: InputDecoration(
                          labelText: lang.tr('Password', '비밀번호'),
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
                        onPressed: () => _submit(role),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        icon: const Icon(Icons.login),
                        label: Text(lang.tr('Login', '로그인')),
                      ),
                      const SizedBox(height: 14),
                      _buildDemoFillRow(
                        context,
                        isPractitioner: isPractitioner,
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

  Widget _buildDemoFillRow(
    BuildContext context, {
    required bool isPractitioner,
  }) {
    final lang = AppLanguageController.instance;
    final buttons = isPractitioner
        ? [
            OutlinedButton(
              onPressed: () =>
                  _applyCredentials(_sharedTestId, _sharedTestPassword),
              child: Text(lang.tr('Fill 123 / 123', '123 / 123 채우기')),
            ),
          ]
        : [
            OutlinedButton(
              onPressed: () =>
                  _applyCredentials(_sharedTestId, _sharedTestPassword),
              child: Text(lang.tr('Fill 123 / 123', '123 / 123 채우기')),
            ),
            OutlinedButton(
              onPressed: () => _applyCredentials(_hugoId, _hugoPassword),
              child: Text(lang.tr('Fill hugo / hugo', 'hugo / hugo 채우기')),
            ),
          ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }
}
