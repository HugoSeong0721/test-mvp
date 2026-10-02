import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult.found(this.lat, this.lng) : problem = null;
  const LocationResult.failed(this.problem)
      : lat = null,
        lng = null;

  final double? lat;
  final double? lng;
  final LocationProblem? problem;

  bool get ok => problem == null;

  String get message => switch (problem) {
        LocationProblem.serviceOff => 'Location Services are off. Turn them on in Settings, or search for a station.',
        LocationProblem.denied => 'Location permission was not given. You can search for a station instead.',
        LocationProblem.deniedForever =>
          'Location is turned off for this app. Allow it in Settings, or search for a station.',
        LocationProblem.unavailable => "Couldn't get your location. Try again or search for a station.",
        null => '',
      };
}

/// Where the device is. Used once to pick the nearest station; the location
/// never leaves the device.
abstract class LocationService {
  static LocationService i = DeviceLocation();

  /// True if we may read the location without showing a permission prompt.
  Future<bool> hasPermission();

  Future<LocationResult> current();
}

class DeviceLocation extends LocationService {
  @override
  Future<bool> hasPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationProblem.serviceOff);
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        // iOS keeps its own prompt up until answered. A browser prompt can be left
        // unanswered forever, so the web preview gives up after a while.
        final ask = Geolocator.requestPermission();
        p = kIsWeb ? await ask.timeout(const Duration(seconds: 15), onTimeout: () => LocationPermission.denied) : await ask;
      }
      if (p == LocationPermission.denied) {
        return const LocationResult.failed(LocationProblem.denied);
      }
      if (p == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationProblem.deniedForever);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult.found(pos.latitude, pos.longitude);
    } on TimeoutException {
      return const LocationResult.failed(LocationProblem.unavailable);
    } catch (_) {
      return const LocationResult.failed(LocationProblem.unavailable);
    }
  }
}

/// Tests and the web preview's `?loc=` switch.
class FakeLocation extends LocationService {
  FakeLocation(this.result, {this.granted = true, this.delay = Duration.zero});

  LocationResult result;
  bool granted;
  Duration delay;
  int asked = 0;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<LocationResult> current() async {
    asked++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }
}
