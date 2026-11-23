import 'place.dart';

/// Which nearby places go on the wheel.
class PlaceFilters {
  const PlaceFilters({
    this.minRating = 4.0,
    this.minReviews = 50,
    this.openNow = true,
  });

  /// Places rated below this stay off the wheel; null keeps every rating.
  final double? minRating;

  /// Places with fewer reviews stay off; 0 keeps them all.
  final int minReviews;

  /// Whether only places known to be open right now go on.
  final bool openNow;

  bool passes(Place p) {
    final double? min = minRating;
    if (min != null && (p.rating ?? 0) < min) return false;
    if (p.reviewCount < minReviews) return false;
    // A place whose hours Google does not know cannot be shown to be open.
    if (openNow && p.openNow != true) return false;
    return true;
  }
}
