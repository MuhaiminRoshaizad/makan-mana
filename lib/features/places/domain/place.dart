/// A place to eat near the search centre.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.distanceMetres,
    required this.openNow,
  });

  /// Google's place ID, the one field the app may keep between sessions.
  final String id;
  final String name;

  /// Google's average rating out of 5, or null when nobody has rated it.
  final double? rating;
  final int reviewCount;

  /// Straight-line distance from the search centre.
  final int distanceMetres;

  /// Null when Google does not know its opening hours.
  final bool? openNow;
}
