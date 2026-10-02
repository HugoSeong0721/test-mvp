import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/places.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/zone.dart';
import 'widgets.dart';

/// Pick a place: my location, a saved spot, or any US/Canadian town (offline search).
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final _query = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _error = null);
    final r = await AppStore.i.useMyLocation();
    if (!mounted) return;
    if (r.ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = r.message);
    }
  }

  Future<void> _choose(Place p) async {
    await AppStore.i.selectPlace(p);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: AppStore.i, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final store = AppStore.i;
    final q = _query.text.trim();
    final results = q.isEmpty ? const <Town>[] : store.db.search(q);
    final here = store.place;
    return Scaffold(
      appBar: AppBar(title: const Text('Places')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const Key('place-search'),
                controller: _query,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Search a town, e.g. Austin, TX',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('search-clear'),
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_query.clear),
                        ),
                  filled: true,
                  fillColor: Palette.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Palette.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Palette.line),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('places-list'),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  if (q.isEmpty) ...[
                    if (_error != null) ...[
                      Notice(key: const Key('places-error'), text: _error!, icon: Icons.location_off_outlined),
                      const SizedBox(height: 8),
                    ],
                    Material(
                      color: Palette.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Palette.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: const Key('places-gps'),
                        leading: store.locating
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Icon(Icons.my_location, color: Palette.pine),
                        title: Text(
                          store.locating ? 'Finding your location…' : 'Use My Location',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('Times for exactly where you are'),
                        trailing: here?.isGps == true ? const Icon(Icons.check, color: Palette.pine) : null,
                        onTap: store.locating ? null : _useLocation,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle('Saved places'),
                    if (store.favorites.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Tap ☆ on the main screen to save a spot — your lake, lease or deer stand.',
                          key: Key('no-favorites'),
                          style: TextStyle(color: Palette.sub, height: 1.35),
                        ),
                      ),
                    for (final (i, f) in store.favorites.indexed)
                      _PlaceRow(
                        key: Key('fav-$i'),
                        icon: Icons.star,
                        iconColor: Palette.major,
                        title: f.name,
                        subtitle: [?f.detail, PlaceZone(f.tz).abbreviation(store.clock())].join(' · '),
                        selected: here != null && !here.isGps && here.sameSpot(f),
                        onTap: () => _choose(f),
                        trailing: IconButton(
                          key: Key('fav-del-$i'),
                          tooltip: 'Remove ${f.name}',
                          icon: const Icon(Icons.delete_outline, color: Palette.sub),
                          onPressed: () => store.removeFavorite(f),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'Search ${thousands(store.db.towns.length)} US and Canadian towns — works offline.',
                      style: const TextStyle(fontSize: 12.5, color: Palette.faint),
                    ),
                  ] else ...[
                    if (results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          'No town named “$q”. Try the nearest bigger town, or use your location.',
                          key: const Key('no-results'),
                          style: const TextStyle(color: Palette.sub),
                        ),
                      ),
                    for (final (i, t) in results.indexed)
                      _PlaceRow(
                        key: Key('town-$i'),
                        icon: Icons.place_outlined,
                        iconColor: Palette.pine,
                        title: t.label,
                        subtitle: here == null ? null : '${miles(milesBetween(here.lat, here.lng, t.lat, t.lng))} away',
                        onTap: () => _choose(t.toPlace()),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.selected = false,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? Palette.pine : Palette.line),
        ),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? (selected ? const Icon(Icons.check, color: Palette.pine) : null),
        onTap: onTap,
      ),
    ),
  );
}
