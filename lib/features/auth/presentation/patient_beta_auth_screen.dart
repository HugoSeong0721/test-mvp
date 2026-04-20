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
      _showMessage('Please enter your email and password.');
      return;
    }
    if (_isRegisterMode && name.isEmpty) {
      _showMessage('A name is required to sign up.');
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
      _showMessage('An error occurred during sign up / login: $error');
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
        return 'This email is already registered. Please log in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Please use a password with at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'operation-not-allowed':
        return 'You need to enable Email/Password sign-in in the Firebase console first.';
      default:
        return error.message ?? 'An authentication error occurred.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Beta Sign Up / Login')),
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
                    children: const [
                      Text(
                        'Quick Guide for First-Time Testers',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text('1. Sign up with your name, email, and password'),
                      SizedBox(height: 4),
                      Text('2. After logging in, confirm your phone number and email in your profile'),
                      SizedBox(height: 4),
                      Text('3. Answer the intake questions and submit'),
                      SizedBox(height: 4),
                      Text('4. You can start with sample wording instead of sensitive real health details'),
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
                        _isRegisterMode ? 'Beta Sign Up' : 'Beta Login',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isRegisterMode
                            ? 'Create a tester account and go straight into the patient flow.'
                            : 'Log back in with the email and password you already created.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 18),
                      if (_isRegisterMode) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
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
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(
                          _loading
                              ? 'Working...'
                              : _isRegisterMode
                                  ? 'Sign Up and Start'
                                  : 'Login',
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
                              ? 'Already have an account? Log in'
                              : 'New here? Sign up',
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
