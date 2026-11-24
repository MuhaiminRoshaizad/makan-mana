import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/data/bundled_places_repository.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

/// A small list round a made-up centre at 5.5, 100.4.
String file(List<Map<String, Object?>> places) => jsonEncode(<String, Object?>{
  'updated': '2026-11-24',
  'places': <String, Object?>{for (final p in places) p['id']! as String: p},
});

Map<String, Object?> entry(
  String id, {
  double lat = 5.5,
  double lon = 100.4,
  double? rating = 4.2,
  int reviews = 120,
  bool closed = false,
}) => <String, Object?>{
  'id': id,
  'name': 'Place $id',
  'rating': rating,
  'reviews': reviews,
  'category': 'Malay Restaurant',
  'lat': lat,
  'lon': lon,
  'temporarilyClosed': closed,
};

const SearchArea area = SearchArea(
  latitude: 5.5,
  longitude: 100.4,
  radiusMetres: 2000,
);

void main() {
  test('it returns the places inside the radius, nearest first, with their '
      'distance worked out from the centre', () async {
    final BundledPlacesRepository repo = BundledPlacesRepository(
      load: () async => file(<Map<String, Object?>>[
        entry('far', lat: 5.5 + 0.03), // about 3.3 km north
        entry('mid', lat: 5.5 + 0.01), // about 1.1 km
        entry('near', lon: 100.4 + 0.002), // about 220 m
      ]),
    );
    final List<Place> got = await repo.nearby(area);
    expect(got.map((Place p) => p.id), <String>['near', 'mid']);
    expect(got.first.distanceMetres, closeTo(222, 3));
    expect(got[1].distanceMetres, closeTo(1112, 5));
    expect(got.first.category, 'Malay Restaurant');
    expect(got.first.openNow, isNull);
  });

  test('a map with no location starts at the middle of the list', () async {
    final BundledPlacesRepository repo = BundledPlacesRepository(
      load: () async => file(<Map<String, Object?>>[
        entry('a', lat: 5.4, lon: 100.3),
        entry('b', lat: 5.6, lon: 100.5),
      ]),
    );
    final LatLon? middle = await repo.middle();
    expect(middle!.latitude, closeTo(5.5, 1e-9));
    expect(middle.longitude, closeTo(100.4, 1e-9));
  });

  test('a place marked temporarily closed stays off', () async {
    final List<Place> got = await BundledPlacesRepository(
      load: () async =>
          file(<Map<String, Object?>>[entry('a'), entry('b', closed: true)]),
    ).nearby(area);
    expect(got.map((Place p) => p.id), <String>['a']);
  });

  test('a build without the file, or with a broken one, has no places', () {
    expect(
      BundledPlacesRepository(
        load: () => Future<String>.error(Exception()),
      ).nearby(area),
      throwsA(isA<NoBundledPlaces>()),
    );
    expect(
      BundledPlacesRepository(load: () async => '{"places": 3}').nearby(area),
      throwsA(isA<NoBundledPlaces>()),
    );
  });

  test('a place with hours is open or closed by the phone\'s clock, one '
      'without stays unknown, and Open now starts on', () async {
    const List<List<int>> lunch = <List<int>>[
      <int>[660, 1290],
    ];
    final Map<String, Object?> withHours = <String, Object?>{
      ...entry('kafe'),
      'hours': <String, Object?>{
        'mon': <Object>[],
        for (final String d in <String>[
          'tue',
          'wed',
          'thu',
          'fri',
          'sat',
          'sun',
        ])
          d: lunch,
      },
      'topReviews': <Object>[
        <String, Object?>{'rating': 5, 'month': '2026-08', 'text': 'Sedap.'},
      ],
    };
    Future<List<Place>> at(DateTime now) => BundledPlacesRepository(
      load: () async =>
          file(<Map<String, Object?>>[withHours, entry('new', lon: 100.401)]),
      now: () => now,
    ).nearby(area);

    // Tuesday 24/11/2026 at noon: open. Monday 23/11/2026 at noon: closed.
    final List<Place> tuesday = await at(DateTime(2026, 11, 24, 12));
    expect(tuesday.firstWhere((Place p) => p.id == 'kafe').openNow, isTrue);
    expect(tuesday.firstWhere((Place p) => p.id == 'new').openNow, isNull);
    final List<Place> monday = await at(DateTime(2026, 11, 23, 12));
    expect(monday.firstWhere((Place p) => p.id == 'kafe').openNow, isFalse);

    final Place kafe = tuesday.firstWhere((Place p) => p.id == 'kafe');
    expect(kafe.reviews.single.rating, 5);
    expect(kafe.reviews.single.text, 'Sedap.');
    expect(kafe.reviews.single.month, DateTime(2026, 8));

    final ProviderContainer c = ProviderContainer(
      overrides: [
        placesRepositoryProvider.overrideWithValue(
          BundledPlacesRepository(
            load: () async => file(<Map<String, Object?>>[]),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(filtersProvider).openNow, isTrue);
  });

  test(
    'the wheel holds the 20 nearest that pass, however many are near',
    () async {
      final ProviderContainer c = ProviderContainer(
        overrides: [
          placesRepositoryProvider.overrideWithValue(
            BundledPlacesRepository(
              load: () async => file(<Map<String, Object?>>[
                for (int i = 0; i < 60; i++)
                  entry('p$i', lat: 5.5 + i * 0.0001),
              ]),
            ),
          ),
          searchAreaProvider.overrideWith((_) async => area),
        ],
      );
      addTearDown(c.dispose);
      final ProviderSubscription<AsyncValue<List<Place>>> sub = c.listen(
        wheelPlacesProvider,
        (_, _) {},
      );
      await c.read(nearbyPlacesProvider.future);
      final List<Place> wheel = sub.read().value!;
      expect(wheel, hasLength(20));
      expect(wheel.first.id, 'p0');
      expect(wheel.last.id, 'p19');
    },
  );
}
