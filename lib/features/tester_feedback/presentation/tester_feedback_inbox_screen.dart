import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_firestore_service.dart';
import '../../../core/settings/app_language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/language_menu_button.dart';

class TesterFeedbackInboxScreen extends StatefulWidget {
  const TesterFeedbackInboxScreen({super.key});

  static const routeName = '/tester-feedback-inbox';

  @override
  State<TesterFeedbackInboxScreen> createState() =>
      _TesterFeedbackInboxScreenState();
}

class _TesterFeedbackInboxScreenState extends State<TesterFeedbackInboxScreen> {
  _FeedbackFilter _filter = _FeedbackFilter.open;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        final lang = AppLanguageController.instance;
        return Scaffold(
          appBar: AppBar(
            title: Text(lang.tr('Tester Feedback Inbox', '테스터 피드백 인박스')),
            actions: const [LanguageMenuButton()],
          ),
          body: AppBackdrop(
            child: SafeArea(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('tester_feedback')
                    .orderBy('submittedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  final openCount = docs
                      .where((doc) => _statusOf(doc.data()) == 'open')
                      .length;
                  final reviewedCount = docs.length - openCount;
                  final categories = docs
                      .map((doc) => _categoryOf(doc.data()))
                      .where((value) => value.isNotEmpty)
                      .toSet()
                      .length;
                  final routeCount = docs
                      .map((doc) => _routeOf(doc.data()))
                      .where((value) => value.isNotEmpty)
                      .toSet()
                      .length;
                  final filteredDocs = docs.where((doc) {
                    final status = _statusOf(doc.data());
                    switch (_filter) {
                      case _FeedbackFilter.all:
                        return true;
                      case _FeedbackFilter.open:
                        return status == 'open';
                      case _FeedbackFilter.reviewed:
                        return status == 'reviewed';
                    }
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                    children: [
                      AppPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Tester feedback', '테스터 피드백'),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppTheme.ink),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                AppMetricChip(
                                  icon: Icons.mark_email_unread_outlined,
                                  label: lang.tr('Open now', '현재 열림'),
                                  value: '$openCount',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.task_alt_outlined,
                                  label: lang.tr('Reviewed', '확인 완료'),
                                  value: '$reviewedCount',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.category_outlined,
                                  label: lang.tr('Categories', '카테고리'),
                                  value: '$categories',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                                AppMetricChip(
                                  icon: Icons.web_asset_outlined,
                                  label: lang.tr('Screens touched', '화면 수'),
                                  value: '$routeCount',
                                  backgroundColor: AppTheme.surface,
                                  labelColor: AppTheme.ink.withValues(
                                    alpha: 0.58,
                                  ),
                                  valueColor: AppTheme.ink,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('Queue view', '큐 보기'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildFilterChip(
                                  context,
                                  label: lang.tr('Open first', '열림 우선'),
                                  selected: _filter == _FeedbackFilter.open,
                                  onTap: () => setState(
                                    () => _filter = _FeedbackFilter.open,
                                  ),
                                ),
                                _buildFilterChip(
                                  context,
                                  label: lang.tr('Reviewed', '확인 완료'),
                                  selected: _filter == _FeedbackFilter.reviewed,
                                  onTap: () => setState(
                                    () => _filter = _FeedbackFilter.reviewed,
                                  ),
                                ),
                                _buildFilterChip(
                                  context,
                                  label: lang.tr('All', '전체'),
                                  selected: _filter == _FeedbackFilter.all,
                                  onTap: () => setState(
                                    () => _filter = _FeedbackFilter.all,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.hasError)
                        AppPanel(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            lang.tr(
                              'Tester feedback could not be loaded right now.',
                              '지금은 테스터 피드백을 불러오지 못했습니다.',
                            ),
                          ),
                        )
                      else if (!snapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (filteredDocs.isEmpty)
                        AppPanel(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _filter == _FeedbackFilter.reviewed
                                ? lang.tr(
                                    'No reviewed tester feedback has been saved yet.',
                                    '아직 확인 완료된 테스터 피드백이 없습니다.',
                                  )
                                : lang.tr(
                                    'No tester feedback is waiting in this view right now.',
                                    '지금 이 보기에는 대기 중인 테스터 피드백이 없습니다.',
                                  ),
                          ),
                        )
                      else
                        ...filteredDocs.map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _FeedbackCard(
                              doc: doc,
                              onMarkReviewed: () async {
                                await AppFirestoreService.markTesterFeedbackReviewed(
                                  feedbackId: doc.id,
                                );
                              },
                              onReopen: () async {
                                await AppFirestoreService.reopenTesterFeedback(
                                  feedbackId: doc.id,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.pine,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? Colors.white : AppTheme.ink,
      ),
      checkmarkColor: Colors.white,
      side: BorderSide(color: AppTheme.border),
    );
  }
}

enum _FeedbackFilter { open, reviewed, all }

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.doc,
    required this.onMarkReviewed,
    required this.onReopen,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function() onMarkReviewed;
  final Future<void> Function() onReopen;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    final data = doc.data();
    final status = _statusOf(data);
    final isOpen = status == 'open';
    final category = _categoryLabel(_categoryOf(data), lang);
    final routeName = _routeOf(data);
    final summary = (data['summary'] ?? '').toString().trim();
    final details = (data['details'] ?? '').toString().trim();
    final reporterName = (data['reporterName'] ?? '').toString().trim();
    final reporterEmail = (data['reporterEmail'] ?? '').toString().trim();
    final submittedAt = _formatTimestamp(
      data['submittedAt'] as Timestamp?,
      fallback: (data['submittedAtIso'] ?? '').toString(),
    );
    final reviewedAt = _formatTimestamp(data['reviewedAt'] as Timestamp?);

    return AppPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(context, label: category, color: AppTheme.pine),
                    _buildTag(
                      context,
                      label: isOpen
                          ? lang.tr('Open', '열림')
                          : lang.tr('Reviewed', '확인 완료'),
                      color: isOpen ? const Color(0xFFB45A35) : AppTheme.jade,
                    ),
                    _buildTag(
                      context,
                      label: routeName.isEmpty
                          ? lang.tr('Unknown screen', '화면 미상')
                          : routeName,
                      color: const Color(0xFF3C657A),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () async {
                  if (isOpen) {
                    await onMarkReviewed();
                  } else {
                    await onReopen();
                  }
                },
                icon: Icon(
                  isOpen ? Icons.task_alt_outlined : Icons.restart_alt,
                ),
                label: Text(
                  isOpen
                      ? lang.tr('Mark reviewed', '확인 완료')
                      : lang.tr('Reopen', '다시 열기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            summary.isEmpty
                ? lang.tr('No short summary was added.', '짧은 요약이 없습니다.')
                : summary,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            details.isEmpty
                ? lang.tr('No detailed note was added.', '상세 메모가 없습니다.')
                : details,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _buildMetaLine(
                context,
                label: lang.tr('Tester', '테스터'),
                value: reporterName.isEmpty
                    ? lang.tr('Anonymous tester', '익명 테스터')
                    : reporterName,
              ),
              _buildMetaLine(
                context,
                label: lang.tr('Email', '이메일'),
                value: reporterEmail.isEmpty
                    ? lang.tr('No email provided', '이메일 없음')
                    : reporterEmail,
              ),
              _buildMetaLine(
                context,
                label: lang.tr('Submitted', '제출 시각'),
                value: submittedAt,
              ),
              if (!isOpen)
                _buildMetaLine(
                  context,
                  label: lang.tr('Reviewed', '확인 시각'),
                  value: reviewedAt,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMetaLine(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return RichText(
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

String _statusOf(Map<String, dynamic> data) {
  return (data['status'] ?? 'open').toString();
}

String _categoryOf(Map<String, dynamic> data) {
  return (data['category'] ?? '').toString();
}

String _routeOf(Map<String, dynamic> data) {
  return (data['routeName'] ?? '').toString();
}

String _categoryLabel(String category, AppLanguageController lang) {
  switch (category) {
    case 'bug':
      return lang.tr('Bug', '버그');
    case 'confusingUx':
      return lang.tr('Confusing UX', '헷갈리는 UX');
    case 'idea':
      return lang.tr('Idea', '아이디어');
    case 'question':
      return lang.tr('Question', '질문');
    default:
      return category.isEmpty ? lang.tr('Unsorted', '미분류') : category;
  }
}

String _formatTimestamp(Timestamp? timestamp, {String fallback = '-'}) {
  if (timestamp != null) {
    final date = timestamp.toDate();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
  return fallback.isEmpty ? '-' : fallback;
}
