import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../domain/opening_hours.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';
import '../domain/review.dart';

/// Raised when a build carries no usable list of places.
class NoBundledPlaces implements Exception {
  const NoBundledPlaces();
}

/// Places from the list bundled into the app when it is built: a file
/// prepared on the developer's machine and kept out of the repository
/// (docs/decisions.md 017). Places visited for details carry their weekly
/// hours and a few reviews; the rest have neither yet.
class BundledPlacesRepository implements PlacesRepository {
  BundledPlacesRepository({
    Future<String> Function()? load,
    DateTime Function()? now,
  }) : _load = load ?? (() => rootBundle.loadString(asset)),
       _now = now ?? DateTime.now;

  static const String asset = 'assets/places/places.private.json';

  final Future<String> Function() _load;

  /// The phone's own clock: the list's hours are local Malaysian time, as
  /// is a phone used here.
  final DateTime Function() _now;
  List<_Entry>? _entries;

  @override
  bool get knowsOpeningHours => true;

  @override
  Future<List<Place>> nearby(SearchArea area) async {
    final List<_Entry> all = _entries ??= await _read();
    final DateTime now = _now();
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
          openNow: e.hours?.isOpenAt(now),
          category: e.category,
          hours: e.hours,
          reviews: e.topReviews,
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
      // A full list with hours and reviews is about 7 MB, which took 30 to
      // 60 ms to decode on a desktop: several frames of a frozen skeleton
      // if done on the UI thread, and more on a phone.
      return await compute(_parse, text);
    } on Object catch (_) {
      throw const NoBundledPlaces();
    }
  }

  static List<_Entry> _parse(String text) {
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
            hours: _hours(raw['hours']),
            topReviews: _reviews(raw['topReviews']),
          ),
    ];
  }

  static const List<String> _days = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  /// {"mon": [[660, 1290]], ...} in minutes from midnight, or null.
  static OpeningHours? _hours(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return OpeningHours(<List<(int, int)>>[
      for (final String day in _days)
        <(int, int)>[
          for (final Object? span
              in (raw[day] as List<dynamic>? ?? <dynamic>[]))
            (
              (span! as List<dynamic>)[0] as int,
              (span as List<dynamic>)[1] as int,
            ),
        ],
    ]);
  }

  /// [{"rating": 5, "month": "2026-08", "text": "..."}], or none.
  static List<Review> _reviews(Object? raw) {
    if (raw is! List<dynamic>) return const <Review>[];
    return <Review>[
      for (final Object? r in raw)
        if (r is Map<String, dynamic>)
          Review(
            rating: (r['rating'] as num).toInt(),
            text: r['text'] as String,
            month: switch (r['month']) {
              final String m => DateTime.tryParse('$m-01'),
              _ => null,
            },
          ),
    ];
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
    required this.hours,
    required this.topReviews,
  });

  final String id;
  final String name;
  final double? rating;
  final int reviews;
  final String? category;
  final double lat;
  final double lon;
  final OpeningHours? hours;
  final List<Review> topReviews;
}
