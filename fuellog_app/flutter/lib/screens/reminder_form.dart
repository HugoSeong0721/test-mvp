import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/format.dart';
import '../core/model.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';
import '../widgets/num_field.dart';

Future<void> openReminderForm(BuildContext context, {Reminder? edit, String? kind}) async {
  final r = await Navigator.of(context).push<FormResult>(
    MaterialPageRoute(
      builder: (_) => ReminderForm(edit: edit, kind: kind),
      fullscreenDialog: edit == null,
    ),
  );
  if (r != null && context.mounted) showResult(context, r);
}

/// 정비 알림 만들기/고치기: 무엇을, 몇 마일·몇 달마다, 마지막으로 한 때.
class ReminderForm extends StatefulWidget {
  const ReminderForm({super.key, this.edit, this.kind, this.vehicleId});
  final Reminder? edit;
  final String? kind;
  final String? vehicleId;

  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final s = AppStore.i;
  late final Units u = s.units;
  late final String vehicleId = widget.edit?.vehicleId ?? widget.vehicleId ?? s.vehicle!.id;
  String? _kind;
  bool _custom = false;
  final _customName = TextEditingController();
  double? _every, _months, _lastOdo;
  late DateTime _lastDate = s.now();
  bool _notify = true;
  bool _tried = false;

  bool get editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    final k = e?.kind ?? widget.kind;
    if (k != null) _pickKind(k, defaults: e == null);
    if (e != null) {
      _every = e.everyMiles == null ? null : u.distance.fromMiles(e.everyMiles!).roundToDouble();
      _months = e.everyMonths?.toDouble();
      _notify = e.notify;
      if (e.lastOdometer != null) _lastOdo = u.distance.fromMiles(e.lastOdometer!).roundToDouble();
      if (e.lastDate != null) _lastDate = e.lastDate!;
    }
    if (_lastOdo == null) {
      final l = s.logFor(vehicleId).latestOdometer;
      if (l != null) _lastOdo = u.distance.fromMiles(l).roundToDouble();
    }
  }

  void _pickKind(String k, {required bool defaults}) {
    final p = presetKind(k);
    if (p == null) {
      _custom = true;
      _customName.text = k;
      return;
    }
    _custom = false;
    _kind = p.name;
    if (defaults) {
      final d = u.distance == DistanceUnit.mi ? p.miles : p.km;
      _every = d;
      _months = p.months?.toDouble();
    }
  }

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  String get _kindName => _custom ? _customName.text.trim() : (_kind ?? '');

  /// 이 종류로 이미 적은 정비 (있으면 '마지막으로 한 때' 를 거기서 가져온다)
  Service? get _logged {
    final k = _kindName;
    if (k.isEmpty) return null;
    Service? last;
    for (final e in s.logFor(vehicleId).services) {
      if (sameKind(e.kind, k) && (last == null || !e.date.isBefore(last.date))) last = e;
    }
    return last;
  }

  String? get _error {
    if (!_tried) return null;
    if (_kindName.isEmpty) return 'Pick what to remind you about';
    if ((_every ?? 0) <= 0 && (_months ?? 0) <= 0) return 'Set a distance, a number of months, or both';
    if (_kindName.isNotEmpty && !editing && s.remindersOf(vehicleId).any((r) => sameKind(r.kind, _kindName))) {
      return 'You already have a $_kindName reminder for this vehicle';
    }
    if ((_every ?? 0) > 0 && _logged == null && (_lastOdo ?? 0) <= 0) {
      return 'Enter the odometer when it was last done';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_error != null) return;
    final logged = _logged;
    final r = Reminder(
      id: widget.edit?.id ?? newId(),
      vehicleId: vehicleId,
      kind: _kindName,
      everyMiles: (_every ?? 0) > 0 ? u.distance.toMiles(_every!) : null,
      everyMonths: (_months ?? 0) > 0 ? _months!.round() : null,
      // 기록에 있으면 그걸 쓰고, 없을 때만 직접 적은 값
      lastOdometer: logged == null && (_lastOdo ?? 0) > 0 ? u.distance.toMiles(_lastOdo!) : null,
      lastDate: logged == null ? _lastDate : null,
      notify: _notify,
    );
    final nav = Navigator.of(context);
    var msg = editing ? 'Reminder updated' : 'Reminder added';
    if (_notify && Notifier.i.supported) {
      final ok = await Notifier.i.requestPermission();
      if (!ok) msg = '$msg. Notifications are off — turn them on in iPhone Settings.';
    }
    s.saveReminder(r);
    final st = ReminderState.of(r, s.logFor(vehicleId), s.now());
    if (st.level == ReminderLevel.overdue) msg = '$msg · already due';
    nav.pop(FormResult(msg));
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete reminder?',
      message: 'Your ${widget.edit!.kind} records stay in the log.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final gone = s.deleteReminder(widget.edit!.id);
    Navigator.pop(context, FormResult('Reminder deleted', undo: gone == null ? null : () => s.saveReminder(gone)));
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final f = s.fmt;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final logged = _logged;
    final err = _error;

    Widget chip(String key, String label, bool on, VoidCallback tap) => Semantics(
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
          decoration: BoxDecoration(color: on ? tk.accent : tk.surface2, borderRadius: BorderRadius.circular(18)),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? tk.onAccent : tk.text2),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('rem-close'),
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(editing ? 'Edit reminder' : 'New reminder'),
        actions: [
          TextButton(
            key: const Key('rem-save-top'),
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
                  title: 'Remind me about',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final k in serviceKinds.where((k) => k.remindable))
                            chip('rk-${k.name}', k.name, !_custom && _kind == k.name, () {
                              setState(() => _pickKind(k.name, defaults: !editing));
                            }),
                          chip('rk-other', 'Other…', _custom, () => setState(() => _custom = true)),
                        ],
                      ),
                      if (_custom)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextField(
                            key: const Key('rem-custom'),
                            controller: _customName,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
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
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Every',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FieldRow(
                        label: 'Distance',
                        hint: 'Leave empty for time only',
                        child: NumField(
                          key: const Key('rem-every'),
                          semanticLabel: 'Every distance',
                          value: _every,
                          max: 999999,
                          suffix: u.distance.short,
                          onChanged: (v) => setState(() => _every = v),
                        ),
                      ),
                      FieldRow(
                        label: 'Time',
                        hint: 'Leave empty for distance only',
                        child: NumField(
                          key: const Key('rem-months'),
                          semanticLabel: 'Every months',
                          value: _months,
                          max: 120,
                          suffix: 'months',
                          onChanged: (v) => setState(() => _months = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Whichever comes first. Suggested values are common intervals — check your owner's manual.",
                          style: TextStyle(fontSize: 12, color: tk.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Last done',
                  child: logged != null
                      ? Text(
                          'From your log: ${fmtDate(logged.date)}'
                          '${logged.odometer != null ? ' at ${f.dist(logged.odometer!)}' : ''}. '
                          'Logging a new ${logged.kind} resets this reminder.',
                          key: const Key('rem-from-log'),
                          style: TextStyle(fontSize: 14, height: 1.35, color: tk.text2),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FieldRow(
                              label: 'Date',
                              child: DateField(
                                fieldKey: 'rem-date',
                                label: fmtDate(_lastDate),
                                onTap: () async {
                                  final d = await pickDate(context, _lastDate, max: s.now());
                                  if (d != null && mounted) setState(() => _lastDate = d);
                                },
                              ),
                            ),
                            FieldRow(
                              label: 'Odometer',
                              child: NumField(
                                key: const Key('rem-last-odo'),
                                semanticLabel: 'Odometer when last done',
                                value: _lastOdo,
                                suffix: u.distance.short,
                                onChanged: (v) => setState(() => _lastOdo = v),
                              ),
                            ),
                          ],
                        ),
                ),
                SectionCard(
                  child: SwitchRow(
                    switchKey: 'rem-notify',
                    label: 'Notify me',
                    hint: Notifier.i.supported
                        ? 'On the due date, or when your driving says the distance is reached'
                        : 'Notifications work in the iPhone app',
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v),
                  ),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      err,
                      key: const Key('rem-error'),
                      style: TextStyle(fontSize: 14, color: tk.bad, fontWeight: FontWeight.w600),
                    ),
                  ),
                BigButton(
                  key: const Key('rem-save'),
                  label: 'Save reminder',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
                if (editing) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    key: const Key('rem-delete'),
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, color: tk.bad),
                    label: Text(
                      'Delete reminder',
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
    );
  }
}
