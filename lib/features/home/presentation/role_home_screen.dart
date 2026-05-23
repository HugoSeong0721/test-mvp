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
    final compact = MediaQuery.sizeOf(context).width < 430;

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
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 24,
                compact ? 8 : 16,
                compact ? 14 : 24,
                compact ? 18 : 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: compact ? 6 : 16),
                    AppPanel(
                      padding: EdgeInsets.all(compact ? 18 : 26),
                      radius: 16,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.mint.withValues(alpha: 0.95),
                          Colors.white,
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr(
                              'Simple patient-practitioner communication for TCM care.',
                              '클리닉 업무, 환자 준비, 베타 테스트를 한 곳에서 시작합니다.',
                            ),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            lang.tr(
                              'New patients receive baseline questions, reply from the portal, and each answer helps the practitioner refine the care picture over time.',
                              '필요한 작업 공간을 선택하세요. 클리닉 포털은 운영 업무, 환자 포털은 문진, 요청, 예약, 방문 기록을 위한 공간입니다.',
                            ),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.72),
                                ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusPill(
                                icon: Icons.event_available_outlined,
                                label: lang.tr('Schedule', '예약'),
                              ),
                              _StatusPill(
                                icon: Icons.assignment_outlined,
                                label: lang.tr('Intake', '문진'),
                              ),
                              _StatusPill(
                                icon: Icons.mark_email_unread_outlined,
                                label: lang.tr('Requests', '요청'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 720;
                        final practitionerCard = _RoleCard(
                          accent: AppTheme.pine,
                          accentSoft: AppTheme.mint,
                          icon: Icons.health_and_safety_outlined,
                          eyebrow: lang.tr('Practitioner', '침술사'),
                          title: lang.tr('Clinic Portal', '클리닉 포털'),
                          description: lang.tr(
                            'Send focused questions, review answers, and build a clearer TCM picture by patient.',
                            '오늘 업무를 확인하고, 환자 관리, 문진 요청, 클리닉별 예약을 처리합니다.',
                          ),
                          buttonLabel: lang.tr('Login', '로그인'),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            LoginScreen.routeName,
                            arguments: const {
                              'role': 'practitioner',
                              'loginMode': 'default',
                            },
                          ),
                          secondaryButtonLabel: lang.tr('Create', '가입'),
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
                          description: lang.tr(
                            'Receive questions, answer simply, and keep your practitioner updated between visits.',
                            '문진을 이어가고, 침술사 요청에 답하고, 예약과 방문 기록을 확인합니다.',
                          ),
                          buttonLabel: lang.tr('Login', '로그인'),
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
    required this.description,
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
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return AppPanel(
      padding: EdgeInsets.all(compact ? 18 : 24),
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
            width: compact ? 42 : 52,
            height: compact ? 42 : 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          SizedBox(height: compact ? 12 : 18),
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
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.68),
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          if (!compact &&
              secondaryButtonLabel != null &&
              onSecondaryPressed != null) ...[
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.pine),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
