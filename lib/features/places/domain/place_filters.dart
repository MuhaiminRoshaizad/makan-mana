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

  /// How many filters are doing something, for the badge on Filters.
  int get activeCount =>
      (minRating != null ? 1 : 0) +
      (minReviews > 0 ? 1 : 0) +
      (openNow ? 1 : 0);

  PlaceFilters copyWith({
    double? Function()? minRating,
    int? minReviews,
    bool? openNow,
  }) => PlaceFilters(
    minRating: minRating == null ? this.minRating : minRating(),
    minReviews: minReviews ?? this.minReviews,
    openNow: openNow ?? this.openNow,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaceFilters &&
      other.minRating == minRating &&
      other.minReviews == minReviews &&
      other.openNow == openNow;

  @override
  int get hashCode => Object.hash(minRating, minReviews, openNow);

  bool passes(Place p) {
    final double? min = minRating;
    if (min != null && (p.rating ?? 0) < min) return false;
    if (p.reviewCount < minReviews) return false;
    // Only places known to be closed go; a place whose hours are not known
    // stays, so a list still being filled in does not empty the wheel.
    if (openNow && p.openNow == false) return false;
    return true;
  }
}
