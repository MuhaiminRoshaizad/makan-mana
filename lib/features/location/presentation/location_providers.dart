import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geolocator_location_repository.dart';
import '../domain/location_repository.dart';

final Provider<LocationRepository> locationRepositoryProvider =
    Provider<LocationRepository>(
      (Ref ref) => const GeolocatorLocationRepository(),
    );

/// Where the phone is. Reading it never shows a prompt; only [ask] does,
/// when the person taps to share their location (docs/decisions.md 003).
final AsyncNotifierProvider<LocationNotifier, LocationState> locationProvider =
    AsyncNotifierProvider<LocationNotifier, LocationState>(
      LocationNotifier.new,
      retry: (_, _) => null,
    );

class LocationNotifier extends AsyncNotifier<LocationState> {
  LocationRepository get _repo => ref.read(locationRepositoryProvider);

  @override
  Future<LocationState> build() => _repo.current();

  /// Asks for permission, or takes the person to the right settings page
  /// when only Settings can change things.
  Future<void> ask() async {
    switch (state.value) {
      case RefusedForGood():
        await _repo.openAppSettings();
      case LocationOff():
        await _repo.openLocationSettings();
      default:
        state = const AsyncLoading<LocationState>();
        state = await AsyncValue.guard(_repo.ask);
    }
  }

  /// Checks again, as after coming back from Settings.
  Future<void> recheck() async {
    state = await AsyncValue.guard(_repo.current);
  }
}
