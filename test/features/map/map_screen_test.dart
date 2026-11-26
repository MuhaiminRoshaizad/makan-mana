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
import 'package:makan_mana/features/places/domain/filters_store.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/maps_link.dart';
import 'package:makan_mana/core/widgets/nav_cover.dart';
import 'package:makan_mana/features/places/presentation/place_sheet.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

const LatLon here = (latitude: 3.1478, longitude: 101.6953);

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

/// A phone whose location is [state]; asking moves it to [afterAsk].
class _Phone implements LocationRepository {
  _Phone(this.state, {this.afterAsk});

  LocationState state;
  final LocationState? afterAsk;
  int asks = 0;

  @override
  Future<LocationState> current() async => state;

  @override
  Future<LocationState> ask() async {
    asks++;
    return state = afterAsk ?? state;
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
  late _Phone phone;
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

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> show(
    WidgetTester tester, {
    LocationState location = const Located(3.1478, 101.6953),
    LocationState? afterAsk,
    PlacesRepository places = const DemoPlacesRepository(delay: Duration.zero),
    FiltersStore? store,
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
    phone = _Phone(location, afterAsk: afterAsk);
    container = ProviderContainer(
      overrides: [
        placesRepositoryProvider.overrideWithValue(places),
        locationRepositoryProvider.overrideWithValue(phone),
        if (store != null) filtersStoreProvider.overrideWithValue(store),
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
    await settle(tester);
  }

  testWidgets('one button says how many places within how far; the map '
      'shows them round you, with you as the blue dot', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.text('15 places within 2 km'), findsOneWidget);
    expect(shown!.places, hasLength(15));
    expect(shown!.radiusMetres, 2000);
    expect(shown!.you, here);
    expect(shown!.dropPin, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('You')),
      isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
    );
  });

  testWidgets('tapping a pin shows its card; Open in Google Maps opens it, '
      'and Close or a tap on the map puts the card away', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final Place first = shown!.places.first;
    shown!.onPinTap(first.id);
    await tester.pumpAndSettle();
    expect(find.text(first.name), findsOneWidget);
    expect(shown!.selectedId, first.id);
    await tester.tap(find.text('Open in Google Maps'));
    await tester.pump();
    expect(opened.single.queryParameters['query'], first.name);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text(first.name), findsNothing);
    shown!.onPinTap(first.id);
    await tester.pumpAndSettle();
    shown!.onMapTap();
    await tester.pumpAndSettle();
    expect(find.text(first.name), findsNothing);
  });

  testWidgets('the card shows a place as the sheet does: its rating, '
      'reviews and distance as three figures', (WidgetTester tester) async {
    await show(tester);
    shown!.onPinTap(shown!.places.first.id);
    await tester.pumpAndSettle();
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Away'), findsOneWidget);
  });

  testWidgets('tapping the card, or pulling it up, opens the place in full', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final Place first = shown!.places.first;
    shown!.onPinTap(first.id);
    await tester.pumpAndSettle();
    final ValueNotifier<double> cover = container.read(navCoverProvider);
    final double cardTop = tester.getTopLeft(find.text(first.name)).dy;
    await tester.tap(find.text('Rating'));
    await tester.pumpAndSettle();
    // Grown into the sheet: edge to edge, near the top, the bar pushed away.
    expect(cover.value, 1);
    expect(
      tester.getTopLeft(find.text(first.name)).dy,
      lessThan(cardTop - 300),
    );
    expect(
      tester.getRect(find.byType(PlaceSummary)).left,
      lessThan(AppSpacing.lg + AppSpacing.lg + 1),
    );
    // A tapped pin is not a spin's winner, so it offers no spin.
    expect(find.text('Spin again'), findsNothing);
    // Pulled down, it is the card again, and the bar comes back.
    await tester.drag(find.text('Rating'), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(cover.value, 0);
    expect(find.text(first.name), findsOneWidget);
    await tester.drag(find.text('Rating'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(cover.value, 1);
  });

  testWidgets('tapping another pin changes what the card shows at once, '
      'without it leaving first', (WidgetTester tester) async {
    await show(tester);
    final List<Place> places = shown!.places;
    shown!.onPinTap(places[0].id);
    await tester.pumpAndSettle();
    final Rect card = tester.getRect(find.byType(PlaceSummary));
    shown!.onPinTap(places[1].id);
    await tester.pump();
    await tester.pump(AppMotion.short);
    expect(find.text(places[1].name), findsOneWidget);
    // Still up: a shorter place makes a shorter card, but it never left.
    expect(
      (tester.getRect(find.byType(PlaceSummary).last).top - card.top).abs(),
      lessThan(80),
    );
  });

  testWidgets('a place sent from the wheel shows alone: the others are put '
      'away, the camera flies in on it and its card says it won; Show all '
      'brings the others back and keeps the card', (WidgetTester tester) async {
    await show(tester);
    final Place p = shown!.places[2];
    container.read(aloneOnMapProvider.notifier).show(p.id);
    await tester.pumpAndSettle();
    expect(shown!.aloneId, p.id);
    expect(shown!.selectedId, p.id);
    expect(shown!.focus, (latitude: p.latitude, longitude: p.longitude));
    expect(find.text('Today you are eating at'), findsOneWidget);
    expect(find.text('Only ${p.name} on the map'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(shown!.aloneId, isNull);
    expect(container.read(aloneOnMapProvider), isNull);
    expect(find.text('Today you are eating at'), findsOneWidget);
  });

  testWidgets('closing the card of a place shown alone brings the others '
      'back and the camera home', (WidgetTester tester) async {
    await show(tester);
    final int home = shown!.recentre;
    container.read(aloneOnMapProvider.notifier).show(shown!.places.first.id);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(shown!.aloneId, isNull);
    expect(shown!.recentre, home + 1);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('a card for a place the filters then take off goes too', (
    WidgetTester tester,
  ) async {
    await show(tester);
    shown!.onPinTap(shown!.places.first.id);
    await tester.pumpAndSettle();
    container
        .read(filtersProvider.notifier)
        .set(const PlaceFilters(minRating: 4.9));
    await tester.pumpAndSettle();
    expect(find.text('Open in Google Maps'), findsNothing);
    expect(find.text('No places within 2 km'), findsOneWidget);
  });

  testWidgets('3D is a toggle that starts on', (WidgetTester tester) async {
    await show(tester);
    expect(shown!.tilted, isTrue);
    await tester.tap(find.bySemanticsLabel('3D view'));
    await tester.pumpAndSettle();
    expect(shown!.tilted, isFalse);
    expect(
      tester.getSemantics(find.bySemanticsLabel('3D view')),
      isSemantics(isToggled: false, hasToggledState: true),
    );
  });

  testWidgets('Pin drops a pin where you are and says how to move it; let '
      'go elsewhere, the search follows; You goes back', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await tester.tap(find.bySemanticsLabel('Pin'));
    await settle(tester);
    expect(shown!.dropPin, here);
    expect(find.text('Drag the pin to where you want to eat'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pin')),
      isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
    );
    shown!.onPinDropped(3.16, 101.70);
    await settle(tester);
    expect(container.read(pinProvider), (latitude: 3.16, longitude: 101.70));
    expect(shown!.latitude, 3.16);
    expect(shown!.you, here);
    await tester.tap(find.bySemanticsLabel('You'));
    await settle(tester);
    expect(container.read(pinProvider), isNull);
    expect(shown!.dropPin, isNull);
    expect(shown!.latitude, here.latitude);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('opened without location it asks once; refused, it searches '
      'round a pin in the middle of the places', (WidgetTester tester) async {
    await show(tester, location: const CanAsk());
    expect(phone.asks, 1);
    await settle(tester);
    expect(phone.asks, 1);
    expect(container.read(pinProvider), here);
    expect(shown!.dropPin, here);
    expect(shown!.you, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pin')),
      isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('allowed when asked, the map centres on you', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      location: const CanAsk(),
      afterAsk: const Located(3.15, 101.70),
    );
    await settle(tester);
    expect(phone.asks, 1);
    expect(shown!.you, (latitude: 3.15, longitude: 101.70));
    expect(shown!.dropPin, isNull);
    expect(shown!.latitude, 3.15);
  });

  testWidgets('with no location and nowhere to start a map, it asks for the '
      'location instead', (WidgetTester tester) async {
    await show(tester, location: const CanAsk(), places: const _Everywhere());
    await settle(tester);
    expect(find.text('Find places near you'), findsOneWidget);
    expect(shown, isNull);
  });

  testWidgets('before the filters are chosen the map shows no places and no '
      'Spin, and the button asks what you are after', (
    WidgetTester tester,
  ) async {
    await show(tester, store: MemoryFiltersStore());
    expect(find.text("Choose what you're after"), findsOneWidget);
    expect(shown!.places, isEmpty);
    expect(find.text('Spin'), findsNothing);
  });

  group('spin', () {
    testWidgets('the camera stays still while it hops; it lands with a ring, '
        'then flies in, and only then shows the card', (
      WidgetTester tester,
    ) async {
      await show(tester);
      await tester.tap(find.text('Spin'));
      final Set<String> hops = <String>{};
      // The hops take 1.41 s in all.
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(shown!.focusTick, 0, reason: 'no camera move while hopping');
        if (shown!.selectedId case final String id) hops.add(id);
      }
      expect(hops.length, greaterThanOrEqualTo(3));
      // Landed: a ring at the winner, the camera not yet moving.
      expect(shown!.ringTick, 1);
      final String winner = shown!.selectedId!;
      final Place p = shown!.places.firstWhere((Place x) => x.id == winner);
      expect(shown!.ringAt, (latitude: p.latitude, longitude: p.longitude));
      expect(find.text('Today you are eating at'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(shown!.focusTick, 1);
      expect(shown!.focus, (latitude: p.latitude, longitude: p.longitude));
      expect(find.text('Today you are eating at'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Today you are eating at'), findsOneWidget);
      expect(find.text(p.name), findsOneWidget);
      // Putting the card away flies back out, then Spin returns.
      final int out = shown!.recentre;
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(shown!.recentre, out + 1);
      await tester.pumpAndSettle();
      expect(find.text('Spin'), findsOneWidget);
    });

    testWidgets('the winner is left alone on the map as it lands, as after '
        'See it on the map; closing its card brings the others back', (
      WidgetTester tester,
    ) async {
      await show(tester);
      await tester.tap(find.text('Spin'));
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final String winner = shown!.selectedId!;
      final Place p = shown!.places.firstWhere((Place x) => x.id == winner);
      // Landed: the others go before the camera flies in.
      expect(shown!.aloneId, winner);
      expect(shown!.focusTick, 0);
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();
      // One fly-in and one ring, not a second from showing it alone.
      expect(shown!.focusTick, 1);
      expect(shown!.ringTick, 1);
      expect(find.text('Only ${p.name} on the map'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(shown!.aloneId, isNull);
      expect(find.text('Show all'), findsNothing);
    });

    testWidgets('the card leaves before Spin comes back, so the two never '
        'cross', (WidgetTester tester) async {
      await show(tester);
      shown!.onPinTap(shown!.places.first.id);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 100));
      // Halfway out: the card is still there and Spin is not.
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(find.text('Spin'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Open in Google Maps'), findsNothing);
      expect(find.text('Spin'), findsOneWidget);
    });

    testWidgets('with Reduce Motion it lands at once, without hops', (
      WidgetTester tester,
    ) async {
      await show(tester, reduceMotion: true);
      await tester.tap(find.text('Spin'));
      await tester.pump();
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      shown!.onPinTap(other);
      await tester.pumpAndSettle();
      expect(find.text('Today you are eating at'), findsNothing);
    });
  });

  testWidgets('the map buttons keep to the right edge', (
    WidgetTester tester,
  ) async {
    // Small text leaves room in the top row, as the real font does; the
    // test font's wide letters would fill it and hide a drift.
    await show(tester, scaler: const TextScaler.linear(0.5));
    expect(
      tester.getRect(find.bySemanticsLabel('3D view')).right,
      closeTo(412 - 16, 0.5),
    );
  });

  testWidgets('with large system text the card fits and its button stays '
      'above the floating bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    shown!.onPinTap(shown!.places.first.id);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Open in Google Maps')).bottom,
      lessThanOrEqualTo(915 - AppNavMetrics.clearance(48)),
    );
  });
}
