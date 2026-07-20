import 'package:flutter/material.dart';

import '../services/practitioner_session_service.dart';
import '../settings/app_language_controller.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

enum PractitionerNavItem { dashboard, insights, symptomTrend }

class PractitionerNavSpec {
  const PractitionerNavSpec({
    required this.item,
    required this.icon,
    required this.labelEn,
    required this.labelKo,
    required this.routeName,
  });

  final PractitionerNavItem item;
  final IconData icon;
  final String labelEn;
  final String labelKo;
  final String routeName;
}

const PractitionerNavSpec _dashboardNavSpec = PractitionerNavSpec(
  item: PractitionerNavItem.dashboard,
  icon: Icons.forum_rounded,
  labelEn: 'Questions',
  labelKo: 'Questions',
  routeName: '/dashboard',
);

const List<PractitionerNavSpec> _analyticsNavSpecs = [
  PractitionerNavSpec(
    item: PractitionerNavItem.insights,
    icon: Icons.auto_graph_rounded,
    labelEn: 'Insights',
    labelKo: 'Insights',
    routeName: '/insights',
  ),
  PractitionerNavSpec(
    item: PractitionerNavItem.symptomTrend,
    icon: Icons.show_chart_rounded,
    labelEn: 'Trends',
    labelKo: 'Trends',
    routeName: '/symptom-trend',
  ),
];

const List<PractitionerNavSpec> kPractitionerNavSpecs = [
  _dashboardNavSpec,
  ..._analyticsNavSpecs,
];

class PractitionerToolItem {
  const PractitionerToolItem({
    required this.icon,
    required this.labelEn,
    required this.labelKo,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String labelEn;
  final String labelKo;
  final VoidCallback onTap;
  final bool active;
}

class PractitionerShell extends StatefulWidget {
  const PractitionerShell({
    super.key,
    required this.currentItem,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.tools = const [],
  });

  final PractitionerNavItem currentItem;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<PractitionerToolItem> tools;
  final Widget body;

  static const double _sidebarWidth = 236;
  static const double _wideBreakpoint = 1100;
  static const Duration _animationDuration = Duration(milliseconds: 220);

  @override
  State<PractitionerShell> createState() => _PractitionerShellState();
}

class _PractitionerShellState extends State<PractitionerShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= PractitionerShell._wideBreakpoint;
    final showSidebar = wide && _sidebarExpanded;

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AppTheme.ink,
              child: SafeArea(
                child: _Sidebar(
                  currentItem: widget.currentItem,
                  tools: widget.tools,
                ),
              ),
            ),
      body: AppBackdrop(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: PractitionerShell._animationDuration,
                curve: Curves.easeInOut,
                width: showSidebar ? PractitionerShell._sidebarWidth : 0,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: PractitionerShell._sidebarWidth,
                    maxWidth: PractitionerShell._sidebarWidth,
                    alignment: Alignment.centerLeft,
                    child: _Sidebar(
                      currentItem: widget.currentItem,
                      tools: widget.tools,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      actions: widget.actions,
                      onToggleSidebar: () {
                        if (wide) {
                          setState(() => _sidebarExpanded = !_sidebarExpanded);
                        } else {
                          _scaffoldKey.currentState?.openDrawer();
                        }
                      },
                      sidebarVisible: showSidebar,
                    ),
                    Expanded(child: widget.body),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentItem, this.tools = const []});

  final PractitionerNavItem currentItem;
  final List<PractitionerToolItem> tools;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.ink, AppTheme.pine, AppTheme.sky],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarBrand(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.checklist_rtl_rounded,
                    color: AppTheme.sun,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Send basic 10. Read replies. Refine TCM view.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _NavTile(
                  spec: _dashboardNavSpec,
                  selected: _dashboardNavSpec.item == currentItem,
                ),
                if (tools.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SidebarSectionLabel(label: 'Work'),
                  for (final tool in tools) _ToolTile(tool: tool),
                ],
                const SizedBox(height: 16),
                const _SidebarSectionLabel(label: 'Later'),
                for (final spec in _analyticsNavSpecs)
                  _NavTile(spec: spec, selected: spec.item == currentItem),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: _SignOutTile(),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.sun,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spa_rounded, color: AppTheme.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.tr('Care Chat', 'Care Chat'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Practitioner',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.spec, required this.selected});

  final PractitionerNavSpec spec;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final label = lang.tr(spec.labelEn, spec.labelKo);
    final fg = selected ? AppTheme.ink : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppTheme.sun : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selected
              ? null
              : () {
                  if (Scaffold.of(context).hasDrawer &&
                      Scaffold.of(context).isDrawerOpen) {
                    Navigator.of(context).pop();
                  }
                  Navigator.of(context).pushReplacementNamed(spec.routeName);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(spec.icon, size: 18, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
          letterSpacing: 0,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final PractitionerToolItem tool;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final fg = tool.active ? AppTheme.ink : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: tool.active ? AppTheme.sun : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (Scaffold.of(context).hasDrawer &&
                Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
            tool.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(tool.icon, size: 17, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.tr(tool.labelEn, tool.labelKo),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: tool.active
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _SignOutTile extends StatelessWidget {
  const _SignOutTile();

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await PractitionerSessionService.signOut();
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                lang.tr('Sign out', 'Sign out'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.actions,
    required this.onToggleSidebar,
    required this.sidebarVisible,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback onToggleSidebar;
  final bool sidebarVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLanguageController.instance;
    final compact = MediaQuery.sizeOf(context).width < 430;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 16,
        compact ? 10 : 16,
        compact ? 10 : 16,
        compact ? 8 : 10,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onToggleSidebar,
              icon: Icon(sidebarVisible ? Icons.menu_open : Icons.menu),
              tooltip: sidebarVisible
                  ? lang.tr('Hide menu', 'Hide menu')
                  : lang.tr('Show menu', 'Show menu'),
            ),
            if (!compact) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
              const SizedBox(width: 12),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
