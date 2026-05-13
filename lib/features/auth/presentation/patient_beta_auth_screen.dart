import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
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
  static const Duration _authTimeout = Duration(seconds: 6);

  final ClinicDataStore _store = ClinicDataStore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  StreamSubscription<PatientSession?>? _sessionSubscription;
  bool _isRegisterMode = true;
  bool _showPassword = false;
  bool _loading = false;
  bool _sessionReady = false;
  bool _loadedRouteArgs = false;
  bool _showAuthFormEvenWithSession = false;
  bool _didAutoOpenSavedPortal = false;
  String? _formError;
  String? _linkedClinicId;
  PatientSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _initializeSession();
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

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    await BetaSessionService.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _activeSession = BetaSessionService.currentSession;
      _sessionReady = true;
    });
    await _sessionSubscription?.cancel();
    _sessionSubscription = BetaSessionService.watchSession().listen((session) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSession = session;
        _sessionReady = true;
      });
      if (session != null &&
          !_showAuthFormEvenWithSession &&
          _requestedPatientHomeUrl()) {
        _openSavedPortalOnce();
      }
    });
  }

  bool _requestedPatientHomeUrl() {
    final fragment = Uri.base.fragment;
    if (fragment.isEmpty) {
      return false;
    }
    final path = fragment.split('?').first.trim();
    return path == PatientHomeScreen.routeName;
  }

  void _openSavedPortalOnce() {
    if (_didAutoOpenSavedPortal || !mounted) {
      return;
    }
    _didAutoOpenSavedPortal = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final session = _activeSession;
      if (session == null) {
        _didAutoOpenSavedPortal = false;
        return;
      }
      unawaited(_preparePatientPortalContext(session));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: PatientHomeScreen.routeName,
            arguments: {
              if (_linkedClinicId != null) 'clinicId': _linkedClinicId,
            },
          ),
          builder: (_) => const PatientHomeScreen(),
        ),
      );
    });
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

  Future<void> _continueToPatientHome() async {
    if (!mounted || _loading) {
      return;
    }

    setState(() => _loading = true);
    final session =
        _activeSession ?? await BetaSessionService.currentSessionAsync();
    if (!mounted) {
      return;
    }
    if (session == null) {
      setState(() => _loading = false);
      return;
    }

    unawaited(_preparePatientPortalContext(session));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: PatientHomeScreen.routeName,
          arguments: {if (_linkedClinicId != null) 'clinicId': _linkedClinicId},
        ),
        builder: (_) => const PatientHomeScreen(),
      ),
    );
  }

  Future<void> _preparePatientPortalContext(PatientSession session) async {
    PatientProfile profile;
    try {
      profile = await _loadTesterProfile(session).timeout(_authTimeout);
    } catch (_) {
      profile = PatientProfile(
        id: session.id,
        name: session.displayName.trim().isEmpty
            ? 'New Patient'
            : session.displayName.trim(),
        phone: '',
        email: session.email,
        birthYear: 1990,
        sex: 'Not entered',
        ethnicity: 'Not entered',
        memo: 'Profile created from beta sign-in fallback',
      );
    }

    _store.saveProfile(profile);
    _store.setCurrentPatientProfile(profile.id);
    try {
      await _store.applyPreferredClinicForPatient(
        patientId: profile.id,
        linkedClinicId: _linkedClinicId,
      );
    } catch (_) {
      // Keep login responsive even if clinic state is not ready.
    }
  }

  Future<void> _signOutTester() async {
    final lang = AppLanguageController.instance;
    setState(() => _loading = true);
    try {
      await PatientProfileService.signOut().timeout(_authTimeout);
      if (!mounted) {
        return;
      }
      setState(() {
        _showAuthFormEvenWithSession = true;
        _didAutoOpenSavedPortal = false;
      });
      _showMessage(
        lang.tr(
          'Signed out from the current tester session.',
          '현재 테스터 세션에서 로그아웃했습니다.',
        ),
      );
    } catch (_) {
      _showMessage(
        lang.tr('Could not sign out right now.', '지금 로그아웃하지 못했습니다.'),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetTesterPortalData(PatientSession session) async {
    final lang = AppLanguageController.instance;
    setState(() => _loading = true);
    try {
      await TesterFlowService.resetPortalData(
        patientId: session.id,
      ).timeout(_authTimeout);
      _showMessage(
        lang.tr('Tester flow data was reset.', '테스터 흐름 데이터가 초기화되었습니다.'),
      );
    } catch (_) {
      _showMessage(lang.tr('Could not reset right now.', '지금 초기화할 수 없습니다.'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reloadTesterPortalData(PatientSession session) async {
    final lang = AppLanguageController.instance;
    setState(() => _loading = true);
    try {
      final profile = await _loadTesterProfile(session).timeout(_authTimeout);
      await TesterFlowService.resetAndSeedPortalData(
        profile: profile,
      ).timeout(_authTimeout);
      _showMessage(
        lang.tr('Tester sample data was reloaded.', '테스터 샘플 데이터가 다시 채워졌습니다.'),
      );
    } catch (_) {
      _showMessage(
        lang.tr(
          'Could not reload sample data right now.',
          '지금 샘플 데이터를 다시 채울 수 없습니다.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<PatientProfile> _loadTesterProfile(PatientSession session) async {
    final localProfile = await PatientProfileService.loadLocalProfile(
      session.id,
    );
    if (localProfile != null) {
      return localProfile;
    }

    final remoteProfile =
        await PatientProfileService.watchProfileForSession(session)
            .firstWhere((profile) => profile != null)
            .timeout(const Duration(seconds: 3));

    if (remoteProfile != null) {
      return remoteProfile;
    }

    return PatientProfile(
      id: session.id,
      name: session.displayName.trim().isEmpty
          ? 'New Patient'
          : session.displayName.trim(),
      phone: '',
      email: session.email,
      birthYear: 1990,
      sex: 'Not entered',
      ethnicity: 'Not entered',
      memo: 'Profile created from beta sign-in fallback',
    );
  }

  Future<void> _submit() async {
    final lang = AppLanguageController.instance;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    _setFormError(null);

    if (email.isEmpty) {
      _setFormError(lang.tr('Please enter your email.', '이메일을 입력해주세요.'));
      return;
    }
    if (password.isEmpty) {
      _setFormError(lang.tr('Please enter your password.', '비밀번호를 입력해주세요.'));
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _setFormError(
        lang.tr('A name is required to sign up.', '회원가입에는 이름이 필요합니다.'),
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

    setState(() => _loading = true);

    try {
      if (_isRegisterMode) {
        await _registerTester(
          name: name,
          email: email,
          password: password,
        ).timeout(_authTimeout);
      } else {
        await _logInTester(
          email: email,
          password: password,
        ).timeout(_authTimeout);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: PatientHomeScreen.routeName,
            arguments: {
              if (_linkedClinicId != null) 'clinicId': _linkedClinicId,
            },
          ),
          builder: (_) => const PatientHomeScreen(),
        ),
      );
    } on LocalBetaAuthException catch (error) {
      _setFormError(_friendlyLocalAuthMessage(error));
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
    final session = await BetaSessionService.signUpLocally(
      name: name,
      email: email,
      password: password,
    );
    try {
      await PatientProfileService.ensureProfileForSession(
        session,
        nameHint: name,
      ).timeout(_authTimeout);
    } catch (_) {}
  }

  Future<void> _logInTester({
    required String email,
    required String password,
  }) async {
    final session = await BetaSessionService.logInLocally(
      email: email,
      password: password,
    );
    try {
      await PatientProfileService.ensureProfileForSession(
        session,
      ).timeout(_authTimeout);
    } catch (_) {}
  }

  Future<void> _showSavedPatientAccounts() async {
    final lang = AppLanguageController.instance;
    final accounts = await BetaSessionService.localAccountSummaries();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.tr('Saved patient emails', '저장된 환자 이메일')),
        content: SizedBox(
          width: 420,
          child: accounts.isEmpty
              ? Text(
                  lang.tr(
                    'No patient account has been saved in this browser yet.',
                    '이 브라우저에 저장된 환자 계정이 아직 없습니다.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return ListTile(
                      title: Text(account.email),
                      subtitle: Text(account.displayName),
                      onTap: () {
                        _emailController.text = account.email;
                        Navigator.pop(context);
                        setState(() {
                          _isRegisterMode = false;
                          _showAuthFormEvenWithSession = true;
                          _formError = null;
                        });
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

  Future<void> _showPatientPasswordResetDialog() async {
    final lang = AppLanguageController.instance;
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final passwordController = TextEditingController();
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(lang.tr('Reset patient password', '환자 비밀번호 재설정')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: lang.tr('Email', '이메일'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: lang.tr('New password', '새 비밀번호'),
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
                    await BetaSessionService.resetLocalPassword(
                      email: emailController.text.trim(),
                      newPassword: passwordController.text.trim(),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    _emailController.text = emailController.text.trim();
                    _passwordController.clear();
                    Navigator.pop(context);
                    _showMessage(
                      lang.tr(
                        'Local password was reset. You can log in now.',
                        '로컬 비밀번호를 재설정했습니다. 이제 로그인할 수 있습니다.',
                      ),
                    );
                    setState(() {
                      _isRegisterMode = false;
                      _showAuthFormEvenWithSession = true;
                    });
                  } on LocalBetaAuthException catch (e) {
                    setDialogState(() => error = _friendlyLocalAuthMessage(e));
                  }
                },
                child: Text(lang.tr('Reset', '재설정')),
              ),
            ],
          ),
        ),
      );
    } finally {
      emailController.dispose();
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

  /*
  String _friendlyAuthMessage(Object error) {
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
      default:
        return error.message ??
            lang.tr('An authentication error occurred.', '인증 오류가 발생했습니다.');
    }
  }

  */
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
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        final activeSession = _activeSession;
        final linkedClinic = _linkedClinicId == null
            ? null
            : _store.clinicById(_linkedClinicId!);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(lang.tr('Patient Login', '환자 로그인')),
            actions: const [LanguageMenuButton()],
          ),
          body: AppBackdrop(
            child: SafeArea(
              child: Center(
                child: !_sessionReady
                    ? const CircularProgressIndicator()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (linkedClinic != null) ...[
                                _buildLinkedClinicCard(
                                  context,
                                  lang: lang,
                                  clinic: linkedClinic,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (activeSession != null) ...[
                                _buildActiveSessionCard(
                                  context,
                                  lang: lang,
                                  session: activeSession,
                                ),
                                const SizedBox(height: 16),
                                _buildSignedInHintCard(context, lang),
                                const SizedBox(height: 16),
                              ],
                              if (activeSession == null ||
                                  _showAuthFormEvenWithSession)
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
          _buildFieldHintCard(
            context,
            accent: AppTheme.copper,
            message: _isRegisterMode
                ? lang.tr(
                    'Use the email address you want to keep using for this patient account.',
                    '이 환자 계정에서 계속 사용할 이메일 주소를 입력해주세요.',
                  )
                : lang.tr(
                    'Enter the email address you used when you signed up.',
                    '가입할 때 사용한 이메일 주소를 입력해주세요.',
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearFormErrorOnChange(),
            decoration: InputDecoration(
              labelText: lang.tr('Email', '이메일'),
              hintText: lang.tr('Enter your email address', '이메일 주소를 입력해주세요'),
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
                onPressed: () => setState(() => _showPassword = !_showPassword),
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
              _isRegisterMode ? Icons.arrow_circle_right_outlined : Icons.login,
            ),
            label: Text(
              _loading ? lang.tr('Working...', '처리 중...') : submitLabel,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _loading ? null : _showSavedPatientAccounts,
                child: Text(lang.tr('Find saved email', '저장된 이메일 찾기')),
              ),
              TextButton(
                onPressed: _loading ? null : _showPatientPasswordResetDialog,
                child: Text(lang.tr('Reset password', '비밀번호 찾기/재설정')),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
        colors: [Colors.white, AppTheme.mint.withValues(alpha: 0.45)],
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
                    : () => setState(() => _showAuthFormEvenWithSession = true),
                icon: const Icon(Icons.switch_account_outlined),
                label: Text(lang.tr('Use another account', '다른 계정 사용')),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _resetTesterPortalData(session),
                icon: const Icon(Icons.restart_alt),
                label: Text(lang.tr('Reset data', '데이터 초기화')),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _reloadTesterPortalData(session),
                icon: const Icon(Icons.refresh),
                label: Text(lang.tr('Reload sample', '샘플 다시 채우기')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInHintCard(
    BuildContext context,
    AppLanguageController lang,
  ) {
    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr(
              'This browser already has a saved patient session.',
              '이 브라우저에는 이미 저장된 환자 세션이 있습니다.',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            lang.tr(
              'Use Continue to reopen the saved portal, or sign out first if you want to use a different patient account.',
              '저장된 포털로 다시 들어가려면 Continue를 누르고, 다른 환자 계정을 쓰려면 먼저 Sign out 해주세요.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.72),
            ),
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

  Widget _buildLinkedClinicCard(
    BuildContext context, {
    required AppLanguageController lang,
    required ClinicCenter clinic,
  }) {
    return AppPanel(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, AppTheme.mint.withValues(alpha: 0.4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.tr('Clinic link received', '한의원 링크로 들어왔습니다'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(clinic.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${clinic.practitionerName}${clinic.location.isEmpty ? '' : ' · ${clinic.location}'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.72),
            ),
          ),
          if (clinic.patientNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              clinic.patientNote,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            lang.tr(
              'After sign up or login, this clinic will already be selected in the patient portal.',
              '로그인 후에는 이 한의원이 환자 포털에 미리 선택된 상태로 열립니다.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}
