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
}
