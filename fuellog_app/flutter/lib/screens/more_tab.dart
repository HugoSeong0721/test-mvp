import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/brand.dart';
import '../core/csv.dart';
import '../core/files.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../widgets/common.dart';
import 'import_screen.dart';
import 'trip_screen.dart';
import 'vehicles_screen.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Future<void> _export(BuildContext context) async {
    final s = AppStore.i;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final n = s.data.fills.length + s.data.services.length;
    try {
      final ok = await Files.i.shareCsv(exportFileName(s.now()), exportCsv(s.data), origin);
      if (ok && context.mounted) showResult(context, FormResult('Exported $n record${n == 1 ? '' : 's'}'));
    } catch (e) {
      if (context.mounted) showResult(context, const FormResult("Couldn't export. Please try again."));
    }
  }

  @override
  // 저장소가 바뀔 때마다 다시 그린다 (const 로 만든 탭은 부모가 다시 그려져도 안 그려진다)
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final tk = Tk.of(context);
    final s = AppStore.i;
    final u = s.units;

    Widget tile(String key, IconData icon, String title, VoidCallback onTap, {String? sub, Color? color}) => ListTile(
      key: Key(key),
      leading: Icon(icon, color: color ?? tk.accent),
      title: Text(title, style: TextStyle(fontSize: 16, color: tk.text)),
      subtitle: sub == null ? null : Text(sub, style: TextStyle(fontSize: 13, color: tk.muted)),
      trailing: Icon(Icons.chevron_right_rounded, color: tk.muted),
      onTap: onTap,
    );

    Widget group(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: tk.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );

    Widget label(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Text(
        t,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tk.muted),
      ),
    );

    return ListView(
      key: const Key('more-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        group([
          tile(
            'more-vehicles',
            Icons.directions_car_rounded,
            'Vehicles',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehiclesScreen())),
            sub: '${s.vehicles.length} · add, rename or delete',
          ),
          tile(
            'more-trip',
            Icons.groups_rounded,
            'Trip cost split',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TripScreen())),
            sub: 'Road trip gas money per person',
          ),
        ]),
        label('UNITS'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Segmented<DistanceUnit>(
                keyPrefix: 'u-dist',
                items: const [(DistanceUnit.mi, 'Miles'), (DistanceUnit.km, 'Kilometers')],
                value: u.distance,
                onChanged: (d) => s.setUnits(u.copyWith(distance: d, economy: EconomyUnit.natural(d, u.volume))),
              ),
              const SizedBox(height: 8),
              Segmented<VolumeUnit>(
                keyPrefix: 'u-vol',
                items: const [(VolumeUnit.gal, 'Gallons'), (VolumeUnit.l, 'Liters')],
                value: u.volume,
                onChanged: (v) => s.setUnits(u.copyWith(volume: v, economy: EconomyUnit.natural(u.distance, v))),
              ),
              const SizedBox(height: 8),
              Segmented<EconomyUnit>(
                keyPrefix: 'u-econ',
                items: [for (final e in EconomyUnit.values) (e, e.short)],
                value: u.economy,
                onChanged: (e) => s.setUnits(u.copyWith(economy: e)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Changing units only changes how numbers are shown — your log stays exact.',
                  style: TextStyle(fontSize: 12, color: tk.muted),
                ),
              ),
            ],
          ),
        ),
        label('YOUR DATA'),
        group([
          Builder(
            builder: (c) => tile(
              'more-export',
              Icons.ios_share_rounded,
              'Export CSV',
              () => _export(c),
              sub: 'All vehicles, fill-ups, service and reminders',
            ),
          ),
          tile(
            'more-import',
            Icons.file_open_rounded,
            'Import CSV',
            () => startImport(context),
            sub: 'From a backup or another app',
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
          child: Text(
            'No account, no cloud. Your log is saved only on $deviceWord'
            '${deviceWord == 'this iPhone' ? ' (and in your iPhone backup)' : ''}. '
            'Before switching phones, export a CSV and import it on the new one.',
            key: const Key('data-note'),
            style: TextStyle(fontSize: 12, height: 1.4, color: tk.muted),
          ),
        ),
        label('ABOUT'),
        group([
          tile(
            'more-privacy',
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => launchUrl(Uri.parse(privacyUrl), mode: LaunchMode.externalApplication),
            color: tk.text2,
          ),
          ListTile(
            key: const Key('more-version'),
            leading: Icon(Icons.info_outline_rounded, color: tk.text2),
            title: Text('$appName $appVersion', style: TextStyle(fontSize: 16, color: tk.text)),
            subtitle: Text('Free. No account. Made by Soulfulfill.', style: TextStyle(fontSize: 13, color: tk.muted)),
          ),
        ]),
      ],
    );
  }
}
