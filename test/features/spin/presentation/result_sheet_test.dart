import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/spin/presentation/result_sheet.dart';

const Place mamak = Place(
  id: 'ChIJ-mamak',
  name: 'Restoran Mamak',
  rating: 4.0,
  reviewCount: 5420,
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
    TextScaler scaler = TextScaler.noScaling,
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
            body: Builder(
              builder: (BuildContext c) => Center(
                child: TextButton(
                  onPressed: () => showResultSheet(
                    c,
                    place: place,
                    onSpinAgain: () => spunAgain++,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
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
    expect(
      tester.getRect(find.text('Spin again')).bottom,
      lessThanOrEqualTo(915 - 48),
    );
  });
}
