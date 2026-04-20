import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/patient_beta_auth_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});

  static const routeName = '/';

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  static const _entryPassword = 'Daisy';
  final TextEditingController _passwordController = TextEditingController();
  bool _unlocked = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() {
    final lang = AppLanguageController.instance;
    if (_passwordController.text.trim() == _entryPassword) {
      setState(() => _unlocked = true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.tr('Incorrect password.', '비밀번호가 올바르지 않습니다.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lang.tr('Test MVP Lock', '테스트 MVP 잠금')),
          actions: const [LanguageMenuButton()],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang.tr('Enter Access Password', '접속 비밀번호 입력'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _unlock(),
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _unlock,
                    child: Text(lang.tr('Enter', '입장')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Test MVP', '테스트 MVP')),
        actions: const [LanguageMenuButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  lang.tr('Web Test Entry', '웹 테스트 진입'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.tr(
                    'The login pages are split by flow so you can jump straight into what you want to test.',
                    '보고 싶은 흐름에 맞춰 로그인 페이지를 나눠두었습니다.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lang.tr('Practitioner', '침술사'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'Dashboard -> patient detail -> answer request flow',
                            '대시보드 -> 환자 상세 -> 답변 요청 흐름',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {'role': 'practitioner', 'loginMode': 'default'},
                            );
                          },
                          child: Text(lang.tr('Practitioner Login', '침술사 로그인')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lang.tr('Patient Test Account', '환자 테스트 계정'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'Use this to preview the default patient sample flow or test your Hugo profile.',
                            '기본 환자 예시 흐름 또는 Hugo 프로필 테스트용입니다.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'Accounts: 123 / 123   or   hugo / hugo',
                            '계정: 123 / 123 또는 hugo / hugo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {'role': 'patient', 'loginMode': 'default'},
                            );
                          },
                          child: Text(lang.tr('Patient Test Login', '환자 테스트 로그인')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          lang.tr('Friend Beta Sign Up / Login', '지인 베타 회원가입/로그인'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'This is the shared flow for friends to create an account and submit their own test intake.',
                            '주변 사람들이 직접 가입해서 본인 테스트 문진을 제출하는 흐름입니다.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.tr(
                            'Create an account with email and password',
                            '이메일/비밀번호로 계정 생성',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.pushNamed(context, PatientBetaAuthScreen.routeName);
                          },
                          child: Text(
                            lang.tr(
                              'Friend Beta Sign Up / Login',
                              '지인 베타 회원가입/로그인',
                            ),
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
      ),
    );
  }
}
