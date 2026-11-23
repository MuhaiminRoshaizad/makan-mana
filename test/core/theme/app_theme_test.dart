import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/app_theme.dart';
import 'package:makan_mana/core/theme/app_tokens.dart';

void main() {
  test('the theme uses Plus Jakarta Sans, no ripple and iOS page slides', () {
    final ThemeData t = buildAppTheme();
    expect(t.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    expect(t.splashFactory, NoSplash.splashFactory);
    for (final TargetPlatform p in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      expect(
        t.pageTransitionsTheme.builders[p],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
  });

  test('the chrome is ink on soft white, with no other colour', () {
    final ColorScheme cs = buildAppTheme().colorScheme;
    expect(cs.brightness, Brightness.light);
    expect(cs.primary, AppColors.ink);
    expect(cs.onPrimary, AppColors.surface);
    expect(cs.surface, AppColors.background);
  });

  testWidgets('pushed pages show the iOS back chevron', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (BuildContext c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    Scaffold(appBar: AppBar(title: const Text('x'))),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('scrolling bounces and draws no overscroll stretch', (
    WidgetTester tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );
    const AppScrollBehavior behavior = AppScrollBehavior();
    expect(behavior.getScrollPhysics(ctx), isA<BouncingScrollPhysics>());
    const Widget child = SizedBox();
    expect(
      behavior.buildOverscrollIndicator(
        ctx,
        child,
        ScrollableDetails.vertical(controller: ScrollController()),
      ),
      same(child),
    );
  });
}
