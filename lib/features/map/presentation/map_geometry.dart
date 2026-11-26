import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../places/domain/places_repository.dart';

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

/// Where the camera looks and how close: a centre and a zoom.
typedef MapView = ({double latitude, double longitude, double zoom});

/// The view that shows every one of [points] inside the part of a [view]
/// left [clear] of what floats over the map, the points filling [fill] of
/// it on their longer side. In Web Mercator, as MapLibre draws, with 512 dp
/// tiles. A lone point, or points very close together, stop at [maxZoom].
MapView frame(
  List<LatLon> points,
  Size view, {
  EdgeInsets clear = EdgeInsets.zero,
  double fill = 0.85,
  double maxZoom = 16,
}) {
  assert(points.isNotEmpty);
  double x(LatLon p) => (p.longitude + 180) / 360;
  double y(LatLon p) {
    final double s = math.sin(p.latitude * math.pi / 180);
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }

  final List<double> xs = points.map(x).toList();
  final List<double> ys = points.map(y).toList();
  final double minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final double minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final double clearW = view.width - clear.horizontal;
  final double clearH = view.height - clear.vertical;
  double fit(double room, double span) =>
      span <= 0 ? maxZoom : math.log(fill * room / (512 * span)) / math.ln2;
  final double zoom = math.min(
    maxZoom,
    math.min(fit(clearW, maxX - minX), fit(clearH, maxY - minY)),
  );
  // The clear part's middle is off the view's middle by half the
  // difference of its margins; aim the camera that far the other way.
  final double world = 512 * math.pow(2, zoom).toDouble();
  final double cx = (minX + maxX) / 2 - (clear.left - clear.right) / 2 / world;
  final double cy = (minY + maxY) / 2 - (clear.top - clear.bottom) / 2 / world;
  final double lat =
      math.atan(
        (math.exp(math.pi * (1 - 2 * cy)) - math.exp(-math.pi * (1 - 2 * cy))) /
            2,
      ) *
      180 /
      math.pi;
  return (latitude: lat, longitude: cx * 360 - 180, zoom: zoom);
}
