import 'package:flutter/material.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/role_home_screen.dart';
import 'features/insights/presentation/practitioner_insights_screen.dart';
import 'features/patient_brief/presentation/patient_brief_screen.dart';
import 'features/patient_intake/presentation/patient_intake_screen.dart';
import 'features/practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';

class TestMvpApp extends StatelessWidget {
  const TestMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      initialRoute: RoleHomeScreen.routeName,
      routes: {
        RoleHomeScreen.routeName: (_) => const RoleHomeScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        PatientIntakeScreen.routeName: (_) => const PatientIntakeScreen(),
        PractitionerDashboardScreen.routeName: (_) =>
            const PractitionerDashboardScreen(),
        PractitionerInsightsScreen.routeName: (_) =>
            const PractitionerInsightsScreen(),
        PatientBriefScreen.routeName: (_) => const PatientBriefScreen(),
      },
    );
  }
}
