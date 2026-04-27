import 'package:flutter/material.dart';
import 'package:iottie_automation/features/patient_requests/presentation/patient_requests_screen.dart';
import 'package:iottie_automation/features/visit_history/presentation/visit_history_screen.dart';

import 'core/navigation/current_route_tracker.dart';
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
            PatientHomeScreen.routeName: (_) => const PatientHomeScreen(),
            PatientIntakeScreen.routeName: (_) => const PatientIntakeScreen(),
            PatientRequestsScreen.routeName: (_) =>
                const PatientRequestsScreen(),
            VisitHistoryScreen.routeName: (_) => const VisitHistoryScreen(),
            PractitionerDashboardScreen.routeName: (_) =>
                const PractitionerDashboardScreen(),
            PractitionerInsightsScreen.routeName: (_) =>
                const PractitionerInsightsScreen(),
            SymptomTrendScreen.routeName: (_) => const SymptomTrendScreen(),
            PatientBriefScreen.routeName: (_) => const PatientBriefScreen(),
            TesterFeedbackInboxScreen.routeName: (_) =>
                const TesterFeedbackInboxScreen(),
          },
          onGenerateRoute: (settings) {
            // Shareable shortcut URLs that go straight to a single role.
            // /clinic  -> practitioner login
            // /patient -> patient sign-up / login (absorbs the old beta flow)
            switch (settings.name) {
              case '/clinic':
                return MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: '/clinic',
                    arguments: {
                      'role': 'practitioner',
                      'loginMode': 'default',
                    },
                  ),
                  builder: (_) => const LoginScreen(),
                );
              case '/patient':
                return MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/patient'),
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
