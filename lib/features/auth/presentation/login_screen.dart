import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../patient_intake/presentation/patient_intake_screen.dart';
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

  void _submit(String role, String loginMode) {
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
        role == 'patient' &&
        id == _hugoId &&
        password == _hugoPassword;

    if (!isPractitionerLogin && !isPatientDefaultLogin && !isPatientHugoLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The ID or password is incorrect.')),
      );
      return;
    }

    if (isPractitionerLogin) {
      Navigator.pushReplacementNamed(context, PractitionerDashboardScreen.routeName);
      return;
    }

    if (isPatientHugoLogin) {
      ClinicDataStore.instance.setCurrentPatientProfile('hugo_demo');
    } else {
      ClinicDataStore.instance.setCurrentPatientProfile('jane_kim');
    }

    Navigator.pushReplacementNamed(context, PatientIntakeScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    String role = 'patient';
    if (routeArgs is Map) {
      role = (routeArgs['role'] as String?) ?? 'patient';
    } else if (routeArgs is String) {
      role = routeArgs;
    }

    final roleLabel = role == 'practitioner' ? 'Practitioner' : 'Patient';
    final helperText = role == 'practitioner'
        ? 'Test account: 123 / 123'
        : 'Test accounts: 123 / 123 or hugo / hugo';

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
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
                  '$roleLabel Login',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  helperText,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _idController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _submit(role, 'default'),
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(role, 'default'),
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                  onPressed: () => _submit(role, 'default'),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
