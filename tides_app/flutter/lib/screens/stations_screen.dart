import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/station.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// Pick a station: near me, favorites, search (name, city, state or ID), popular.
class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key, this.closable = true});

  /// False on first launch (nothing to go back to).
  final bool closable;

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final store = AppStore.i;
  final _q = TextEditingController();
  bool _locating = false;
  String? _locError;

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
    _q.addListener(_changed);
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    _q.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(Station s) async {
    FocusScope.of(context).unfocus();
    final nav = Navigator.of(context);
    store.selectStation(s);
    if (widget.closable && nav.canPop()) nav.pop();
  }

  Future<void> _nearMe() async {
    if (_locating) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _locating = true;
      _locError = null;
    });
    final nav = Navigator.of(context);
    final r = await store.useMyLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locError = r.ok ? null : r.message;
    });
    if (r.ok && widget.closable && nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    final here = store.here;
    final results = q.isEmpty
        ? const <Station>[]
        : store.db.search(q, lat: here?.$1, lng: here?.$2);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.closable,
        title: const Text(
          'Choose a station',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const Key('search-field'),
              controller: _q,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search beach, city, state or station ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('clear-search'),
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: _q.clear,
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('station-list'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: q.isEmpty ? _home(here) : _results(q, results, here),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _home((double, double)? here) {
    final favs = store.favoriteStations;
    final popular = [
      for (final id in popularStationIds)
        if (store.db.byId(id) != null) store.db.byId(id)!,
    ];
    return [
      ListTile(
        key: const Key('near-me'),
        leading: _locating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const Icon(Icons.my_location, color: Palette.sea),
        title: const Text(
          'Nearest station to me',
          style: TextStyle(fontWeight: FontWeight.w600, color: Palette.sea),
        ),
        subtitle: _locError == null
            ? const Text('Uses your location once, on this device')
            : Text(
                _locError!,
                key: const Key('location-error'),
                style: const TextStyle(color: Palette.warn),
              ),
        onTap: _nearMe,
      ),
      if (favs.isNotEmpty) ...[
        const _Section('Favorites'),
        for (final s in favs) _tile(s, here, 'fav'),
      ],
      if (here != null) ...[
        const _Section('Nearby'),
        for (final (s, _) in store.db.nearest(here.$1, here.$2, count: 8))
          _tile(s, here, 'near'),
      ],
      const _Section('Popular'),
      for (final s in popular) _tile(s, here, 'pop'),
    ];
  }

  List<Widget> _results(
    String q,
    List<Station> results,
    (double, double)? here,
  ) {
    if (results.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No NOAA stations match “$q”.\nTry a nearby town, bay, or the state name.',
            key: const Key('no-results'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.sub),
          ),
        ),
      ];
    }
    return [
      _Section('${results.length == 60 ? '60+' : results.length} stations'),
      for (final s in results) _tile(s, here, 'res'),
    ];
  }

  /// [section] keeps keys unique: a station can be a favorite, nearby and popular at once.
  Widget _tile(Station s, (double, double)? here, String section) {
    final fav = store.isFavorite(s);
    final current = store.station == s;
    final parts = [
      if (s.state.isNotEmpty) s.state,
      'NOAA ${s.id}',
      if (here != null) miles(milesBetween(here.$1, here.$2, s.lat, s.lng)),
    ];
    return ListTile(
      key: Key('station-$section-${s.id}'),
      title: Text(
        s.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(parts.join(' · ')),
      leading: Icon(
        current ? Icons.place : Icons.place_outlined,
        color: current ? Palette.sea : Palette.faint,
      ),
      trailing: IconButton(
        key: Key('fav-$section-${s.id}'),
        tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
        icon: Icon(
          fav ? Icons.star_rounded : Icons.star_outline_rounded,
          color: fav ? const Color(0xFFF2A900) : Palette.faint,
        ),
        onPressed: () => store.toggleFavorite(s),
      ),
      onTap: () => _pick(s),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
        color: Palette.sub,
      ),
    ),
  );
}
