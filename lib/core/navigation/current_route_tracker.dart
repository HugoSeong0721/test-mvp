import 'package:flutter/material.dart';

class CurrentRouteTracker extends NavigatorObserver with ChangeNotifier {
  CurrentRouteTracker._();

  static final CurrentRouteTracker instance = CurrentRouteTracker._();
  static const Set<String> _launcherHiddenRoutes = {'/tester-feedback-inbox'};

  String _currentRouteName = '';
  bool _showLauncher = true;

  String get currentRouteName => _currentRouteName;
  bool get showLauncher => _showLauncher;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _applyRoute(route, fallbackRoute: previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _applyRoute(previousRoute, fallbackRoute: route);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _applyRoute(newRoute, fallbackRoute: oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _applyRoute(previousRoute, fallbackRoute: route);
    super.didRemove(route, previousRoute);
  }

  void _applyRoute(Route<dynamic>? route, {Route<dynamic>? fallbackRoute}) {
    final activeRoute = route ?? fallbackRoute;
    if (activeRoute == null) {
      return;
    }

    final isPopup = activeRoute is PopupRoute<dynamic>;
    final candidateName = activeRoute.settings.name?.trim() ?? '';

    if (!isPopup && candidateName.isNotEmpty) {
      _currentRouteName = candidateName;
    }
    _showLauncher =
        !isPopup && !_launcherHiddenRoutes.contains(_currentRouteName);
    notifyListeners();
  }
}
