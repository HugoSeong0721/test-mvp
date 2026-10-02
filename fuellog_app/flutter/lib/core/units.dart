/// 단위. 저장은 언제나 마일·미국 갤런으로 하고(정확한 기준 하나), 화면에서만 바꿔 보여 준다.
library;

const kmPerMile = 1.609344;
const litersPerGallon = 3.785411784;

enum DistanceUnit {
  mi('mi', 'Miles'),
  km('km', 'Kilometers');

  const DistanceUnit(this.short, this.long);
  final String short, long;

  double fromMiles(double mi) => this == DistanceUnit.mi ? mi : mi * kmPerMile;
  double toMiles(double v) => this == DistanceUnit.mi ? v : v / kmPerMile;
}

enum VolumeUnit {
  gal('gal', 'Gallons (US)'),
  l('L', 'Liters');

  const VolumeUnit(this.short, this.long);
  final String short, long;

  double fromGallons(double g) => this == VolumeUnit.gal ? g : g * litersPerGallon;
  double toGallons(double v) => this == VolumeUnit.gal ? v : v / litersPerGallon;

  /// 주유소 표시 그대로: "$3.459/gal", "$1.199/L"
  String get perLabel => '/$short';
}

enum EconomyUnit {
  mpg('MPG', 'MPG (US)', higherIsBetter: true),
  l100km('L/100 km', 'L/100 km', higherIsBetter: false),
  kml('km/L', 'km/L', higherIsBetter: true);

  const EconomyUnit(this.short, this.long, {required this.higherIsBetter});
  final String short, long;

  /// L/100 km 는 낮을수록 좋다 → 최고·최저, "평균보다 높음" 판단을 뒤집는다.
  final bool higherIsBetter;

  /// MPG(US) → 이 단위. 0 이하는 계산할 수 없는 값.
  double fromMpg(double mpg) => switch (this) {
    EconomyUnit.mpg => mpg,
    EconomyUnit.l100km => mpg <= 0 ? 0 : 100 * litersPerGallon / (mpg * kmPerMile),
    EconomyUnit.kml => mpg * kmPerMile / litersPerGallon,
  };

  double toMpg(double v) => switch (this) {
    EconomyUnit.mpg => v,
    EconomyUnit.l100km => v <= 0 ? 0 : 100 * litersPerGallon / (v * kmPerMile),
    EconomyUnit.kml => v * litersPerGallon / kmPerMile,
  };

  /// 거리·부피 단위에 맞는 기본 연비 단위 (마일+갤런 → MPG, km+L → L/100 km).
  static EconomyUnit natural(DistanceUnit d, VolumeUnit v) =>
      d == DistanceUnit.mi && v == VolumeUnit.gal ? EconomyUnit.mpg : EconomyUnit.l100km;
}

class Units {
  const Units({this.distance = DistanceUnit.mi, this.volume = VolumeUnit.gal, this.economy = EconomyUnit.mpg});

  final DistanceUnit distance;
  final VolumeUnit volume;
  final EconomyUnit economy;

  static const us = Units();
  static const metric = Units(distance: DistanceUnit.km, volume: VolumeUnit.l, economy: EconomyUnit.l100km);

  bool get isUs => this == us;

  Units copyWith({DistanceUnit? distance, VolumeUnit? volume, EconomyUnit? economy}) =>
      Units(distance: distance ?? this.distance, volume: volume ?? this.volume, economy: economy ?? this.economy);

  Map<String, Object> toJson() => {'distance': distance.name, 'volume': volume.name, 'economy': economy.name};

  static Units fromJson(Object? j) {
    if (j is! Map) return us;
    T pick<T extends Enum>(List<T> all, Object? name, T fb) => all.firstWhere((e) => e.name == name, orElse: () => fb);
    return Units(
      distance: pick(DistanceUnit.values, j['distance'], DistanceUnit.mi),
      volume: pick(VolumeUnit.values, j['volume'], VolumeUnit.gal),
      economy: pick(EconomyUnit.values, j['economy'], EconomyUnit.mpg),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Units && other.distance == distance && other.volume == volume && other.economy == economy;

  @override
  int get hashCode => Object.hash(distance, volume, economy);
}
