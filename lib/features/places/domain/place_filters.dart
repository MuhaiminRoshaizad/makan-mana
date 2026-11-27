import 'place.dart';
import 'place_kind.dart';

/// Which nearby places go on the wheel, and how many.
class PlaceFilters {
  const PlaceFilters({
    this.maxDistanceMetres = 2000,
    this.minRating = 4.0,
    this.minReviews = 20,
    this.openNow = true,
    this.kinds = const <PlaceKind>{PlaceKind.kedaiMakan},
    this.maxPlaces = 20,
  });

  /// Places further than this from the search centre stay off.
  final int maxDistanceMetres;

  /// Places rated below this stay off the wheel; null keeps every rating.
  final double? minRating;

  /// Places with fewer reviews stay off; 0 keeps them all.
  final int minReviews;

  /// Whether only places known to be open right now go on.
  final bool openNow;

  /// The kinds of place allowed on; never empty. Kedai makan alone to start
  /// with, since that is what the app is for.
  final Set<PlaceKind> kinds;

  /// How many of the places that pass go on the wheel, nearest first; null
  /// puts them all on.
  final int? maxPlaces;

  /// How many filters are doing something, for the badge on Filters. The
  /// distance is always set and shown beside the badge, so it is not counted.
  int get activeCount =>
      (minRating != null ? 1 : 0) +
      (minReviews > 0 ? 1 : 0) +
      (openNow ? 1 : 0) +
      (kinds.length < PlaceKind.values.length ? 1 : 0);

  PlaceFilters copyWith({
    int? maxDistanceMetres,
    double? Function()? minRating,
    int? minReviews,
    bool? openNow,
    Set<PlaceKind>? kinds,
    int? Function()? maxPlaces,
  }) => PlaceFilters(
    maxDistanceMetres: maxDistanceMetres ?? this.maxDistanceMetres,
    minRating: minRating == null ? this.minRating : minRating(),
    minReviews: minReviews ?? this.minReviews,
    openNow: openNow ?? this.openNow,
    kinds: kinds ?? this.kinds,
    maxPlaces: maxPlaces == null ? this.maxPlaces : maxPlaces(),
  );

  @override
  bool operator ==(Object other) =>
      other is PlaceFilters &&
      other.maxDistanceMetres == maxDistanceMetres &&
      other.minRating == minRating &&
      other.minReviews == minReviews &&
      other.openNow == openNow &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds) &&
      other.maxPlaces == maxPlaces;

  @override
  int get hashCode => Object.hash(
    maxDistanceMetres,
    minRating,
    minReviews,
    openNow,
    Object.hashAllUnordered(kinds),
    maxPlaces,
  );

  bool passes(Place p) {
    if (p.distanceMetres > maxDistanceMetres) return false;
    if (!kinds.contains(kindOf(p))) return false;
    final double? min = minRating;
    if (min != null && (p.rating ?? 0) < min) return false;
    if (p.reviewCount < minReviews) return false;
    // Open now means known to be open: a place whose hours are not known
    // goes too, as it may well be closed.
    if (openNow && p.openNow != true) return false;
    return true;
  }

  /// The places for the wheel from [all], which is nearest first.
  List<Place> pick(Iterable<Place> all) {
    final Iterable<Place> passing = all.where(passes);
    final int? max = maxPlaces;
    return (max == null ? passing : passing.take(max)).toList();
  }
}
