import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_places_repository.dart';
import '../domain/place.dart';
import '../domain/place_filters.dart';
import '../domain/places_repository.dart';

/// Built with `--dart-define=MAKAN_MANA_DEMO=true`: made-up places around a
/// fixed centre, no location and no Google key.
const bool demoMode = bool.fromEnvironment('MAKAN_MANA_DEMO');

/// Raised while the app has no way to find places: the Google Places client
/// and location are not built yet, and this is not the demo build.
class PlacesUnavailable implements Exception {
  const PlacesUnavailable();
}

/// Null while the app has no source of places outside the demo build.
final Provider<PlacesRepository?> placesRepositoryProvider =
    Provider<PlacesRepository?>(
      (Ref ref) => demoMode ? const DemoPlacesRepository() : null,
    );

/// Where to search: null until location is built, except in the demo build,
/// which searches 2 km round Dataran Merdeka.
final Provider<SearchArea?> searchAreaProvider = Provider<SearchArea?>(
  (Ref ref) => demoMode
      ? const SearchArea(
          latitude: 3.1478,
          longitude: 101.6953,
          radiusMetres: 2000,
        )
      : null,
);

final NotifierProvider<FiltersNotifier, PlaceFilters> filtersProvider =
    NotifierProvider<FiltersNotifier, PlaceFilters>(FiltersNotifier.new);

class FiltersNotifier extends Notifier<PlaceFilters> {
  @override
  PlaceFilters build() => const PlaceFilters();

  void set(PlaceFilters filters) => state = filters;
}

/// Every place found in the search area, before filtering. A failed search
/// is shown at once with Try again, instead of Riverpod's automatic retries
/// keeping the skeleton up for minutes.
final FutureProvider<List<Place>> nearbyPlacesProvider =
    FutureProvider<List<Place>>((Ref ref) {
      final PlacesRepository? repo = ref.watch(placesRepositoryProvider);
      final SearchArea? area = ref.watch(searchAreaProvider);
      if (repo == null || area == null) throw const PlacesUnavailable();
      return repo.nearby(area);
    }, retry: (_, _) => null);

/// The places on the wheel: the nearby ones that pass the filters. Changing
/// a filter refilters what was found without searching again.
final Provider<AsyncValue<List<Place>>> wheelPlacesProvider =
    Provider<AsyncValue<List<Place>>>((Ref ref) {
      final PlaceFilters filters = ref.watch(filtersProvider);
      return ref
          .watch(nearbyPlacesProvider)
          .whenData((List<Place> all) => all.where(filters.passes).toList());
    });
