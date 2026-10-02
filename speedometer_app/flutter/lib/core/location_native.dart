import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'engine.dart';
import 'location.dart';
import 'units.dart';

LocationSource createPlatformSource() => NativeLocationSource();

/// 아이폰·안드로이드 GPS (geolocator). 화면이 켜져 있을 때만 받는다 — 백그라운드 위치는 쓰지 않는다.
class NativeLocationSource extends LocationSource {
  @override
  Future<Access> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) return Access.servicesOff;
    return _map(await Geolocator.checkPermission(), asked: false);
  }

  @override
  Future<Access> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) return Access.servicesOff;
    return _map(await Geolocator.requestPermission(), asked: true);
  }

  static Access _map(LocationPermission p, {required bool asked}) =>
      switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse => Access.granted,
        LocationPermission.deniedForever => Access.blocked,
        // iOS 는 "아직 안 물어봄"도 denied 로 준다
        LocationPermission.denied => asked ? Access.denied : Access.unknown,
        LocationPermission.unableToDetermine => Access.unknown,
      };

  @override
  Future<bool> preciseOff() async {
    try {
      return await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<Fix> watch(Mode mode) {
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: switch (mode) {
          Mode.car => ActivityType.automotiveNavigation,
          Mode.boat => ActivityType.otherNavigation,
          Mode.bike || Mode.run => ActivityType.fitness,
        },
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
        showBackgroundLocationIndicator: false,
      ),
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      ),
      _ => const LocationSettings(accuracy: LocationAccuracy.best),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => Fix(
        lat: p.latitude,
        lon: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        speedAccuracy: p.speedAccuracy,
        time: p.timestamp,
      ),
    );
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
