import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/location_repository.dart';
import '../../location/presentation/location_providers.dart';
import '../data/bundled_places_repository.dart';
import '../data/demo_places_repository.dart';
import '../domain/place.dart';
import '../domain/place_filters.dart';
import '../domain/places_repository.dart';

/// Where places come from, chosen when the app is built with
/// `--dart-define=MAKAN_MANA_PLACES=<source>` (docs/decisions.md 017).
enum PlacesSource {
  /// Twenty made-up places round Dataran Merdeka, for trying the app.
  demo,

  /// The list bundled into this build. The default.
  bundled,
}

/// The source this build uses. `MAKAN_MANA_DEMO=true` still picks the demo.
final PlacesSource placesSource = const bool.fromEnvironment('MAKAN_MANA_DEMO')
    ? PlacesSource.demo
    : PlacesSource.values.firstWhere(
        (PlacesSource s) =>
            s.name == const String.fromEnvironment('MAKAN_MANA_PLACES'),
        orElse: () => PlacesSource.bundled,
      );

bool get demoMode => placesSource == PlacesSource.demo;

/// The time now, for anything that depends on it, such as open or closed.
/// Tests give it a fixed time.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// The most places the wheel holds; more would make the wedges unreadable.
/// Google's Nearby Search returns 20 at most as well.
const int wheelMaxPlaces = 20;

/// Raised while the app has no way to find places: the source has nothing
/// in this build.
class PlacesUnavailable implements Exception {
  const PlacesUnavailable();
}

final Provider<PlacesRepository> placesRepositoryProvider =
    Provider<PlacesRepository>(
      (Ref ref) => switch (placesSource) {
        PlacesSource.demo => const DemoPlacesRepository(),
        PlacesSource.bundled => BundledPlacesRepository(),
      },
    );

/// Raised while the search has no centre: location is not shared, is off,
/// or gave no position. [state] says which.
class NeedsLocation implements Exception {
  const NeedsLocation(this.state);
  final LocationState state;
}

/// How far round the centre to search, in metres; the search area sheet
/// changes it.
final NotifierProvider<RadiusNotifier, int> radiusProvider =
    NotifierProvider<RadiusNotifier, int>(RadiusNotifier.new);

class RadiusNotifier extends Notifier<int> {
  @override
  int build() => 2000;

  void set(int metres) => state = metres;
}

/// Where to search: round the phone's location, or in the demo round
/// Dataran Merdeka.
final FutureProvider<SearchArea> searchAreaProvider =
    FutureProvider<SearchArea>((Ref ref) async {
      final int radius = ref.watch(radiusProvider);
      if (demoMode) {
        return SearchArea(
          latitude: 3.1478,
          longitude: 101.6953,
          radiusMetres: radius,
        );
      }
      final LocationState here = await ref.watch(locationProvider.future);
      if (here is Located) {
        return SearchArea(
          latitude: here.latitude,
          longitude: here.longitude,
          radiusMetres: radius,
        );
      }
      throw NeedsLocation(here);
    }, retry: (_, _) => null);

final NotifierProvider<FiltersNotifier, PlaceFilters> filtersProvider =
    NotifierProvider<FiltersNotifier, PlaceFilters>(FiltersNotifier.new);

class FiltersNotifier extends Notifier<PlaceFilters> {
  /// The starting filters for this source: Open now only where the source
  /// knows opening hours, since otherwise it would keep every place off.
  PlaceFilters get defaults => PlaceFilters(
    openNow: ref.read(placesRepositoryProvider).knowsOpeningHours,
  );

  @override
  PlaceFilters build() => defaults;

  void set(PlaceFilters filters) => state = filters;
}

/// Every place found in the search area, before filtering. A failed search
/// is shown at once with Try again, instead of Riverpod's automatic retries
/// keeping the skeleton up for minutes.
final FutureProvider<List<Place>> nearbyPlacesProvider =
    FutureProvider<List<Place>>((Ref ref) async {
      final PlacesRepository repo = ref.watch(placesRepositoryProvider);
      final SearchArea area = await ref.watch(searchAreaProvider.future);
      try {
        return await repo.nearby(area);
      } on NoBundledPlaces {
        throw const PlacesUnavailable();
      }
    }, retry: (_, _) => null);

/// The places on the wheel: the nearest ones that pass the filters, up to
/// [wheelMaxPlaces]. Changing a filter refilters what was found without
/// searching again.
final Provider<AsyncValue<List<Place>>> wheelPlacesProvider =
    Provider<AsyncValue<List<Place>>>((Ref ref) {
      final PlaceFilters filters = ref.watch(filtersProvider);
      return ref
          .watch(nearbyPlacesProvider)
          .whenData(
            (List<Place> all) =>
                all.where(filters.passes).take(wheelMaxPlaces).toList(),
          );
    });
