import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/location_repository.dart';

/// The phone's location through geolocator: one reading at a time, only
/// while the app is open.
class GeolocatorLocationRepository implements LocationRepository {
  const GeolocatorLocationRepository();

  /// Long enough for a first fix outdoors; past it, the last known position
  /// will do for finding lunch.
  static const Duration _wait = Duration(seconds: 10);

  @override
  Future<LocationState> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationOff();
    }
    return _from(await Geolocator.checkPermission());
  }

  @override
  Future<LocationState> ask() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationOff();
    }
    return _from(await Geolocator.requestPermission());
  }

  Future<LocationState> _from(LocationPermission p) async {
    switch (p) {
      case LocationPermission.deniedForever:
        return const RefusedForGood();
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return const CanAsk();
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return _position();
    }
  }

  Future<LocationState> _position() async {
    try {
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _wait,
        ),
      );
      return Located(p.latitude, p.longitude);
    } on TimeoutException {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) return Located(last.latitude, last.longitude);
      return const PositionUnavailable();
    } on LocationServiceDisabledException {
      return const LocationOff();
    } on PermissionDeniedException {
      return const CanAsk();
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
