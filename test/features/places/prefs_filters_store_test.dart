import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/data/prefs_filters_store.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/place_kind.dart';

void main() {
  test('filters survive being written and read back', () {
    final PlaceFilters f = const PlaceFilters().copyWith(
      maxDistanceMetres: 5000,
      minRating: () => null,
      minReviews: 200,
      openNow: false,
      kinds: <PlaceKind>{PlaceKind.cafe, PlaceKind.fastFood},
      maxPlaces: () => null,
    );
    expect(decodeFilters(encodeFilters(f)), f);
    expect(
      decodeFilters(encodeFilters(const PlaceFilters())),
      const PlaceFilters(),
    );
  });

  test('a kind this build no longer knows is dropped, and none left means '
      'kedai makan', () {
    final Map<String, Object?> j = encodeFilters(const PlaceFilters())
      ..['kinds'] = <String>['noodleBar'];
    expect(decodeFilters(j).kinds, <PlaceKind>{PlaceKind.kedaiMakan});
  });
}
