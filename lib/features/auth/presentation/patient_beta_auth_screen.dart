import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/patient_profile_service.dart';
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _showMessage('회원가입에는 이름이 필요합니다.');
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
      _showMessage('회원가입/로그인 처리 중 오류가 발생했습니다: $error');
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
    switch (error.code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다. 로그인으로 들어가 주세요.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호를 6자 이상으로 입력해 주세요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'operation-not-allowed':
        return 'Firebase 콘솔에서 이메일/비밀번호 로그인을 먼저 활성화해야 합니다.';
      default:
        return error.message ?? '인증 처리 중 오류가 발생했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지인 베타 회원가입/로그인')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegisterMode ? '베타 회원가입' : '베타 로그인',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRegisterMode
                        ? '지인 테스트용 계정을 만들고 바로 환자 화면으로 들어갑니다.'
                        : '가입한 이메일과 비밀번호로 다시 들어갑니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 18),
                  if (_isRegisterMode) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      border: const OutlineInputBorder(),
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
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _loading
                          ? '처리 중...'
                          : _isRegisterMode
                              ? '회원가입 후 시작'
                              : '로그인',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(
                              () => _isRegisterMode = !_isRegisterMode,
                            ),
                    child: Text(
                      _isRegisterMode
                          ? '이미 계정이 있으면 로그인'
                          : '처음이면 회원가입',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
