import 'dart:math' as math;

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

/// The places to eat in an area. Every screen reads places through this,
/// so a source can be swapped without touching them (docs/decisions.md 017).
abstract interface class PlacesRepository {
  /// The places to eat in [area], nearest first. A source may return more
  /// than fit on the wheel.
  Future<List<Place>> nearby(SearchArea area);

  /// Whether its places say if they are open now. The Open now filter is
  /// offered only when they do.
  bool get knowsOpeningHours;
}

/// Straight-line distance in metres between two points on the Earth, by the
/// haversine formula.
double distanceMetres(double lat1, double lon1, double lat2, double lon2) {
  const double earth = 6371000;
  double rad(double d) => d * math.pi / 180;
  final double dLat = rad(lat2 - lat1);
  final double dLon = rad(lon2 - lon1);
  final double h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(h));
}
