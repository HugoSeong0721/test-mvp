import 'package:flutter/material.dart';

import '../core/csv.dart';
import '../core/files.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';

/// 파일을 고르고 → 무엇이 들어올지 먼저 보여 준 뒤 → 사용자가 누르면 더한다. 지금 기록은 지우지 않는다.
Future<void> startImport(BuildContext context) async {
  String? text;
  try {
    text = await Files.i.pickCsv();
  } catch (e) {
    if (context.mounted) showResult(context, const FormResult("Couldn't open that file."));
    return;
  }
  if (text == null || !context.mounted) return;
  final r = await Navigator.of(context).push<FormResult>(MaterialPageRoute(builder: (_) => ImportScreen(text: text!)));
  if (r != null && context.mounted) showResult(context, r);
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.text});
  final String text;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final s = AppStore.i;
  DistanceUnit? _dist;
  VolumeUnit? _vol;
  late ImportPlan _plan = _make();

  ImportPlan _make() =>
      planImport(widget.text, s.data, defaultVehicleId: s.vehicle?.id, distanceUnit: _dist, volumeUnit: _vol);

  void _apply() {
    final p = _plan;
    s.applyImport(p);
    Navigator.pop(
      context,
      FormResult(
        'Imported ${p.total} record${p.total == 1 ? '' : 's'}${p.duplicates > 0 ? ' · ${p.duplicates} already in your log' : ''}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    final p = _plan;
    Widget row(String k, String label, int n) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, color: tk.text)),
          ),
          Text(
            '$n',
            key: Key(k),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tk.text),
          ),
        ],
      ),
    );
    final names = p.newVehicles.map((v) => v.name).join(', ');
    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(title: const Text('Import CSV')),
      body: ListView(
        key: const Key('import-list'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SectionCard(
            title: p.isEmpty ? 'Nothing to import' : 'Ready to add',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row('imp-fills', 'Fill-ups', p.fills.length),
                row('imp-services', 'Service records', p.services.length),
                row('imp-reminders', 'Reminders', p.reminders.length),
                if (p.newVehicles.isNotEmpty) row('imp-vehicles', 'New vehicles', p.newVehicles.length),
                if (names.isNotEmpty) Text(names, style: TextStyle(fontSize: 13, color: tk.muted)),
                if (p.duplicates > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${p.duplicates} already in your log — skipped.',
                      key: const Key('imp-dups'),
                      style: TextStyle(fontSize: 13, color: tk.text2),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Nothing in your current log is changed or removed.',
                    style: TextStyle(fontSize: 13, color: tk.text2),
                  ),
                ),
              ],
            ),
          ),
          if (p.unitsGuessed)
            SectionCard(
              key: const Key('imp-units'),
              title: 'Units in this file',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "The file doesn't say which units it uses. Check these:",
                    style: TextStyle(fontSize: 13, color: tk.text2),
                  ),
                  const SizedBox(height: 10),
                  Segmented<DistanceUnit>(
                    keyPrefix: 'imp-dist',
                    items: const [(DistanceUnit.mi, 'Miles'), (DistanceUnit.km, 'Kilometers')],
                    value: p.distanceUnit,
                    onChanged: (v) => setState(() {
                      _dist = v;
                      _plan = _make();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Segmented<VolumeUnit>(
                    keyPrefix: 'imp-vol',
                    items: const [(VolumeUnit.gal, 'Gallons'), (VolumeUnit.l, 'Liters')],
                    value: p.volumeUnit,
                    onChanged: (v) => setState(() {
                      _vol = v;
                      _plan = _make();
                    }),
                  ),
                ],
              ),
            ),
          if (p.problems.isNotEmpty)
            SectionCard(
              key: const Key('imp-problems'),
              title: "Rows we couldn't read (${p.problems.length})",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in p.problems.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        e.line <= 1 ? e.reason : 'Line ${e.line}: ${e.reason}',
                        style: TextStyle(fontSize: 13, color: tk.text2),
                      ),
                    ),
                  if (p.problems.length > 8)
                    Text('…and ${p.problems.length - 8} more', style: TextStyle(fontSize: 13, color: tk.muted)),
                ],
              ),
            ),
          BigButton(
            key: const Key('imp-go'),
            label: p.isEmpty ? 'Nothing to import' : 'Import ${p.total} record${p.total == 1 ? '' : 's'}',
            icon: Icons.download_done_rounded,
            onPressed: p.isEmpty ? null : _apply,
          ),
          const SizedBox(height: 10),
          Text(
            'Works with files exported from this app, and from most other fuel log apps whose CSV has columns like '
            'Date, Odometer, Gallons and Price.',
            style: TextStyle(fontSize: 12, height: 1.35, color: tk.muted),
          ),
        ],
      ),
    );
  }
}
