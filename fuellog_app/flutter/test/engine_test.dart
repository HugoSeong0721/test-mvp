// 엔진 테스트 — 화면 없이 숫자만. 손으로 계산한 값과 맞는지 고정한다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuellog/core/calc.dart';
import 'package:fuellog/core/csv.dart';
import 'package:fuellog/core/model.dart';
import 'package:fuellog/core/units.dart';

const car = 'car1';

FillUp fill(String id, DateTime d, double odo, double gal, double cost, {bool full = true, bool missed = false}) =>
    FillUp(id: id, vehicleId: car, date: d, odometer: odo, volume: gal, cost: cost, full: full, missed: missed);

DateTime day(int m, int d, [int y = 2026]) => DateTime(y, m, d, 12);

void main() {
  group('MPG', () {
    test('first full fill-up is the baseline, next full gives MPG', () {
      final log = VehicleLog([fill('a', day(9, 1), 10000, 12, 40), fill('b', day(9, 8), 10300, 10, 35)], []);
      expect(log.info['a']!.role, FillRole.first);
      expect(log.info['b']!.role, FillRole.tank);
      expect(log.tanks.single.mpg, closeTo(30, 1e-9));
      expect(log.tanks.single.costPerMile, closeTo(35 / 300, 1e-9));
      expect(log.avgMpg(), closeTo(30, 1e-9));
    });

    test('partial fill-ups add their fuel to the next full tank', () {
      final log = VehicleLog([
        fill('a', day(9, 1), 10000, 12, 40),
        fill('p', day(9, 4), 10150, 4, 14, full: false),
        fill('b', day(9, 8), 10400, 6, 21),
      ], []);
      expect(log.info['p']!.role, FillRole.partial);
      expect(log.info['p']!.tank, same(log.tanks.single));
      expect(log.tanks.single.gallons, 10);
      expect(log.tanks.single.mpg, closeTo(40, 1e-9));
      expect(log.tanks.single.fills, 2);
    });

    test('a missed fill-up skips that tank, then counting restarts', () {
      final log = VehicleLog([
        fill('a', day(9, 1), 10000, 12, 40),
        fill('b', day(9, 15), 10900, 10, 35, missed: true),
        fill('c', day(9, 22), 11200, 10, 35),
      ], []);
      expect(log.info['b']!.role, FillRole.skipped);
      expect(log.info['c']!.role, FillRole.tank);
      expect(log.tanks.single.mpg, closeTo(30, 1e-9));
    });

    test('partial fill-ups before the first full tank are not used', () {
      final log = VehicleLog([
        fill('p', day(9, 1), 9900, 3, 10, full: false),
        fill('a', day(9, 2), 10000, 12, 40),
        fill('b', day(9, 9), 10250, 10, 35),
      ], []);
      expect(log.info['p']!.role, FillRole.beforeFirst);
      expect(log.avgMpg(), closeTo(25, 1e-9));
    });

    test('average = total miles / total gallons, not the mean of tanks', () {
      final log = VehicleLog([
        fill('a', day(9, 1), 10000, 10, 30),
        fill('b', day(9, 2), 10100, 5, 15), // 20 MPG, 100 mi
        fill('c', day(9, 9), 10500, 10, 30), // 40 MPG, 400 mi
      ], []);
      expect(log.avgMpg(), closeTo(500 / 15, 1e-9));
      expect(log.lastTank!.end.id, 'c');
      expect(log.fuelCostPerMile(), closeTo(45 / 500, 1e-9));
    });

    test('entries out of date order are sorted by odometer', () {
      final log = VehicleLog([fill('b', day(9, 8), 10300, 10, 35), fill('a', day(9, 1), 10000, 12, 40)], []);
      expect(log.tanks.single.end.id, 'b');
    });

    test('open partial fill-up waits for the next full tank', () {
      final log = VehicleLog([
        fill('a', day(9, 1), 10000, 12, 40),
        fill('p', day(9, 4), 10150, 4, 14, full: false),
      ], []);
      expect(log.info['p']!.role, FillRole.partial);
      expect(log.info['p']!.tank, isNull);
      expect(log.avgMpg(), isNull);
    });
  });

  group('units', () {
    test('MPG conversions', () {
      expect(EconomyUnit.l100km.fromMpg(30), closeTo(7.8405, 1e-3));
      expect(EconomyUnit.kml.fromMpg(30), closeTo(12.754, 1e-3));
      for (final u in EconomyUnit.values) {
        expect(u.toMpg(u.fromMpg(27.3)), closeTo(27.3, 1e-9));
      }
      expect(DistanceUnit.km.fromMiles(100), closeTo(160.9344, 1e-9));
      expect(VolumeUnit.l.fromGallons(1), closeTo(3.785411784, 1e-12));
      expect(EconomyUnit.natural(DistanceUnit.km, VolumeUnit.l), EconomyUnit.l100km);
      expect(EconomyUnit.natural(DistanceUnit.mi, VolumeUnit.gal), EconomyUnit.mpg);
    });
  });

  group('monthly costs', () {
    test('fuel and service per month, empty months included', () {
      final log = VehicleLog(
        [fill('a', day(7, 3), 10000, 10, 40), fill('b', day(9, 3), 10300, 10, 35)],
        [Service(id: 's', vehicleId: car, date: day(9, 20), kind: 'Oil change', cost: 60)],
      );
      final m = log.monthly(day(10, 2));
      expect([for (final e in m) e.month], [7, 8, 9, 10]);
      expect(m[0].fuel, 40);
      expect(m[1].total, 0);
      expect(m[2].fuel, 35);
      expect(m[2].service, 60);
      expect(log.fuelSpent(since: DateTime(2026, 9)), 35);
    });
  });

  group('dates', () {
    test('addMonths clamps to month end', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
    });

    test('CSV date formats', () {
      expect(parseCsvDate('2026-10-02'), DateTime(2026, 10, 2, 12));
      expect(parseCsvDate('2026-10-02 09:15'), DateTime(2026, 10, 2, 9, 15));
      expect(parseCsvDate('2026-10-02T21:05:00'), DateTime(2026, 10, 2, 21, 5));
      expect(parseCsvDate('10/02/2026'), DateTime(2026, 10, 2, 12));
      expect(parseCsvDate('10/2/26 9:15 PM'), DateTime(2026, 10, 2, 21, 15));
      expect(parseCsvDate('25/09/2026'), DateTime(2026, 9, 25, 12));
      expect(parseCsvDate('02.10.2026'), DateTime(2026, 10, 2, 12));
      expect(parseCsvDate('2026-02-30'), isNull);
      expect(parseCsvDate('soon'), isNull);
    });
  });

  group('reminders', () {
    final now = day(10, 2);
    VehicleLog logWith(List<Service> s) => VehicleLog([
      fill('a', day(6, 1), 40000, 12, 40),
      fill('b', day(7, 1), 41000, 12, 40),
      fill('c', day(8, 1), 42000, 12, 40),
      fill('d', day(9, 30), 44000, 12, 40),
    ], s);

    test('miles-based reminder uses the last service of that kind', () {
      final r = Reminder(id: 'r', vehicleId: car, kind: 'Oil change', everyMiles: 5000);
      final st = ReminderState.of(
        r,
        logWith([Service(id: 's', vehicleId: car, date: day(7, 1), kind: 'oil change', odometer: 41000, cost: 50)]),
        now,
      );
      expect(st.lastService?.id, 's');
      expect(st.dueOdometer, 46000);
      expect(st.milesLeft, 2000);
      expect(st.level, ReminderLevel.ok);
      expect(st.progress, closeTo(0.6, 1e-9));
      // 최근 180일: 4000 mi / 121 일 → 남은 2000 mi 는 약 61일 뒤
      expect(st.estimatedDate, isNotNull);
      expect(daysBetween(day(9, 30), st.estimatedDate!), 61);
    });

    test('estimated date already passed → due now, notify tomorrow morning (not never)', () {
      // 9/22 이후 기록이 없고, 하루 ~30 mi 로 203 mi 남음 → 예상일 9/29 은 오늘(10/2)보다 앞
      final log = VehicleLog([fill('a', day(8, 23), 54200, 12, 40), fill('b', day(9, 22), 55106, 12, 40)], []);
      final r = Reminder(
        id: 'r',
        vehicleId: car,
        kind: 'Oil change',
        everyMiles: 5000,
        lastOdometer: 50309,
        lastDate: day(5, 9),
      );
      final st = ReminderState.of(r, log, now);
      expect(st.milesLeft, closeTo(203, 1e-9));
      expect(st.estimatedDate, dayOf(now), reason: 'never in the past');
      expect(st.estimatePassed, isTrue);
      expect(st.notifyAt!.isAfter(now), isTrue, reason: 'still gets a notification');
      expect(st.notifyAt, DateTime(2026, 10, 3, 9));
    });

    test('months-based reminder with a manual "last done" date', () {
      final r = Reminder(id: 'r', vehicleId: car, kind: 'Inspection', everyMonths: 12, lastDate: day(10, 10, 2025));
      final st = ReminderState.of(r, logWith([]), now);
      expect(st.dueDate, DateTime(2026, 10, 10));
      expect(st.daysLeft, 8);
      expect(st.level, ReminderLevel.soon);
      expect(st.notifyAt, DateTime(2026, 10, 10, 9));
    });

    test('overdue by miles, and earliest of date / distance wins', () {
      final r = Reminder(
        id: 'r',
        vehicleId: car,
        kind: 'Tire rotation',
        everyMiles: 3000,
        everyMonths: 6,
        lastOdometer: 40000,
        lastDate: day(6, 1),
      );
      final st = ReminderState.of(r, logWith([]), now);
      expect(st.milesLeft, -1000);
      expect(st.level, ReminderLevel.overdue);
      expect(st.estimatedDate, isNull);
    });

    test('logging the service resets the reminder', () {
      final r = Reminder(
        id: 'r',
        vehicleId: car,
        kind: 'Tire rotation',
        everyMiles: 3000,
        lastOdometer: 40000,
        lastDate: day(6, 1),
      );
      final st = ReminderState.of(
        r,
        logWith([Service(id: 's', vehicleId: car, date: day(9, 30), kind: 'Tire rotation', odometer: 44000)]),
        now,
      );
      expect(st.dueOdometer, 47000);
      expect(st.level, ReminderLevel.ok);
    });

    test('service without odometer uses the odometer known on that day', () {
      final r = Reminder(id: 'r', vehicleId: car, kind: 'Oil change', everyMiles: 5000);
      final st = ReminderState.of(
        r,
        logWith([Service(id: 's', vehicleId: car, date: day(8, 5), kind: 'Oil change')]),
        now,
      );
      expect(st.baseOdometer, 42000);
      expect(st.dueOdometer, 47000);
    });

    test('miles-only reminder without any odometer is unknown', () {
      final r = Reminder(id: 'r', vehicleId: car, kind: 'Oil change', everyMiles: 5000);
      final st = ReminderState.of(r, VehicleLog([], []), now);
      expect(st.level, ReminderLevel.unknown);
      expect(st.notifyAt, isNull);
    });
  });

  group('trip cost', () {
    test('split', () {
      const t = TripCost(miles: 300, mpg: 30, pricePerGallon: 3.5, people: 4, roundTrip: true);
      expect(t.gallons, 20);
      expect(t.total, 70);
      expect(t.perPerson, 17.5);
      expect(t.valid, isTrue);
      expect(const TripCost(miles: 0, mpg: 30, pricePerGallon: 3, people: 1).valid, isFalse);
    });
  });

  group('storage JSON', () {
    test('round trip and broken entries dropped', () {
      final d = LogData(
        vehicles: [Vehicle(id: car, name: 'Civic')],
        fills: [fill('a', day(9, 1), 10000, 12.345, 42.7, full: false)..note = 'Costco'],
        services: [Service(id: 's', vehicleId: car, date: day(9, 2), kind: 'Oil change', cost: 59.99)],
        reminders: [Reminder(id: 'r', vehicleId: car, kind: 'Oil change', everyMiles: 5000, everyMonths: 6)],
        units: Units.metric,
        currentVehicleId: car,
      );
      final j = jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>;
      (j['fills'] as List).add({'id': 'x', 'vehicle': car, 'date': 'nope', 'odo': 1, 'vol': 1, 'cost': 1});
      (j['fills'] as List).add({'id': 'y', 'vehicle': 'ghost', 'date': '2026-01-01', 'odo': 1, 'vol': 1, 'cost': 1});
      (j['reminders'] as List).add({'id': 'z', 'vehicle': car, 'kind': 'X'});
      final back = LogData.fromJson(j);
      expect(back.fills.length, 1);
      expect(back.fills.single.full, isFalse);
      expect(back.fills.single.note, 'Costco');
      expect(back.services.single.cost, 59.99);
      expect(back.reminders.length, 1);
      expect(back.units, Units.metric);
      expect(back.currentVehicleId, car);
      expect(LogData.fromJson('garbage').vehicles, isEmpty);
    });
  });

  group('CSV', () {
    LogData sample() => LogData(
      vehicles: [
        Vehicle(id: car, name: 'Civic, "Blue"'),
        Vehicle(id: 'car2', name: 'Truck'),
      ],
      fills: [
        fill('a', day(9, 1), 10000, 12.345, 42.70),
        fill('p', day(9, 4), 10150.5, 4, 14, full: false)..note = 'half tank\nnew line',
        fill('b', day(9, 8), 10400, 6, 21, missed: true),
        FillUp(id: 't', vehicleId: 'car2', date: day(9, 3), odometer: 5000, volume: 20, cost: 70),
      ],
      services: [
        Service(
          id: 's',
          vehicleId: car,
          date: day(9, 20),
          kind: 'Oil change',
          odometer: 10500,
          cost: 59.99,
          note: 'synthetic',
        ),
        Service(id: 's2', vehicleId: 'car2', date: day(9, 21), kind: 'Insurance', cost: 120),
      ],
      reminders: [
        Reminder(
          id: 'r',
          vehicleId: car,
          kind: 'Oil change',
          everyMiles: 5000,
          everyMonths: 6,
          lastDate: day(9, 20),
          lastOdometer: 10500,
        ),
      ],
    );

    test('export then import into an empty log gives the same records', () {
      final src = sample();
      final text = exportCsv(src);
      expect(text.split('\r\n').first, startsWith('Vehicle,Type,Date,Odometer (mi),Fuel (gal)'));
      final dst = LogData();
      final plan = planImport(text, dst);
      expect(plan.problems, isEmpty);
      expect(plan.newVehicles.map((v) => v.name), ['Civic, "Blue"', 'Truck']);
      expect(plan.fills.length, 4);
      expect(plan.services.length, 2);
      expect(plan.reminders.length, 1);
      plan.apply(dst);
      final civic = dst.vehicles.first.id;
      final p = dst.fills.firstWhere((f) => f.odometer == 10150.5);
      expect(p.vehicleId, civic);
      expect(p.full, isFalse);
      expect(p.note, 'half tank\nnew line');
      expect(dst.fills.firstWhere((f) => f.odometer == 10400).missed, isTrue);
      expect(dst.fills.firstWhere((f) => f.odometer == 10000).volume, closeTo(12.345, 1e-9));
      expect(dst.fills.firstWhere((f) => f.odometer == 10000).cost, closeTo(42.70, 1e-9));
      expect(dst.services.firstWhere((s) => s.kind == 'Insurance').odometer, isNull);
      expect(dst.reminders.single.everyMonths, 6);
      expect(dst.currentVehicleId, civic);

      // 같은 파일을 또 가져오면 전부 중복으로 건너뛴다
      final again = planImport(text, dst);
      expect(again.total, 0);
      expect(again.duplicates, 7);
    });

    test('metric export keeps units in the header and reads back exactly', () {
      final src = sample()..units = Units.metric;
      final text = exportCsv(src);
      expect(text, contains('Odometer (km)'));
      expect(text, contains('Fuel (L)'));
      final plan = planImport(text, LogData());
      expect(plan.distanceUnit, DistanceUnit.km);
      expect(plan.volumeUnit, VolumeUnit.l);
      final f = plan.fills.firstWhere((f) => (f.odometer - 10000).abs() < 0.1);
      expect(f.volume, closeTo(12.345, 1e-3));
    });

    test('Fuelly import format (snake_case, partial/missed 1/0)', () {
      const text =
          'fuelup_date,odometer,gallons,price,partial_fuelup,missed_fuelup,notes\n'
          '2026-09-01,10000,12,3.25,0,0,\n'
          '9/4/26,10150,4,3.50,1,0,top off\n'
          '2026-09-08,10400,6,3.50,0,0,\n';
      final d = LogData(
        vehicles: [Vehicle(id: car, name: 'Civic')],
      );
      final plan = planImport(text, d, defaultVehicleId: car);
      expect(plan.problems, isEmpty);
      // 'gallons' 는 적혀 있지만 주행거리 단위는 없다 → 추정(화면에서 바꿀 수 있게)
      expect(plan.unitsGuessed, isTrue);
      expect(plan.volumeUnit, VolumeUnit.gal);
      expect(plan.fills.length, 3);
      expect(plan.fills[1].full, isFalse);
      expect(plan.fills[1].cost, closeTo(14, 1e-9));
      plan.apply(d);
      expect(VehicleLog(d.fills, []).avgMpg(), closeTo(40, 1e-9));
    });

    test('Fuelly app export (Type Gas/Service, separate Time, Full/Partial, \$ prices)', () {
      const text =
          'Type,MPG,Date,Time,Vehicle,Odometer,Filled Up,Price,Gallons,Total Cost,Octane,Gas Brand,Location,Tags,Payment Type,Tire Pressure,Notes,Services\n'
          'Gas,,2026-09-01,8:05 AM,Civic,"10,000",Full,\$3.259,12.000,\$39.11,87,Shell,,,,,,\n'
          'Gas,,2026-09-04,6:30 PM,Civic,"10,150",Partial,\$3.499,4.000,\$14.00,87,,,,,,,\n'
          'Gas,40.0,2026-09-08,7:00 AM,Civic,"10,400",Full,\$3.499,6.000,\$20.99,87,,,,,,,\n'
          'Service,,2026-09-20,10:00 AM,Civic,"10,500",,,,\$59.99,,,,,,,synthetic,Oil Change\n';
      final plan = planImport(text, LogData());
      expect(plan.problems, isEmpty);
      expect(plan.newVehicles.single.name, 'Civic');
      expect(plan.fills.length, 3);
      expect(plan.fills[0].date, DateTime(2026, 9, 1, 8, 5));
      expect(plan.fills[1].date, DateTime(2026, 9, 4, 18, 30));
      expect(plan.fills[1].full, isFalse);
      expect(plan.fills[0].odometer, 10000);
      expect(plan.fills[0].cost, closeTo(39.11, 1e-9));
      expect(plan.services.single.kind, 'Oil Change');
      expect(plan.services.single.cost, closeTo(59.99, 1e-9));
      expect(plan.services.single.note, 'synthetic');
    });

    test('trip miles instead of odometer are added up', () {
      const text =
          'Date,Miles,Gallons,Total\n'
          '2026-09-01,0,12,40\n'
          '2026-09-08,300,10,35\n'
          '2026-09-15,320,10,36\n';
      final plan = planImport(text, LogData());
      expect(plan.problems, isEmpty);
      expect([for (final f in plan.fills) f.odometer], [0, 300, 620]);
    });

    test('semicolon file with decimal commas (European export)', () {
      const text =
          'Date;Odometer (km);Litres;Total\n'
          '02.09.2026;16000;40,5;70,20\n';
      final plan = planImport(text, LogData());
      expect(plan.problems, isEmpty);
      expect(plan.fills.single.volume, closeTo(40.5 / litersPerGallon, 1e-9));
      expect(plan.fills.single.cost, closeTo(70.2, 1e-9));
      expect(plan.fills.single.odometer, closeTo(16000 / kmPerMile, 1e-9));
    });

    test('bad rows are reported with line numbers, good rows kept', () {
      const text =
          'Date,Odometer,Gallons,Total\n'
          'yesterday,10000,12,40\n'
          '2026-09-08,10300,,35\n'
          '2026-09-15,10600,10,36\n';
      final plan = planImport(text, LogData());
      expect(plan.fills.length, 1);
      expect([for (final p in plan.problems) p.line], [2, 3]);
    });

    test('file without the needed columns is refused', () {
      final plan = planImport('a,b,c\n1,2,3\n', LogData());
      expect(plan.isEmpty, isTrue);
      expect(plan.problems.single.line, 1);
      expect(planImport('', LogData()).problems, isNotEmpty);
    });

    test('quoted cells with commas, quotes and new lines', () {
      final rows = parseCsv('a,b\r\n"x, y","say ""hi""\nthere"\r\n');
      expect(rows, [
        ['a', 'b'],
        ['x, y', 'say "hi"\nthere'],
      ]);
    });
  });
}
