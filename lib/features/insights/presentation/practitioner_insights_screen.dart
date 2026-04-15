import 'package:flutter/material.dart';

class PractitionerInsightsScreen extends StatelessWidget {
  const PractitionerInsightsScreen({super.key});

  static const routeName = '/insights';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('침술사 인사이트 대시보드'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: Chip(label: Text('침술사 화면'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '최근 12주 집계 (데모)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _KpiCard(title: '총 내원', value: '148명'),
              _KpiCard(title: '재내원율', value: '63%'),
              _KpiCard(title: '사전문진 응답률', value: '71%'),
              _KpiCard(title: '노쇼율', value: '9%'),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('환자 구성'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('성별: 여성 58% · 남성 39% · 기타/무응답 3%'),
                  SizedBox(height: 4),
                  Text('연령대: 20대 18% · 30대 33% · 40대 27% · 50대+ 22%'),
                  SizedBox(height: 4),
                  Text('인종/문화권: East Asian 41% · White 29% · Hispanic 15% · Black 9% · 기타 6%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('자주 오는 증상 추세'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _TrendRow('수면 질 저하/새벽 각성', 42),
                  _TrendRow('목/어깨 통증', 38),
                  _TrendRow('소화 불편(더부룩/역류)', 31),
                  _TrendRow('두통/눈피로(HEENT)', 27),
                  _TrendRow('피로/에너지 저하', 25),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('자주 제공한 조언'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _AdviceRow('취침 전 스트레칭/호흡 루틴', 36, 63),
                  _AdviceRow('카페인 시간 조절', 30, 57),
                  _AdviceRow('식후 10분 걷기', 26, 52),
                  _AdviceRow('수분 섭취 패턴 조정', 19, 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('아이템 기획 인사이트 (침술사용)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('1) 수면/통증 동시 추적 카드: 반복 내원군 비중이 높아 우선순위 높음'),
                  SizedBox(height: 6),
                  Text('2) 맞춤 리마인드 템플릿: 사전문진 응답률 개선 여지 큼'),
                  SizedBox(height: 6),
                  Text('3) 조언 이행 체크(체크리스트형): 재내원율과 연결된 행동 데이터 확보 가능'),
                  SizedBox(height: 6),
                  Text('4) 카테고리 누락 경고(10문진 기준): 진단 일관성 향상에 도움'),
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
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
            child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(99))),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow(this.label, this.count, this.followupRate);

  final String label;
  final int count;
  final int followupRate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('권고 $count회 · 이행 $followupRate%'),
        ],
      ),
    );
  }
}
