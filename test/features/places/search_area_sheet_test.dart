import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/features/location/domain/location_repository.dart';
import 'package:makan_mana/features/location/presentation/location_providers.dart';
import 'package:makan_mana/features/places/data/demo_places_repository.dart';
import 'package:makan_mana/features/places/presentation/area_button.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

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

/// A phone that is always at the same spot, counting each reading.
class _Here implements LocationRepository {
  int reads = 0;

  @override
  Future<LocationState> current() async {
    reads++;
    return const Located(3.1478, 101.6953);
  }

  @override
  Future<LocationState> ask() => current();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  late _Here phone;
  late ProviderContainer container;

  Future<void> show(
    WidgetTester tester, {
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = tester.view.viewPadding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    phone = _Here();
    container = ProviderContainer(
      overrides: [
        placesRepositoryProvider.overrideWithValue(
          const DemoPlacesRepository(delay: Duration.zero),
        ),
        locationRepositoryProvider.overrideWithValue(phone),
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
          home: const Scaffold(body: Center(child: AreaButton())),
        ),
      ),
    );
    // Read the location once, as the Spin tab does on opening.
    await container.read(locationProvider.future);
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(AreaButton));
    await tester.pumpAndSettle();
  }

  testWidgets('the button says how far the search reaches', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.text('Within 2 km of you'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Search area, Within 2 km of you'),
      findsOneWidget,
    );
  });

  testWidgets('the radius reads in kilometres, and Search applies it and '
      'reads the location again', (WidgetTester tester) async {
    await show(tester);
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Radius')),
      isSemantics(
        label: 'Radius',
        value: '2 km',
        increasedValue: '3 km',
        decreasedValue: '1 km',
      ),
    );
    // Two steps up: 2 km, 3 km, 5 km.
    final Rect track = tester.getRect(find.byType(Slider));
    await tester.tapAt(
      Offset(track.left + track.width * 4 / 6, track.center.dy),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 km'), findsOneWidget);
    final int before = phone.reads;
    await tester.tap(find.text('Search this area'));
    await tester.pumpAndSettle();
    expect(container.read(radiusProvider), 5000);
    expect(phone.reads, before + 1);
    expect(find.text('Within 5 km of you'), findsOneWidget);
  });

  testWidgets('a sheet closed without Search changes nothing', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await open(tester);
    final Rect track = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(track.right - 4, track.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('15 km'), findsWidgets);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(container.read(radiusProvider), 2000);
    expect(find.text('Within 2 km of you'), findsOneWidget);
  });

  testWidgets('with large system text the sheet fits and Search stays above '
      'the navigation bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    await open(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.text('Search area'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Search this area')).bottom,
      lessThanOrEqualTo(915 - 48),
    );
  });
}
