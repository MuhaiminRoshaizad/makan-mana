import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/app/app.dart';
import 'package:makan_mana/app/floating_nav.dart';
import 'package:makan_mana/core/theme/app_tokens.dart';

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
  Future<void> openApp(WidgetTester tester, {TextScaler? scaler}) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // A three-button navigation bar, 48 dp tall.
    tester.view.padding = tester.view.viewPadding = FakeViewPadding(
      top: 24 * tester.view.devicePixelRatio,
      bottom: 48 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      ProviderScope(
        child: scaler == null
            ? const MakanManaApp()
            : MediaQuery.withClampedTextScaling(
                child: Builder(
                  builder: (BuildContext context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: scaler),
                    child: const MakanManaApp(),
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a tab opens it and moves the thumb under it', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    expect(find.text('Makan Mana'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Map').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingNav>(find.byType(FloatingNav)).index, 1);
    expect(find.text('Makan Mana'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Map').last),
      isSemantics(isSelected: true, isButton: true),
    );

    await tester.tap(find.bySemanticsLabel('Spin').last);
    await tester.pumpAndSettle();
    expect(find.text('Makan Mana'), findsOneWidget);
  });

  testWidgets('the bar floats above a 48 dp navigation bar, centred', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    final Rect bar = tester.getRect(find.byType(FloatingNav));
    expect(bar.bottom, 915 - 48 - AppNavMetrics.bottomGap);
    expect(bar.center.dx, closeTo(412 / 2, 0.5));
    expect(bar.height, AppNavMetrics.height);
  });

  testWidgets('each tab is at least 48 dp tall to tap', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    for (final String label in <String>['Spin', 'Map']) {
      final Size s = tester.getSize(find.bySemanticsLabel(label).last);
      expect(s.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('large system text does not overflow the bar', (
    WidgetTester tester,
  ) async {
    await openApp(tester, scaler: const _DampedScaler());
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FloatingNav)).height,
      AppNavMetrics.height,
    );
  });

  test('the thumb stays inside the capsule when the spring overshoots', () {
    expect(thumbLeft(-0.2, 2), 0);
    expect(thumbLeft(1.3, 2), AppNavMetrics.tabWidth);
    expect(thumbLeft(0.5, 2), AppNavMetrics.tabWidth / 2);
  });
}
