import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/patient_beta_auth_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});

  static const routeName = '/';

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  static const _entryPassword = 'Daisy';

  final TextEditingController _passwordController = TextEditingController();

  bool _unlocked = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _unlock() {
    final lang = AppLanguageController.instance;
    if (_passwordController.text.trim() == _entryPassword) {
      setState(() => _unlocked = true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.tr('Incorrect password.', '비밀번호가 올바르지 않습니다.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(lang.tr('Test MVP', '테스트 MVP')),
        actions: const [LanguageMenuButton()],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            primary: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _unlocked
                        ? _buildUnlockedView(context, lang)
                        : _buildLockedView(context, lang),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedView(BuildContext context, AppLanguageController lang) {
    final sections = [
      _SidebarSection(
        title: lang.tr('Board', '보드'),
        items: [
          lang.tr('Preview Community', '프리뷰 커뮤니티'),
          lang.tr('System HelpDesk', '시스템 헬프데스크'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Human Resource', '인력'),
        items: [
          lang.tr('Practitioner Route', '침술사 경로'),
          lang.tr('Patient Route', '환자 경로'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Purchase Order', '요청'),
        items: [
          lang.tr('Requests Inbox', '요청함'),
          lang.tr('Shared Scheduling', '공유 스케줄'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Shipment', '방문'),
        items: [
          lang.tr('Visit Window', '방문 구간'),
          lang.tr('Shared Slots', '공유 슬롯'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Member', '멤버'),
        items: [
          lang.tr('Patient Brief', '환자 브리프'),
          lang.tr('Friend Beta', '지인 베타'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Product', '문진'),
        items: [
          lang.tr('Intake Review', '문진 검토'),
          lang.tr('Visit History', '방문 기록'),
        ],
      ),
      _SidebarSection(
        title: lang.tr('Inventory', '허브'),
        items: [
          lang.tr('Route Selector', '경로 선택'),
          lang.tr('Portal Preview', '포털 프리뷰'),
        ],
      ),
    ];

    final boardItems = [
      _BoardItem(
        index: '2600',
        company: lang.tr('All', '전체'),
        type: lang.tr('Community', '커뮤니티'),
        title: lang.tr(
          'Start with Preview Login to unlock practitioner, patient, and beta routes',
          'Preview Login 으로 침술사, 환자, beta 경로를 먼저 여세요',
        ),
        view: lang.tr('Login', '로그인'),
        owner: lang.tr('System', '시스템'),
      ),
      _BoardItem(
        index: '2599',
        company: lang.tr('Clinic', '클리닉'),
        type: lang.tr('Notice', '공지'),
        title: lang.tr(
          'Practitioner route opens the dashboard-first review flow',
          'Practitioner 경로는 대시보드 우선 검토 흐름을 엽니다',
        ),
        view: lang.tr('Ready', '준비'),
        owner: lang.tr('Admin', '관리자'),
      ),
      _BoardItem(
        index: '2598',
        company: lang.tr('Patient', '환자'),
        type: lang.tr('Notice', '공지'),
        title: lang.tr(
          'Patient route opens requests, intake, schedule, and visit history',
          'Patient 경로는 요청, 문진, 일정, 방문 기록 흐름을 엽니다',
        ),
        view: lang.tr('Ready', '준비'),
        owner: lang.tr('Admin', '관리자'),
      ),
      _BoardItem(
        index: '2597',
        company: lang.tr('Beta', '베타'),
        type: lang.tr('Community', '커뮤니티'),
        title: lang.tr(
          'Friend beta route supports live sign-up and onboarding',
          'Friend beta 경로는 실사용 회원가입과 온보딩을 지원합니다',
        ),
        view: lang.tr('Live', '실사용'),
        owner: lang.tr('Bella', 'Bella'),
      ),
      _BoardItem(
        index: '2596',
        company: lang.tr('All', '전체'),
        type: lang.tr('Notice', '공지'),
        title: lang.tr(
          'Use the shared password Daisy to reveal the route selector',
          '공유 비밀번호 Daisy 로 route selector 를 엽니다',
        ),
        view: lang.tr('Locked', '잠금'),
        owner: lang.tr('Admin', '관리자'),
      ),
      _BoardItem(
        index: '2595',
        company: lang.tr('All', '전체'),
        type: lang.tr('Community', '커뮤니티'),
        title: lang.tr(
          'This first screen is intentionally styled like a familiar enterprise board',
          '이 첫 화면은 익숙한 사내 시스템 게시판처럼 느껴지도록 구성했습니다',
        ),
        view: lang.tr('Preview', '프리뷰'),
        owner: lang.tr('Design', '디자인'),
      ),
    ];

    return LayoutBuilder(
      key: const ValueKey('locked'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;

        final sidebar = Container(
          width: wide ? 192 : double.infinity,
          color: const Color(0xFFF0F0EE),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                color: const Color(0xFF4A4A4A),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.tr('Preview', '프리뷰'),
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 28,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF9A9A9A)),
                      ),
                      child: Text(
                        lang.tr('Route search', '경로 검색'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final section in sections) ...[
                _buildSidebarSectionWidget(
                  context,
                  title: section.title,
                  items: section.items,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );

        final board = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.tr('Preview Community', '프리뷰 커뮤니티'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF5B86A2),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Spacer(),
                _buildBoardFilter(
                  context,
                  label: lang.tr('Type', '유형'),
                  value: lang.tr('-- View All --', '-- 전체 보기 --'),
                  width: 156,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: wide ? 0 : 1,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFADADAD)),
                    ),
                    child: Text(
                      lang.tr('Title or Contents', '제목 또는 내용'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.52),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildPillAction(
                  context,
                  label: lang.tr('Search', '검색'),
                  fill: const Color(0xFFE99191),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildPillAction(
                  context,
                  label: lang.tr('Open Guide', '가이드'),
                  fill: const Color(0xFFE88F8F),
                ),
                const SizedBox(width: 10),
                _buildPillAction(
                  context,
                  label: lang.tr('Unlock Preview', '프리뷰 열기'),
                  fill: const Color(0xFFE88F8F),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildBoardTable(context, boardItems),
          ],
        );

        final sideLogin = _buildSideLogin(context, lang);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F6),
            border: Border.all(color: const Color(0xFFC5C5C5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildEnterpriseTopBar(context, lang),
              wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sidebar,
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 10, child: board),
                                const SizedBox(width: 18),
                                SizedBox(width: 290, child: sideLogin),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          sidebar,
                          const SizedBox(height: 16),
                          sideLogin,
                          const SizedBox(height: 16),
                          board,
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnlockedView(BuildContext context, AppLanguageController lang) {
    return Column(
      key: const ValueKey('unlocked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          padding: const EdgeInsets.all(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.pine, AppTheme.jade, Color(0xFF2E7C67)],
          ),
          borderColor: Colors.white.withValues(alpha: 0.14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKicker(lang.tr('Live Entry Hub', '실시간 진입 허브')),
              const SizedBox(height: 18),
              Text(
                lang.tr('Choose the right portal route', '맞는 포털 경로 선택'),
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  lang.tr(
                    'Each route is designed like a separate portal entry so testers can jump straight into clinic review, patient portal review, or live beta onboarding.',
                    '각 경로를 별도의 포털 입구처럼 구성해서 클리닉 검토, 환자 포털 검토, 실사용 베타 온보딩 중 원하는 흐름으로 바로 들어갈 수 있게 했습니다.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppMetricChip(
                    icon: Icons.health_and_safety_outlined,
                    label: lang.tr('Practitioner Route', '침술사 경로'),
                    value: lang.tr('Dashboard first', '대시보드 중심'),
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    labelColor: Colors.white.withValues(alpha: 0.72),
                    valueColor: Colors.white,
                  ),
                  AppMetricChip(
                    icon: Icons.face_4_outlined,
                    label: lang.tr('Patient Route', '환자 경로'),
                    value: lang.tr('Portal preview', '포털 체험'),
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    labelColor: Colors.white.withValues(alpha: 0.72),
                    valueColor: Colors.white,
                  ),
                  AppMetricChip(
                    icon: Icons.groups_2_outlined,
                    label: lang.tr('Beta Route', '지인 베타'),
                    value: lang.tr('Live onboarding', '실사용 온보딩'),
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    labelColor: Colors.white.withValues(alpha: 0.72),
                    valueColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                lang.tr('Choose your route', '경로 선택 가이드'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppGuideStep(
                    dark: true,
                    step: '1',
                    title: lang.tr('Clinic review', '클리닉 검토'),
                    description: lang.tr(
                      'Use practitioner login when you want schedules, patient cards, and operations first.',
                      '일정, 환자 카드, 운영 화면을 먼저 볼 때는 침술사 로그인을 사용하세요.',
                    ),
                  ),
                  AppGuideStep(
                    dark: true,
                    step: '2',
                    title: lang.tr('Patient portal review', '환자 포털 검토'),
                    description: lang.tr(
                      'Use patient test login when you want requests, intake, schedule, and history flow.',
                      '요청, 문진, 일정, 기록 흐름을 검토할 때는 환자 테스트 로그인을 사용하세요.',
                    ),
                  ),
                  AppGuideStep(
                    dark: true,
                    step: '3',
                    title: lang.tr('Live onboarding', '실사용 온보딩'),
                    description: lang.tr(
                      'Use friend beta when someone will create their own account and try the portal personally.',
                      '사용자가 직접 계정을 만들고 포털을 체험할 때는 지인 베타를 사용하세요.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final cards = [
              _buildFlowCard(
                context: context,
                icon: Icons.monitor_heart_outlined,
                eyebrow: lang.tr('Practitioner', '침술사'),
                title: lang.tr('Practitioner Login', '침술사 로그인'),
                description: lang.tr(
                  'Open the operational dashboard and move into patient detail, answer requests, and intake review.',
                  '운영 대시보드로 들어가 환자 상세, 답변 요청, 문진 검토 흐름을 확인합니다.',
                ),
                tags: [
                  lang.tr('Opens dashboard', '대시보드 진입'),
                  lang.tr('Best for clinic QA', '운영 QA용'),
                  lang.tr('Shared account', '공유 계정'),
                ],
                secondaryText: lang.tr(
                  'Best for workflow review and clinic-side testing.',
                  '운영 흐름과 관리자 화면 점검에 적합합니다.',
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5FBF8), Color(0xFFDDEEE8)],
                ),
                button: FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      LoginScreen.routeName,
                      arguments: const {
                        'role': 'practitioner',
                        'loginMode': 'default',
                      },
                    );
                  },
                  child: Text(lang.tr('Practitioner Login', '침술사 로그인')),
                ),
              ),
              _buildFlowCard(
                context: context,
                icon: Icons.favorite_border,
                eyebrow: lang.tr('Patient Test Account', '환자 테스트 계정'),
                title: lang.tr('Patient Test Login', '환자 테스트 로그인'),
                description: lang.tr(
                  'Preview the sample patient flow or jump into the Hugo demo profile for personal testing.',
                  '샘플 환자 흐름 또는 Hugo 데모 프로필로 바로 들어갑니다.',
                ),
                tags: [
                  lang.tr('Opens patient home', '환자 홈 진입'),
                  lang.tr('Portal review', '포털 검토용'),
                  lang.tr('2 demo accounts', '2개 데모 계정'),
                ],
                secondaryText: lang.tr(
                  'Accounts: 123 / 123 or hugo / hugo',
                  '계정: 123 / 123 또는 hugo / hugo',
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBF5), Color(0xFFF2E4D3)],
                ),
                button: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      LoginScreen.routeName,
                      arguments: const {
                        'role': 'patient',
                        'loginMode': 'default',
                      },
                    );
                  },
                  child: Text(lang.tr('Patient Test Login', '환자 테스트 로그인')),
                ),
              ),
              _buildFlowCard(
                context: context,
                icon: Icons.person_add_alt_1_outlined,
                eyebrow: lang.tr('Friend Beta', '지인 베타'),
                title: lang.tr('Friend Beta Sign Up / Login', '지인 베타 회원가입/로그인'),
                description: lang.tr(
                  'Shared onboarding flow for friends who sign up with email and submit their own intake.',
                  '지인들이 이메일로 가입하고 직접 문진을 제출하는 베타 흐름입니다.',
                ),
                tags: [
                  lang.tr('Email sign-up', '이메일 가입'),
                  lang.tr('Opens patient home', '환자 홈 진입'),
                  lang.tr('Live onboarding', '실사용 온보딩'),
                ],
                secondaryText: lang.tr(
                  'Use this for live friend onboarding tests.',
                  '실제 지인 온보딩 테스트에 사용합니다.',
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7F4FB), Color(0xFFE8E1F0)],
                ),
                button: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      PatientBetaAuthScreen.routeName,
                    );
                  },
                  child: Text(
                    lang.tr('Friend Beta Sign Up / Login', '지인 베타 회원가입/로그인'),
                  ),
                ),
              ),
            ];

            if (!wide) {
              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 14),
                Expanded(child: cards[1]),
                const SizedBox(width: 14),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnterpriseTopBar(
    BuildContext context,
    AppLanguageController lang,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFEAEAEA),
        border: Border(bottom: BorderSide(color: Color(0xFFD0D0D0))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF4A4A4A),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: const Icon(Icons.push_pin, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            lang.tr('Mingyu', 'Mingyu'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.ink.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 120,
            height: 28,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA7A7A7)),
            ),
            child: Text(
              lang.tr('Order search', '검색'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFA7A7A7)),
            ),
            child: Row(
              children: [
                Text(
                  lang.tr('- Go to Another Company -', '- 다른 회사로 이동 -'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              lang.tr(
                'Test MVP Enterprise Managing System | Logout',
                'Test MVP Enterprise Managing System | Logout',
              ),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionWidget(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFB8D1BE),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          color: const Color(0xFFF9F9F7),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.82),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardFilter(
    BuildContext context, {
    required String label,
    required String value,
    required double width,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label :',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.ink.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: width,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFADADAD)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillAction(
    BuildContext context, {
    required String label,
    required Color fill,
  }) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBoardTable(BuildContext context, List<_BoardItem> items) {
    final textTheme = Theme.of(context).textTheme;

    Widget buildCell(
      String text, {
      required int flex,
      TextAlign textAlign = TextAlign.left,
      FontWeight? fontWeight,
      Color? color,
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            text,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: color ?? AppTheme.ink.withValues(alpha: 0.86),
              fontWeight: fontWeight,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFACACAC)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFF6D6D6D),
            child: Row(
              children: [
                buildCell(
                  'Idx',
                  flex: 5,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                buildCell(
                  'Company',
                  flex: 7,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                buildCell(
                  'Type',
                  flex: 7,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                buildCell(
                  'Title',
                  flex: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                buildCell(
                  'View',
                  flex: 6,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                buildCell(
                  'Writer',
                  flex: 7,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          for (var index = 0; index < items.length; index++)
            Container(
              color: index.isEven
                  ? const Color(0xFFF6F6F6)
                  : const Color(0xFFEFEFEF),
              child: Row(
                children: [
                  buildCell(
                    items[index].index,
                    flex: 5,
                    textAlign: TextAlign.center,
                  ),
                  buildCell(items[index].company, flex: 7),
                  buildCell(items[index].type, flex: 7),
                  buildCell(
                    items[index].title,
                    flex: 32,
                    fontWeight: FontWeight.w600,
                  ),
                  buildCell(
                    items[index].view,
                    flex: 6,
                    textAlign: TextAlign.center,
                  ),
                  buildCell(
                    items[index].owner,
                    flex: 7,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: const Color(0xFF8B8B8B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Total Count : ${items.length}',
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideLogin(BuildContext context, AppLanguageController lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFB6B6B6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFB8D1BE),
            child: Text(
              lang.tr('Preview Login', '프리뷰 로그인'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSmallLoginLabel(context, lang.tr('Username', '사용자명')),
                const SizedBox(height: 6),
                _buildSmallStaticField(
                  context,
                  value: lang.tr('preview_user', 'preview_user'),
                ),
                const SizedBox(height: 12),
                _buildSmallLoginLabel(context, lang.tr('Password', '비밀번호')),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    labelText: lang.tr('Access Password', '접속 비밀번호'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSmallLoginLabel(context, lang.tr('System', '시스템')),
                const SizedBox(height: 6),
                _buildSmallStaticField(
                  context,
                  value: lang.tr('Test MVP Preview', 'Test MVP Preview'),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _unlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88A897),
                  ),
                  child: Text(lang.tr('Login', '로그인')),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    border: Border.all(color: const Color(0xFFDADADA)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lang.tr(
                      'Use Daisy to unlock the route board. After that you can choose practitioner, patient, or beta.',
                      'Daisy 로 route board 를 열면 practitioner, patient, beta 중에서 선택할 수 있습니다.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLoginLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.ink.withValues(alpha: 0.82),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSmallStaticField(BuildContext context, {required String value}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFCACACA)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _buildKicker(String text) {
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

  Widget _buildFlowCard({
    required BuildContext context,
    required IconData icon,
    required String eyebrow,
    required String title,
    required String description,
    required List<String> tags,
    required String secondaryText,
    required Gradient gradient,
    required Widget button,
  }) {
    return AppPanel(
      padding: const EdgeInsets.all(22),
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.pine),
          ),
          const SizedBox(height: 18),
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map(_buildFlowTag).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            secondaryText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: button),
        ],
      ),
    );
  }

  Widget _buildFlowTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.ink.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _SidebarSection {
  const _SidebarSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class _BoardItem {
  const _BoardItem({
    required this.index,
    required this.company,
    required this.type,
    required this.title,
    required this.view,
    required this.owner,
  });

  final String index;
  final String company;
  final String type;
  final String title;
  final String view;
  final String owner;
}
