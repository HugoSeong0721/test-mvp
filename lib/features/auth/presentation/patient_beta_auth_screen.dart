import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/services/tester_flow_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../home/presentation/role_home_screen.dart';
import '../../patient_home/presentation/patient_home_screen.dart';

class PatientBetaAuthScreen extends StatefulWidget {
  const PatientBetaAuthScreen({super.key});

  static const routeName = '/patient-beta-auth';

  @override
  State<PatientBetaAuthScreen> createState() => _PatientBetaAuthScreenState();
}

class _PatientBetaAuthScreenState extends State<PatientBetaAuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegisterMode = true;
  bool _showPassword = false;
  bool _loading = false;
  String? _formError;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continueToPatientHome() {
    if (!mounted) {
      return;
    }
    Navigator.pushReplacementNamed(context, PatientHomeScreen.routeName);
  }

  Future<void> _signOutTester() async {
    final lang = AppLanguageController.instance;
    try {
      await PatientProfileService.signOut();
      if (!mounted) {
        return;
      }
      setState(() {});
      _showMessage(
        lang.tr(
          'Signed out from the current tester session.',
          '현재 테스터 세션에서 로그아웃했습니다.',
        ),
      );
    } catch (error) {
      _showMessage(
        lang.tr(
          'Could not sign out right now: $error',
          '지금 로그아웃하지 못했습니다: $error',
        ),
      );
    }
  }

  Future<void> _resetTesterPortalData(PatientSession session) async {
    final lang = AppLanguageController.instance;
    setState(() => _loading = true);
    try {
      await TesterFlowService.resetPortalData(patientId: session.id);
      _showMessage(
        lang.tr(
          'Tester flow data was reset.',
          '테스터 흐름 데이터가 초기화되었습니다.',
        ),
      );
    } catch (error) {
      _showMessage(
        lang.tr(
          'Could not reset tester flow data right now: $error',
          '지금은 테스터 흐름 데이터를 초기화하지 못했습니다: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    final lang = AppLanguageController.instance;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    _setFormError(null);

    if (email.isEmpty && password.isEmpty) {
      _setFormError(
        lang.tr('Please enter your email and password.', '이메일과 비밀번호를 입력해주세요.'),
      );
      return;
    }
    if (email.isEmpty) {
      _setFormError(
        lang.tr('Please enter your email.', '이메일을 입력해주세요.'),
      );
      return;
    }
    if (password.isEmpty) {
      _setFormError(
        lang.tr('Please enter your password.', '비밀번호를 입력해주세요.'),
      );
      return;
    }
    if (_isRegisterMode && password.length < 6) {
      _setFormError(
        lang.tr(
          'Password must be at least 6 characters.',
          '비밀번호는 6자 이상이어야 합니다.',
        ),
      );
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _setFormError(
        lang.tr('A name is required to sign up.', '회원가입에는 이름이 필요합니다.'),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isRegisterMode) {
        await _registerTester(name: name, email: email, password: password);
      } else {
        await _logInTester(email: email, password: password);
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, PatientHomeScreen.routeName);
    } on LocalBetaAuthException catch (error) {
      _setFormError(_friendlyLocalAuthMessage(error));
    } on FirebaseAuthException catch (error) {
      _setFormError(_friendlyAuthMessage(error));
    } catch (error) {
      _setFormError(
        lang.tr(
          'An error occurred during sign up / login: $error',
          '회원가입 또는 로그인 중 오류가 발생했습니다: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _registerTester({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      if (credential.user != null) {
        await PatientProfileService.ensureProfileForUser(
          credential.user!,
          nameHint: name,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (error.code != 'operation-not-allowed') {
        rethrow;
      }

      final session = await BetaSessionService.signUpLocally(
        name: name,
        email: email,
        password: password,
      );
      await PatientProfileService.ensureProfileForSession(
        session,
        nameHint: name,
      );
    }
  }

  Future<void> _logInTester({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await PatientProfileService.ensureProfileForUser(credential.user!);
      }
    } on FirebaseAuthException catch (error) {
      if (!_shouldTryLocalLogin(error)) {
        rethrow;
      }

      final session = await BetaSessionService.logInLocally(
        email: email,
        password: password,
      );
      await PatientProfileService.ensureProfileForSession(session);
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

  String _friendlyAuthMessage(FirebaseAuthException error) {
    final lang = AppLanguageController.instance;
    switch (error.code) {
      case 'email-already-in-use':
        return lang.tr(
          'This email is already registered. Please log in instead.',
          '이미 등록된 이메일입니다. 로그인으로 진행해주세요.',
        );
      case 'invalid-email':
        return lang.tr(
          'Please enter a valid email address.',
          '올바른 이메일 주소를 입력해주세요.',
        );
      case 'weak-password':
        return lang.tr(
          'Please use a password with at least 6 characters.',
          '비밀번호는 6자 이상으로 입력해주세요.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return lang.tr(
          'The email or password is incorrect.',
          '이메일 또는 비밀번호가 올바르지 않습니다.',
        );
      case 'operation-not-allowed':
        return lang.tr(
          'You need to enable Email/Password sign-in in the Firebase console first.',
          'Firebase 콘솔에서 이메일/비밀번호 로그인을 먼저 활성화해야 합니다.',
        );
      default:
        return error.message ??
            lang.tr('An authentication error occurred.', '인증 오류가 발생했습니다.');
    }
  }

  bool _shouldTryLocalLogin(FirebaseAuthException error) {
    return error.code == 'operation-not-allowed' ||
        error.code == 'user-not-found' ||
        error.code == 'wrong-password' ||
        error.code == 'invalid-credential';
  }

  String _friendlyLocalAuthMessage(LocalBetaAuthException error) {
    final lang = AppLanguageController.instance;
    switch (error.code) {
      case 'email-already-in-use':
        return lang.tr(
          'This tester email is already saved in this browser. Please log in instead.',
          '이 이메일은 이미 이 브라우저에 저장되어 있습니다. 로그인으로 진행해주세요.',
        );
      case 'invalid-email':
        return lang.tr(
          'Please enter a valid email address.',
          '올바른 이메일 주소를 입력해주세요.',
        );
      case 'weak-password':
        return lang.tr(
          'Please use a password with at least 6 characters.',
          '비밀번호는 6자 이상으로 입력해주세요.',
        );
      case 'user-not-found':
        return lang.tr(
          'No saved tester account was found in this browser yet. Please sign up first.',
          '이 브라우저에는 아직 저장된 계정이 없습니다. 먼저 가입해주세요.',
        );
      case 'wrong-password':
        return lang.tr(
          'The saved tester password does not match.',
          '저장된 비밀번호가 일치하지 않습니다.',
        );
      default:
        return lang.tr(
          'The local session could not be opened right now.',
          '로컬 세션을 지금 열 수 없습니다.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PatientSession?>(
      stream: BetaSessionService.watchSession(),
      builder: (context, sessionSnapshot) {
        return AnimatedBuilder(
          animation: AppLanguageController.instance,
          builder: (context, _) {
            final lang = AppLanguageController.instance;
            final activeSession = sessionSnapshot.data;

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: Text(lang.tr('Patient Login', '환자 로그인')),
                actions: const [LanguageMenuButton()],
              ),
              body: AppBackdrop(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (activeSession != null) ...[
                              _buildActiveSessionCard(
                                context,
                                lang: lang,
                                session: activeSession,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildAuthCard(context, lang),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
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
            );
          },
        );
      },
    );
  }

  Widget _buildAuthCard(BuildContext context, AppLanguageController lang) {
    final title = _isRegisterMode
        ? lang.tr('Sign up', '회원가입')
        : lang.tr('Log in', '로그인');
    final submitLabel = _isRegisterMode
        ? lang.tr('Sign Up and Continue', '가입하고 계속')
        : lang.tr('Log In and Continue', '로그인하고 계속');
    final toggleLabel = _isRegisterMode
        ? lang.tr('Already have an account? Log in', '이미 계정이 있나요? 로그인')
        : lang.tr('New here? Sign up', '처음이신가요? 회원가입');

    return AppPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(lang.tr('Sign Up', '회원가입')),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(lang.tr('Login', '로그인')),
              ),
            ],
            selected: {_isRegisterMode},
            onSelectionChanged: _loading
                ? null
                : (selection) {
                    setState(() {
                      _isRegisterMode = selection.first;
                      _formError = null;
                    });
                  },
          ),
          if (_formError != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(context, _formError!),
          ],
          const SizedBox(height: 18),
          if (_isRegisterMode) ...[
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearFormErrorOnChange(),
              decoration: InputDecoration(
                labelText: lang.tr('Name', '이름'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearFormErrorOnChange(),
            decoration: InputDecoration(
              labelText: lang.tr('Email', '이메일'),
              prefixIcon: const Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearFormErrorOnChange(),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: lang.tr('Password', '비밀번호'),
              helperText: _isRegisterMode
                  ? lang.tr('At least 6 characters', '최소 6자 이상')
                  : null,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _showPassword = !_showPassword,
                ),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.copper),
            icon: Icon(
              _isRegisterMode
                  ? Icons.arrow_circle_right_outlined
                  : Icons.login,
            ),
            label: Text(
              _loading
                  ? lang.tr('Working...', '처리 중...')
                  : submitLabel,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                    _isRegisterMode = !_isRegisterMode;
                    _formError = null;
                  }),
            child: Text(toggleLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(
    BuildContext context, {
    required AppLanguageController lang,
    required PatientSession session,
  }) {
    return AppPanel(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          AppTheme.mint.withValues(alpha: 0.45),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lang.tr('You are signed in', '현재 로그인됨'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            session.email.isNotEmpty
                ? session.email
                : (session.displayName.isNotEmpty
                    ? session.displayName
                    : session.id),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _continueToPatientHome,
                icon: const Icon(Icons.arrow_circle_right_outlined),
                label: Text(lang.tr('Continue', '계속')),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _signOutTester,
                icon: const Icon(Icons.logout),
                label: Text(lang.tr('Sign out', '로그아웃')),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _resetTesterPortalData(session),
                icon: const Icon(Icons.restart_alt),
                label: Text(lang.tr('Reset data', '데이터 초기화')),
              ),
            ],
          ),
        ],
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
