import 'place.dart';

/// Where to look: a centre and how far round it.
class SearchArea {
  const SearchArea({
    required this.latitude,
    required this.longitude,
    required this.radiusMetres,
  });

  final double latitude;
  final double longitude;

  /// Up to 50 km, the most Nearby Search accepts (docs/decisions.md 004).
  final int radiusMetres;
}

/// The places to eat in an area. Google Places is the real source; the
/// demo build uses made-up ones.
abstract interface class PlacesRepository {
  /// Up to 20 places to eat in [area], nearest first.
  Future<List<Place>> nearby(SearchArea area);
}
