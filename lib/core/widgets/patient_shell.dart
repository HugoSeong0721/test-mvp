import 'package:flutter/material.dart';

import '../settings/app_language_controller.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

enum PatientNavItem { home, intake, requests, history }

class PatientNavSpec {
  const PatientNavSpec({
    required this.item,
    required this.icon,
    required this.labelEn,
    required this.labelKo,
    required this.routeName,
  });

  final PatientNavItem item;
  final IconData icon;
  final String labelEn;
  final String labelKo;
  final String routeName;
}

const List<PatientNavSpec> kPatientNavSpecs = [
  PatientNavSpec(
    item: PatientNavItem.home,
    icon: Icons.home_rounded,
    labelEn: 'Home',
    labelKo: 'Home',
    routeName: '/patient-home',
  ),
  PatientNavSpec(
    item: PatientNavItem.requests,
    icon: Icons.chat_bubble_rounded,
    labelEn: 'Questions',
    labelKo: 'Questions',
    routeName: '/patient-requests',
  ),
];

class PatientShell extends StatelessWidget {
  const PatientShell({
    super.key,
    required this.currentItem,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
  });

  final PatientNavItem currentItem;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PatientHeader(
                title: title,
                subtitle: subtitle,
                actions: actions,
              ),
              Expanded(child: body),
              _PatientBottomNav(currentItem: currentItem),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.title,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLanguageController.instance;
    final compact = MediaQuery.sizeOf(context).width < 430;
    final visibleActions = compact ? actions.take(2).toList() : actions;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        compact ? 10 : 16,
        compact ? 12 : 20,
        compact ? 8 : 12,
      ),
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 42 : 50,
              height: compact ? 42 : 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.copper.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppTheme.copper,
                size: 24,
              ),
            ),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style:
                        (compact
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleLarge)
                            ?.copyWith(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.62),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (visibleActions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: visibleActions,
                ),
              ),
            ],
            IconButton(
              tooltip: lang.tr('Sign out', 'Sign out'),
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (_) => false),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientBottomNav extends StatelessWidget {
  const _PatientBottomNav({required this.currentItem});

  final PatientNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        4,
        compact ? 12 : 20,
        compact ? 10 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.ink,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final spec in kPatientNavSpecs)
              Expanded(
                child: _NavButton(
                  spec: spec,
                  selected: spec.item == currentItem,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.spec, required this.selected});

  final PatientNavSpec spec;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final label = lang.tr(spec.labelEn, spec.labelKo);
    final fg = selected ? AppTheme.ink : Colors.white.withValues(alpha: 0.74);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selected
              ? null
              : () =>
                    Navigator.of(context).pushReplacementNamed(spec.routeName),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: selected ? AppTheme.sun : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(spec.icon, size: 20, color: fg),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
