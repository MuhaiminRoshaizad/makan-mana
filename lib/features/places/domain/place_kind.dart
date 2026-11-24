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

/// Google types that mean a cafe, dessert or drinks place.
final RegExp _cafeTypes = RegExp(
  r'(cafe|bakery|dessert|ice cream|bubble tea|juice|tea house|cake|'
  r'pastry|donut|waffle|coffee store|coffee stand)',
  caseSensitive: false,
);

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
  final String type = p.category ?? '';
  if (_chains.hasMatch(p.name) || _fastFoodTypes.hasMatch(type)) {
    return PlaceKind.fastFood;
  }
  // "Coffee shop" is Google's word for a kopitiam.
  if (_cafeTypes.hasMatch(type) && !_localName.hasMatch(p.name)) {
    return PlaceKind.cafe;
  }
  return PlaceKind.kedaiMakan;
}
