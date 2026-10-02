// Test helpers: serve real NOAA responses captured by the `Fetch NOAA tides data`
// workflow (test/fixtures, 2026-10-01 … 2026-10-11 UTC) instead of the network.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

/// Pinned "now": Fri Oct 2 2026, 12:00 PM PDT.
final testNow = DateTime.utc(2026, 10, 2, 19);

/// Mock NOAA. Stations with captured data answer with it; any other reference
/// station gets San Francisco's series and any subordinate station San Nicolas
/// Island's highs/lows (layout tests only — the app itself never invents data).
class FakeNoaa {
  final Set<String> subordinate = {'9410068'};
  bool offline = false;
  int calls = 0;
  final List<Uri> requests = [];

  static const captured = {
    '9414290',
    '1612340',
    '8518750',
    '9410068',
    '9455920',
    '8723214',
  };

  late final http.Client client = MockClient((req) async {
    calls++;
    requests.add(req.url);
    if (offline) throw const SocketException('offline');
    final q = req.url.queryParameters;
    final id = q['station']!;
    final six = q['interval'] == '6';
    final isSub = subordinate.contains(id) || id.startsWith('S');
    if (six && isSub) {
      return http.Response(
        '{"error": {"message":"No Predictions data was found. Please make sure the Datum input is valid."}}',
        200,
      );
    }
    // Captured stations answer with their own data; others get one consistent stand-in pair.
    final src = captured.contains(id) ? id : (isSub ? '9410068' : '9414290');
    // The 30-day table asks for ~32 days of highs/lows.
    final days = DateTime.parse(q['end_date']!).difference(DateTime.parse(q['begin_date']!)).inDays;
    if (!six && days > 15 && File('test/fixtures/${src}_hilo30.json').existsSync()) {
      return http.Response(fixture('${src}_hilo30'), 200, headers: {'content-type': 'application/json;charset=UTF-8'});
    }
    return http.Response(
      fixture('${src}_${six ? '6min' : 'hilo'}'),
      200,
      headers: {'content-type': 'application/json;charset=UTF-8'},
    );
  });
}
