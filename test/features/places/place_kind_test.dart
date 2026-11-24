import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/place_kind.dart';

Place p(String name, [String? type]) => Place(
  id: name,
  name: name,
  rating: 4.2,
  reviewCount: 100,
  distanceMetres: 300,
  openNow: true,
  category: type,
);

void main() {
  // Names and Google types as they come in the places list round Bertam.
  test('restaurants, kopitiam, mamak and hawker stalls are kedai makan', () {
    for (final Place x in <Place>[
      p('AZLAN NASI KANDAR', 'Indian Muslim restaurant'),
      p('Restoran Selera Kampung', 'Malay Restaurant'),
      p('Union Cafe 友联茶室', 'Cafe'),
      p('Pak Aq Cafe', 'Cafe'),
      p('TOK BA Kopitiam', 'Cafe'),
      p('Kafe 5 beradek', 'Cafe'),
      p('Gerai Laksa', 'Hawker stall'),
      p('Medan Selera Bertam', 'Food court'),
      p('Warung Masakan Panas Wan Not'),
    ]) {
      expect(kindOf(x), PlaceKind.kedaiMakan, reason: x.name);
    }
  });

  test('cafes, bakeries and dessert places are cafes', () {
    for (final Place x in <Place>[
      p('Matchamanis Cafe', 'Cafe'),
      p('Mojo Pink Cafe', 'Cafe'),
      p('Factory Dessert & Cafe', 'Dessert shop'),
      p('Boulangerie Bertam', 'Bakery'),
    ]) {
      expect(kindOf(x), PlaceKind.cafe, reason: x.name);
    }
  });

  test('burgers, pizza and the big brands are fast food & chains', () {
    for (final Place x in <Place>[
      p('KFC Bertam Drive Thru (DT)', 'Fast food restaurant'),
      p("Domino's Kepala Batas", 'Pizza restaurant'),
      p('Pizza Hut Delivery Bertam', 'Pizza takeaway'),
      p('ZUS Coffee - Tasek Gelugor', 'Coffee shop'),
      p('Gigi Coffee Lotus Bertam', 'Cafe'),
      p('Burger Bakar Abang', 'Hamburger restaurant'),
    ]) {
      expect(kindOf(x), PlaceKind.fastFood, reason: x.name);
    }
  });

  test('a place with no type and a plain name is kedai makan', () {
    expect(kindOf(p('Pak Su')), PlaceKind.kedaiMakan);
  });

  test('by default only kedai makan reach the wheel', () {
    const PlaceFilters f = PlaceFilters();
    expect(f.passes(p('Restoran Maheran', 'Restaurant')), isTrue);
    expect(f.passes(p('Matchamanis Cafe', 'Cafe')), isFalse);
    expect(f.passes(p('KFC Kepala Batas', 'Fast food restaurant')), isFalse);
    final PlaceFilters all = f.copyWith(kinds: PlaceKind.values.toSet());
    expect(all.passes(p('KFC Kepala Batas', 'Fast food restaurant')), isTrue);
  });
}
