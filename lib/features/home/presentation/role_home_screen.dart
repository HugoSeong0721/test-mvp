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
    final compact = MediaQuery.sizeOf(context).width < 520;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeTopBar(lang: lang),
                    SizedBox(height: compact ? 18 : 30),
                    _HeroBand(compact: compact),
                    SizedBox(height: compact ? 14 : 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final cards = [
                          _RoleCard(
                            accent: AppTheme.copper,
                            tint: AppTheme.blush,
                            icon: Icons.favorite_rounded,
                            label: lang.tr('Patient', 'Patient'),
                            title: lang.tr(
                              'Get my questions',
                              'Get my questions',
                            ),
                            points: const [
                              'Join',
                              'Pick clinic',
                              'Answer clearly',
                            ],
                            primary: lang.tr('Patient start', 'Patient start'),
                            onPrimary: () => Navigator.pushNamed(
                              context,
                              PatientBetaAuthScreen.routeName,
                            ),
                          ),
                          _RoleCard(
                            accent: AppTheme.pine,
                            tint: AppTheme.mint,
                            icon: Icons.forum_rounded,
                            label: lang.tr('Practitioner', 'Practitioner'),
                            title: lang.tr(
                              'Send and review',
                              'Send and review',
                            ),
                            points: const [
                              'Send basic 10',
                              'Read replies',
                              'Build TCM view',
                            ],
                            primary: lang.tr(
                              'Practitioner login',
                              'Practitioner login',
                            ),
                            secondary: lang.tr(
                              'Create account',
                              'Create account',
                            ),
                            onPrimary: () => Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {
                                'role': 'practitioner',
                                'loginMode': 'default',
                              },
                            ),
                            onSecondary: () => Navigator.pushNamed(
                              context,
                              LoginScreen.routeName,
                              arguments: const {
                                'role': 'practitioner',
                                'loginMode': 'register',
                              },
                            ),
                          ),
                        ];

                        if (!wide) {
                          return Column(
                            children: [
                              cards.first,
                              const SizedBox(height: 12),
                              cards.last,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards.first),
                            const SizedBox(width: 14),
                            Expanded(child: cards.last),
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

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.lang});

  final AppLanguageController lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.spa_rounded, color: AppTheme.sun),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            lang.tr('Care Chat', 'Care Chat'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const LanguageMenuButton(),
      ],
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      padding: EdgeInsets.all(compact ? 18 : 30),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.ink, AppTheme.pine, AppTheme.sky],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.sun,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TCM conversation first',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Questions in. Answers back. Care picture sharper.',
                  style:
                      (compact
                              ? theme.textTheme.displaySmall
                              : theme.textTheme.displayMedium)
                          ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'New patients get the basic 10. Practitioners read replies and keep refining the TCM view over time.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 28),
            const _ConversationPreview(),
          ],
        ],
      ),
    );
  }
}

class _ConversationPreview extends StatelessWidget {
  const _ConversationPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        children: const [
          _Bubble(text: 'How is your sleep recently?', alignRight: false),
          SizedBox(height: 10),
          _Bubble(text: 'Light sleep, wakes around 3am.', alignRight: true),
          SizedBox(height: 10),
          _Bubble(
            text: 'Pattern note: sleep + age + habits',
            alignRight: false,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.alignRight});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: alignRight ? AppTheme.sun : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.accent,
    required this.tint,
    required this.icon,
    required this.label,
    required this.title,
    required this.points,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final Color accent;
  final Color tint;
  final IconData icon;
  final String label;
  final String title;
  final List<String> points;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return AppPanel(
      padding: EdgeInsets.all(compact ? 16 : 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, tint.withValues(alpha: 0.78)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final point in points)
                _PointChip(label: point, color: accent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(backgroundColor: accent),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(primary),
            ),
          ),
          if (secondary != null && onSecondary != null) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondary!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  const _PointChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
