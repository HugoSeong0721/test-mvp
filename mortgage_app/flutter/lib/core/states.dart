/// 주별 세율 — 주를 고르면 재산세율(집)·판매세율(자동차)을 채운다. 사용자가 고쳐 쓸 수 있는 추정값.
/// 재산세: Tax Foundation "Property Taxes by State and County, 2026" (자가 주택 실효세율, 2024 자료)
/// 판매세: Tax Foundation "State and Local Sales Tax Rates, 2026" (주 세율 + 평균 지방세, 2026-01-01)
/// 원본 표: mortgage_app/store/state_rates.json
library;

class UsState {
  const UsState(
    this.code,
    this.name,
    this.propertyTax,
    this.salesTax,
    this.localSalesTax,
  );
  final String code, name;

  /// 재산세 실효세율 % (집값 대비 연).
  final double propertyTax;

  /// 주 판매세 %, 평균 지방 판매세 %.
  final double salesTax, localSalesTax;

  /// 자동차에 쓰는 판매세 추정 = 주 + 평균 지방 (차량 세율이 따로 있는 주도 있다).
  double get combinedSalesTax =>
      ((salesTax + (localSalesTax < 0 ? 0 : localSalesTax)) * 1000).round() /
      1000;
}

const usStates = <UsState>[
  UsState('AL', 'Alabama', 0.37, 4.0, 5.46),
  UsState('AK', 'Alaska', 0.94, 0, 1.82),
  UsState('AZ', 'Arizona', 0.48, 5.6, 2.92),
  UsState('AR', 'Arkansas', 0.56, 6.5, 2.96),
  UsState('CA', 'California', 0.7, 7.25, 1.74),
  UsState('CO', 'Colorado', 0.5, 2.9, 4.99),
  UsState('CT', 'Connecticut', 1.54, 6.35, 0),
  UsState('DE', 'Delaware', 0.54, 0, 0),
  UsState('DC', 'District of Columbia', 0.6, 6.0, 0),
  UsState('FL', 'Florida', 0.78, 6.0, 0.98),
  UsState('GA', 'Georgia', 0.79, 4.0, 3.49),
  UsState('HI', 'Hawaii', 0.29, 4.0, 0.5),
  UsState('ID', 'Idaho', 0.5, 6.0, 0.03),
  UsState('IL', 'Illinois', 1.88, 6.25, 2.71),
  UsState('IN', 'Indiana', 0.76, 7.0, 0),
  UsState('IA', 'Iowa', 1.33, 6.0, 0.94),
  UsState('KS', 'Kansas', 1.21, 6.5, 2.19),
  UsState('KY', 'Kentucky', 0.74, 6.0, 0),
  UsState('LA', 'Louisiana', 0.55, 5.0, 5.11),
  UsState('ME', 'Maine', 0.98, 5.5, 0),
  UsState('MD', 'Maryland', 0.92, 6.0, 0),
  UsState('MA', 'Massachusetts', 1.0, 6.25, 0),
  UsState('MI', 'Michigan', 1.19, 6.0, 0),
  UsState('MN', 'Minnesota', 1.0, 6.875, 1.26),
  UsState('MS', 'Mississippi', 0.58, 7.0, 0.06),
  UsState('MO', 'Missouri', 0.89, 4.225, 4.22),
  UsState('MT', 'Montana', 0.61, 0, 0),
  UsState('NE', 'Nebraska', 1.44, 5.5, 1.48),
  UsState('NV', 'Nevada', 0.5, 6.85, 1.39),
  UsState('NH', 'New Hampshire', 1.5, 0, 0),
  UsState('NJ', 'New Jersey', 1.88, 6.625, -0.02),
  UsState('NM', 'New Mexico', 0.63, 4.875, 2.79),
  UsState('NY', 'New York', 1.3, 4.0, 4.54),
  UsState('NC', 'North Carolina', 0.66, 4.75, 2.25),
  UsState('ND', 'North Dakota', 0.92, 5.0, 2.09),
  UsState('OH', 'Ohio', 1.36, 5.75, 1.54),
  UsState('OK', 'Oklahoma', 0.79, 4.5, 4.56),
  UsState('OR', 'Oregon', 0.81, 0, 0),
  UsState('PA', 'Pennsylvania', 1.26, 6.0, 0.34),
  UsState('RI', 'Rhode Island', 1.12, 7.0, 0),
  UsState('SC', 'South Carolina', 0.49, 6.0, 1.49),
  UsState('SD', 'South Dakota', 1.0, 4.2, 1.91),
  UsState('TN', 'Tennessee', 0.52, 7.0, 2.61),
  UsState('TX', 'Texas', 1.4, 6.25, 1.95),
  UsState('UT', 'Utah', 0.48, 6.1, 1.32),
  UsState('VT', 'Vermont', 1.51, 6.0, 0.39),
  UsState('VA', 'Virginia', 0.78, 5.3, 0.47),
  UsState('WA', 'Washington', 0.75, 6.5, 3.01),
  UsState('WV', 'West Virginia', 0.51, 6.0, 0.59),
  UsState('WI', 'Wisconsin', 1.32, 5.0, 0.72),
  UsState('WY', 'Wyoming', 0.53, 4.0, 1.56),
];

UsState? stateByCode(String? code) {
  for (final s in usStates) {
    if (s.code == code) return s;
  }
  return null;
}
