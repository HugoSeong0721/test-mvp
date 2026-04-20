import 'package:flutter/material.dart';

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
  bool _guideShown = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() {
    if (_passwordController.text.trim() == _entryPassword) {
      setState(() => _unlocked = true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
    );
  }

  Future<void> _showFirstVisitGuide() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('처음 방문 가이드'),
          content: const SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지인 테스트용으로 이렇게 안내하면 됩니다.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text('1. 링크를 열고 첫 비밀번호 Daisy 입력'),
                  SizedBox(height: 6),
                  Text('2. 지인 베타 회원가입/로그인 선택'),
                  SizedBox(height: 6),
                  Text('3. 이름 + 이메일 + 비밀번호로 회원가입'),
                  SizedBox(height: 6),
                  Text('4. 환자 화면에서 전화번호/이메일/기본 프로필 입력'),
                  SizedBox(height: 6),
                  Text('5. 문진 질문에 답하고 제출하기'),
                  SizedBox(height: 12),
                  Divider(),
                  SizedBox(height: 12),
                  Text(
                    '테스트할 때 같이 말해두면 좋은 것',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('- 처음에는 민감한 실제 건강정보 대신 테스트용 문구로 입력해보기'),
                  SizedBox(height: 6),
                  Text('- 전화번호와 이메일을 넣으면 답변 요청 흐름까지 테스트 가능'),
                  SizedBox(height: 6),
                  Text('- 제출 후 침술사 화면에서 바로 반영되는지 같이 확인하기'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test MVP 잠금')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '접속 비밀번호 입력',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _unlock,
                    child: const Text('입장'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_guideShown) {
      _guideShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showFirstVisitGuide();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Test MVP')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '웹 테스트 진입',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  '보고 싶은 흐름에 맞춰 로그인 페이지를 나눠두었습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFF7FBFA),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '처음 오는 사람 가이드',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '지인에게 링크를 보낼 때 이 가이드를 같이 보여주면 가입과 제출 흐름을 훨씬 쉽게 따라올 수 있습니다.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _showFirstVisitGuide,
                          child: const Text('가이드 보기'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '침술사',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('대시보드 -> 환자 상세 -> 답변 요청 흐름'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {
                                'role': 'practitioner',
                                'loginMode': 'default',
                              },
                            );
                          },
                          child: const Text('침술사 로그인 페이지'),
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
                        const Text(
                          '환자 테스트 계정',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('기본 환자 예시 화면 확인용'),
                        const SizedBox(height: 8),
                        const Text('계정: 123 / 123'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {
                                'role': 'patient',
                                'loginMode': 'default',
                              },
                            );
                          },
                          child: const Text('환자 테스트 로그인'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFF4FBFA),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '내 프로필 전용 로그인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('Hugo Seong 프로필로 직접 테스트하는 전용 진입'),
                        const SizedBox(height: 8),
                        const Text('계정: hugo / hugo'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {
                                'role': 'patient',
                                'loginMode': 'hugo',
                              },
                            );
                          },
                          child: const Text('Hugo 전용 로그인'),
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
                        const Text(
                          '지인 베타 회원가입/로그인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('주변 사람들이 직접 가입해서 제출해보는 전용 흐름'),
                        const SizedBox(height: 8),
                        const Text('이메일/비밀번호로 계정 생성'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              PatientBetaAuthScreen.routeName,
                            );
                          },
                          child: const Text('지인 베타 회원가입/로그인'),
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
