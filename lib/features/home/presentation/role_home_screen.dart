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
      const SnackBar(content: Text('Incorrect password.')),
    );
  }

  Future<void> _showFirstVisitGuide() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('First-Time Guide'),
          content: const SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You can share this quick guide with beta testers.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text('1. Open the link and enter the first password: Daisy'),
                  SizedBox(height: 6),
                  Text('2. Choose Friend Beta Sign Up / Login'),
                  SizedBox(height: 6),
                  Text('3. Create an account with name, email, and password'),
                  SizedBox(height: 6),
                  Text('4. Fill in phone number, email, and basic profile details'),
                  SizedBox(height: 6),
                  Text('5. Answer the intake questions and submit'),
                  SizedBox(height: 12),
                  Divider(),
                  SizedBox(height: 12),
                  Text(
                    'Helpful notes for testers',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('- Start with sample or test wording instead of sensitive real health details'),
                  SizedBox(height: 6),
                  Text('- Add both phone and email if you want to test the answer-request flow'),
                  SizedBox(height: 6),
                  Text('- After submitting, check the practitioner screen together to confirm it appears'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
        appBar: AppBar(title: const Text('Test MVP Lock')),
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
                    'Enter Access Password',
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
                    child: const Text('Enter'),
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
                  'Web Test Entry',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The login pages are split by flow so you can jump straight into what you want to test.',
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
                                'First-Time Visitor Guide',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'If you are sending this link to friends or testers, this guide makes sign-up and submission much easier to follow.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _showFirstVisitGuide,
                          child: const Text('View Guide'),
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
                          'Practitioner',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('Dashboard -> patient detail -> answer request flow'),
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
                          child: const Text('Practitioner Login'),
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
                          'Patient Test Account',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('Use this to preview the default patient sample flow'),
                        const SizedBox(height: 8),
                        const Text('Account: 123 / 123'),
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
                          child: const Text('Patient Test Login'),
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
                          'My Profile Login',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('Direct test entry for the Hugo Seong profile'),
                        const SizedBox(height: 8),
                        const Text('Account: hugo / hugo'),
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
                          child: const Text('Hugo Login'),
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
                          'Friend Beta Sign Up / Login',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('This is the shared flow for friends to create an account and submit their own test intake.'),
                        const SizedBox(height: 8),
                        const Text('Create an account with email and password'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              PatientBetaAuthScreen.routeName,
                            );
                          },
                          child: const Text('Friend Beta Sign Up / Login'),
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
