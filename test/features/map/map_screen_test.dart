import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/core/theme/app_tokens.dart';
import 'package:makan_mana/features/location/domain/location_repository.dart';
import 'package:makan_mana/features/location/presentation/location_providers.dart';
import 'package:makan_mana/features/map/presentation/map_screen.dart';
import 'package:makan_mana/features/map/presentation/places_map.dart';
import 'package:makan_mana/features/places/data/demo_places_repository.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/maps_link.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

const SearchArea area = SearchArea(
  latitude: 3.1478,
  longitude: 101.6953,
  radiusMetres: 2000,
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

/// A phone that has not shared its location.
class _NotShared implements LocationRepository {
  int asks = 0;

  @override
  Future<LocationState> current() async => const CanAsk();

  @override
  Future<LocationState> ask() async {
    asks++;
    return const CanAsk();
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

/// The demo's places, from a source that covers everywhere, so has no
/// middle for a map to start from.
class _Everywhere extends DemoPlacesRepository {
  const _Everywhere() : super(delay: Duration.zero);

  @override
  Future<LatLon?> middle() async => null;
}

void main() {
  /// What the screen last asked the map to show.
  MapProps? shown;
  late ProviderContainer container;
  final List<Uri> opened = <Uri>[];

  setUp(() {
    shown = null;
    opened.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  late _NotShared phone;

  Future<void> show(
    WidgetTester tester, {
    bool located = true,
    PlacesRepository places = const DemoPlacesRepository(delay: Duration.zero),
    TextScaler scaler = TextScaler.noScaling,
    bool reduceMotion = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = tester.view.viewPadding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    container = ProviderContainer(
      overrides: [
        placesRepositoryProvider.overrideWithValue(places),
        // Not the demo build, so without a pin the area comes from the
        // phone's location.
        locationRepositoryProvider.overrideWithValue(phone = _NotShared()),
        if (located)
          searchAreaProvider.overrideWith((Ref ref) async {
            final LatLon? pin = ref.watch(pinProvider);
            return pin == null
                ? area
                : SearchArea(
                    latitude: pin.latitude,
                    longitude: pin.longitude,
                    radiusMetres: 2000,
                  );
          }),
        mapViewProvider.overrideWithValue((MapProps props) {
          shown = props;
          return const ColoredBox(color: Color(0xFFE9E7E1));
        }),
        openLinkProvider.overrideWithValue((Uri uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: scaler, disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(body: MapScreen(random: math.Random(7))),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('the map shows the places on the wheel round the search '
      'centre, and says how many', (WidgetTester tester) async {
    await show(tester);
    expect(find.text('15 places within 2 km'), findsOneWidget);
    expect(shown!.places, hasLength(15));
    expect(shown!.latitude, area.latitude);
    expect(shown!.radiusMetres, 2000);
    expect(shown!.selectedId, isNull);
  });

  testWidgets('tapping a pin shows its card; Open in Google Maps opens it, '
      'and Close or a tap on the map puts the card away', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final String id = shown!.places.first.id;
    final String name = shown!.places.first.name;
    shown!.onPinTap(id);
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
    expect(shown!.selectedId, id);
    expect(find.textContaining('stars,'), findsOneWidget);
    await tester.tap(find.text('Open in Google Maps'));
    await tester.pump();
    expect(opened.single.queryParameters['query'], name);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text(name), findsNothing);
    shown!.onPinTap(id);
    await tester.pumpAndSettle();
    shown!.onMapTap();
    await tester.pumpAndSettle();
    expect(find.text(name), findsNothing);
  });

  testWidgets('a card for a place the filters then take off goes too', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final String id = shown!.places.first.id;
    shown!.onPinTap(id);
    await tester.pumpAndSettle();
    container
        .read(filtersProvider.notifier)
        .set(const PlaceFilters(minRating: 4.9));
    await tester.pumpAndSettle();
    expect(find.text('Open in Google Maps'), findsNothing);
    expect(find.text('No places pass these filters'), findsOneWidget);
  });

  testWidgets('the map buttons keep to the right edge', (
    WidgetTester tester,
  ) async {
    // Small text leaves room in the top row, as the real font does; the
    // test font's wide letters would fill it and hide a drift.
    await show(tester, scaler: const TextScaler.linear(0.5));
    for (final String label in <String>['3D view', 'Back to the search area']) {
      expect(
        tester.getRect(find.bySemanticsLabel(label)).right,
        closeTo(412 - 16, 0.5),
      );
    }
  });

  testWidgets('3D is a toggle that starts on; recentre asks the map to go '
      'back to the search area', (WidgetTester tester) async {
    await show(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('3D view')),
      isSemantics(isToggled: true, hasToggledState: true),
    );
    expect(shown!.tilted, isTrue);
    await tester.tap(find.bySemanticsLabel('3D view'));
    await tester.pumpAndSettle();
    expect(shown!.tilted, isFalse);
    expect(
      tester.getSemantics(find.bySemanticsLabel('3D view')),
      isSemantics(isToggled: false, hasToggledState: true),
    );
    final int before = shown!.recentre;
    await tester.tap(find.bySemanticsLabel('Back to the search area'));
    await tester.pumpAndSettle();
    expect(shown!.recentre, before + 1);
  });

  testWidgets('without a location the map starts at the middle of the '
      'places to choose a spot; Search here searches round it', (
    WidgetTester tester,
  ) async {
    await show(tester, located: false);
    expect(find.text('Choose where to eat'), findsOneWidget);
    // No area yet: no ring, no places.
    expect(shown!.radiusMetres, isNull);
    expect(shown!.places, isEmpty);
    expect(shown!.latitude, 3.1478);
    shown!.onMoved(3.15, 101.70);
    await tester.pump();
    await tester.tap(find.text('Search here'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(container.read(pinProvider), (latitude: 3.15, longitude: 101.70));
    expect(find.text('Choose where to eat'), findsNothing);
    expect(shown!.latitude, 3.15);
    expect(shown!.radiusMetres, 2000);
    expect(shown!.places, isNotEmpty);
  });

  testWidgets('while choosing a spot, Use my location asks for it', (
    WidgetTester tester,
  ) async {
    await show(tester, located: false);
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    expect(phone.asks, 1);
  });

  testWidgets('a source that covers everywhere has nowhere to start a map, '
      'so it asks for the location', (WidgetTester tester) async {
    await show(tester, located: false, places: const _Everywhere());
    expect(find.text('Find places near you'), findsOneWidget);
    expect(shown, isNull);
  });

  testWidgets('moving the map out of the ring offers Search this area, which '
      'searches round the new middle', (WidgetTester tester) async {
    await show(tester);
    Finder pill() => find.ancestor(
      of: find.text('Search this area'),
      matching: find.byType(IgnorePointer),
    );
    bool offered() => !tester.widget<IgnorePointer>(pill().first).ignoring;
    expect(offered(), isFalse);
    // Inside the 2 km ring, as when flying to a spin's winner: still the
    // same area.
    shown!.onMoved(area.latitude + 0.017, area.longitude);
    await tester.pumpAndSettle();
    expect(offered(), isFalse);
    shown!.onMoved(area.latitude + 0.02, area.longitude);
    await tester.pumpAndSettle();
    expect(offered(), isTrue);
    await tester.tap(find.text('Search this area'));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(container.read(pinProvider)!.latitude, area.latitude + 0.02);
    expect(shown!.latitude, area.latitude + 0.02);
    await tester.pumpAndSettle();
    expect(offered(), isFalse);
  });

  testWidgets('with large system text the card fits and its button stays '
      'above the floating bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    shown!.onPinTap(shown!.places.first.id);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The floating bar sits 12 dp above the 48 dp system bar, 60 dp tall.
    expect(
      tester.getRect(find.text('Open in Google Maps')).bottom,
      lessThanOrEqualTo(915 - 48 - 12 - 60),
    );
    expect(
      tester.getRect(find.text('Open in Google Maps')).bottom,
      lessThanOrEqualTo(915 - AppNavMetrics.clearance(48)),
    );
  });

  group('spin', () {
    testWidgets('Spin hops across the pins, slowing, then lands on one and '
        'flies there', (WidgetTester tester) async {
      await show(tester);
      await tester.tap(find.text('Spin'));
      final Set<String> hops = <String>{};
      for (int i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (shown!.selectedId case final String id) hops.add(id);
      }
      expect(hops.length, greaterThanOrEqualTo(3));
      await tester.pumpAndSettle();
      expect(find.text('Today you are eating at'), findsOneWidget);
      final String winner = shown!.selectedId!;
      final Place p = shown!.places.firstWhere((Place x) => x.id == winner);
      expect(find.text(p.name), findsOneWidget);
      expect(shown!.focusTick, 1);
      expect(shown!.focus, (latitude: p.latitude, longitude: p.longitude));
      expect(find.text('Spin'), findsNothing);
      // Putting the card away brings Spin back.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Spin'), findsOneWidget);
    });

    testWidgets('with Reduce Motion it lands at once, without hops', (
      WidgetTester tester,
    ) async {
      await show(tester, reduceMotion: true);
      await tester.tap(find.text('Spin'));
      await tester.pump();
      expect(find.text('Today you are eating at'), findsOneWidget);
      expect(shown!.focusTick, 1);
    });

    testWidgets('pins cannot be tapped mid-spin, and a tapped pin is not '
        'called the winner', (WidgetTester tester) async {
      await show(tester);
      await tester.tap(find.text('Spin'));
      await tester.pump(const Duration(milliseconds: 50));
      final String? hop = shown!.selectedId;
      final String other = shown!.places
          .firstWhere((Place x) => x.id != hop)
          .id;
      shown!.onPinTap(other);
      await tester.pump();
      expect(shown!.selectedId, hop);
      // The hops run on timers, which pumpAndSettle does not wait for.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      shown!.onPinTap(other);
      await tester.pumpAndSettle();
      expect(find.text('Today you are eating at'), findsNothing);
    });
  });
}
