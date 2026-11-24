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

  test('the list says nothing about opening hours, so Open now starts off', () {
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
    expect(c.read(filtersProvider).openNow, isFalse);
    expect(c.read(filtersProvider).minRating, 4.0);
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
          searchAreaProvider.overrideWithValue(area),
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

  test('a centre reads as latitude then longitude, and nonsense as none', () {
    expect(parseCentre('3.14,101.69'), <double>[3.14, 101.69]);
    expect(parseCentre(' 3.14 , 101.69 '), <double>[3.14, 101.69]);
    expect(parseCentre(''), isNull);
    expect(parseCentre('3.14'), isNull);
    expect(parseCentre('95,100'), isNull);
    expect(parseCentre('a,b'), isNull);
  });
}
