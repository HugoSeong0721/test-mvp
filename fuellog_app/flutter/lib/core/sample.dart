/// 예시 기록 — 웹 미리보기 `?demo=1` 과 테스트 로봇 스크린샷에만 쓴다 (앱 안에서는 절대 자동으로 넣지 않는다).
library;

import 'model.dart';
import 'units.dart';

/// 시프트·XOR 만 쓰는 난수 — 웹(JS 숫자)·네이티브에서 같은 값 (Catdoku 교훈).
class _Rng {
  _Rng(this._s);
  int _s;
  double next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s / 0x100000000;
  }
}

/// [today] 까지 약 14개월치. 승용차 1대 + 픽업트럭 1대.
LogData sampleData(DateTime today) {
  final civic = Vehicle(id: 'demo-civic', name: '2019 Honda Civic');
  final truck = Vehicle(id: 'demo-truck', name: '2021 Ford F-150');
  final d = LogData(vehicles: [civic, truck], currentVehicleId: civic.id, units: Units.us);
  final rng = _Rng(20261002);

  void drive(Vehicle v, double startOdo, double mpg, double tank, int everyDays) {
    var day = DateTime(today.year - 1, today.month - 2, 3, 8, 10);
    var odo = startOdo;
    var k = 0;
    // 첫 가득 주유 (기준점)
    d.fills.add(
      FillUp(id: '${v.id}-f$k', vehicleId: v.id, date: day, odometer: odo, volume: tank * 0.8, cost: tank * 0.8 * 3.29),
    );
    while (true) {
      k++;
      day = day.add(Duration(days: everyDays + (rng.next() * 4).round() - 1, minutes: (rng.next() * 600).round()));
      if (day.isAfter(today)) break;
      // 여름엔 연비가 조금 좋고, 겨울엔 나쁘다
      final season = 1 + 0.06 * (day.month >= 5 && day.month <= 9 ? 1 : (day.month <= 2 || day.month == 12 ? -1 : 0));
      final m = mpg * season * (0.95 + rng.next() * 0.1);
      final partial = k % 9 == 4;
      final gal = double.parse((tank * (partial ? 0.35 : 0.72 + rng.next() * 0.2)).toStringAsFixed(3));
      odo += gal * m;
      final price = 3.05 + 0.35 * (day.month >= 4 && day.month <= 8 ? 1 : 0) + rng.next() * 0.3;
      d.fills.add(
        FillUp(
          id: '${v.id}-f$k',
          vehicleId: v.id,
          date: day,
          odometer: odo.roundToDouble(),
          volume: gal,
          cost: double.parse((gal * double.parse(price.toStringAsFixed(3))).toStringAsFixed(2)),
          full: !partial,
          note: k % 11 == 0 ? 'Costco' : '',
        ),
      );
    }
  }

  drive(civic, 41250, 32.5, 12.4, 8);
  drive(truck, 18800, 19.5, 26, 7);

  final civicFills = d.fills.where((f) => f.vehicleId == civic.id).toList();
  double odoNear(DateTime t) =>
      civicFills.lastWhere((f) => !f.date.isAfter(t), orElse: () => civicFills.first).odometer + 40;
  void svc(String id, int monthsAgo, int dayOfMonth, String kind, double cost, {String note = ''}) {
    final t = DateTime(today.year, today.month - monthsAgo, dayOfMonth, 10, 30);
    d.services.add(
      Service(id: id, vehicleId: civic.id, date: t, kind: kind, odometer: odoNear(t), cost: cost, note: note),
    );
  }

  svc('demo-s1', 11, 14, 'Oil change', 64.99, note: 'Full synthetic 0W-20');
  svc('demo-s2', 8, 2, 'Tire rotation', 25);
  svc('demo-s3', 7, 20, 'Registration', 132);
  svc('demo-s4', 5, 9, 'Oil change', 69.99);
  svc('demo-s5', 3, 16, 'Car wash', 15);
  svc('demo-s6', 2, 1, 'Wipers', 32.48);
  d.services.add(
    Service(
      id: 'demo-s7',
      vehicleId: truck.id,
      date: DateTime(today.year, today.month - 4, 12, 9),
      kind: 'Oil change',
      odometer: 25100,
      cost: 89.5,
    ),
  );

  d.reminders.addAll([
    Reminder(id: 'demo-r1', vehicleId: civic.id, kind: 'Oil change', everyMiles: 5000, everyMonths: 6),
    Reminder(id: 'demo-r2', vehicleId: civic.id, kind: 'Tire rotation', everyMiles: 6000, everyMonths: 6),
    Reminder(id: 'demo-r3', vehicleId: civic.id, kind: 'Registration', everyMonths: 12),
    Reminder(id: 'demo-r4', vehicleId: truck.id, kind: 'Oil change', everyMiles: 7500, everyMonths: 6),
  ]);
  return d;
}
