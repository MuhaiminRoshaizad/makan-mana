import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/data/demo_places_repository.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

Place place({
  double? rating = 4.2,
  int reviews = 100,
  bool? open = true,
  int metres = 500,
}) => Place(
  id: 'x',
  name: 'x',
  rating: rating,
  reviewCount: reviews,
  distanceMetres: metres,
  openNow: open,
);

const SearchArea area = SearchArea(
  latitude: 3.1478,
  longitude: 101.6953,
  radiusMetres: 2000,
);

void main() {
  group('the default filters (4.0 and up, 20 reviews, open now)', () {
    const PlaceFilters f = PlaceFilters();

    test('keep a well-rated, reviewed place that is open', () {
      expect(f.passes(place()), isTrue);
      expect(f.passes(place(rating: 4.0, reviews: 20)), isTrue);
    });

    test('drop one rated too low, too little reviewed, or closed', () {
      expect(f.passes(place(rating: 3.9)), isFalse);
      expect(f.passes(place(reviews: 19)), isFalse);
      expect(f.passes(place(open: false)), isFalse);
    });

    test('drop one nobody has rated', () {
      expect(f.passes(place(rating: null)), isFalse);
    });

    test('keep one whose hours are not known yet, rather than empty the '
        'wheel while the list is filled in', () {
      expect(f.passes(place(open: null)), isTrue);
    });
  });

  test('with every filter off, every place passes', () {
    const PlaceFilters off = PlaceFilters(
      minRating: null,
      minReviews: 0,
      openNow: false,
    );
    expect(off.passes(place(rating: null, reviews: 0, open: null)), isTrue);
  });

  test('the demo finds 20 places nearest first, 15 of which pass the '
      'default filters', () async {
    final List<Place> all = await const DemoPlacesRepository(
      delay: Duration.zero,
    ).nearby(area);
    expect(all, hasLength(20));
    for (int i = 1; i < all.length; i++) {
      expect(
        all[i].distanceMetres,
        greaterThanOrEqualTo(all[i - 1].distanceMetres),
      );
    }
    expect(all.where(const PlaceFilters().passes), hasLength(15));
  });

  test('the demo keeps only places inside the radius', () async {
    final List<Place> near = await const DemoPlacesRepository(
      delay: Duration.zero,
    ).nearby(const SearchArea(latitude: 0, longitude: 0, radiusMetres: 800));
    expect(near.every((Place p) => p.distanceMetres <= 800), isTrue);
    expect(near, hasLength(6));
  });

  test(
    'changing a filter refilters the wheel without searching again',
    () async {
      int searches = 0;
      final ProviderContainer c = ProviderContainer(
        overrides: [
          placesRepositoryProvider.overrideWithValue(
            _Counting(() => searches++),
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
      expect(sub.read().value, hasLength(15));

      c
          .read(filtersProvider.notifier)
          .set(
            const PlaceFilters(minRating: null, minReviews: 0, openNow: false),
          );
      expect(sub.read().value, hasLength(20));
      expect(searches, 1);
    },
  );

  test('outside the demo build, the wheel reports that places are not '
      'available yet', () async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    final ProviderSubscription<AsyncValue<List<Place>>> sub = c.listen(
      wheelPlacesProvider,
      (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().hasError, isTrue);
  });

  test('the defaults count as three filters, and Any as none', () {
    expect(const PlaceFilters().activeCount, 3);
    expect(
      const PlaceFilters(
        minRating: null,
        minReviews: 0,
        openNow: false,
      ).activeCount,
      0,
    );
  });

  test('filters equal by value, and copyWith can clear the rating', () {
    expect(const PlaceFilters(), const PlaceFilters());
    expect(
      const PlaceFilters().copyWith(minRating: () => null).minRating,
      isNull,
    );
    expect(const PlaceFilters().copyWith(minReviews: 200).minReviews, 200);
    expect(const PlaceFilters().copyWith(minReviews: 200).minRating, 4.0);
  });
}

class _Counting implements PlacesRepository {
  @override
  bool get knowsOpeningHours => true;

  _Counting(this.onSearch);
  final void Function() onSearch;

  @override
  Future<List<Place>> nearby(SearchArea area) {
    onSearch();
    return const DemoPlacesRepository(delay: Duration.zero).nearby(area);
  }
}
