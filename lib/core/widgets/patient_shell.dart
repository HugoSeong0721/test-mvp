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
    icon: Icons.home_outlined,
    labelEn: 'Home',
    labelKo: 'Home',
    routeName: '/patient-home',
  ),
  PatientNavSpec(
    item: PatientNavItem.intake,
    icon: Icons.assignment_outlined,
    labelEn: 'Questions',
    labelKo: 'Questions',
    routeName: '/intake',
  ),
  PatientNavSpec(
    item: PatientNavItem.requests,
    icon: Icons.mail_outline,
    labelEn: 'Messages',
    labelKo: 'Messages',
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
              _Header(title: title, subtitle: subtitle, actions: actions),
              _TabBar(currentItem: currentItem),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.actions, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLanguageController.instance;
    final compact = MediaQuery.sizeOf(context).width < 430;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 6 : 10, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          if (!compact)
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.copper.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_outline,
                color: AppTheme.copper,
                size: 18,
              ),
            ),
          if (!compact) const SizedBox(width: 12),
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
                          ?.copyWith(fontWeight: FontWeight.w700),
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
          if (!compact && actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                children: actions,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (!compact)
            IconButton(
              tooltip: lang.tr('Sign out', '로그아웃'),
              visualDensity: VisualDensity.standard,
              onPressed: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (_) => false),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentItem});

  final PatientNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.4)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        child: Row(
          children: [
            for (final spec in kPatientNavSpecs)
              _TabButton(spec: spec, selected: spec.item == currentItem),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.selected});

  final PatientNavSpec spec;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final label = lang.tr(spec.labelEn, spec.labelKo);
    final compact = MediaQuery.sizeOf(context).width < 430;
    final fg = selected
        ? AppTheme.copper
        : AppTheme.ink.withValues(alpha: 0.62);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: selected
            ? null
            : () => Navigator.of(context).pushReplacementNamed(spec.routeName),
        child: Container(
          width: compact ? 110 : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppTheme.copper : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(spec.icon, size: 18, color: fg),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(spec.icon, size: 17, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
