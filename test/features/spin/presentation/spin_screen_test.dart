import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/features/location/domain/location_repository.dart';
import 'package:makan_mana/features/location/presentation/location_providers.dart';
import 'package:makan_mana/features/places/data/bundled_places_repository.dart';
import 'package:makan_mana/features/places/data/demo_places_repository.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/place_filters.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';
import 'package:makan_mana/features/spin/presentation/spin_screen.dart';
import 'package:makan_mana/features/spin/presentation/spin_wheel.dart';

const SearchArea area = SearchArea(
  latitude: 3.1478,
  longitude: 101.6953,
  radiusMetres: 2000,
);

/// Answers from the demo places, or fails, after [delay].
class _Repo implements PlacesRepository {
  @override
  bool get knowsOpeningHours => true;

  _Repo({this.delay = Duration.zero, this.fail = false});
  final Duration delay;
  bool fail;
  int searches = 0;

  @override
  Future<List<Place>> nearby(SearchArea a) async {
    searches++;
    await Future<void>.delayed(delay);
    if (fail) throw Exception('no network');
    return const DemoPlacesRepository(delay: Duration.zero).nearby(a);
  }
}

/// A phone whose location is [state]; asking moves it to [afterAsk].
class _Location implements LocationRepository {
  _Location(this.state, {this.afterAsk});
  LocationState state;
  final LocationState? afterAsk;
  int asks = 0;
  int appSettings = 0;
  int locationSettings = 0;

  @override
  Future<LocationState> current() async => state;

  @override
  Future<LocationState> ask() async {
    asks++;
    return state = afterAsk ?? state;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => locationSettings++;
}

/// A build with no places file in it.
class _NoFile implements PlacesRepository {
  @override
  bool get knowsOpeningHours => true;

  @override
  Future<List<Place>> nearby(SearchArea a) => throw const NoBundledPlaces();
}

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
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> show(
    WidgetTester tester, {
    PlacesRepository? repo,
    PlaceFilters? filters,
    _Location? location,
    TextScaler scaler = TextScaler.noScaling,
    Size size = const Size(412, 915),
    EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 48),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesRepositoryProvider.overrideWithValue(repo ?? _Repo()),
          // With a fake phone, the area comes from its location.
          if (location != null)
            locationRepositoryProvider.overrideWithValue(location)
          else
            searchAreaProvider.overrideWith((_) async => area),
          if (filters != null)
            filtersProvider.overrideWithBuild((_, _) => filters),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: scaler,
              padding: padding,
            ),
            child: const Scaffold(body: SpinScreen()),
          ),
        ),
      ),
    );
  }

  /// Lets the zero-delay fake search answer and the screen redraw.
  Future<void> loaded(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('a quick answer shows no placeholder; a slow one shows the '
      'skeleton after 300 ms, then the wheel', (WidgetTester tester) async {
    await show(tester, repo: _Repo(delay: const Duration(seconds: 1)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('Finding places nearby'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('Finding places nearby'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.bySemanticsLabel('Finding places nearby'), findsNothing);
    expect(find.byType(SpinWheel), findsOneWidget);
  });

  testWidgets('the wheel holds the places that pass the filters, with the '
      'one under the arrow named above it', (WidgetTester tester) async {
    await show(tester);
    await loaded(tester);
    expect(find.text('15 places on the wheel'), findsOneWidget);
    expect(find.text('Throw the wheel, or tap Spin'), findsOneWidget);
    final SpinWheel wheel = tester.widget<SpinWheel>(find.byType(SpinWheel));
    expect(wheel.names, hasLength(15));
    // The name above the wheel is one of the places on it.
    expect(
      wheel.names.where((String n) => find.text(n).evaluate().isNotEmpty),
      hasLength(1),
    );
  });

  testWidgets('when nothing passes the filters, it says so and how to fix '
      'it', (WidgetTester tester) async {
    await show(
      tester,
      filters: const PlaceFilters(minRating: 4.5, minReviews: 500),
    );
    await loaded(tester);
    expect(find.text('Nothing nearby passes these filters'), findsOneWidget);
    expect(find.byType(SpinWheel), findsNothing);

    // The way out is right there.
    await tester.tap(find.text('Edit filters'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum rating'), findsOneWidget);
  });

  testWidgets('a failed search offers Try again, which searches again', (
    WidgetTester tester,
  ) async {
    final _Repo repo = _Repo(fail: true);
    await show(tester, repo: repo);
    await loaded(tester);
    expect(find.text("Couldn't find places nearby"), findsOneWidget);

    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await loaded(tester);
    expect(repo.searches, 2);
    expect(find.byType(SpinWheel), findsOneWidget);
  });

  testWidgets('a build with no places file says so, rather than inventing '
      'any', (WidgetTester tester) async {
    await show(tester, repo: _NoFile());
    await loaded(tester);
    expect(find.text('No places in this build'), findsOneWidget);
    expect(find.byType(SpinWheel), findsNothing);
  });

  group('location', () {
    testWidgets('nothing is asked at launch; Use my location asks, and the '
        'wheel fills once it is shared', (WidgetTester tester) async {
      final _Location phone = _Location(
        const CanAsk(),
        afterAsk: const Located(3.1478, 101.6953),
      );
      await show(tester, location: phone);
      await loaded(tester);
      expect(phone.asks, 0);
      expect(find.text('Find places near you'), findsOneWidget);
      await tester.tap(find.text('Use my location'));
      await loaded(tester);
      expect(phone.asks, 1);
      expect(find.byType(SpinWheel), findsOneWidget);
    });

    testWidgets('refused once, it can still ask; refused again stays on the '
        'card', (WidgetTester tester) async {
      final _Location phone = _Location(const CanAsk());
      await show(tester, location: phone);
      await loaded(tester);
      await tester.tap(find.text('Use my location'));
      await loaded(tester);
      expect(phone.asks, 1);
      expect(find.text('Find places near you'), findsOneWidget);
    });

    testWidgets('refused for good, the button opens Settings', (
      WidgetTester tester,
    ) async {
      final _Location phone = _Location(const RefusedForGood());
      await show(tester, location: phone);
      await loaded(tester);
      expect(find.text('Location is off for Makan Mana'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      await loaded(tester);
      expect(phone.appSettings, 1);
      expect(phone.asks, 0);
    });

    testWidgets('location switched off opens the location settings, and '
        'coming back with it on fills the wheel', (WidgetTester tester) async {
      final _Location phone = _Location(const LocationOff());
      await show(tester, location: phone);
      await loaded(tester);
      expect(find.text('Location is turned off'), findsOneWidget);
      await tester.tap(find.text('Turn on location'));
      await loaded(tester);
      expect(phone.locationSettings, 1);
      phone.state = const Located(3.1478, 101.6953);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await loaded(tester);
      expect(find.byType(SpinWheel), findsOneWidget);
    });

    testWidgets('no position offers to try again', (WidgetTester tester) async {
      final _Location phone = _Location(const PositionUnavailable());
      await show(tester, location: phone);
      await loaded(tester);
      expect(find.text("Couldn't tell where you are"), findsOneWidget);
      phone.state = const Located(3.1478, 101.6953);
      await tester.tap(find.text('Try again'));
      await loaded(tester);
      expect(find.byType(SpinWheel), findsOneWidget);
    });
  });

  testWidgets('large system text fits, and the wheel ends above the '
      'floating bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    await loaded(tester);
    expect(tester.takeException(), isNull);
    final Rect wheel = tester.getRect(find.byType(SpinWheel));
    // 915 minus the 48 dp system bar, the 60 dp tab bar and its 12 dp gap.
    expect(wheel.bottom, lessThanOrEqualTo(915 - 48 - 60 - 12));
    expect(wheel.left, greaterThanOrEqualTo(0));
    expect(wheel.right, lessThanOrEqualTo(412));
  });

  testWidgets('the hint goes once the wheel has been spun', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await loaded(tester);
    await tester.tap(find.bySemanticsLabel('Spin'));
    await tester.pump(const Duration(milliseconds: 500));
    final AnimatedOpacity hint = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Throw the wheel, or tap Spin'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(hint.opacity, 0);
    // Let the spin finish so no timers outlive the test.
    for (int i = 0; i < 12 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    unawaited(Future<void>.value());
  });

  testWidgets('when the wheel lands, the result names the same place, and '
      'Spin again closes it and spins', (WidgetTester tester) async {
    await show(tester);
    await loaded(tester);
    final SpinWheel wheel = tester.widget<SpinWheel>(find.byType(SpinWheel));
    await tester.tap(find.bySemanticsLabel('Spin'));
    for (int i = 0; i < 12 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Today you are eating at').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.text('Today you are eating at'), findsOneWidget);
    // The name above the wheel and the result agree.
    final String shown = wheel.names.firstWhere(
      (String n) => find.text(n).evaluate().length == 2,
    );
    expect(find.text(shown), findsNWidgets(2));

    await tester.tap(find.text('Spin again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Today you are eating at'), findsNothing);
    expect(find.bySemanticsLabel('Spinning'), findsOneWidget);
    for (int i = 0; i < 12 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  });

  group('on its side', () {
    const Size wide = Size(915, 412);
    // Landscape with three-button navigation: the buttons move to the side.
    const EdgeInsets bars = EdgeInsets.only(top: 24, right: 48);

    testWidgets('the name sits beside the wheel, and both stay above the '
        'floating bar', (WidgetTester tester) async {
      await show(tester, size: wide, padding: bars);
      await loaded(tester);
      expect(tester.takeException(), isNull);
      final Rect wheel = tester.getRect(find.byType(SpinWheel));
      final Rect count = tester.getRect(find.text('15 places on the wheel'));
      expect(count.right, lessThan(wheel.left));
      // 412 minus the floating bar's 60 dp and its 12 dp gap.
      expect(wheel.bottom, lessThanOrEqualTo(412 - 60 - 12));
      expect(wheel.right, lessThanOrEqualTo(915 - 48));
      expect(wheel.height, greaterThan(200));
    });

    testWidgets('large system text still fits', (WidgetTester tester) async {
      await show(
        tester,
        size: wide,
        padding: bars,
        scaler: const _DampedScaler(),
      );
      await loaded(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the skeleton puts the wheel where the wheel will be', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        size: wide,
        padding: bars,
        repo: _Repo(delay: const Duration(seconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final Rect bone = tester.getRect(
        find.bySemanticsLabel('Finding places nearby'),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final Rect wheel = tester.getRect(find.byType(SpinWheel));
      // The wheel's disc starts under the arrow's room.
      expect(bone.left, closeTo(wheel.left, 0.5));
      expect(bone.bottom, closeTo(wheel.bottom, 0.5));
      expect(bone.width, closeTo(wheel.width, 0.5));
    });
  });
}
