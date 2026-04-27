import 'package:flutter/material.dart';

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
  icon: Icons.space_dashboard_outlined,
  labelEn: 'Dashboard',
  labelKo: '대시보드',
  routeName: '/dashboard',
);

const List<PractitionerNavSpec> _analyticsNavSpecs = [
  PractitionerNavSpec(
    item: PractitionerNavItem.insights,
    icon: Icons.insights_outlined,
    labelEn: 'Insights',
    labelKo: '인사이트',
    routeName: '/insights',
  ),
  PractitionerNavSpec(
    item: PractitionerNavItem.symptomTrend,
    icon: Icons.show_chart,
    labelEn: 'Symptom Trends',
    labelKo: '증상 추세',
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

  static const double _sidebarWidth = 232;
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
              backgroundColor: AppTheme.pine,
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
                          setState(
                            () => _sidebarExpanded = !_sidebarExpanded,
                          );
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
  const _Sidebar({
    required this.currentItem,
    this.tools = const [],
  });

  final PractitionerNavItem currentItem;
  final List<PractitionerToolItem> tools;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.pine,
        border: Border(right: BorderSide(color: Color(0x33000000))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.tr('Test MVP', '테스트 MVP'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
                  const SizedBox(height: 14),
                  _SidebarSectionLabel(
                    label: AppLanguageController.instance.tr('Tools', '도구'),
                  ),
                  for (final tool in tools) _ToolTile(tool: tool),
                ],
                const SizedBox(height: 14),
                _SidebarSectionLabel(
                  label: AppLanguageController.instance.tr(
                    'Analytics',
                    '분석',
                  ),
                ),
                for (final spec in _analyticsNavSpecs)
                  _NavTile(
                    spec: spec,
                    selected: spec.item == currentItem,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: _SignOutTile(),
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
    final fg = Colors.white;
    final bg = selected
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(spec.icon, size: 18, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
          letterSpacing: 0.6,
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
    final fg = Colors.white;
    final bg = tool.active
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
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
                Icon(tool.icon, size: 17, color: fg.withValues(alpha: 0.9)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.tr(tool.labelEn, tool.labelKo),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.92),
                      fontWeight:
                          tool.active ? FontWeight.w700 : FontWeight.w500,
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
  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                lang.tr('Sign out', '로그아웃'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onToggleSidebar,
            icon: Icon(sidebarVisible ? Icons.menu_open : Icons.menu),
            tooltip: sidebarVisible
                ? lang.tr('Hide menu', '메뉴 숨기기')
                : lang.tr('Show menu', '메뉴 표시'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 12),
            ...actions,
          ],
        ],
      ),
    );
  }
}
