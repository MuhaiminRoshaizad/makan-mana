import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/core/widgets/tab_back.dart';
import 'package:makan_mana/features/places/domain/opening_hours.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/review.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';
import 'package:makan_mana/features/places/presentation/maps_link.dart';
import 'package:makan_mana/features/places/presentation/place_card.dart';

const Place mamak = Place(
  id: 'ChIJ-mamak',
  name: 'Restoran Mamak',
  rating: 4.0,
  reviewCount: 5420,
  latitude: 0,
  longitude: 0,
  distanceMetres: 1200,
  openNow: true,
);

/// Android 14 and later scale small text by the full factor but damp large
/// sizes, which a linear scaler cannot reproduce.
class _DampedScaler extends TextScaler {
  const _DampedScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 14 ? fontSize * 2 : 28 + (fontSize - 14) * 1.3;

  @override
  double get textScaleFactor => 2;
}

void main() {
  late List<Uri> opened;
  late bool canOpen;
  late int spunAgain;

  Future<void> show(
    WidgetTester tester, {
    Place place = mamak,
    DateTime? now,
    TextScaler scaler = TextScaler.noScaling,
    bool full = true,
  }) async {
    opened = <Uri>[];
    canOpen = true;
    spunAgain = 0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = tester.view.viewPadding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(
            () => now ?? DateTime(2026, 11, 24, 12),
          ),
          openLinkProvider.overrideWithValue((Uri uri) async {
            opened.add(uri);
            return canOpen;
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: PlaceCardHost(
                    place: place,
                    won: true,
                    onClose: () {},
                    onSpinAgain: () => spunAgain++,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (full) {
      await tester.tap(find.text('Rating'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('it names the place with its rating, reviews and distance', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.text('Today you are eating at'), findsOneWidget);
    expect(find.text('Restoran Mamak'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);
    expect(find.text('5,420'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
  });

  testWidgets('a place nobody has rated says so, without a star', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      place: const Place(
        id: 'x',
        name: 'Gerai Baru',
        rating: null,
        reviewCount: 0,
        latitude: 0,
        longitude: 0,
        distanceMetres: 80,
        openNow: true,
      ),
    );
    expect(find.text('None'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.star_fill), findsNothing);
  });

  testWidgets('Open in Google Maps hands the phone a Maps link to the place', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Open in Google Maps'));
    await tester.pump();
    expect(opened.single.host, 'www.google.com');
    expect(opened.single.path, '/maps/search/');
    expect(opened.single.queryParameters, <String, String>{
      'api': '1',
      'query': 'Restoran Mamak',
      'query_place_id': 'ChIJ-mamak',
    });
  });

  test('a made-up demo place is searched for by name only', () {
    const Place demo = Place(
      id: 'demo-warung-soto',
      name: 'Warung Soto',
      rating: 4.2,
      reviewCount: 288,
      latitude: 0,
      longitude: 0,
      distanceMetres: 1400,
      openNow: true,
    );
    expect(
      mapsLinkFor(demo).queryParameters.containsKey('query_place_id'),
      isFalse,
    );
  });

  testWidgets("when nothing can open the link, it says it couldn't", (
    WidgetTester tester,
  ) async {
    await show(tester);
    canOpen = false;
    await tester.tap(find.text('Open in Google Maps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Couldn't open Google Maps"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('Spin again asks for another spin', (WidgetTester tester) async {
    await show(tester);
    await tester.tap(find.text('Spin again'));
    expect(spunAgain, 1);
  });

  testWidgets('with large system text the sheet still fits, its last button '
      'above the navigation bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Spin again'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Spin again')).bottom,
      lessThanOrEqualTo(915 - 48),
    );
  });

  const List<(int, int)> lunchToNight = <(int, int)>[(660, 1290)];
  final Place kafe = Place(
    id: 'ChIJ-kafe',
    name: 'Kafe Bertam',
    rating: 4.5,
    reviewCount: 446,
    latitude: 0,
    longitude: 0,
    distanceMetres: 300,
    openNow: true,
    hours: const OpeningHours(<List<(int, int)>>[
      <(int, int)>[],
      lunchToNight,
      lunchToNight,
      lunchToNight,
      lunchToNight,
      lunchToNight,
      lunchToNight,
    ]),
    reviews: <Review>[
      Review(rating: 5, month: DateTime(2026, 8), text: 'Sedap, fast service.'),
      Review(rating: 3, month: DateTime(2025, 11), text: 'Okay only.'),
    ],
  );

  testWidgets('it says whether the place is open, in 24-hour time', (
    WidgetTester tester,
  ) async {
    await show(tester, place: kafe);
    expect(find.text('Open until 21:30'), findsOneWidget);
  });

  testWidgets('on its day off it says when it opens next', (
    WidgetTester tester,
  ) async {
    // Monday 23/11/2026.
    await show(tester, place: kafe, now: DateTime(2026, 11, 23, 12));
    expect(find.text('Closed, opens tomorrow 11:00'), findsOneWidget);
  });

  testWidgets('reviews follow the buttons, each with its stars and age', (
    WidgetTester tester,
  ) async {
    await show(tester, place: kafe);
    expect(find.text('Sedap, fast service.'), findsOneWidget);
    expect(find.text('3 months ago'), findsOneWidget);
    expect(find.text('A year ago'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('5 out of 5 stars')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Open in Google Maps')).dy,
      // The figures card has a Reviews label too; the heading is the last.
      lessThan(tester.getTopLeft(find.text('Reviews').last).dy),
    );
  });

  testWidgets('with more reviews on Google than kept, a link opens the place '
      'there to read them all', (WidgetTester tester) async {
    await show(tester, place: kafe);
    await tester.ensureVisible(
      find.text('Read all 446 reviews on Google Maps'),
    );
    await tester.tap(find.text('Read all 446 reviews on Google Maps'));
    await tester.pump();
    expect(opened.single.queryParameters['query_place_id'], 'ChIJ-kafe');
  });

  testWidgets('a place without hours or reviews shows neither', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.textContaining('Open until'), findsNothing);
    // Only the figures card's label, no reviews heading.
    expect(find.text('Reviews'), findsOneWidget);
  });

  testWidgets('a review cut short says where to read the rest, and the link '
      'opens the place on Google Maps; a short one has no link', (
    WidgetTester tester,
  ) async {
    final String long = List<String>.filled(60, 'Sedap gila, ').join();
    final String capped = 'x' * Review.keptLength;
    await show(
      tester,
      place: Place(
        id: 'ChIJ-long',
        name: 'Kafe Panjang',
        rating: 4.5,
        reviewCount: 3,
        latitude: 0,
        longitude: 0,
        distanceMetres: 300,
        openNow: true,
        reviews: <Review>[
          const Review(rating: 5, text: 'Short and sweet.'),
          Review(rating: 4, text: long),
          // Kept at the list's limit: the end was cut before the app.
          Review(rating: 3, text: capped),
        ],
      ),
    );
    final Finder more = find.text('Read the full review on Google Maps');
    expect(more, findsNWidgets(2));
    await tester.ensureVisible(more.first);
    await tester.tap(more.first);
    await tester.pump();
    expect(opened.single.queryParameters['query_place_id'], 'ChIJ-long');
  });

  testWidgets('Back shrinks the full sheet to the card, then closes the card', (
    WidgetTester tester,
  ) async {
    final TabBack back = TabBack();
    int closed = 0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: TabBackScope(
              back: back,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: PlaceCardHost(
                      place: mamak,
                      won: true,
                      onClose: () => closed++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final double card = tester.getTopLeft(find.text('Restoran Mamak')).dy;
    await tester.tap(find.text('Rating'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Restoran Mamak')).dy, lessThan(card));
    expect(back.handle(), isTrue);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Restoran Mamak')).dy, card);
    expect(closed, 0);
    expect(back.handle(), isTrue);
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('in the full sheet scrolled to the top, pulling the content down '
      'shrinks it back to the card, as a finger does, step by step', (
    WidgetTester tester,
  ) async {
    final String long = List<String>.filled(30, 'Sedap gila.').join(' ');
    await show(
      tester,
      place: Place(
        id: 'ChIJ-busy',
        name: 'Kafe Bertam',
        rating: 4.5,
        reviewCount: 900,
        latitude: 0,
        longitude: 0,
        distanceMetres: 300,
        openNow: true,
        reviews: <Review>[
          const Review(rating: 5, text: 'Sedap, fast service.'),
          for (int i = 0; i < 5; i++) Review(rating: 4, text: long),
        ],
      ),
    );
    final double full = tester.getTopLeft(find.text('Kafe Bertam')).dy;
    // A finger moves a few pixels a frame, not 400 at once.
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.text('Sedap, fast service.')),
    );
    for (int i = 0; i < 40; i++) {
      await g.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Kafe Bertam')).dy,
      greaterThan(full + 300),
    );
  });
}
