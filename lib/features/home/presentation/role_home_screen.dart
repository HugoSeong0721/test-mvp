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

    return Scaffold(
      appBar: AppBar(title: const Text('Test MVP')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
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
                        const Text('Use this to preview the default patient sample flow or test your Hugo profile.'),
                        const SizedBox(height: 8),
                        const Text('Accounts: 123 / 123   or   hugo / hugo'),
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
