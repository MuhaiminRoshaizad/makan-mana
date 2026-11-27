import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/core/widgets/app_sheet.dart';

void main() {
  testWidgets('a sheet ends its last button above a 48 dp navigation bar, '
      'over everything in the root navigator', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.padding = tester.view.viewPadding = FakeViewPadding(
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final GlobalKey<NavigatorState> inner = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          // A nested navigator, like a tab's.
          body: Navigator(
            key: inner,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (BuildContext c) => Center(
                child: TextButton(
                  onPressed: () => showAppSheet<void>(
                    c,
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Last'),
                        ),
                      ],
                    ),
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

    expect(
      tester.getRect(find.text('Last')).bottom,
      lessThanOrEqualTo(915 - 48),
    );
    // Opened on the root navigator, not the nested one.
    expect(inner.currentState!.canPop(), isFalse);
  });

  group('pulling down on the content', () {
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          scrollBehavior: const AppScrollBehavior(),
          home: Builder(
            builder: (BuildContext c) => Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  c,
                  // Long enough to scroll, as the filters are on a small
                  // phone or with large text.
                  builder: (_) => SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < 40; i++)
                          SizedBox(height: 48, child: Text('Row $i')),
                      ],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> pull(WidgetTester tester, double by) async {
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.text('Row 2')),
      );
      for (double moved = 0; moved < by; moved += 10) {
        await g.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('at the top, a long pull closes the sheet, as the shop card '
        'does', (WidgetTester tester) async {
      await open(tester);
      await pull(tester, 300);
      expect(find.text('Row 0'), findsNothing);
    });

    Rect sheet(WidgetTester tester) => tester.getRect(
      find
          .ancestor(of: find.text('Row 0'), matching: find.byType(Material))
          .first,
    );

    double backdrop(WidgetTester tester) =>
        tester.widget<ColoredBox>(find.byKey(appSheetScrimKey)).color.a;

    testWidgets('the whole sheet follows a pull on its content, and the '
        'backdrop lightens with it', (WidgetTester tester) async {
      await open(tester);
      final double top = sheet(tester).top;
      final double dark = backdrop(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.text('Row 2')),
      );
      for (int i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(sheet(tester).top, greaterThan(top + 60));
      expect(backdrop(tester), lessThan(dark));
      await g.up();
      await tester.pumpAndSettle();
      expect(sheet(tester).top, moreOrLessEquals(top, epsilon: 0.5));
    });

    testWidgets('a long sheet stops below the status bar', (
      WidgetTester tester,
    ) async {
      tester.view.padding = tester.view.viewPadding = FakeViewPadding(
        top: 24 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await open(tester);
      expect(sheet(tester).top, greaterThanOrEqualTo(24));
    });

    testWidgets('a short pull springs back and the sheet stays', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final double top = tester.getTopLeft(find.text('Row 0')).dy;
      await pull(tester, 40);
      expect(find.text('Row 0'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Row 0')).dy, top);
    });

    testWidgets('content that fits closes from a pull on it too', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          scrollBehavior: const AppScrollBehavior(),
          home: Builder(
            builder: (BuildContext c) => Center(
              child: TextButton(
                onPressed: () => showAppSheet<void>(
                  c,
                  builder: (_) => const SingleChildScrollView(
                    child: SizedBox(height: 200, child: Text('Short')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Short'), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.text('Short'), findsNothing);
    });
  });
}
