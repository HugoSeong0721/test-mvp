import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/patient_beta_auth_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(lang.tr('Test MVP', '테스트 MVP')),
        actions: const [LanguageMenuButton()],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      lang.tr('Test MVP', '테스트 MVP'),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 720;
                        final practitionerCard = _RoleCard(
                          accent: AppTheme.pine,
                          accentSoft: AppTheme.mint,
                          icon: Icons.health_and_safety_outlined,
                          eyebrow: lang.tr('Practitioner', '침술사'),
                          title: lang.tr('Clinic Portal', '클리닉 포털'),
                          buttonLabel: lang.tr(
                            'Continue as Practitioner',
                            '침술사로 시작',
                          ),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            LoginScreen.routeName,
                            arguments: const {
                              'role': 'practitioner',
                              'loginMode': 'default',
                            },
                          ),
                          secondaryButtonLabel: lang.tr(
                            'Create Practitioner Account',
                            '침술사 회원가입',
                          ),
                          onSecondaryPressed: () => Navigator.pushNamed(
                            context,
                            LoginScreen.routeName,
                            arguments: const {
                              'role': 'practitioner',
                              'loginMode': 'register',
                            },
                          ),
                        );
                        final patientCard = _RoleCard(
                          accent: AppTheme.copper,
                          accentSoft: AppTheme.blush,
                          icon: Icons.favorite_outline,
                          eyebrow: lang.tr('Patient', '환자'),
                          title: lang.tr('Patient Portal', '환자 포털'),
                          buttonLabel: lang.tr('Continue as Patient', '환자로 시작'),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            PatientBetaAuthScreen.routeName,
                          ),
                        );

                        if (!wide) {
                          return Column(
                            children: [
                              practitionerCard,
                              const SizedBox(height: 16),
                              patientCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: practitionerCard),
                            const SizedBox(width: 18),
                            Expanded(child: patientCard),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.accent,
    required this.accentSoft,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  final Color accent;
  final Color accentSoft;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, accentSoft.withValues(alpha: 0.55)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.58),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          if (secondaryButtonLabel != null && onSecondaryPressed != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondaryPressed,
                child: Text(secondaryButtonLabel!),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
