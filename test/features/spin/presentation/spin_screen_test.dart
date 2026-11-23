import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
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
    bool demo = true,
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (demo) ...[
            placesRepositoryProvider.overrideWithValue(repo ?? _Repo()),
            searchAreaProvider.overrideWithValue(area),
          ],
          if (filters != null)
            filtersProvider.overrideWithBuild((_, _) => filters),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(412, 915),
              textScaler: scaler,
              padding: const EdgeInsets.only(top: 24, bottom: 48),
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
    expect(find.text('14 places on the wheel'), findsOneWidget);
    expect(find.text('Throw the wheel, or tap Spin'), findsOneWidget);
    final SpinWheel wheel = tester.widget<SpinWheel>(find.byType(SpinWheel));
    expect(wheel.names, hasLength(14));
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

  testWidgets('outside the demo build it says finding places is not set up, '
      'rather than inventing any', (WidgetTester tester) async {
    await show(tester, demo: false);
    await loaded(tester);
    expect(find.text('Finding places is not set up yet'), findsOneWidget);
    expect(find.byType(SpinWheel), findsNothing);
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
}
