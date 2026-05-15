import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';
import '../../../core/widgets/practitioner_shell.dart';

class PractitionerInsightsScreen extends StatelessWidget {
  const PractitionerInsightsScreen({super.key});

  static const routeName = '/insights';

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return PractitionerShell(
      currentItem: PractitionerNavItem.insights,
      title: lang.tr('Insights', '인사이트'),
      actions: const [LanguageMenuButton()],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lang.tr('Last 12 weeks', '최근 12주'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiCard(title: lang.tr('Total Visits', '총 내원'), value: '148'),
              _KpiCard(title: lang.tr('Return Rate', '재내원율'), value: '63%'),
              _KpiCard(
                title: lang.tr('Pre-Visit Intake Response Rate', '사전 문진 응답률'),
                value: '71%',
              ),
              _KpiCard(title: lang.tr('No-Show Rate', '노쇼율'), value: '9%'),
            ],
          ),
          const SizedBox(height: 12),
          _SectionTitle(lang.tr('Patient Mix', '환자 구성')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr(
                      'Gender: Female 58% · Male 39% · Other/No Response 3%',
                      '성별: 여성 58% · 남성 39% · 기타/무응답 3%',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.tr(
                      'Age Range: 20s 18% · 30s 33% · 40s 27% · 50+ 22%',
                      '연령대: 20대 18% · 30대 33% · 40대 27% · 50대 이상 22%',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.tr(
                      'Race/Cultural Background: East Asian 41% · White 29% · Hispanic 15% · Black 9% · Other 6%',
                      '인종/문화권: 동아시아 41% · 백인 29% · 히스패닉 15% · 흑인 9% · 기타 6%',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(lang.tr('Most Common Symptom Trends', '가장 흔한 증상 추세')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _TrendRow(
                    lang.tr(
                      'Poor Sleep / Early Morning Waking',
                      '수면 저하 / 새벽 각성',
                    ),
                    42,
                  ),
                  _TrendRow(lang.tr('Neck / Shoulder Pain', '목 / 어깨 통증'), 38),
                  _TrendRow(
                    lang.tr('Digestive Discomfort / Reflux', '소화 불편 / 역류'),
                    31,
                  ),
                  _TrendRow(
                    lang.tr(
                      'Headache / Eye Fatigue (HEENT)',
                      '두통 / 눈 피로 (HEENT)',
                    ),
                    27,
                  ),
                  _TrendRow(lang.tr('Low Energy / Fatigue', '기력 저하 / 피로'), 25),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(lang.tr('Most Common Advice Given', '가장 자주 준 조언')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _AdviceRow(
                    label: lang.tr(
                      'Bedtime Stretching / Breathing Routine',
                      '취침 전 스트레칭 / 호흡 루틴',
                    ),
                    count: 36,
                    followupRate: 63,
                  ),
                  _AdviceRow(
                    label: lang.tr('Adjust Caffeine Timing', '카페인 시간 조절'),
                    count: 30,
                    followupRate: 57,
                  ),
                  _AdviceRow(
                    label: lang.tr('10-Minute Walk After Meals', '식후 10분 걷기'),
                    count: 26,
                    followupRate: 52,
                  ),
                  _AdviceRow(
                    label: lang.tr(
                      'Hydration Pattern Adjustment',
                      '수분 섭취 패턴 조정',
                    ),
                    count: 19,
                    followupRate: 48,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(lang.tr('Opportunities', '기회')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.tr('Sleep + pain tracking', '수면 + 통증 추적')),
                  const SizedBox(height: 6),
                  Text(lang.tr('Personalized reminders', '개인화 리마인더')),
                  const SizedBox(height: 6),
                  Text(lang.tr('Advice checklist', '조언 체크리스트')),
                  const SizedBox(height: 6),
                  Text(lang.tr('Missing-category warning', '누락 카테고리 경고')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final width = (count / 45).clamp(0.1, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ($count)'),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: width,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
    required this.label,
    required this.count,
    required this.followupRate,
  });

  final String label;
  final int count;
  final int followupRate;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            lang.tr(
              'Recommended $count times · Follow-through $followupRate%',
              '$count회 권장 · 이행률 $followupRate%',
            ),
          ),
        ],
      ),
    );
  }
}
