import 'place.dart';

/// The three kinds of place the office can choose between.
enum PlaceKind {
  /// Restaurants, warung, kopitiam, mamak, hawker stalls and food courts.
  kedaiMakan('Kedai makan'),

  /// Cafes, bakeries, dessert and drinks places.
  cafe('Cafes & desserts'),

  /// Burger and pizza places, and the big brands.
  fastFood('Fast food & chains');

  const PlaceKind(this.label);
  final String label;
}

/// Brands with branches everywhere, whatever Google calls them.
final RegExp _chains = RegExp(
  r"\b(kfc|mcdonald'?s|burger king|a&w|marrybrown|texas chicken|domino'?s|"
  r'pizza hut|us pizza|subway|wendy|4fingers|zus coffee|starbucks|tealive|'
  r'kenangan|gigi coffee|coffee bean|chagee|mixue|bask bear|luckin|'
  r'secret recipe|dunkin|baskin|llaollao|family ?mart|7-eleven|tealive)\b',
  caseSensitive: false,
);

/// Google types that mean fast food.
final RegExp _fastFoodTypes = RegExp(
  r'(fast food|hamburger|pizza|fried chicken takeaway)',
  caseSensitive: false,
);

/// Google types that mean a cafe or drinks place, unless the name says
/// kedai makan.
final RegExp _cafeTypes = RegExp(
  r'(cafe|bubble tea|juice|tea house|coffee store|coffee stand)',
  caseSensitive: false,
);

/// Google types that mean a bakery or dessert place, whatever the name:
/// "Kedai kek" is a cake shop.
final RegExp _sweetTypes = RegExp(
  r'(bakery|dessert|sweets|ice cream|cake|pastry|donut|waffle|cendol)',
  caseSensitive: false,
);

/// Names that say bakery or dessert. Google types many such places plain
/// "Restaurant" or "Hawker stall".
final RegExp _sweetName = RegExp(
  r'(cendol|ais kacang|waffle|churros|\bkek\b|\bcakes?\b|cheese ?cake|'
  r'bakery|bakehouse|patisserie|donut|doughnut|ice ?cream|aiskrim|bingsu|'
  r'gelato|\bboba|dessert)',
  caseSensitive: false,
);

/// A main meal in the name keeps a place kedai makan, as in a "Chicken Chop
/// | Kambing Grill | Dessert" cafe.
final RegExp _mealName = RegExp(
  r'\b(nasi|mee|laksa|kambing|chicken chop|grill|ayam|ikan|seafood|'
  r'restoran)\b',
  caseSensitive: false,
);

/// Places whose name and Google type both mislead, set by hand by their
/// Google id.
const Map<String, PlaceKind> _byHand = <String, PlaceKind>{
  // Sweetrolley, Bertam: desserts, typed "Restaurant".
  'ChIJE2AQMj_RSjARGoH5w32RIbU': PlaceKind.cafe,
};

/// A name that says kedai makan, even when Google types it "Cafe": in
/// Malaysia many kopitiam and kedai are called "Cafe" or "Kafe".
final RegExp _localName = RegExp(
  r'\b(kopitiam|kopidiam|kopi|kedai|warung|gerai|restoran|nasi|mee|mamak|'
  r'tomyam|roti|laksa|kuey|ikan|soto|selera|medan|kafe|'
  // Malay kedai are often named for their owner: Pak Aq Cafe, Kak Ros Cafe.
  r'pak|mak|kak|abang|bang|tok|wan|cik|che|haji|hj|ummi|ummie)\b'
  // Chinese kopitiam signs: 茶室, 茶餐室, 餐室, 咖啡店.
  r'|茶室|茶餐室|餐室|咖啡店',
  caseSensitive: false,
);

/// Which kind [p] is, from its name and Google's type. Anything unclear is
/// kedai makan, the kind the app is for.
PlaceKind kindOf(Place p) {
  if (_byHand[p.id] case final PlaceKind kind) return kind;
  final String type = p.category ?? '';
  if (_chains.hasMatch(p.name) || _fastFoodTypes.hasMatch(type)) {
    return PlaceKind.fastFood;
  }
  if (_sweetTypes.hasMatch(type)) return PlaceKind.cafe;
  if (_sweetName.hasMatch(p.name) && !_mealName.hasMatch(p.name)) {
    return PlaceKind.cafe;
  }
  // "Coffee shop" is Google's word for a kopitiam.
  if (_cafeTypes.hasMatch(type) && !_localName.hasMatch(p.name)) {
    return PlaceKind.cafe;
  }
  return PlaceKind.kedaiMakan;
}
