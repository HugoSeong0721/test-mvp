import 'package:flutter/material.dart';
import 'package:iottie_automation/features/patient_requests/presentation/patient_requests_screen.dart';
import 'package:iottie_automation/features/visit_history/presentation/visit_history_screen.dart';

import 'core/navigation/current_route_tracker.dart';
import 'core/services/beta_session_service.dart';
import 'core/services/practitioner_session_service.dart';
import 'core/settings/app_language_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/tester_feedback_launcher.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/patient_beta_auth_screen.dart';
import 'features/home/presentation/role_home_screen.dart';
import 'features/insights/presentation/practitioner_insights_screen.dart';
import 'features/patient_brief/presentation/patient_brief_screen.dart';
import 'features/patient_home/presentation/patient_home_screen.dart';
import 'features/patient_intake/presentation/patient_intake_screen.dart';
import 'features/practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';
import 'features/symptom_trend/presentation/symptom_trend_screen.dart';
import 'features/tester_feedback/presentation/tester_feedback_inbox_screen.dart';

class TestMvpApp extends StatelessWidget {
  const TestMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: lang.tr('Test MVP', '테스트 MVP'),
          theme: AppTheme.light(),
          navigatorObservers: [CurrentRouteTracker.instance],
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const TesterFeedbackLauncher(),
              ],
            );
          },
          initialRoute: RoleHomeScreen.routeName,
          routes: {
            RoleHomeScreen.routeName: (_) => const RoleHomeScreen(),
            LoginScreen.routeName: (_) => const LoginScreen(),
            PatientBetaAuthScreen.routeName: (_) =>
                const PatientBetaAuthScreen(),
            PatientHomeScreen.routeName: (_) => const _PatientRouteGuard(
              child: PatientHomeScreen(),
            ),
            PatientIntakeScreen.routeName: (_) => const _PatientRouteGuard(
              child: PatientIntakeScreen(),
            ),
            PatientRequestsScreen.routeName: (_) => const _PatientRouteGuard(
              child: PatientRequestsScreen(),
            ),
            VisitHistoryScreen.routeName: (_) => const _PatientRouteGuard(
              child: VisitHistoryScreen(),
            ),
            PractitionerDashboardScreen.routeName: (_) =>
                const _PractitionerRouteGuard(
                  child: PractitionerDashboardScreen(),
                ),
            PractitionerInsightsScreen.routeName: (_) =>
                const _PractitionerRouteGuard(
                  child: PractitionerInsightsScreen(),
                ),
            SymptomTrendScreen.routeName: (_) =>
                const _PractitionerRouteGuard(child: SymptomTrendScreen()),
            PatientBriefScreen.routeName: (_) => const PatientBriefScreen(),
            TesterFeedbackInboxScreen.routeName: (_) =>
                const TesterFeedbackInboxScreen(),
          },
          onGenerateRoute: (settings) {
            // Shareable shortcut URLs that go straight to a single role.
            // /clinic  -> practitioner login
            // /patient -> patient sign-up / login (absorbs the old beta flow)
            final rawName = settings.name;
            if (rawName == null || rawName.trim().isEmpty) {
              return null;
            }
            final uri = Uri.tryParse(rawName);
            final path = uri?.path ?? rawName;
            final existingArgs = settings.arguments is Map
                ? Map<String, dynamic>.from(settings.arguments! as Map)
                : null;
            final linkedClinicArg = uri?.queryParameters['clinic'];
            final routeArgs = <String, dynamic>{
              ...?existingArgs,
              ...?linkedClinicArg == null
                  ? null
                  : <String, dynamic>{'clinicId': linkedClinicArg},
            };
            switch (path) {
              case '/clinic':
                return MaterialPageRoute<void>(
                  settings: RouteSettings(
                    name: '/clinic',
                    arguments: {
                      'role': 'practitioner',
                      'loginMode': 'default',
                      ...routeArgs,
                    },
                  ),
                  builder: (_) => const LoginScreen(),
                );
              case '/patient':
                return MaterialPageRoute<void>(
                  settings: RouteSettings(name: '/patient', arguments: routeArgs),
                  builder: (_) => const PatientBetaAuthScreen(),
                );
            }
            return null;
          },
        );
      },
    );
  }
}

class _PatientRouteGuard extends StatefulWidget {
  const _PatientRouteGuard({required this.child});

  final Widget child;

  @override
  State<_PatientRouteGuard> createState() => _PatientRouteGuardState();
}

class _PatientRouteGuardState extends State<_PatientRouteGuard> {
  bool _initialized = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _initializeGuard();
  }

  Future<void> _initializeGuard() async {
    await BetaSessionService.initialize();
    if (!mounted) {
      return;
    }
    setState(() => _initialized = true);
  }

  void _redirectToPatientLogin() {
    if (_redirecting || !mounted) {
      return;
    }
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        PatientBetaAuthScreen.routeName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _GuardLoadingScreen();
    }

    if (BetaSessionService.currentSession == null) {
      _redirectToPatientLogin();
      return const _GuardLoadingScreen();
    }

    return widget.child;
  }
}

class _PractitionerRouteGuard extends StatefulWidget {
  const _PractitionerRouteGuard({required this.child});

  final Widget child;

  @override
  State<_PractitionerRouteGuard> createState() => _PractitionerRouteGuardState();
}

class _PractitionerRouteGuardState extends State<_PractitionerRouteGuard> {
  bool _initialized = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _initializeGuard();
  }

  Future<void> _initializeGuard() async {
    await PractitionerSessionService.initialize();
    if (!mounted) {
      return;
    }
    setState(() => _initialized = true);
  }

  void _redirectToPractitionerLogin() {
    if (_redirecting || !mounted) {
      return;
    }
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        LoginScreen.routeName,
        arguments: const {'role': 'practitioner', 'loginMode': 'default'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _GuardLoadingScreen();
    }

    if (PractitionerSessionService.currentSession == null) {
      _redirectToPractitionerLogin();
      return const _GuardLoadingScreen();
    }

    return widget.child;
  }
}

class _GuardLoadingScreen extends StatelessWidget {
  const _GuardLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}
