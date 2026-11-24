import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/place.dart';
import '../domain/places_repository.dart';

/// Raised when a build carries no usable list of places.
class NoBundledPlaces implements Exception {
  const NoBundledPlaces();
}

/// Places from the list bundled into the app when it is built: a file
/// prepared on the developer's machine and kept out of the repository
/// (docs/decisions.md 017). It has ratings and review counts but no opening
/// hours.
class BundledPlacesRepository implements PlacesRepository {
  BundledPlacesRepository({Future<String> Function()? load})
    : _load = load ?? (() => rootBundle.loadString(asset));

  static const String asset = 'assets/places/places.private.json';

  final Future<String> Function() _load;
  List<_Entry>? _entries;

  @override
  bool get knowsOpeningHours => false;

  @override
  Future<List<Place>> nearby(SearchArea area) async {
    final List<_Entry> all = _entries ??= await _read();
    final List<Place> near = <Place>[];
    for (final _Entry e in all) {
      final int metres = distanceMetres(
        area.latitude,
        area.longitude,
        e.lat,
        e.lon,
      ).round();
      if (metres > area.radiusMetres) continue;
      near.add(
        Place(
          id: e.id,
          name: e.name,
          rating: e.rating,
          reviewCount: e.reviews,
          distanceMetres: metres,
          openNow: null,
          category: e.category,
        ),
      );
    }
    near.sort((Place a, Place b) => a.distanceMetres - b.distanceMetres);
    return near;
  }

  Future<List<_Entry>> _read() async {
    final String text;
    try {
      text = await _load();
    } catch (_) {
      // A build made without the file, as on CI.
      throw const NoBundledPlaces();
    }
    try {
      final Map<String, dynamic> places =
          (jsonDecode(text) as Map<String, dynamic>)['places']
              as Map<String, dynamic>;
      return <_Entry>[
        for (final Object? raw in places.values)
          if (raw is Map<String, dynamic> && raw['temporarilyClosed'] != true)
            _Entry(
              id: raw['id'] as String,
              name: raw['name'] as String,
              rating: (raw['rating'] as num?)?.toDouble(),
              reviews: (raw['reviews'] as num?)?.toInt() ?? 0,
              category: raw['category'] as String?,
              lat: (raw['lat'] as num).toDouble(),
              lon: (raw['lon'] as num).toDouble(),
            ),
      ];
    } on Object catch (_) {
      throw const NoBundledPlaces();
    }
  }
}

class _Entry {
  const _Entry({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.lat,
    required this.lon,
  });

  final String id;
  final String name;
  final double? rating;
  final int reviews;
  final String? category;
  final double lat;
  final double lon;
}
