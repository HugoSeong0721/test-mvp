import 'package:flutter/material.dart';

import '../../../core/data/clinic_data_store.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../home/presentation/role_home_screen.dart';
import '../../patient_home/presentation/patient_home_screen.dart';
import '../../practitioner_dashboard/presentation/practitioner_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _sharedTestId = '123';
  static const _sharedTestPassword = '123';
  static const _hugoId = 'hugo';
  static const _hugoPassword = 'hugo';

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _applyCredentials(String id, String password) {
    _idController.text = id;
    _passwordController.text = password;
  }

  void _submit(String role) {
    final lang = AppLanguageController.instance;
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    final isPractitionerLogin =
        role == 'practitioner' &&
        id == _sharedTestId &&
        password == _sharedTestPassword;

    final isPatientDefaultLogin =
        role == 'patient' &&
        id == _sharedTestId &&
        password == _sharedTestPassword;

    final isPatientHugoLogin =
        role == 'patient' && id == _hugoId && password == _hugoPassword;

    if (!isPractitionerLogin && !isPatientDefaultLogin && !isPatientHugoLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'The ID or password is incorrect.',
              '아이디 또는 비밀번호가 올바르지 않습니다.',
            ),
          ),
        ),
      );
      return;
    }

    if (isPractitionerLogin) {
      Navigator.pushReplacementNamed(
        context,
        PractitionerDashboardScreen.routeName,
      );
      return;
    }

    if (isPatientHugoLogin) {
      ClinicDataStore.instance.setCurrentPatientProfile('hugo_demo');
    } else {
      ClinicDataStore.instance.setCurrentPatientProfile('jane_kim');
    }

    Navigator.pushReplacementNamed(context, PatientHomeScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    String role = 'patient';
    if (routeArgs is Map) {
      role = (routeArgs['role'] as String?) ?? 'patient';
    } else if (routeArgs is String) {
      role = routeArgs;
    }

    final isPractitioner = role == 'practitioner';
    final accent = isPractitioner ? AppTheme.pine : AppTheme.copper;
    final accentSoft = isPractitioner
        ? AppTheme.mint.withValues(alpha: 0.82)
        : const Color(0xFFF1E0CE);

    final roleLabel = isPractitioner
        ? lang.tr('Practitioner', '침술사')
        : lang.tr('Patient', '환자');
    final portalLabel = isPractitioner
        ? lang.tr('Clinic-side portal', '클리닉 포털')
        : lang.tr('Patient-side portal', '환자 포털');
    final destinationLabel = isPractitioner
        ? lang.tr('Practitioner dashboard', '침술사 대시보드')
        : lang.tr('Patient command center', '환자 시작 허브');
    final firstReviewLabel = isPractitioner
        ? lang.tr('Check the active visit window first', '활성 방문 구간부터 확인')
        : lang.tr(
            'Open requests or continue intake first',
            '요청 확인 또는 문진 이어쓰기부터 시작',
          );
    final helperText = isPractitioner
        ? lang.tr('Shared credentials: 123 / 123', '공유 계정: 123 / 123')
        : lang.tr(
            'Shared credentials: 123 / 123 or hugo / hugo',
            '공유 계정: 123 / 123 또는 hugo / hugo',
          );

    final heroTitle = isPractitioner
        ? lang.tr(
            'Clinic access that feels closer to Jane or Healthie than a raw prototype login',
            '초기 프로토타입 로그인보다 Jane, Healthie 같은 클리닉 포털에 더 가까운 진입 화면',
          )
        : lang.tr(
            'Patient access that explains the portal before asking for credentials',
            '계정부터 묻기 전에 환자 포털이 무엇인지 먼저 설명해주는 진입 화면',
          );

    final heroBody = isPractitioner
        ? lang.tr(
            'Competitor clinic products frame the visit window, patient review path, and operational next step before the user enters credentials. This screen now follows that same structure.',
            '경쟁사 클리닉 제품은 계정 입력 전에 오늘의 방문 구간, 환자 검토 경로, 다음 운영 행동을 먼저 보여줍니다. 이 화면도 같은 순서로 정리했습니다.',
          )
        : lang.tr(
            'Competitor patient portals reduce confusion by showing which account to use, what opens next, and what the first task will be after entry. This screen now follows the same pattern.',
            '경쟁사 환자 포털은 어떤 계정을 써야 하는지, 로그인 후 어디가 열리는지, 처음 무엇을 해야 하는지를 먼저 보여줘서 혼란을 줄입니다. 이 화면도 같은 흐름으로 바꿨습니다.',
          );

    final startSteps = isPractitioner
        ? [
            AppGuideStep(
              step: '1',
              title: lang.tr('Use the clinic demo account', '클리닉 데모 계정 사용'),
              description: lang.tr(
                'Choose the shared practitioner account and open the dashboard-first review flow.',
                '공유된 침술사 계정을 선택해 대시보드 중심 검토 흐름으로 바로 들어갑니다.',
              ),
            ),
            AppGuideStep(
              step: '2',
              title: lang.tr('Review the current visit window', '현재 방문 구간 확인'),
              description: lang.tr(
                'The dashboard opens with schedule visibility, patient filters, and work-in-progress cards near the top.',
                '대시보드는 일정 가시성, 환자 필터, 진행 중 환자 카드가 상단에 먼저 보이도록 열립니다.',
              ),
            ),
            AppGuideStep(
              step: '3',
              title: lang.tr('Open a patient flow', '환자 흐름 열기'),
              description: lang.tr(
                'Move into patient brief, requests, and intake review without losing the dashboard context.',
                '대시보드 맥락을 유지한 채 환자 브리프, 요청, 문진 검토로 이어서 이동합니다.',
              ),
            ),
          ]
        : [
            AppGuideStep(
              step: '1',
              title: lang.tr('Choose the right demo account', '맞는 데모 계정 선택'),
              description: lang.tr(
                'Use the sample patient for general portal review or Hugo for the personal demo flow.',
                '일반 포털 검토는 샘플 환자를, 개인 데모 흐름은 Hugo 계정을 사용합니다.',
              ),
            ),
            AppGuideStep(
              step: '2',
              title: lang.tr('Land in patient home', '환자 홈으로 진입'),
              description: lang.tr(
                'You arrive in a patient command center, not a blank prototype page.',
                '빈 시제품 화면이 아니라 patient command center 형태의 홈으로 들어갑니다.',
              ),
            ),
            AppGuideStep(
              step: '3',
              title: lang.tr('Continue from the top section', '상단 안내부터 이어가기'),
              description: lang.tr(
                'Requests, intake, schedule, and visit history are organized in a clear top-down order.',
                '요청, 문진, 일정, 방문 기록이 위에서 아래로 명확하게 정리되어 있습니다.',
              ),
            ),
          ];

    final previewItems = isPractitioner
        ? [
            _PortalPreviewItem(
              icon: Icons.event_available_outlined,
              title: lang.tr('Today\'s operating window', '오늘 운영 구간'),
              description: lang.tr(
                'Daily visit window, shared slots, and schedule availability appear near the top.',
                '일일 방문 구간, 공유 슬롯, 일정 가시성이 상단에 먼저 보입니다.',
              ),
            ),
            _PortalPreviewItem(
              icon: Icons.groups_outlined,
              title: lang.tr('Patient cards with context', '맥락이 있는 환자 카드'),
              description: lang.tr(
                'Each card leads into patient brief, requests, and intake review with context still visible.',
                '각 카드에서 맥락을 잃지 않고 환자 브리프, 요청, 문진 검토로 이동할 수 있습니다.',
              ),
            ),
            _PortalPreviewItem(
              icon: Icons.rate_review_outlined,
              title: lang.tr('Action-first workflow', '행동 우선 워크플로'),
              description: lang.tr(
                'Operations, follow-up tasks, and drill-down screens are placed before archive-style detail.',
                '운영 작업, 후속 조치, 상세 진입이 기록성 정보보다 먼저 배치되어 있습니다.',
              ),
            ),
          ]
        : [
            _PortalPreviewItem(
              icon: Icons.home_outlined,
              title: lang.tr('Patient command center', '환자 command center'),
              description: lang.tr(
                'The home screen explains what is waiting and what to do first before dense forms appear.',
                '복잡한 폼이 나오기 전에 무엇이 기다리고 있고 무엇부터 해야 하는지 홈에서 먼저 설명합니다.',
              ),
            ),
            _PortalPreviewItem(
              icon: Icons.inventory_2_outlined,
              title: lang.tr('Requests and intake first', '요청과 문진 우선'),
              description: lang.tr(
                'Requests, intake continuation, and the next visit stay above lower-priority history.',
                '요청, 문진 이어쓰기, 다음 방문 정보가 우선순위가 낮은 기록보다 위에 배치됩니다.',
              ),
            ),
            _PortalPreviewItem(
              icon: Icons.badge_outlined,
              title: lang.tr('Two clear demo paths', '두 가지 데모 경로'),
              description: lang.tr(
                'Sample patient and Hugo demo accounts let you compare a shared flow and a personal flow.',
                '샘플 환자와 Hugo 데모 계정으로 공용 흐름과 개인 흐름을 비교해 볼 수 있습니다.',
              ),
            ),
          ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(lang.tr('Login', '로그인')),
        actions: const [LanguageMenuButton()],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 940;

                    final story = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKicker(context, portalLabel),
                        const SizedBox(height: 22),
                        Text(
                          heroTitle,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 590),
                          child: Text(
                            heroBody,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.78),
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            AppMetricChip(
                              icon: isPractitioner
                                  ? Icons.health_and_safety_outlined
                                  : Icons.favorite_border,
                              label: lang.tr('Portal', '포털'),
                              value: roleLabel,
                              backgroundColor: accentSoft,
                              valueColor: accent,
                            ),
                            AppMetricChip(
                              icon: Icons.arrow_forward_outlined,
                              label: lang.tr('After login', '로그인 후'),
                              value: destinationLabel,
                            ),
                            AppMetricChip(
                              icon: Icons.check_circle_outline,
                              label: lang.tr('Start with', '먼저 볼 것'),
                              value: firstReviewLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        AppPanel(
                          padding: const EdgeInsets.all(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              accentSoft.withValues(alpha: 0.72),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Start here', '여기부터 시작'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: startSteps,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppPanel(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.tr('Portal preview', '포털 미리보기'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 14),
                              for (final item in previewItems)
                                _buildPreviewRow(context, item: item),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Text(
                                  isPractitioner
                                      ? lang.tr(
                                          'This page is meant to feel like a real clinic portal entry, not a dev-only switchboard.',
                                          '이 화면은 개발용 스위치보드가 아니라 실제 클리닉 포털 입구처럼 느껴지도록 구성했습니다.',
                                        )
                                      : lang.tr(
                                          'This page is meant to answer first-use questions before patients touch a dense portal workflow.',
                                          '이 화면은 환자가 복잡한 포털 흐름에 들어가기 전에 먼저 궁금해할 내용을 위에서부터 답해주도록 구성했습니다.',
                                        ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final form = AppPanel(
                      padding: const EdgeInsets.all(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFDFCFA), Color(0xFFEEE4D6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lang.tr('Portal access', '포털 접근'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.62),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            lang.tr('$roleLabel Login', '$roleLabel 로그인'),
                            textAlign: wide ? TextAlign.left : TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isPractitioner
                                ? lang.tr(
                                    'Quick actions appear before the form so you can see the route, choose the right account, and understand what will open next.',
                                    '폼보다 빠른 행동이 먼저 보이도록 구성해서 어떤 경로인지, 어떤 계정을 쓸지, 다음에 무엇이 열리는지 먼저 확인할 수 있습니다.',
                                  )
                                : lang.tr(
                                    'Pick the right demo path first, then use the form only as the last step into the portal.',
                                    '먼저 맞는 데모 경로를 고른 뒤, 마지막 단계로만 폼을 사용해 포털로 들어가도록 구성했습니다.',
                                  ),
                            textAlign: wide ? TextAlign.left : TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.72),
                                ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr('Route snapshot', '경로 요약'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _buildMiniSnapshot(
                                      context,
                                      label: lang.tr('Account', '계정'),
                                      value: isPractitioner
                                          ? lang.tr('Clinic demo', '클리닉 데모')
                                          : lang.tr(
                                              'Sample or Hugo demo',
                                              '샘플 또는 Hugo 데모',
                                            ),
                                    ),
                                    _buildMiniSnapshot(
                                      context,
                                      label: lang.tr('Destination', '진입 화면'),
                                      value: destinationLabel,
                                    ),
                                    _buildMiniSnapshot(
                                      context,
                                      label: lang.tr('First step', '첫 단계'),
                                      value: firstReviewLabel,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: accentSoft.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr('Quick access', '빠른 계정 선택'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lang.tr(
                                    'Choose an account first, then the form fields will already be filled in.',
                                    '먼저 계정을 고르면 아래 로그인 입력란이 바로 채워집니다.',
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: isPractitioner
                                      ? [
                                          _buildQuickAccessCard(
                                            context,
                                            accent: accent,
                                            icon: Icons.monitor_heart_outlined,
                                            title: lang.tr(
                                              'Clinic Demo',
                                              '클리닉 데모',
                                            ),
                                            subtitle: lang.tr(
                                              'Shared account 123 / 123',
                                              '공유 계정 123 / 123',
                                            ),
                                            note: lang.tr(
                                              'Recommended first route',
                                              '가장 먼저 보기 좋은 경로',
                                            ),
                                            highlighted: true,
                                            onPressed: () => _applyCredentials(
                                              _sharedTestId,
                                              _sharedTestPassword,
                                            ),
                                          ),
                                        ]
                                      : [
                                          _buildQuickAccessCard(
                                            context,
                                            accent: accent,
                                            icon: Icons.favorite_border,
                                            title: lang.tr(
                                              'Sample Patient',
                                              '샘플 환자',
                                            ),
                                            subtitle: lang.tr(
                                              'Shared account 123 / 123',
                                              '공유 계정 123 / 123',
                                            ),
                                            note: lang.tr(
                                              'Best for general portal review',
                                              '일반 포털 검토용',
                                            ),
                                            highlighted: true,
                                            onPressed: () => _applyCredentials(
                                              _sharedTestId,
                                              _sharedTestPassword,
                                            ),
                                          ),
                                          _buildQuickAccessCard(
                                            context,
                                            accent: accent,
                                            icon: Icons.face_4_outlined,
                                            title: lang.tr(
                                              'Hugo Demo',
                                              'Hugo 데모',
                                            ),
                                            subtitle: lang.tr(
                                              'Shared account hugo / hugo',
                                              '공유 계정 hugo / hugo',
                                            ),
                                            note: lang.tr(
                                              'Best for personal-path review',
                                              '개인 경로 검토용',
                                            ),
                                            onPressed: () => _applyCredentials(
                                              _hugoId,
                                              _hugoPassword,
                                            ),
                                          ),
                                        ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr('Shared credentials', '공유 계정 정보'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  helperText,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isPractitioner
                                      ? lang.tr(
                                          'Recommended first: open the dashboard, review the visit window, then drill into patient detail.',
                                          '추천 시작 순서: 대시보드 진입 -> 방문 구간 확인 -> 환자 상세 진입',
                                        )
                                      : lang.tr(
                                          'Recommended first: open the sample patient path, then compare it with the Hugo demo path.',
                                          '추천 시작 순서: 샘플 환자 경로 확인 -> Hugo 데모 경로와 비교',
                                        ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.ink.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _idController,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _submit(role),
                            decoration: InputDecoration(
                              labelText: lang.tr('ID', '아이디'),
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(role),
                            decoration: InputDecoration(
                              labelText: lang.tr('Password', '비밀번호'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.tr(
                                    'What opens right after access',
                                    '로그인 후 바로 열리는 화면',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                _buildChecklistRow(
                                  context,
                                  icon: isPractitioner
                                      ? Icons.space_dashboard_outlined
                                      : Icons.home_outlined,
                                  text: destinationLabel,
                                ),
                                const SizedBox(height: 8),
                                _buildChecklistRow(
                                  context,
                                  icon: Icons.play_circle_outline,
                                  text: firstReviewLabel,
                                ),
                                const SizedBox(height: 8),
                                _buildChecklistRow(
                                  context,
                                  icon: Icons.touch_app_outlined,
                                  text: isPractitioner
                                      ? lang.tr(
                                          'From there you can open patient brief, requests, and intake review.',
                                          '그 다음 환자 브리프, 요청, 문진 검토로 바로 이동할 수 있습니다.',
                                        )
                                      : lang.tr(
                                          'From there you can continue requests, intake, scheduling, and visit history in order.',
                                          '그 다음 요청, 문진, 일정, 방문 기록 순서로 자연스럽게 이어서 볼 수 있습니다.',
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => _submit(role),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                            ),
                            icon: const Icon(Icons.login),
                            label: Text(lang.tr('Login', '로그인')),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              RoleHomeScreen.routeName,
                            ),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(
                              lang.tr('Back to entry hub', '진입 화면으로 돌아가기'),
                            ),
                          ),
                        ],
                      ),
                    );

                    return SingleChildScrollView(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 11, child: story),
                                const SizedBox(width: 24),
                                Expanded(flex: 9, child: form),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                story,
                                const SizedBox(height: 24),
                                form,
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKicker(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildPreviewRow(
    BuildContext context, {
    required _PortalPreviewItem item,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.pine, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSnapshot(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required String note,
    required VoidCallback onPressed,
    bool highlighted = false,
  }) {
    return SizedBox(
      width: 220,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
          backgroundColor: highlighted
              ? Colors.white.withValues(alpha: 0.66)
              : Colors.white.withValues(alpha: 0.4),
          side: BorderSide(
            color: highlighted
                ? accent.withValues(alpha: 0.55)
                : AppTheme.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: highlighted
                    ? accent.withValues(alpha: 0.12)
                    : AppTheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                note,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.68),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.pine),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.76),
            ),
          ),
        ),
      ],
    );
  }
}

class _PortalPreviewItem {
  const _PortalPreviewItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
