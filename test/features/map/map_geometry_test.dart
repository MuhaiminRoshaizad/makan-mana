import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/map/presentation/map_geometry.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';

void main() {
  test('the search ring closes, and every point is the radius away', () {
    const double lat = 3.139;
    const double lon = 101.687;
    final List<List<double>> ring = circleRing(lat, lon, 2000);
    expect(ring.first, ring.last);
    for (final List<double> p in ring) {
      expect(distanceMetres(lat, lon, p[1], p[0]), closeTo(2000, 10));
    }
  });

  test('at the zoom chosen, the circle spans the asked share of the view', () {
    const double lat = 3.139;
    for (final double r in <double>[500, 2000, 15000]) {
      final double z = zoomToFit(r, lat, 412);
      final double metresPerDp =
          40075016.686 * math.cos(lat * math.pi / 180) / (512 * math.pow(2, z));
      expect(2 * r / metresPerDp, closeTo(0.8 * 412, 0.01));
    }
    // A wider circle needs a smaller zoom.
    expect(zoomToFit(15000, lat, 412), lessThan(zoomToFit(2000, lat, 412)));
  });

  group('framing places', () {
    // Web Mercator, as MapLibre draws: x and y in dp at zoom z, 512 dp tiles.
    Offset dp(double lat, double lon, double z) {
      final double world = 512 * math.pow(2, z).toDouble();
      final double s = math.sin(lat * math.pi / 180);
      return Offset(
        (lon + 180) / 360 * world,
        (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * world,
      );
    }

    const List<LatLon> shops = <LatLon>[
      (latitude: 3.134, longitude: 101.679),
      (latitude: 3.147, longitude: 101.690),
      (latitude: 3.131, longitude: 101.696),
      (latitude: 3.153, longitude: 101.684),
    ];
    const Size view = Size(412, 915);
    const EdgeInsets clear = EdgeInsets.fromLTRB(16, 140, 16, 220);

    test('every place lands inside the part of the view left clear', () {
      final MapView v = frame(shops, view, clear: clear);
      final Offset centre = dp(v.latitude, v.longitude, v.zoom);
      for (final LatLon p in shops) {
        final Offset at =
            dp(p.latitude, p.longitude, v.zoom) -
            centre +
            Offset(view.width / 2, view.height / 2);
        expect(at.dx, inInclusiveRange(clear.left, view.width - clear.right));
        expect(at.dy, inInclusiveRange(clear.top, view.height - clear.bottom));
      }
    });

    test('the places fill the clear part, not a corner of it', () {
      final MapView v = frame(shops, view, clear: clear);
      final List<Offset> at = <Offset>[
        for (final LatLon p in shops) dp(p.latitude, p.longitude, v.zoom),
      ];
      final double w =
          at.map((Offset o) => o.dx).reduce(math.max) -
          at.map((Offset o) => o.dx).reduce(math.min);
      final double h =
          at.map((Offset o) => o.dy).reduce(math.max) -
          at.map((Offset o) => o.dy).reduce(math.min);
      final double clearW = view.width - clear.horizontal;
      final double clearH = view.height - clear.vertical;
      // One side or the other is close to full, with a margin.
      expect(math.max(w / clearW, h / clearH), closeTo(0.85, 0.02));
    });

    test('a single place is not zoomed in past street level', () {
      final MapView v = frame(<LatLon>[shops.first], view, clear: clear);
      expect(v.zoom, lessThanOrEqualTo(16));
      expect(v.latitude, closeTo(shops.first.latitude, 0.01));
    });
  });
}
