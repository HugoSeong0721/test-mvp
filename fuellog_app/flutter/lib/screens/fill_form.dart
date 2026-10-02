import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';

Future<void> openFillForm(BuildContext context, {FillUp? edit}) async {
  final r = await Navigator.of(context).push<FormResult>(
    MaterialPageRoute(
      builder: (_) => FillForm(edit: edit),
      fullscreenDialog: edit == null,
    ),
  );
  if (r != null && context.mounted) showResult(context, r);
}

enum _F { vol, price, total }

enum OdoMode { odometer, trip }

/// 주유 한 번 기록 — 한 화면. 양·단가·총액 중 둘을 넣으면 나머지가 채워지고, 저장 전에 이번 탱크 연비가 보인다.
class FillForm extends StatefulWidget {
  const FillForm({super.key, this.edit});
  final FillUp? edit;

  @override
  State<FillForm> createState() => _FillFormState();
}

class _FillFormState extends State<FillForm> {
  final s = AppStore.i;
  late final Units u = s.units;
  late final String vehicleId = widget.edit?.vehicleId ?? s.vehicle!.id;
  late DateTime _date = widget.edit?.date ?? s.now();
  OdoMode _mode = OdoMode.odometer;
  double? _odo, _trip, _vol, _price, _total;
  bool _full = true, _missed = false;
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  List<_F> _recent = [_F.vol, _F.price];
  bool _tried = false, _dirty = false;

  bool get editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _odo = _round(u.distance.fromMiles(e.odometer), 1);
      _vol = _round(u.volume.fromGallons(e.volume), 3);
      _total = e.cost;
      _price = _vol! > 0 ? _round(e.cost / _vol!, 3) : null;
      _full = e.full;
      _missed = e.missed;
      _recent = [_F.vol, _F.total];
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static double _round(double v, int d) => double.parse(v.toStringAsFixed(d));

  _F get _auto => _F.values.firstWhere((f) => !_recent.contains(f));

  void _set(_F f, double? v) {
    setState(() {
      _dirty = true;
      switch (f) {
        case _F.vol:
          _vol = v;
        case _F.price:
          _price = v;
        case _F.total:
          _total = v;
      }
      _recent = [f, ..._recent.where((e) => e != f)].take(2).toList();
      switch (_auto) {
        case _F.total:
          _total = _vol != null && _price != null ? _round(_vol! * _price!, 2) : null;
        case _F.price:
          _price = _vol != null && _vol! > 0 && _total != null ? _round(_total! / _vol!, 3) : null;
        case _F.vol:
          _vol = _price != null && _price! > 0 && _total != null ? _round(_total! / _price!, 3) : null;
      }
    });
  }

  FillUp? get _prev => s.previousFill(vehicleId, _date, exceptId: widget.edit?.id);

  /// 마일로 바꾼 주행거리.
  double? get _odoMiles {
    if (_mode == OdoMode.trip) {
      final p = _prev;
      return p == null || _trip == null || _trip! <= 0 ? null : p.odometer + u.distance.toMiles(_trip!);
    }
    return _odo == null || _odo! <= 0 ? null : u.distance.toMiles(_odo!);
  }

  FillUp? _draft() {
    final odo = _odoMiles;
    if (odo == null || _vol == null || _vol! <= 0) return null;
    return FillUp(
      id: widget.edit?.id ?? 'draft',
      vehicleId: vehicleId,
      date: _date,
      odometer: odo,
      volume: u.volume.toGallons(_vol!),
      cost: _total ?? 0,
      full: _full,
      missed: _missed,
      note: _note.text.trim(),
    );
  }

  String? get _odoError {
    final odo = _odoMiles;
    if (odo == null) {
      if (!_tried) return null;
      return _mode == OdoMode.trip ? 'Enter the trip distance' : 'Enter the odometer reading';
    }
    final c = s.odometerConflict(vehicleId, _date, odo, exceptId: widget.edit?.id);
    if (c == null) return null;
    final f = s.fmt;
    final when = '${fmtDate(c.date)} fill-up';
    if ((c.odometer - odo).abs() < 0.05) return 'Same as the $when (${f.dist(c.odometer)})';
    return c.date.isBefore(_date)
        ? 'Must be more than ${f.dist(c.odometer)} ($when)'
        : 'Must be less than ${f.dist(c.odometer)} ($when)';
  }

  String? get _volError => _tried && (_vol == null || _vol! <= 0) ? 'Enter how much fuel you bought' : null;
  String? get _costError => _tried && _total == null ? 'Enter the total or the price' : null;

  void _save() {
    setState(() => _tried = true);
    final d = _draft();
    if (d == null || _odoError != null || _costError != null) return;
    final f = FillUp(
      id: widget.edit?.id ?? newId(),
      vehicleId: d.vehicleId,
      date: d.date,
      odometer: d.odometer,
      volume: d.volume,
      cost: d.cost,
      full: d.full,
      missed: d.missed,
      note: d.note,
    );
    final old = widget.edit == null ? null : FillUp.fromJson(widget.edit!.toJson());
    s.saveFill(f);
    final info = s.logFor(vehicleId).info[f.id];
    final mpg = info?.role == FillRole.tank ? ' · ${s.fmt.econ(info!.tank!.mpg)} this tank' : '';
    Navigator.pop(
      context,
      FormResult(
        '${editing ? 'Fill-up updated' : 'Fill-up saved'}$mpg',
        undo: old == null ? () => s.deleteFill(f.id) : () => s.saveFill(old),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete fill-up?',
      message: 'This fill-up will be removed from your log.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final gone = s.deleteFill(widget.edit!.id);
    Navigator.pop(context, FormResult('Fill-up deleted', undo: gone == null ? null : () => s.saveFill(gone)));
  }

  Future<void> _pickDate() async {
    final d = await pickDate(context, _date, max: s.now());
    if (d != null && mounted) {
      setState(() {
        _date = d;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final f = s.fmt;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final prev = _prev;
    final odoErr = _odoError;
    final canTrip = !editing && prev != null;
    final vs = u.volume.short;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (popped, _) async {
        if (popped) return;
        final nav = Navigator.of(context);
        final ok = await confirm(
          context,
          title: 'Discard changes?',
          message: "This fill-up hasn't been saved.",
          action: 'Discard',
        );
        if (ok && mounted) {
          setState(() => _dirty = false);
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: tk.bg,
        appBar: AppBar(
          leading: IconButton(
            key: const Key('fill-close'),
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(editing ? 'Edit fill-up' : 'Fill-up'),
          actions: [
            TextButton(
              key: const Key('fill-save-top'),
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
          ],
        ),
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
                          label: 'Date',
                          child: DateField(fieldKey: 'fill-date', label: fmtDate(_date), onTap: _pickDate),
                        ),
                        if (canTrip)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Segmented<OdoMode>(
                              keyPrefix: 'mode',
                              items: const [(OdoMode.odometer, 'Odometer'), (OdoMode.trip, 'Trip meter')],
                              value: _mode,
                              onChanged: (m) => setState(() => _mode = m),
                            ),
                          ),
                        if (_mode == OdoMode.odometer)
                          FieldRow(
                            label: 'Odometer',
                            hint: prev == null ? null : 'Last: ${f.dist(prev.odometer)}',
                            child: NumField(
                              key: const Key('fill-odo'),
                              semanticLabel: 'Odometer',
                              value: _odo,
                              decimals: 1,
                              max: 9999999,
                              suffix: u.distance.short,
                              error: odoErr != null,
                              onChanged: (v) => setState(() {
                                _odo = v;
                                _dirty = true;
                              }),
                            ),
                          )
                        else
                          FieldRow(
                            label: 'Trip distance',
                            hint: _odoMiles == null ? 'Since last fill-up' : 'Odometer ${f.dist(_odoMiles!)}',
                            child: NumField(
                              key: const Key('fill-trip'),
                              semanticLabel: 'Trip distance',
                              value: _trip,
                              decimals: 1,
                              max: 99999,
                              suffix: u.distance.short,
                              error: odoErr != null,
                              onChanged: (v) => setState(() {
                                _trip = v;
                                _dirty = true;
                              }),
                            ),
                          ),
                        if (odoErr != null) _ErrorText(odoErr, k: 'odo-error'),
                      ],
                    ),
                  ),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldRow(
                          label: u.volume == VolumeUnit.gal ? 'Gallons' : 'Liters',
                          child: NumField(
                            key: const Key('fill-vol'),
                            semanticLabel: u.volume == VolumeUnit.gal ? 'Gallons' : 'Liters',
                            value: _vol,
                            decimals: 3,
                            max: 9999,
                            suffix: vs,
                            dim: _auto == _F.vol,
                            error: _volError != null,
                            onChanged: (v) => _set(_F.vol, v),
                          ),
                        ),
                        if (_volError != null) _ErrorText(_volError!, k: 'vol-error'),
                        FieldRow(
                          label: 'Price',
                          hint: 'per ${u.volume == VolumeUnit.gal ? 'gallon' : 'liter'}',
                          child: NumField(
                            key: const Key('fill-price'),
                            semanticLabel: 'Price per ${u.volume == VolumeUnit.gal ? 'gallon' : 'liter'}',
                            value: _price,
                            decimals: 3,
                            max: 999,
                            prefix: r'$',
                            suffix: '/$vs',
                            fixedDecimals: true,
                            dim: _auto == _F.price,
                            hint: s.lastPricePerGallon == null
                                ? null
                                : f.pricePerUnit(s.lastPricePerGallon!).toStringAsFixed(3),
                            onChanged: (v) => _set(_F.price, v),
                          ),
                        ),
                        FieldRow(
                          label: 'Total',
                          child: NumField(
                            key: const Key('fill-total'),
                            semanticLabel: 'Total cost',
                            value: _total,
                            decimals: 2,
                            max: 99999,
                            prefix: r'$',
                            fixedDecimals: true,
                            dim: _auto == _F.total,
                            error: _costError != null,
                            onChanged: (v) => _set(_F.total, v),
                          ),
                        ),
                        if (_costError != null) _ErrorText(_costError!, k: 'cost-error'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Enter any two — the third fills in.',
                            style: TextStyle(fontSize: 12, color: tk.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchRow(
                          switchKey: 'fill-full',
                          label: 'Filled the tank',
                          hint: 'Turn off for a partial fill-up',
                          value: _full,
                          onChanged: (v) => setState(() {
                            _full = v;
                            _dirty = true;
                          }),
                        ),
                        SwitchRow(
                          switchKey: 'fill-missed',
                          label: 'Missed logging a fill-up',
                          hint: 'Skips MPG for this tank so your average stays right',
                          value: _missed,
                          onChanged: (v) => setState(() {
                            _missed = v;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const Key('fill-note'),
                          controller: _note,
                          maxLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _dirty = true,
                          style: TextStyle(fontSize: 16, color: tk.text),
                          decoration: InputDecoration(
                            hintText: 'Note (station, trip …)',
                            filled: true,
                            fillColor: tk.surface2,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Preview(draft: odoErr == null ? _draft() : null, vehicleId: vehicleId),
                  BigButton(
                    key: const Key('fill-save'),
                    label: 'Save fill-up',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
                  if (editing) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      key: const Key('fill-delete'),
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline_rounded, color: tk.bad),
                      label: Text(
                        'Delete fill-up',
                        style: TextStyle(color: tk.bad, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (keyboard) const KeyboardBar(),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text, {required this.k});
  final String text;
  final String k;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      key: Key(k),
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 13, color: Tk.of(context).bad, fontWeight: FontWeight.w600),
    ),
  );
}

/// 저장하기 전에 이번 탱크 결과를 보여 준다.
class _Preview extends StatelessWidget {
  const _Preview({required this.draft, required this.vehicleId});
  final FillUp? draft;
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    if (d == null) return const SizedBox.shrink();
    final tk = Tk.of(context);
    final s = AppStore.i;
    final f = s.fmt;
    final others = s.data.fills.where((e) => e.vehicleId == vehicleId && e.id != d.id);
    final log = VehicleLog([...others, d], []);
    final info = log.info[d.id];
    final avgBefore = VehicleLog(others, []).avgMpg();
    String title;
    String sub;
    var good = false;
    switch (info?.role) {
      case FillRole.tank:
        final t = info!.tank!;
        title = 'This tank: ${f.econ(t.mpg)}';
        sub = '${f.dist(t.miles)} on ${f.vol(t.gallons)}${t.cost > 0 ? ' · ${f.perDist(t.costPerMile)}' : ''}';
        good = true;
        if (avgBefore != null) {
          final diff = f.economy(t.mpg) - f.economy(avgBefore);
          final better = s.units.economy.higherIsBetter ? diff > 0 : diff < 0;
          if (diff.abs() >= 0.05) {
            sub =
                '$sub\n${diff.abs().toStringAsFixed(1)} ${f.eShort} ${better ? 'better' : 'worse'} than your average (${f.econ(avgBefore)})';
          }
          final ratio = t.mpg / avgBefore;
          if (ratio > 1.6 && !d.missed) {
            sub =
                '$sub\nMuch higher than usual — if you skipped logging a fill-up, turn on "Missed logging a fill-up".';
          }
        }
      case FillRole.first:
        title = 'First full tank';
        sub = 'MPG shows after your next full fill-up.';
      case FillRole.partial:
        title = 'Partial fill-up';
        sub = 'It counts toward the next full tank.';
      case FillRole.beforeFirst:
        title = 'Partial fill-up';
        sub = 'MPG starts after your first full tank.';
      case FillRole.skipped:
        title = 'MPG skipped for this tank';
        sub = 'Because a fill-up was missed. Counting restarts from here.';
      case null:
        return const SizedBox.shrink();
    }
    return Container(
      key: const Key('fill-preview'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: good ? tk.accentSoft : tk.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(good ? Icons.speed_rounded : Icons.info_outline_rounded, color: good ? tk.accent : tk.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('preview-title'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text, fontFeatures: tabular),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub,
                    style: TextStyle(fontSize: 13, height: 1.35, color: tk.text2, fontFeatures: tabular),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
