import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// 차 이름 묻기 (새 차·이름 바꾸기).
Future<String?> askVehicleName(BuildContext context, {String initial = '', required String title}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('vehicle-name'),
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. 2021 Ford F-150'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(key: const Key('name-cancel'), onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          key: const Key('name-ok'),
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  ).whenComplete(() => Future.delayed(const Duration(milliseconds: 400), c.dispose));
}

Future<void> addVehicleFlow(BuildContext context) async {
  final name = await askVehicleName(context, title: 'Add vehicle');
  if (name == null || !context.mounted) return;
  final v = AppStore.i.addVehicle(name);
  showResult(context, FormResult('Added ${v.name}'));
}

/// 위 제목의 차 이름을 누르면 뜨는 고르기.
Future<void> showVehiclePicker(BuildContext context) {
  final tk = Tk.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tk.surface,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
        child: ListenableBuilder(
          listenable: AppStore.i,
          builder: (c, _) {
            final s = AppStore.i;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vehicles',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tk.text),
                        ),
                      ),
                      TextButton(
                        key: const Key('picker-done'),
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Done', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final v in s.vehicles)
                        ListTile(
                          key: Key('pick-${v.id}'),
                          leading: Icon(Icons.directions_car_rounded, color: tk.accent),
                          title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: v.id == s.vehicle?.id ? Icon(Icons.check_rounded, color: tk.accent) : null,
                          onTap: () {
                            s.selectVehicle(v.id);
                            Navigator.pop(c);
                          },
                        ),
                      ListTile(
                        key: const Key('picker-add'),
                        leading: Icon(Icons.add_rounded, color: tk.accent),
                        title: Text(
                          'Add vehicle',
                          style: TextStyle(color: tk.accent, fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          Navigator.pop(c);
                          await addVehicleFlow(context);
                        },
                      ),
                      ListTile(
                        key: const Key('picker-manage'),
                        leading: Icon(Icons.edit_rounded, color: tk.text2),
                        title: const Text('Rename or delete'),
                        onTap: () {
                          Navigator.pop(c);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehiclesScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// 차 목록: 이름 바꾸기·지우기·추가.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  Future<void> _delete(BuildContext context, Vehicle v) async {
    final s = AppStore.i;
    final fills = s.data.fills.where((f) => f.vehicleId == v.id).length;
    final svcs = s.data.services.where((e) => e.vehicleId == v.id).length;
    final ok = await confirm(
      context,
      title: 'Delete ${v.name}?',
      message:
          'This removes $fills fill-up${fills == 1 ? '' : 's'} and $svcs service record${svcs == 1 ? '' : 's'}. '
          'Export a CSV first if you might want them later.',
      action: 'Delete',
    );
    if (!ok || !context.mounted) return;
    final gone = s.deleteVehicle(v.id);
    final last = !s.hasVehicle;
    showResult(context, FormResult('Deleted ${v.name}', undo: () => s.restoreVehicle(gone)));
    // 마지막 차를 지우면 첫 화면으로
    if (last) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final tk = Tk.of(context);
    return Scaffold(
      backgroundColor: tk.bg,
      appBar: AppBar(title: const Text('Vehicles')),
      body: ListenableBuilder(
        listenable: AppStore.i,
        builder: (context, _) {
          final s = AppStore.i;
          return ListView(
            key: const Key('vehicles-list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              for (final v in s.vehicles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: Key('veh-${v.id}'),
                      leading: Icon(Icons.directions_car_rounded, color: tk.accent),
                      title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${s.data.fills.where((f) => f.vehicleId == v.id).length} fill-ups'
                        '${v.id == s.vehicle?.id ? ' · selected' : ''}',
                      ),
                      onTap: () async {
                        final n = await askVehicleName(context, initial: v.name, title: 'Rename');
                        if (n != null && n.trim().isNotEmpty) s.renameVehicle(v.id, n);
                      },
                      trailing: IconButton(
                        key: Key('veh-del-${v.id}'),
                        tooltip: 'Delete ${v.name}',
                        icon: Icon(Icons.delete_outline_rounded, color: tk.bad),
                        onPressed: () => _delete(context, v),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              BigButton(
                key: const Key('veh-add'),
                label: 'Add vehicle',
                icon: Icons.add_rounded,
                filled: false,
                onPressed: () => addVehicleFlow(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
