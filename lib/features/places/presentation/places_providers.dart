import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The most places the wheel holds; more would make the wedges unreadable.
/// Google's Nearby Search returns 20 at most as well.
const int wheelMaxPlaces = 20;

/// Raised while the app has no way to find places: the source has nothing
/// in this build, or there is no centre to search round yet.
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

/// Where to search. The demo searches 2 km round Dataran Merdeka. Until the
/// app reads the phone's location, other builds search round a centre given
/// as `--dart-define=MAKAN_MANA_CENTRE=<lat>,<lon>`, kept in a private
/// defines file; without one there is nowhere to search.
final Provider<SearchArea?> searchAreaProvider = Provider<SearchArea?>((
  Ref ref,
) {
  if (demoMode) {
    return const SearchArea(
      latitude: 3.1478,
      longitude: 101.6953,
      radiusMetres: 2000,
    );
  }
  final List<double>? centre = parseCentre(
    const String.fromEnvironment('MAKAN_MANA_CENTRE'),
  );
  if (centre == null) return null;
  return SearchArea(
    latitude: centre[0],
    longitude: centre[1],
    radiusMetres: 2000,
  );
});

/// "5.5,100.4" as [5.5, 100.4]; null when it is not a latitude and a
/// longitude.
List<double>? parseCentre(String text) {
  final List<String> parts = text.split(',');
  if (parts.length != 2) return null;
  final double? lat = double.tryParse(parts[0].trim());
  final double? lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
    return null;
  }
  return <double>[lat, lon];
}

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
      final SearchArea? area = ref.watch(searchAreaProvider);
      if (area == null) throw const PlacesUnavailable();
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
