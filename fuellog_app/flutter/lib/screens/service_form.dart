import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';
import 'reminder_form.dart';

Future<void> openServiceForm(BuildContext context, {Service? edit, String? kind}) async {
  final r = await Navigator.of(context).push<FormResult>(
    MaterialPageRoute(
      builder: (_) => ServiceForm(edit: edit, kind: kind),
      fullscreenDialog: edit == null,
    ),
  );
  if (r != null && context.mounted) showResult(context, r);
}

/// 정비·기타 비용 기록. 같은 종류의 알림이 있으면 저장하는 순간 다시 센다.
class ServiceForm extends StatefulWidget {
  const ServiceForm({super.key, this.edit, this.kind});
  final Service? edit;
  final String? kind;

  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  final s = AppStore.i;
  late final Units u = s.units;
  late final String vehicleId = widget.edit?.vehicleId ?? s.vehicle!.id;
  late DateTime _date = widget.edit?.date ?? s.now();
  String? _kind;
  bool _custom = false;
  late final _customName = TextEditingController();
  double? _odo, _cost;
  late final _note = TextEditingController(text: widget.edit?.note ?? '');
  bool _tried = false, _dirty = false;

  bool get editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final k = widget.edit?.kind ?? widget.kind;
    if (k != null) {
      final p = presetKind(k);
      if (p != null) {
        _kind = p.name;
      } else {
        _custom = true;
        _customName.text = k;
      }
    }
    final e = widget.edit;
    if (e != null) {
      _odo = e.odometer == null ? null : double.parse(u.distance.fromMiles(e.odometer!).toStringAsFixed(1));
      _cost = e.cost;
    }
  }

  @override
  void dispose() {
    _customName.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _kindName => _custom ? _customName.text.trim() : (_kind ?? '');

  void _save() {
    setState(() => _tried = true);
    final kind = _kindName;
    if (kind.isEmpty) return;
    final svc = Service(
      id: widget.edit?.id ?? newId(),
      vehicleId: vehicleId,
      date: _date,
      kind: kind,
      odometer: _odo == null || _odo! <= 0 ? null : u.distance.toMiles(_odo!),
      cost: _cost ?? 0,
      note: _note.text.trim(),
    );
    final old = widget.edit == null ? null : Service.fromJson(widget.edit!.toJson());
    s.saveService(svc);
    final undo = old == null ? () => s.deleteService(svc.id) : () => s.saveService(old);
    // 같은 종류 알림이 있으면 다시 세기 시작한 걸 알려 준다
    final rem = s.remindersOf(vehicleId).where((r) => sameKind(r.kind, kind)).firstOrNull;
    if (rem != null) {
      final st = ReminderState.of(rem, s.logFor(vehicleId), s.now());
      final next = [
        if (st.dueOdometer != null) s.fmt.dist(st.dueOdometer!),
        if (st.dueDate != null) fmtDate(st.dueDate!),
      ].join(' or ');
      Navigator.pop(context, FormResult('$kind saved · next due ${next.isEmpty ? 'later' : next}', undo: undo));
      return;
    }
    final preset = presetKind(kind);
    final nav = Navigator.of(context);
    if (!editing && preset != null && preset.remindable) {
      Navigator.pop(
        context,
        FormResult(
          '$kind saved',
          actionLabel: 'Remind me next time',
          action: () => nav.push(
            MaterialPageRoute(
              builder: (_) => ReminderForm(kind: kind, vehicleId: vehicleId),
            ),
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, FormResult('${editing ? 'Updated' : 'Saved'}: $kind', undo: undo));
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this record?',
      message: '${widget.edit!.kind} on ${fmtDate(widget.edit!.date)} will be removed.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final gone = s.deleteService(widget.edit!.id);
    Navigator.pop(context, FormResult('Deleted', undo: gone == null ? null : () => s.saveService(gone)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final f = s.fmt;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final latest = s.logFor(vehicleId).latestOdometer;
    final kindMissing = _tried && _kindName.isEmpty;

    Widget chip(String key, String label, bool on, VoidCallback tap, {IconData? icon}) => Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: tap,
      child: GestureDetector(
        key: Key(key),
        onTap: () {
          HapticFeedback.selectionClick();
          tap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: on ? tk.service : tk.surface2, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: on ? Colors.white : tk.text2),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? Colors.white : tk.text2),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (popped, _) async {
        if (popped) return;
        final nav = Navigator.of(context);
        final ok = await confirm(
          context,
          title: 'Discard changes?',
          message: "This record hasn't been saved.",
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
            key: const Key('svc-close'),
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(editing ? 'Edit service' : 'Service & expenses'),
          actions: [
            TextButton(
              key: const Key('svc-save-top'),
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
                    title: 'What was it?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final k in serviceKinds)
                              chip(
                                'kind-${k.name}',
                                k.name,
                                !_custom && _kind == k.name,
                                () => setState(() {
                                  _kind = k.name;
                                  _custom = false;
                                  _dirty = true;
                                }),
                                icon: kindIcon(k.name),
                              ),
                            chip(
                              'kind-other',
                              'Other…',
                              _custom,
                              () => setState(() {
                                _custom = true;
                                _dirty = true;
                              }),
                              icon: Icons.edit_rounded,
                            ),
                          ],
                        ),
                        if (_custom)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextField(
                              key: const Key('svc-custom'),
                              controller: _customName,
                              autofocus: widget.edit == null,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() => _dirty = true),
                              style: TextStyle(fontSize: 16, color: tk.text),
                              decoration: InputDecoration(
                                hintText: 'e.g. Spark plugs',
                                filled: true,
                                fillColor: tk.surface2,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        if (kindMissing)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Pick what it was',
                              key: const Key('kind-error'),
                              style: TextStyle(fontSize: 13, color: tk.bad, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldRow(
                          label: 'Date',
                          child: DateField(
                            fieldKey: 'svc-date',
                            label: fmtDate(_date),
                            onTap: () async {
                              final d = await pickDate(context, _date, max: s.now());
                              if (d != null && mounted) {
                                setState(() {
                                  _date = d;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                        ),
                        FieldRow(
                          label: 'Odometer',
                          hint: latest == null ? 'Optional' : 'Optional · last ${f.dist(latest)}',
                          child: NumField(
                            key: const Key('svc-odo'),
                            semanticLabel: 'Odometer',
                            value: _odo,
                            decimals: 1,
                            suffix: u.distance.short,
                            onChanged: (v) => setState(() {
                              _odo = v;
                              _dirty = true;
                            }),
                          ),
                        ),
                        FieldRow(
                          label: 'Cost',
                          child: NumField(
                            key: const Key('svc-cost'),
                            semanticLabel: 'Cost',
                            value: _cost,
                            decimals: 2,
                            max: 999999,
                            prefix: r'$',
                            fixedDecimals: true,
                            onChanged: (v) => setState(() {
                              _cost = v;
                              _dirty = true;
                            }),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const Key('svc-note'),
                          controller: _note,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _dirty = true,
                          style: TextStyle(fontSize: 16, color: tk.text),
                          decoration: InputDecoration(
                            hintText: 'Note (shop, parts …)',
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
                  BigButton(
                    key: const Key('svc-save'),
                    label: 'Save',
                    icon: Icons.check_rounded,
                    color: tk.service,
                    onPressed: _save,
                  ),
                  if (editing) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      key: const Key('svc-delete'),
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline_rounded, color: tk.bad),
                      label: Text(
                        'Delete',
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
