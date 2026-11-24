import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/app/opening/opening_overlay.dart';

void main() {
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall c,
        ) async {
          calls.add(c);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  int taps = 0;
  Future<void> show(
    WidgetTester tester, {
    bool enabled = true,
    bool reduceMotion = false,
  }) async {
    taps = 0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(412, 915),
          disableAnimations: reduceMotion,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: OpeningOverlay(
            enabled: enabled,
            child: Center(
              child: GestureDetector(
                onTap: () => taps++,
                child: const Text('The app'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder painter() => find.byWidgetPredicate(
    (Widget w) => w is CustomPaint && w.painter is OpeningPainter,
  );
  double reels(WidgetTester tester) =>
      (tester.widget<CustomPaint>(painter()).painter! as OpeningPainter).t;

  testWidgets('off, the app shows at once with nothing over it', (
    WidgetTester tester,
  ) async {
    await show(tester, enabled: false);
    expect(painter(), findsNothing);
    await tester.tap(find.text('The app'));
    expect(taps, 1);
  });

  testWidgets('the reels roll and stop before the screen rolls on, the app '
      'cannot be tapped until the opening has gone, and the bars go back to '
      'dark icons', (WidgetTester tester) async {
    await show(tester);
    expect(painter(), findsOneWidget);
    expect(reels(tester), 0);
    await tester.tap(find.text('The app'), warnIfMissed: false);
    expect(taps, 0);

    // It starts on the frame after the first, once the screen has a size.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(reels(tester), inExclusiveRange(0, 1));
    // The reels have stopped; the screen has not moved yet.
    await tester.pump(const Duration(milliseconds: 600));
    expect(reels(tester), 1);
    expect(tester.getTopLeft(painter()).dy, 0);
    expect(tester.getCenter(find.text('The app')).dy, 915 / 2);

    // Rolling on: the opening goes up and the app comes up from below.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(painter()).dy, lessThan(0));
    expect(tester.getCenter(find.text('The app')).dy, greaterThan(915 / 2));

    await tester.pumpAndSettle();
    expect(painter(), findsNothing);
    expect(tester.getCenter(find.text('The app')).dy, 915 / 2);
    await tester.tap(find.text('The app'));
    expect(taps, 1);
    final List<Map<Object?, Object?>> styles = <Map<Object?, Object?>>[
      for (final MethodCall c in calls)
        if (c.method == 'SystemChrome.setSystemUIOverlayStyle')
          c.arguments as Map<Object?, Object?>,
    ];
    expect(styles.first['statusBarIconBrightness'], 'Brightness.light');
    expect(styles.last['statusBarIconBrightness'], 'Brightness.dark');
  });

  testWidgets('with Reduce Motion the reels show stopped and the opening '
      'fades in a quarter of a second', (WidgetTester tester) async {
    await show(tester, reduceMotion: true);
    await tester.pump();
    expect(reels(tester), 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(painter(), findsNothing);
  });
}
