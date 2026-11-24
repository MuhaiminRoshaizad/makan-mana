import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/filters_store.dart';
import '../domain/place_filters.dart';
import '../domain/place_kind.dart';

/// Filters kept on the phone with shared_preferences, as one JSON string.
class PrefsFiltersStore implements FiltersStore {
  PrefsFiltersStore(this._prefs);

  static const String key = 'filters.v1';

  /// The options for [SharedPreferencesWithCache.create]: this store reads
  /// only its own key.
  static const SharedPreferencesWithCacheOptions options =
      SharedPreferencesWithCacheOptions(allowList: <String>{key});

  final SharedPreferencesWithCache _prefs;

  @override
  bool get chosen => _prefs.containsKey(key);

  @override
  PlaceFilters? load() {
    final String? raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return decodeFilters(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (_) {
      // Saved by an older build in a shape this one cannot read.
      return null;
    }
  }

  @override
  Future<void> save(PlaceFilters filters) =>
      _prefs.setString(key, jsonEncode(encodeFilters(filters)));
}

/// The filters as JSON. Kinds are kept by name, so renaming one drops it
/// rather than mixing it up with another.
Map<String, Object?> encodeFilters(PlaceFilters f) => <String, Object?>{
  'distance': f.maxDistanceMetres,
  'rating': f.minRating,
  'reviews': f.minReviews,
  'openNow': f.openNow,
  'kinds': <String>[for (final PlaceKind k in f.kinds) k.name],
  'places': f.maxPlaces,
};

PlaceFilters decodeFilters(Map<String, dynamic> j) {
  final Set<PlaceKind> kinds = <PlaceKind>{
    for (final Object? name in j['kinds'] as List<dynamic>)
      ...PlaceKind.values.where((PlaceKind k) => k.name == name),
  };
  return PlaceFilters(
    maxDistanceMetres: (j['distance'] as num).toInt(),
    minRating: (j['rating'] as num?)?.toDouble(),
    minReviews: (j['reviews'] as num).toInt(),
    openNow: j['openNow'] as bool,
    kinds: kinds.isEmpty ? const <PlaceKind>{PlaceKind.kedaiMakan} : kinds,
    maxPlaces: (j['places'] as num?)?.toInt(),
  );
}
