import 'dart:math' as math;

/// The Earth's circumference at the equator, in metres (WGS 84).
const double _circumference = 40075016.686;

/// A closed ring [radiusMetres] round a centre, as GeoJSON [longitude,
/// latitude] pairs, for drawing the search area.
List<List<double>> circleRing(
  double latitude,
  double longitude,
  double radiusMetres, {
  int points = 72,
}) {
  const double metresPerDegree = _circumference / 360;
  final double dLat = radiusMetres / metresPerDegree;
  final double dLon =
      radiusMetres / (metresPerDegree * math.cos(latitude * math.pi / 180));
  return <List<double>>[
    for (int i = 0; i <= points; i++)
      <double>[
        longitude + dLon * math.sin(2 * math.pi * i / points),
        latitude + dLat * math.cos(2 * math.pi * i / points),
      ],
  ];
}

/// The zoom at which a circle of [radiusMetres] spans [fraction] of a view
/// [widthDp] wide. MapLibre's tiles are 512 dp, so at zoom z a dp covers
/// circumference × cos(latitude) / (512 × 2^z) metres.
double zoomToFit(
  double radiusMetres,
  double latitude,
  double widthDp, {
  double fraction = 0.8,
}) {
  final double metresPerDp = 2 * radiusMetres / (fraction * widthDp);
  return math.log(
        _circumference *
            math.cos(latitude * math.pi / 180) /
            (512 * metresPerDp),
      ) /
      math.ln2;
}
