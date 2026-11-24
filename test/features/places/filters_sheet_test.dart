import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/features/places/data/bundled_places_repository.dart';
import 'package:makan_mana/features/places/data/demo_places_repository.dart';
import 'package:makan_mana/features/places/domain/place.dart';
import 'package:makan_mana/features/places/domain/places_repository.dart';
import 'package:makan_mana/features/places/presentation/filters_button.dart';
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

/// Shows the wheel's count beside the Filters button.
class _Count extends ConsumerWidget {
  const _Count();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Place>? on = ref.watch(wheelPlacesProvider).value;
    return Text('on wheel: ${on?.length}');
  }
}

void main() {
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesRepositoryProvider.overrideWithValue(
            const DemoPlacesRepository(delay: Duration.zero),
          ),
          searchAreaProvider.overrideWithValue(
            const SearchArea(latitude: 0, longitude: 0, radiusMetres: 2000),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[FiltersButton(), _Count()],
              ),
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(FiltersButton));
    await tester.pumpAndSettle();
  }

  testWidgets('the button counts the filters in use', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.bySemanticsLabel('Filters, 3 in use'), findsOneWidget);
    expect(find.text('on wheel: 14'), findsOneWidget);
  });

  testWidgets('choosing filters counts the matches live and applies them '
      'with Show', (WidgetTester tester) async {
    await show(tester);
    await open(tester);
    expect(find.text('Show 14 places'), findsOneWidget);

    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    // Rating no longer filters: the three rated under 4.0 come back.
    expect(find.text('Show 17 places'), findsOneWidget);
    expect(find.text('on wheel: 14'), findsOneWidget);

    await tester.tap(find.text('Show 17 places'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum rating'), findsNothing);
    expect(find.text('on wheel: 17'), findsOneWidget);
    expect(find.bySemanticsLabel('Filters, 2 in use'), findsOneWidget);
  });

  testWidgets('filters nothing passes say so and offer no way to apply', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await open(tester);
    await tester.tap(find.text('4.5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('500+'));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('Lower the rating'), findsOneWidget);
  });

  testWidgets('a sheet closed without Show changes nothing', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await open(tester);
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    // Tap above the sheet to close it.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    expect(find.text('on wheel: 14'), findsOneWidget);
    expect(find.bySemanticsLabel('Filters, 3 in use'), findsOneWidget);
  });

  testWidgets('Reset is off at the defaults and brings them back', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await open(tester);
    TextButton reset() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reset'));
    expect(reset().onPressed, isNull);

    await tester.tap(find.text('Open now'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
    expect(reset().onPressed, isNotNull);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
    );
    expect(find.text('Show 14 places'), findsOneWidget);
  });

  testWidgets('with large system text the sheet fits and Show stays above '
      'the navigation bar', (WidgetTester tester) async {
    await show(tester, scaler: const _DampedScaler());
    await open(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.text('Minimum rating'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Show 14 places')).bottom,
      lessThanOrEqualTo(915 - 48),
    );
  });

  testWidgets('with a places list that has no opening hours, Open now is not '
      'offered', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesRepositoryProvider.overrideWithValue(
            BundledPlacesRepository(load: () async => '{"places": {}}'),
          ),
          searchAreaProvider.overrideWithValue(
            const SearchArea(latitude: 0, longitude: 0, radiusMetres: 2000),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: Center(child: FiltersButton())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // Rating and reviews only: two filters in use.
    expect(find.bySemanticsLabel('Filters, 2 in use'), findsOneWidget);
    await tester.tap(find.byType(FiltersButton));
    await tester.pumpAndSettle();
    expect(find.text('Minimum rating'), findsOneWidget);
    expect(find.text('Open now'), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
  });
}
