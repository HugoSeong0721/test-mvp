import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/patient_profile_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';

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

  Future<void> _submit() async {
    final lang = AppLanguageController.instance;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage(lang.tr('Please enter your email and password.', '이메일과 비밀번호를 입력해주세요.'));
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _showMessage(lang.tr('A name is required to sign up.', '회원가입에는 이름이 필요합니다.'));
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential credential;
      if (_isRegisterMode) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user?.updateDisplayName(name);
        if (credential.user != null) {
          await PatientProfileService.ensureProfileForUser(
            credential.user!,
            nameHint: name,
          );
        }
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          await PatientProfileService.ensureProfileForUser(credential.user!);
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, PatientIntakeScreen.routeName);
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage(
        lang.tr(
          'An error occurred during sign up / login: $error',
          '회원가입/로그인 중 오류가 발생했습니다: $error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        return lang.tr('Please enter a valid email address.', '올바른 이메일 주소를 입력해주세요.');
      case 'weak-password':
        return lang.tr('Please use a password with at least 6 characters.', '비밀번호는 6자 이상으로 입력해주세요.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return lang.tr('The email or password is incorrect.', '이메일 또는 비밀번호가 올바르지 않습니다.');
      case 'operation-not-allowed':
        return lang.tr(
          'You need to enable Email/Password sign-in in the Firebase console first.',
          'Firebase 콘솔에서 이메일/비밀번호 로그인을 먼저 활성화해야 합니다.',
        );
      default:
        return error.message ?? lang.tr('An authentication error occurred.', '인증 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Friend Beta Sign Up / Login', '지인 베타 회원가입/로그인')),
        actions: const [LanguageMenuButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: const Color(0xFFF7FBFA),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.tr('Quick Guide for First-Time Testers', '처음 쓰는 분 간단 안내'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.tr(
                          '1. Sign up with your name, email, and password',
                          '1. 이름, 이메일, 비밀번호로 가입하세요',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.tr(
                          '2. After logging in, confirm your phone number and email in your profile',
                          '2. 로그인 후 프로필에서 전화번호와 이메일을 확인하세요',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.tr(
                          '3. Answer the intake questions and submit',
                          '3. 문진 질문에 답하고 제출하세요',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang.tr(
                          '4. You can start with sample wording instead of sensitive real health details',
                          '4. 민감한 실제 건강정보 대신 테스트용 문구로 시작해도 됩니다',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isRegisterMode
                            ? lang.tr('Beta Sign Up', '베타 회원가입')
                            : lang.tr('Beta Login', '베타 로그인'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isRegisterMode
                            ? lang.tr(
                                'Create a tester account and go straight into the patient flow.',
                                '테스터 계정을 만들고 바로 환자 흐름으로 들어갑니다.',
                              )
                            : lang.tr(
                                'Log back in with the email and password you already created.',
                                '이미 만든 이메일과 비밀번호로 다시 로그인하세요.',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 18),
                      if (_isRegisterMode) ...[
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: lang.tr('Name', '이름'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: lang.tr('Email', '이메일'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: lang.tr('Password', '비밀번호'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(
                          _loading
                              ? lang.tr('Working...', '처리 중...')
                              : _isRegisterMode
                                  ? lang.tr('Sign Up and Start', '가입 후 시작')
                                  : lang.tr('Login', '로그인'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _isRegisterMode = !_isRegisterMode),
                        child: Text(
                          _isRegisterMode
                              ? lang.tr(
                                  'Already have an account? Log in',
                                  '이미 계정이 있나요? 로그인',
                                )
                              : lang.tr('New here? Sign up', '처음이신가요? 회원가입'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
