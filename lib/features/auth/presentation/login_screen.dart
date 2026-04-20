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
  static const _practitionerId = '123';
  static const _practitionerPassword = '123';
  static const _patientId = 'hugo';
  static const _patientPassword = 'hugo';

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(String role) {
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    final isPractitionerLogin =
        role == 'practitioner' &&
        id == _practitionerId &&
        password == _practitionerPassword;
    final isPatientLogin =
        role == 'patient' && id == _patientId && password == _patientPassword;

    if (!isPractitionerLogin && !isPatientLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID 또는 비밀번호가 올바르지 않습니다.')),
      );
      return;
    }

    if (isPractitionerLogin) {
      Navigator.pushReplacementNamed(context, PractitionerDashboardScreen.routeName);
      return;
    }

    ClinicDataStore.instance.setCurrentPatientProfile('hugo_demo');
    Navigator.pushReplacementNamed(context, PatientIntakeScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final roleArg = ModalRoute.of(context)?.settings.arguments;
    final role = roleArg is String ? roleArg : 'patient';
    final roleLabel = role == 'practitioner' ? '침술사' : '환자';
    final helperText =
        role == 'practitioner' ? '테스트 계정: 123 / 123' : '테스트 계정: hugo / hugo';

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
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
                  '$roleLabel 로그인',
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
                  onSubmitted: (_) => _submit(role),
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
                  onSubmitted: (_) => _submit(role),
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
                  onPressed: () => _submit(role),
                  child: const Text('로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
