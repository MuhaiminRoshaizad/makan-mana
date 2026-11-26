import 'dart:math' as math;

import '../domain/place.dart';
import '../domain/places_repository.dart';

/// Twenty made-up places for the demo build, so the app can be tried and
/// screenshotted without a Google key. Six of them fail the default
/// filters, which leaves 15 on the wheel.
class DemoPlacesRepository implements PlacesRepository {
  const DemoPlacesRepository({this.delay = const Duration(milliseconds: 900)});

  /// How long a search pretends to take, so the loading state shows.
  final Duration delay;

  @override
  bool get knowsOpeningHours => true;

  /// Dataran Merdeka, where the demo's places are.
  @override
  Future<LatLon?> middle() async => (latitude: 3.1478, longitude: 101.6953);

  @override
  Future<List<Place>> nearby(SearchArea area) async {
    await Future<void>.delayed(delay);
    final List<Place> all = <Place>[
      for (final (int i, (String, double, int, int, bool) p) in _places.indexed)
        _place(area, i, p),
    ]..sort((Place a, Place b) => a.distanceMetres - b.distanceMetres);
    return <Place>[
      for (final Place p in all)
        if (p.distanceMetres <= area.radiusMetres) p,
    ];
  }

  /// Spreads the places round the centre at their stated distances, each a
  /// golden angle on from the last so none line up.
  static Place _place(
    SearchArea area,
    int i,
    (String, double, int, int, bool) p,
  ) {
    final (String name, double rating, int reviews, int metres, bool open) = p;
    final double bearing = i * 137.5 * math.pi / 180;
    const double metresPerDegree = 111320;
    return Place(
      id: 'demo-${name.toLowerCase().replaceAll(' ', '-')}',
      name: name,
      rating: rating,
      reviewCount: reviews,
      latitude: area.latitude + metres * math.cos(bearing) / metresPerDegree,
      longitude:
          area.longitude +
          metres *
              math.sin(bearing) /
              (metresPerDegree * math.cos(area.latitude * math.pi / 180)),
      distanceMetres: metres,
      openNow: open,
    );
  }

  static const List<(String, double, int, int, bool)> _places =
      <(String, double, int, int, bool)>[
        ('Gerai Laksa', 4.5, 420, 350, true),
        ('Kedai Mee Rebus', 4.2, 412, 500, true),
        ('Kedai Kopi Baru', 3.8, 520, 600, true),
        ('Warung Nasi Campur', 4.3, 968, 650, true),
        ('Gerai Char Kuey Teow', 3.6, 140, 750, true),
        ('Restoran Tomyam', 4.1, 2210, 800, true),
        ('Kopitiam Lama', 4.6, 310, 900, true),
        ('Kedai Mee Kari', 3.9, 76, 1000, true),
        ('Gerai Roti Canai', 4.4, 1203, 1100, true),
        ('Restoran Mamak', 4.0, 5420, 1200, true),
        ('Kedai Nasi Ayam', 4.3, 760, 1300, true),
        ('Warung Soto', 4.2, 288, 1400, true),
        ('Restoran Nasi Kerabu', 4.3, 890, 1500, false),
        ('Restoran Daun Pisang', 4.5, 480, 1600, true),
        ('Warung Ayam Penyet', 4.1, 31, 1600, true),
        ('Kedai Dim Sum', 4.1, 654, 1700, true),
        ('Restoran Ikan Bakar', 4.4, 1388, 1800, true),
        ('Warung Mee Goreng', 4.0, 199, 1900, true),
        ('Restoran Satay', 3.4, 610, 1900, false),
        ('Kedai Bubur Nasi', 4.2, 345, 2000, true),
      ];
}
