import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/services/beta_session_service.dart';
import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../home/presentation/role_home_screen.dart';
import '../../patient_home/presentation/patient_home_screen.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';
import '../../patient_requests/presentation/patient_requests_screen.dart';

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

  Future<void> _submit() async {
    final lang = AppLanguageController.instance;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        lang.tr('Please enter your email and password.', '이메일과 비밀번호를 입력해주세요.'),
      );
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _showMessage(
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
      _showMessage(_friendlyLocalAuthMessage(error));
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage(
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
          '이 테스터 이메일은 이미 이 브라우저에 저장되어 있습니다. 로그인으로 진행해주세요.',
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
          'No saved beta tester account was found in this browser yet. Please sign up first.',
          '이 브라우저에는 아직 저장된 베타 계정이 없습니다. 먼저 가입해주세요.',
        );
      case 'wrong-password':
        return lang.tr(
          'The saved beta tester password does not match.',
          '저장된 베타 테스터 비밀번호가 일치하지 않습니다.',
        );
      default:
        return lang.tr(
          'The local beta session could not be opened right now.',
          '로컬 베타 세션을 지금 열 수 없습니다.',
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
            final modeTitle = _isRegisterMode
                ? lang.tr('Create your beta access', '베타 계정 만들기')
                : lang.tr('Return to your beta access', '베타 계정으로 다시 들어가기');
            final modeBody = _isRegisterMode
                ? lang.tr(
                    'Use this screen to create a lightweight tester account, then move directly into the patient portal flow.',
                    '이 화면에서 가벼운 테스터 계정을 만든 뒤 바로 환자 포털 흐름으로 들어갈 수 있습니다.',
                  )
                : lang.tr(
                    'Use the same email and password you created before to continue your patient-side testing flow.',
                    '이전에 만든 이메일과 비밀번호로 다시 들어와 환자 측 테스트 흐름을 이어갈 수 있습니다.',
                  );

            final heroTitle = _isRegisterMode
                ? lang.tr(
                    'A friend-beta entry that explains the workflow before asking for account details',
                    '계정 입력 전에 워크플로부터 설명해주는 friend beta 진입 화면',
                  )
                : lang.tr(
                    'A return-login screen that reminds testers where they are heading next',
                    '다시 로그인해도 다음에 어디로 가는지 먼저 알려주는 beta 재진입 화면',
                  );
            final heroBody = _isRegisterMode
                ? lang.tr(
                    'Competitor client portals usually welcome the user, describe the first few steps, and only then show the sign-up form. This screen now follows the same order.',
                    '경쟁사 client portal은 먼저 환영 메시지와 첫 단계 설명을 보여준 뒤 마지막에 가입 폼을 보여주는 경우가 많습니다. 이 화면도 같은 순서로 정리했습니다.',
                  )
                : lang.tr(
                    'Competitor portals reduce re-entry confusion by reminding users what this screen is for and what opens after login. This screen now follows the same pattern.',
                    '경쟁사 포털은 다시 들어오는 사용자도 이 화면이 무엇을 위한 곳인지, 로그인 후 무엇이 열리는지를 먼저 보여줘서 혼란을 줄입니다. 이 화면도 같은 패턴으로 맞췄습니다.',
                  );

            final nextActionLabel = _isRegisterMode
                ? lang.tr(
                    'Create account and land in patient home',
                    '계정 생성 후 환자 홈으로 진입',
                  )
                : lang.tr('Resume patient portal review', '환자 포털 검토 이어가기');

            final prepItems = _isRegisterMode
                ? [
                    _BetaPreviewItem(
                      icon: Icons.person_outline,
                      title: lang.tr('Simple tester profile', '간단한 테스터 프로필'),
                      description: lang.tr(
                        'Use a short tester name only. Real sensitive health details are not required for beta onboarding.',
                        '간단한 테스터 이름만 사용하면 됩니다. 베타 온보딩 단계에서는 실제 민감 건강정보가 필요하지 않습니다.',
                      ),
                    ),
                    _BetaPreviewItem(
                      icon: Icons.alternate_email,
                      title: lang.tr('Working email access', '사용 가능한 이메일'),
                      description: lang.tr(
                        'Use an email you can actually log back into later for repeat testing.',
                        '반복 테스트를 위해 나중에 다시 로그인할 수 있는 이메일을 사용하는 것이 좋습니다.',
                      ),
                    ),
                    _BetaPreviewItem(
                      icon: Icons.lock_outline,
                      title: lang.tr('Password ready', '비밀번호 준비'),
                      description: lang.tr(
                        'Use at least 6 characters so either Firebase auth or the local beta fallback can save it.',
                        'Firebase 인증이든 로컬 베타 대체 로그인 방식이든 저장될 수 있도록 비밀번호는 6자 이상으로 준비해주세요.',
                      ),
                    ),
                  ]
                : [
                    _BetaPreviewItem(
                      icon: Icons.login_outlined,
                      title: lang.tr('Use the same email', '같은 이메일 사용'),
                      description: lang.tr(
                        'Return with the exact email you signed up with before.',
                        '이전에 가입했던 동일한 이메일로 다시 들어와야 합니다.',
                      ),
                    ),
                    _BetaPreviewItem(
                      icon: Icons.password_outlined,
                      title: lang.tr('Use the same password', '같은 비밀번호 사용'),
                      description: lang.tr(
                        'This screen is for returning testers, not for resetting or creating a new account.',
                        '이 화면은 기존 테스터의 재진입용이며, 새 계정 생성 화면이 아닙니다.',
                      ),
                    ),
                    _BetaPreviewItem(
                      icon: Icons.home_outlined,
                      title: lang.tr(
                        'Continue from patient home',
                        '환자 홈부터 이어가기',
                      ),
                      description: lang.tr(
                        'After access you continue from the patient home screen and move into requests or intake.',
                        '로그인 후에는 환자 홈으로 들어가 요청 확인이나 문진 이어쓰기로 바로 이동할 수 있습니다.',
                      ),
                    ),
                  ];

            final portalPreviewItems = [
              _BetaPreviewItem(
                icon: Icons.space_dashboard_outlined,
                title: lang.tr('Patient home first', '환자 홈 우선 진입'),
                description: lang.tr(
                  'The first screen is a command-center style home that explains what is waiting and where to start.',
                  '첫 화면은 무엇이 기다리고 있고 어디서 시작해야 하는지 설명하는 command-center 형식의 환자 홈입니다.',
                ),
              ),
              _BetaPreviewItem(
                icon: Icons.assignment_turned_in_outlined,
                title: lang.tr(
                  'Requests and intake near the top',
                  '요청과 문진이 상단에',
                ),
                description: lang.tr(
                  'Current follow-up tasks and intake continuation stay above lower-priority history screens.',
                  '현재 후속 작업과 문진 이어쓰기가 우선순위가 낮은 기록 화면보다 위에 배치됩니다.',
                ),
              ),
              _BetaPreviewItem(
                icon: Icons.event_note_outlined,
                title: lang.tr(
                  'Next visit context stays visible',
                  '다음 방문 맥락 유지',
                ),
                description: lang.tr(
                  'Scheduling, visit history, and profile context are easier to scan without hunting through menus.',
                  '일정, 방문 기록, 프로필 맥락을 메뉴 깊숙이 찾지 않아도 더 쉽게 훑어볼 수 있습니다.',
                ),
              ),
            ];

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: Text(lang.tr('Friend Beta Access', '지인 베타 진입')),
                actions: const [LanguageMenuButton()],
              ),
              body: AppBackdrop(
                child: SafeArea(
                  child: SingleChildScrollView(
                    primary: true,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 940;

                              final story = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildKicker(
                                    context,
                                    lang.tr('Beta patient access', '환자 베타 진입'),
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    heroTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 580,
                                    ),
                                    child: Text(
                                      heroBody,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppTheme.ink.withValues(
                                              alpha: 0.78,
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      AppMetricChip(
                                        icon: Icons.groups_2_outlined,
                                        label: lang.tr('Audience', '대상'),
                                        value: lang.tr(
                                          'Friend testers',
                                          '지인 테스터',
                                        ),
                                        backgroundColor: AppTheme.mint
                                            .withValues(alpha: 0.86),
                                        valueColor: AppTheme.pine,
                                      ),
                                      AppMetricChip(
                                        icon: Icons.arrow_forward_outlined,
                                        label: lang.tr('Next action', '다음 행동'),
                                        value: nextActionLabel,
                                      ),
                                      AppMetricChip(
                                        icon: Icons.home_outlined,
                                        label: lang.tr('After access', '진입 후'),
                                        value: lang.tr('Patient home', '환자 홈'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  AppPanel(
                                    padding: const EdgeInsets.all(22),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.9),
                                        AppTheme.mint.withValues(alpha: 0.72),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang.tr('Start here', '여기부터 시작'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            AppGuideStep(
                                              step: '1',
                                              title: _isRegisterMode
                                                  ? lang.tr(
                                                      'Create your tester access',
                                                      '테스터 계정 만들기',
                                                    )
                                                  : lang.tr(
                                                      'Use your existing access',
                                                      '기존 계정으로 진입',
                                                    ),
                                              description: _isRegisterMode
                                                  ? lang.tr(
                                                      'Sign up once with email and password so you can reopen the portal later.',
                                                      '이메일과 비밀번호로 한 번 가입해두면 나중에 포털을 다시 열 수 있습니다.',
                                                    )
                                                  : lang.tr(
                                                      'Use the email and password you created before to continue the same portal flow.',
                                                      '이전에 만든 이메일과 비밀번호로 같은 포털 흐름을 이어갑니다.',
                                                    ),
                                            ),
                                            AppGuideStep(
                                              step: '2',
                                              title: lang.tr(
                                                'Confirm basic contact info',
                                                '기본 연락처 확인',
                                              ),
                                              description: lang.tr(
                                                'Once inside the portal, make sure your name, email, and phone basics are in place.',
                                                '포털에 들어간 뒤에는 이름, 이메일, 전화번호 같은 기본 정보가 준비되어 있는지 확인합니다.',
                                              ),
                                            ),
                                            AppGuideStep(
                                              step: '3',
                                              title: lang.tr(
                                                'Continue to requests or intake',
                                                '요청 또는 문진으로 이동',
                                              ),
                                              description: lang.tr(
                                                'From patient home you can continue the active task flow instead of hunting through menus.',
                                                '환자 홈에서 메뉴를 헤매지 않고 활성 작업 흐름으로 바로 이어질 수 있습니다.',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AppPanel(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang.tr('Portal preview', '포털 미리보기'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 14),
                                        for (final item in portalPreviewItems)
                                          _buildPreviewRow(context, item: item),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.border,
                                            ),
                                          ),
                                          child: Text(
                                            lang.tr(
                                              'This beta flow is meant to feel like a guided client-portal onboarding, not a raw dev auth form.',
                                              '이 beta 흐름은 개발용 인증 폼이 아니라 안내가 있는 client-portal onboarding처럼 느껴지도록 구성했습니다.',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.ink
                                                      .withValues(alpha: 0.74),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );

                              final form = AppPanel(
                                padding: const EdgeInsets.all(28),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFDFCFA),
                                    Color(0xFFEEE4D6),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      lang.tr('Beta access', '베타 접근'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: AppTheme.ink.withValues(
                                              alpha: 0.62,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      modeTitle,
                                      textAlign: wide
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      modeBody,
                                      textAlign: wide
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppTheme.ink.withValues(
                                              alpha: 0.72,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppTheme.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang.tr(
                                              'Mode snapshot',
                                              '현재 모드 요약',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              _buildMiniSnapshot(
                                                context,
                                                label: lang.tr('Mode', '모드'),
                                                value: _isRegisterMode
                                                    ? lang.tr('Sign up', '회원가입')
                                                    : lang.tr('Login', '로그인'),
                                              ),
                                              _buildMiniSnapshot(
                                                context,
                                                label: lang.tr(
                                                  'Destination',
                                                  '진입 화면',
                                                ),
                                                value: lang.tr(
                                                  'Patient home',
                                                  '환자 홈',
                                                ),
                                              ),
                                              _buildMiniSnapshot(
                                                context,
                                                label: lang.tr(
                                                  'First task',
                                                  '첫 단계',
                                                ),
                                                value: lang.tr(
                                                  'Requests or intake',
                                                  '요청 또는 문진',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (activeSession != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceSoft
                                              .withValues(alpha: 0.82),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.tr(
                                                'Active tester session',
                                                '현재 테스터 세션',
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '${lang.tr('Email', '이메일')}: ${activeSession.email.isEmpty ? '-' : activeSession.email}',
                                            ),
                                            Text(
                                              '${lang.tr('Name', '이름')}: ${activeSession.displayName.trim().isEmpty ? lang.tr('Saved in profile after access', '입장 후 프로필에서 저장됨') : activeSession.displayName}',
                                            ),
                                            Text(
                                              '${lang.tr('Session source', '세션 방식')}: ${activeSession.usesFirebaseAuth ? lang.tr('Firebase email sign-in', 'Firebase 이메일 로그인') : lang.tr('Saved in this browser', '이 브라우저에 저장됨')}',
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                FilledButton.tonalIcon(
                                                  onPressed:
                                                      _continueToPatientHome,
                                                  icon: const Icon(
                                                    Icons
                                                        .arrow_circle_right_outlined,
                                                  ),
                                                  label: Text(
                                                    lang.tr(
                                                      'Continue with this tester',
                                                      '이 테스터로 계속',
                                                    ),
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: _loading
                                                      ? null
                                                      : _signOutTester,
                                                  icon: const Icon(
                                                    Icons.logout,
                                                  ),
                                                  label: Text(
                                                    lang.tr('Sign out', '로그아웃'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildConnectedTesterPanel(
                                        context,
                                        lang: lang,
                                        session: activeSession,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mint.withValues(
                                          alpha: 0.44,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppTheme.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang.tr(
                                              'Before you continue',
                                              '진행 전 준비',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          for (final item in prepItems)
                                            _buildPreviewRow(
                                              context,
                                              item: item,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SegmentedButton<bool>(
                                      segments: [
                                        ButtonSegment<bool>(
                                          value: true,
                                          label: Text(
                                            lang.tr('Sign Up', '회원가입'),
                                          ),
                                        ),
                                        ButtonSegment<bool>(
                                          value: false,
                                          label: Text(lang.tr('Login', '로그인')),
                                        ),
                                      ],
                                      selected: {_isRegisterMode},
                                      onSelectionChanged: (selection) {
                                        setState(
                                          () =>
                                              _isRegisterMode = selection.first,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    if (_isRegisterMode) ...[
                                      TextField(
                                        controller: _nameController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: lang.tr('Name', '이름'),
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: lang.tr('Email', '이메일'),
                                        prefixIcon: const Icon(
                                          Icons.alternate_email,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: !_showPassword,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submit(),
                                      decoration: InputDecoration(
                                        labelText: lang.tr('Password', '비밀번호'),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () =>
                                                _showPassword = !_showPassword,
                                          ),
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surface.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: AppTheme.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang.tr('After access', '진입 후 흐름'),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 10),
                                          _buildChecklistRow(
                                            context,
                                            icon: Icons.home_outlined,
                                            text: lang.tr(
                                              'You land directly in the patient home screen.',
                                              '바로 환자 홈 화면으로 진입합니다.',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildChecklistRow(
                                            context,
                                            icon: Icons.assignment_outlined,
                                            text: lang.tr(
                                              'From there you can continue requests, intake, schedule, and visit history in a clearer order.',
                                              '그 다음 요청, 문진, 일정, 방문 기록을 더 명확한 순서로 이어서 볼 수 있습니다.',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildChecklistRow(
                                            context,
                                            icon: Icons.shield_outlined,
                                            text: _isRegisterMode
                                                ? lang.tr(
                                                    'Use sample wording if needed. Real sensitive health data is not required for beta signup.',
                                                    '필요하면 테스트용 문구를 사용해도 됩니다. 베타 가입 단계에서는 실제 민감 건강정보가 필요하지 않습니다.',
                                                  )
                                                : lang.tr(
                                                    'If Firebase email sign-in is still off, this beta screen keeps the tester account in this browser and still opens the patient portal.',
                                                    'Firebase 이메일 로그인이 아직 꺼져 있어도, 이 베타 화면은 계정을 이 브라우저에 저장한 뒤 환자 포털을 계속 열 수 있습니다.',
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: _loading ? null : _submit,
                                      icon: Icon(
                                        _isRegisterMode
                                            ? Icons.arrow_circle_right_outlined
                                            : Icons.login,
                                      ),
                                      label: Text(
                                        _loading
                                            ? lang.tr('Working...', '처리 중...')
                                            : _isRegisterMode
                                            ? lang.tr(
                                                'Sign Up and Enter',
                                                '가입 후 입장',
                                              )
                                            : lang.tr(
                                                'Login and Continue',
                                                '로그인 후 계속',
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => setState(
                                              () => _isRegisterMode =
                                                  !_isRegisterMode,
                                            ),
                                      child: Text(
                                        _isRegisterMode
                                            ? lang.tr(
                                                'Already have an account? Log in',
                                                '이미 계정이 있나요? 로그인',
                                              )
                                            : lang.tr(
                                                'New here? Sign up',
                                                '처음이신가요? 회원가입',
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    OutlinedButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : () =>
                                                Navigator.pushReplacementNamed(
                                                  context,
                                                  RoleHomeScreen.routeName,
                                                ),
                                      icon: const Icon(Icons.arrow_back),
                                      label: Text(
                                        lang.tr(
                                          'Back to entry hub',
                                          '진입 화면으로 돌아가기',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              return wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 11, child: story),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 9, child: form),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        story,
                                        const SizedBox(height: 24),
                                        form,
                                      ],
                                    );
                            },
                          ),
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

  Widget _buildConnectedTesterPanel(
    BuildContext context, {
    required AppLanguageController lang,
    required PatientSession session,
  }) {
    return StreamBuilder<PatientProfile?>(
      stream: PatientProfileService.watchProfileForSession(session),
      builder: (context, profileSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('intake_submissions')
              .where('patientId', isEqualTo: session.id)
              .snapshots(),
          builder: (context, submissionSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('answer_requests')
                  .where('patientId', isEqualTo: session.id)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, requestSnapshot) {
                final profile = profileSnapshot.data;
                final intakeCount = submissionSnapshot.data?.docs.length ?? 0;
                final pendingRequestCount =
                    requestSnapshot.data?.docs.length ?? 0;
                final hasDataError =
                    profileSnapshot.hasError ||
                    submissionSnapshot.hasError ||
                    requestSnapshot.hasError;
                final dataLoading =
                    !profileSnapshot.hasData ||
                    !submissionSnapshot.hasData ||
                    !requestSnapshot.hasData;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Live tester connection', '실제 테스터 연결 상태'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          'This beta account is connected to the current patient-side profile, requests, and intake submission data.',
                          '이 beta 계정은 현재 환자 프로필, 요청함, 문진 제출 데이터와 연결되어 있습니다.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (hasDataError)
                        Text(
                          lang.tr(
                            'Some live beta data could not be loaded right now.',
                            '일부 실사용 beta 데이터를 지금 불러오지 못했습니다.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.red.shade700),
                        )
                      else if (dataLoading)
                        const LinearProgressIndicator(minHeight: 3)
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildMiniSnapshot(
                              context,
                              label: lang.tr('Profile', '프로필'),
                              value: profile == null
                                  ? lang.tr('Creating', '생성 중')
                                  : profile.hasRequiredAlertInfo
                                  ? lang.tr('Ready', '준비됨')
                                  : lang.tr('Needs review', '보완 필요'),
                            ),
                            _buildMiniSnapshot(
                              context,
                              label: lang.tr('Intake submissions', '문진 제출'),
                              value: lang.tr(
                                '$intakeCount saved',
                                '$intakeCount건 저장',
                              ),
                            ),
                            _buildMiniSnapshot(
                              context,
                              label: lang.tr('Pending requests', '대기 요청'),
                              value: lang.tr(
                                '$pendingRequestCount waiting',
                                '$pendingRequestCount건 대기',
                              ),
                            ),
                            _buildMiniSnapshot(
                              context,
                              label: lang.tr('Patient record', '환자 레코드'),
                              value: profile?.name.isNotEmpty == true
                                  ? profile!.name
                                  : session.email.isNotEmpty
                                  ? session.email
                                  : session.id,
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              PatientRequestsScreen.routeName,
                            ),
                            icon: const Icon(Icons.mail_outline),
                            label: Text(lang.tr('Open requests', '요청함 열기')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              PatientIntakeScreen.routeName,
                            ),
                            icon: const Icon(Icons.assignment_outlined),
                            label: Text(lang.tr('Open intake', '문진 열기')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildKicker(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildPreviewRow(
    BuildContext context, {
    required _BetaPreviewItem item,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.pine, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSnapshot(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.pine),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.76),
            ),
          ),
        ),
      ],
    );
  }
}

class _BetaPreviewItem {
  const _BetaPreviewItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
