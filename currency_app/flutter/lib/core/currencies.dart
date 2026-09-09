/// 통화 목록 + 오프라인 기준 스냅샷.
///
/// snapshotRate = 1 USD당 해당 통화 수량, snapshotChange = 전일 대비 USD→통화 변동(%).
/// 여기 적힌 숫자는 인터넷이 없을 때 쓰는 마지막 수단이다. 앱이 열리면
/// RateService가 무료 환율 API에서 최신 환율을 받아 덮어쓴다.
/// (스냅샷 기준: 2026-08-07)
const snapshotDate = '2026-08-07';

enum CurrencyGroup { fiat, crypto, metal }

class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.group,
    required this.snapshotRate,
    required this.snapshotChange,
    this.flag,
    this.badge,
    this.badgeStyle,
    this.keywords = '',
    this.tz,
  });

  final String code;
  final String name;
  final CurrencyGroup group;
  final double snapshotRate;
  final double snapshotChange;

  /// 국기 이모지 (법정통화) — 없으면 [badge] 글자를 쓴다.
  final String? flag;
  final String? badge;

  /// 'au' 금 · 'ag' 은 · 'pm' 백금/팔라듐 · 'cr' 암호화폐
  final String? badgeStyle;

  /// 코드·이름 외에 검색에 걸리게 할 별칭 ("키르기즈", "som" 같은 다른 표기)
  final String keywords;

  /// 현지 시각을 보여줄 IANA 시간대. 여러 시간대를 쓰는 통화는 대표 도시,
  /// 암호화폐·귀금속은 나라가 없어 null.
  final String? tz;

  bool matches(String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    return code.toLowerCase().contains(s) ||
        name.toLowerCase().contains(s) ||
        keywords.toLowerCase().contains(s);
  }
}

const currencies = <Currency>[
  Currency(code: 'USD', name: '미국 달러', group: CurrencyGroup.fiat, flag: '🇺🇸', snapshotRate: 1, snapshotChange: 0, tz: 'America/New_York'),
  Currency(code: 'KRW', name: '대한민국 원', group: CurrencyGroup.fiat, flag: '🇰🇷', snapshotRate: 1385.20, snapshotChange: 0.32, tz: 'Asia/Seoul'),
  Currency(code: 'EUR', name: '유로', group: CurrencyGroup.fiat, flag: '🇪🇺', snapshotRate: 0.8633, snapshotChange: -0.18, tz: 'Europe/Berlin'),
  Currency(code: 'JPY', name: '일본 엔', group: CurrencyGroup.fiat, flag: '🇯🇵', snapshotRate: 148.03, snapshotChange: 0.24, tz: 'Asia/Tokyo'),
  Currency(code: 'GBP', name: '영국 파운드', group: CurrencyGroup.fiat, flag: '🇬🇧', snapshotRate: 0.7444, snapshotChange: -0.09, tz: 'Europe/London'),
  Currency(code: 'CNY', name: '중국 위안', group: CurrencyGroup.fiat, flag: '🇨🇳', snapshotRate: 7.163, snapshotChange: 0.05, tz: 'Asia/Shanghai'),
  Currency(code: 'HKD', name: '홍콩 달러', group: CurrencyGroup.fiat, flag: '🇭🇰', snapshotRate: 7.821, snapshotChange: 0.01, tz: 'Asia/Hong_Kong'),
  Currency(code: 'TWD', name: '대만 달러', group: CurrencyGroup.fiat, flag: '🇹🇼', snapshotRate: 29.91, snapshotChange: 0.12, tz: 'Asia/Taipei'),
  Currency(code: 'SGD', name: '싱가포르 달러', group: CurrencyGroup.fiat, flag: '🇸🇬', snapshotRate: 1.284, snapshotChange: -0.06, tz: 'Asia/Singapore'),
  Currency(code: 'THB', name: '태국 바트', group: CurrencyGroup.fiat, flag: '🇹🇭', snapshotRate: 32.41, snapshotChange: 0.21, tz: 'Asia/Bangkok'),
  Currency(code: 'VND', name: '베트남 동', group: CurrencyGroup.fiat, flag: '🇻🇳', snapshotRate: 26150, snapshotChange: 0.08, tz: 'Asia/Ho_Chi_Minh'),
  Currency(code: 'PHP', name: '필리핀 페소', group: CurrencyGroup.fiat, flag: '🇵🇭', snapshotRate: 57.20, snapshotChange: 0.15, tz: 'Asia/Manila'),
  Currency(code: 'AUD', name: '호주 달러', group: CurrencyGroup.fiat, flag: '🇦🇺', snapshotRate: 1.5452, snapshotChange: -0.31, tz: 'Australia/Sydney'),
  Currency(code: 'CAD', name: '캐나다 달러', group: CurrencyGroup.fiat, flag: '🇨🇦', snapshotRate: 1.3742, snapshotChange: 0.11, tz: 'America/Toronto'),
  Currency(code: 'CHF', name: '스위스 프랑', group: CurrencyGroup.fiat, flag: '🇨🇭', snapshotRate: 0.7962, snapshotChange: -0.22, tz: 'Europe/Zurich'),
  Currency(code: 'INR', name: '인도 루피', group: CurrencyGroup.fiat, flag: '🇮🇳', snapshotRate: 87.54, snapshotChange: 0.04, tz: 'Asia/Kolkata'),
  Currency(code: 'KGS', name: '키르기스스탄 솜', group: CurrencyGroup.fiat, flag: '🇰🇬', snapshotRate: 87.45, snapshotChange: 0.07, keywords: '키르기즈 키르기스탄 솜 kyrgyz kyrgyzstan som', tz: 'Asia/Bishkek'),
  Currency(code: 'RUB', name: '러시아 루블', group: CurrencyGroup.fiat, flag: '🇷🇺', snapshotRate: 79.60, snapshotChange: -0.11, keywords: '루블 ruble russia', tz: 'Europe/Moscow'),
  Currency(code: 'KZT', name: '카자흐스탄 텡게', group: CurrencyGroup.fiat, flag: '🇰🇿', snapshotRate: 527.40, snapshotChange: 0.18, keywords: '텡게 tenge kazakh', tz: 'Asia/Almaty'),
  Currency(code: 'UZS', name: '우즈베키스탄 숨', group: CurrencyGroup.fiat, flag: '🇺🇿', snapshotRate: 12420, snapshotChange: 0.09, keywords: '숨 sum soum uzbek', tz: 'Asia/Tashkent'),
  Currency(code: 'MXN', name: '멕시코 페소', group: CurrencyGroup.fiat, flag: '🇲🇽', snapshotRate: 18.62, snapshotChange: -0.14, tz: 'America/Mexico_City'),
  Currency(code: 'BRL', name: '브라질 헤알', group: CurrencyGroup.fiat, flag: '🇧🇷', snapshotRate: 5.423, snapshotChange: 0.19, tz: 'America/Sao_Paulo'),
  Currency(code: 'BTC', name: '비트코인', group: CurrencyGroup.crypto, badge: '₿', badgeStyle: 'cr', snapshotRate: 1 / 89420, snapshotChange: -1.42),
  Currency(code: 'ETH', name: '이더리움', group: CurrencyGroup.crypto, badge: 'Ξ', badgeStyle: 'cr', snapshotRate: 1 / 4210, snapshotChange: -2.05),
  Currency(code: 'DOGE', name: '도지코인', group: CurrencyGroup.crypto, badge: 'Ð', badgeStyle: 'cr', snapshotRate: 1 / 0.213, snapshotChange: 3.10),
  Currency(code: 'XAU', name: '금 (트로이온스)', group: CurrencyGroup.metal, badge: 'Au', badgeStyle: 'au', snapshotRate: 1 / 3392, snapshotChange: 0.45),
  Currency(code: 'XAG', name: '은 (트로이온스)', group: CurrencyGroup.metal, badge: 'Ag', badgeStyle: 'ag', snapshotRate: 1 / 38.2, snapshotChange: 0.62),
  Currency(code: 'XPT', name: '백금 (트로이온스)', group: CurrencyGroup.metal, badge: 'Pt', badgeStyle: 'pm', snapshotRate: 1 / 1310, snapshotChange: -0.12),
  Currency(code: 'XPD', name: '팔라듐 (트로이온스)', group: CurrencyGroup.metal, badge: 'Pd', badgeStyle: 'pm', snapshotRate: 1 / 1125, snapshotChange: 0.08),
];

final Map<String, Currency> currencyByCode = {
  for (final c in currencies) c.code: c,
};

const groupLabels = {
  CurrencyGroup.fiat: '법정통화',
  CurrencyGroup.crypto: '암호화폐',
  CurrencyGroup.metal: '귀금속',
};

/// 온보딩 첫 화면에 타일로 보여줄 "많이 쓰는 통화"
const popularCodes = ['KGS', 'USD', 'KRW', 'RUB', 'KZT', 'EUR'];
