import 'dart:math' as math;

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
}
