import 'package:flutter/material.dart';

import '../navigation/current_route_tracker.dart';
import '../services/app_firestore_service.dart';
import '../services/beta_session_service.dart';
import '../settings/app_language_controller.dart';
import '../theme/app_theme.dart';

class TesterFeedbackLauncher extends StatelessWidget {
  const TesterFeedbackLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurrentRouteTracker.instance,
      builder: (context, _) {
        if (!CurrentRouteTracker.instance.showLauncher) {
          return const SizedBox.shrink();
        }

        final lang = AppLanguageController.instance;
        return SafeArea(
          minimum: const EdgeInsets.all(18),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: () => _openFeedbackSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.pine,
                foregroundColor: Colors.white,
                elevation: 10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(lang.tr('Feedback', '피드백')),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFeedbackSheet(BuildContext context) async {
    final routeName = CurrentRouteTracker.instance.currentRouteName;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TesterFeedbackSheet(routeName: routeName),
    );
  }
}

enum _FeedbackCategory { bug, confusingUx, idea, question }

class _TesterFeedbackSheet extends StatefulWidget {
  const _TesterFeedbackSheet({required this.routeName});

  final String routeName;

  @override
  State<_TesterFeedbackSheet> createState() => _TesterFeedbackSheetState();
}

class _TesterFeedbackSheetState extends State<_TesterFeedbackSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  _FeedbackCategory _category = _FeedbackCategory.bug;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _prefillFromSession();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _goalController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _prefillFromSession() async {
    final session = await BetaSessionService.currentSessionAsync();
    if (!mounted || session == null) {
      return;
    }
    _nameController.text = session.displayName;
    _emailController.text = session.email;
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final routeLabel = widget.routeName.isEmpty
        ? lang.tr('Unknown screen', '화면 정보 없음')
        : widget.routeName;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.tr('Send tester feedback', '테스터 피드백 보내기'),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lang.tr(
                  'Use this whenever something is broken, confusing, or worth improving during testing.',
                  '테스트 중 막히는 점, 헷갈리는 점, 개선 아이디어가 있으면 바로 여기로 남겨주세요.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${lang.tr('Current screen', '현재 화면')}: $routeLabel',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<_FeedbackCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: lang.tr('Category', '분류'),
                ),
                items: _FeedbackCategory.values.map((category) {
                  return DropdownMenuItem<_FeedbackCategory>(
                    value: category,
                    child: Text(_categoryLabel(category, lang)),
                  );
                }).toList(),
                onChanged: _sending
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                enabled: !_sending,
                decoration: InputDecoration(
                  labelText: lang.tr(
                    'What were you trying to do?',
                    '무엇을 하려던 중이었나요?',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                enabled: !_sending,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: lang.tr(
                    'What happened? What should change?',
                    '무슨 일이 있었고, 무엇이 바뀌면 좋을까요?',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                enabled: !_sending,
                decoration: InputDecoration(
                  labelText: lang.tr('Your name (optional)', '이름 (선택)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: lang.tr('Your email (optional)', '이메일 (선택)'),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.pine,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(lang.tr('Send feedback', '피드백 보내기')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(
    _FeedbackCategory category,
    AppLanguageController lang,
  ) {
    return switch (category) {
      _FeedbackCategory.bug => lang.tr('Bug / broken', '버그 / 안됨'),
      _FeedbackCategory.confusingUx => lang.tr('Confusing UX', '헷갈리는 화면'),
      _FeedbackCategory.idea => lang.tr('Idea / request', '아이디어 / 요청'),
      _FeedbackCategory.question => lang.tr('Question', '질문'),
    };
  }

  Future<void> _submit() async {
    final lang = AppLanguageController.instance;
    final goal = _goalController.text.trim();
    final details = _detailsController.text.trim();

    if (goal.isEmpty && details.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Please write at least a short problem or note before sending.',
              '보내기 전에 짧게라도 문제나 메모를 적어주세요.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await AppFirestoreService.sendTesterFeedback(
        category: _categoryLabel(_category, lang),
        routeName: widget.routeName,
        summary: goal,
        details: details,
        reporterName: _nameController.text.trim(),
        reporterEmail: _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Feedback was queued. Thank you.',
              '피드백이 전송 대기열에 들어갔습니다. 감사합니다.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.tr(
              'Feedback could not be sent right now. Please try again in a moment.',
              '지금은 피드백을 보내지 못했습니다. 잠시 후 다시 시도해주세요.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}
