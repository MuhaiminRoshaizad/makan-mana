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
  @override
  Future<LocationState> current() async => const CanAsk();

  @override
  Future<LocationState> ask() async => const CanAsk();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
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

  Future<void> show(
    WidgetTester tester, {
    bool located = true,
    TextScaler scaler = TextScaler.noScaling,
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
        placesRepositoryProvider.overrideWithValue(
          const DemoPlacesRepository(delay: Duration.zero),
        ),
        if (located)
          searchAreaProvider.overrideWith((_) async => area)
        else
          locationRepositoryProvider.overrideWithValue(_NotShared()),
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
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: const Scaffold(body: MapScreen()),
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

  testWidgets('without a location there is no map, only the way to share '
      'it', (WidgetTester tester) async {
    await show(tester, located: false);
    expect(find.text('Find places near you'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(shown, isNull);
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
}
