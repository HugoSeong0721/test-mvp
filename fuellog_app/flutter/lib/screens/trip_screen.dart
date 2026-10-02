import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';

/// 로드트립 기름값 나누기. 연비·단가는 내 기록에서 가져온다 (없으면 직접).
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final s = AppStore.i;
  late final Units u = s.units;
  double? _dist, _econ, _price;
  bool _round = false;
  int _people = 2;
  late final bool _econFromLog, _priceFromLog;

  @override
  void initState() {
    super.initState();
    final avg = s.log.avgMpg();
    _econFromLog = avg != null;
    if (avg != null) _econ = double.parse(u.economy.fromMpg(avg).toStringAsFixed(1));
    final p = s.lastPricePerGallon;
    _priceFromLog = p != null;
    if (p != null) _price = double.parse(s.fmt.pricePerUnit(p).toStringAsFixed(3));
  }

  TripCost get _trip => TripCost(
    miles: u.distance.toMiles(_dist ?? 0),
    mpg: u.economy.toMpg(_econ ?? 0),
    pricePerGallon: u.volume == VolumeUnit.gal ? (_price ?? 0) : (_price ?? 0) * litersPerGallon,
    people: _people,
    roundTrip: _round,
  );

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final f = s.fmt;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final t = _trip;
    Widget round(String key, IconData i, VoidCallback? on, String tip) =>
        IconButton.filledTonal(key: Key(key), tooltip: tip, onPressed: on, icon: Icon(i));
    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(title: const Text('Trip cost split')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('form'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FieldRow(
                        label: 'Distance',
                        hint: 'One way',
                        child: NumField(
                          key: const Key('trip-dist'),
                          semanticLabel: 'Trip distance',
                          value: _dist,
                          max: 99999,
                          suffix: u.distance.short,
                          hint: '0',
                          onChanged: (v) => setState(() => _dist = v),
                        ),
                      ),
                      SwitchRow(
                        switchKey: 'trip-round',
                        label: 'Round trip',
                        value: _round,
                        onChanged: (v) => setState(() => _round = v),
                      ),
                      FieldRow(
                        label: 'Fuel economy',
                        hint: _econFromLog ? 'Your average' : 'Your car',
                        child: NumField(
                          key: const Key('trip-econ'),
                          semanticLabel: 'Fuel economy',
                          value: _econ,
                          decimals: 1,
                          max: 999,
                          suffix: u.economy.short,
                          onChanged: (v) => setState(() => _econ = v),
                        ),
                      ),
                      FieldRow(
                        label: 'Gas price',
                        hint: _priceFromLog
                            ? 'Your last fill-up'
                            : 'per ${u.volume == VolumeUnit.gal ? 'gallon' : 'liter'}',
                        child: NumField(
                          key: const Key('trip-price'),
                          semanticLabel: 'Gas price',
                          value: _price,
                          decimals: 3,
                          max: 999,
                          prefix: r'$',
                          suffix: '/${u.volume.short}',
                          fixedDecimals: true,
                          onChanged: (v) => setState(() => _price = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('People', style: TextStyle(fontSize: 15, color: tk.text)),
                            ),
                            round(
                              'trip-minus',
                              Icons.remove_rounded,
                              _people > 1 ? () => setState(() => _people--) : null,
                              'Fewer people',
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '$_people',
                                key: const Key('trip-people'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tk.text),
                              ),
                            ),
                            round(
                              'trip-plus',
                              Icons.add_rounded,
                              _people < 20 ? () => setState(() => _people++) : null,
                              'More people',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const Key('trip-result'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: tk.accentSoft, borderRadius: BorderRadius.circular(16)),
                  child: t.valid
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Each person pays', style: TextStyle(fontSize: 14, color: tk.text2)),
                            Text(
                              money(t.perPerson),
                              key: const Key('trip-each'),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: tk.accent,
                                fontFeatures: tabular,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Total ${money(t.total)} · ${u.volume.fromGallons(t.gallons).toStringAsFixed(1)} ${u.volume.short} for ${f.dist(t.totalMiles)}',
                              key: const Key('trip-total'),
                              style: TextStyle(fontSize: 14, color: tk.text2, fontFeatures: tabular),
                            ),
                          ],
                        )
                      : Text(
                          'Enter the distance${_econ == null ? ', fuel economy' : ''}${_price == null ? ' and gas price' : ''} to split the cost.',
                          style: TextStyle(fontSize: 14, color: tk.text2),
                        ),
                ),
              ],
            ),
          ),
          if (keyboard) const KeyboardBar(),
        ],
      ),
    );
  }
}
