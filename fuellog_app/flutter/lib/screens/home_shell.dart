import 'package:flutter/material.dart';

import '../core/ads.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'charts_tab.dart';
import 'log_tab.dart';
import 'more_tab.dart';
import 'reminders_tab.dart';
import 'vehicles_screen.dart';

/// 아래 탭 4개 (Log · Charts · Reminders · More) + 위 차량 고르기 + 탭 위 배너.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// 다른 화면에서 탭을 바꿀 때 (예: 기록 탭의 '곧 할 정비' → 알림 탭)
  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_HomeShellState>()?.setTab(tab);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _noticeShown = false;

  void setTab(int t) => setState(() => _tab = t);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = AppStore.i.loadNotice;
      if (n != null && !_noticeShown && mounted) {
        _noticeShown = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n)));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 하루가 지나 돌아오면 '며칠 남음'·알림 예약을 다시 계산
    if (state == AppLifecycleState.resumed) AppStore.i.refresh();
  }

  @override
  // 저장소가 바뀔 때마다 다시 그린다 (const 로 만든 탭은 부모가 다시 그려져도 안 그려진다)
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final due = s.dueReminders.length;
    const titles = ['Log', 'Charts', 'Reminders', 'More'];
    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(toolbarHeight: 52, title: _tab == 3 ? const Text('More') : _VehicleButton(title: titles[_tab])),
      body: IndexedStack(index: _tab, children: const [LogTab(), ChartsTab(), RemindersTab(), MoreTab()]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(color: tk.bg, child: Ads.i.banner()),
          NavigationBar(
            key: const Key('nav'),
            selectedIndex: _tab,
            onDestinationSelected: setTab,
            destinations: [
              const NavigationDestination(
                key: Key('tab-log'),
                icon: Icon(Icons.local_gas_station_outlined),
                selectedIcon: Icon(Icons.local_gas_station_rounded),
                label: 'Log',
              ),
              const NavigationDestination(
                key: Key('tab-charts'),
                icon: Icon(Icons.show_chart_rounded),
                label: 'Charts',
              ),
              NavigationDestination(
                key: const Key('tab-reminders'),
                icon: Badge(
                  isLabelVisible: due > 0,
                  label: Text('$due'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: due > 0,
                  label: Text('$due'),
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: 'Reminders',
              ),
              const NavigationDestination(key: Key('tab-more'), icon: Icon(Icons.more_horiz_rounded), label: 'More'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 제목 자리의 "2019 Honda Civic ▾" — 누르면 차량 고르기.
class _VehicleButton extends StatelessWidget {
  const _VehicleButton({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final v = AppStore.i.vehicle;
    return Semantics(
      button: true,
      label: 'Vehicle: ${v?.name ?? ''}. Change vehicle',
      excludeSemantics: true,
      // 앱 바 제목(머리글)에 합쳐지지 않게 따로 + 누르기 동작
      container: true,
      onTap: () => showVehiclePicker(context),
      child: InkWell(
        key: const Key('vehicle-switch'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => showVehiclePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  v?.name ?? title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tk.text),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, color: tk.text2),
            ],
          ),
        ),
      ),
    );
  }
}
