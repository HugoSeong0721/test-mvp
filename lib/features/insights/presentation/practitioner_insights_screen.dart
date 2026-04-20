import 'package:flutter/material.dart';

import '../../../core/settings/app_language_controller.dart';
import '../../../core/widgets/language_menu_button.dart';

class PractitionerInsightsScreen extends StatelessWidget {
  const PractitionerInsightsScreen({super.key});

  static const routeName = '/insights';

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageController.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('Practitioner Insights Dashboard', '침술사 인사이트 대시보드')),
        actions: [
          const LanguageMenuButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(label: Text(lang.tr('Practitioner View', '침술사 화면'))),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lang.tr('Last 12 Weeks Summary (Demo)', '최근 12주 요약 (데모)'),
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
                  _TrendRow(lang.tr('Poor Sleep / Early Morning Waking', '수면 저하 / 새벽 각성'), 42),
                  _TrendRow(lang.tr('Neck / Shoulder Pain', '목 / 어깨 통증'), 38),
                  _TrendRow(lang.tr('Digestive Discomfort / Reflux', '소화 불편 / 역류'), 31),
                  _TrendRow(lang.tr('Headache / Eye Fatigue (HEENT)', '두통 / 눈 피로 (HEENT)'), 27),
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
                    label: lang.tr('Bedtime Stretching / Breathing Routine', '취침 전 스트레칭 / 호흡 루틴'),
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
                    label: lang.tr('Hydration Pattern Adjustment', '수분 섭취 패턴 조정'),
                    count: 19,
                    followupRate: 48,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle(
            lang.tr(
              'Product Opportunity Insights (For Practitioner)',
              '제품 기회 인사이트 (침술사용)',
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr(
                      '1) Sleep + pain tracking card: high priority because repeat visits often cluster here',
                      '1) 수면 + 통증 추적 카드: 재내원 패턴이 자주 모이는 영역이라 우선순위가 높음',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.tr(
                      '2) Personalized reminder templates: clear room to improve pre-visit intake response rate',
                      '2) 개인화 리마인더 템플릿: 사전 문진 응답률을 높일 여지가 큼',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.tr(
                      '3) Advice adherence checklist: useful for capturing behavior data tied to return visits',
                      '3) 조언 이행 체크리스트: 재내원과 연결된 행동 데이터를 잡기 좋음',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.tr(
                      '4) Missing-category warning (based on the 10-question system): helps improve diagnostic consistency',
                      '4) 누락 카테고리 경고 (10문항 시스템 기반): 진단 일관성 향상에 도움',
                    ),
                  ),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
