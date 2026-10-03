import 'package:flutter_timezone/flutter_timezone.dart';

import 'zone.dart';

/// The phone's own time zone name ("America/Chicago"). Used for spots picked by
/// GPS: the phone sets its zone from where it is, so times match its clock.
abstract class DeviceZone {
  static DeviceZone i = PlatformDeviceZone();

  Future<String> name();
}

class PlatformDeviceZone extends DeviceZone {
  @override
  Future<String> name() async {
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (PlaceZone.isKnown(id)) return id;
    } catch (_) {}
    return 'UTC';
  }
}

class FakeDeviceZone extends DeviceZone {
  FakeDeviceZone(this.zone);
  String zone;

  @override
  Future<String> name() async => zone;
}
