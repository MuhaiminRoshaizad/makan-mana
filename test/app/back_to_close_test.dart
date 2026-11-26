import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/app/app.dart';
import 'package:makan_mana/app/floating_nav.dart';
import 'package:makan_mana/app/tab_root.dart';
import 'package:makan_mana/core/widgets/toast.dart';
import 'package:makan_mana/features/places/presentation/places_providers.dart';

void main() {
  int closes = 0;
  final List<bool> handlesBack = <bool>[];

  setUp(() {
    closes = 0;
    handlesBack.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemNavigator.pop') closes++;
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            handlesBack.add(call.arguments as bool);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  const String hint = BackToClose.hint;

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MakanManaApp()));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  int tab(WidgetTester tester) =>
      tester.widget<FloatingNav>(find.byType(FloatingNav)).index;

  testWidgets('a place sent to the map from the Spin tab opens the Map tab', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    expect(tab(tester), 0);
    ProviderScope.containerOf(
      tester.element(find.byType(FloatingNav)),
    ).read(aloneOnMapProvider.notifier).show('anything');
    await tester.pumpAndSettle();
    expect(tab(tester), 1);
  });

  testWidgets('Back on Map goes to Spin; on Spin it asks once, and a second '
      'Back closes the app', (WidgetTester tester) async {
    await openApp(tester);
    await tester.tap(find.bySemanticsLabel('Map').last);
    await tester.pumpAndSettle();
    expect(tab(tester), 1);

    await back(tester);
    expect(tab(tester), 0);
    expect(find.text(hint), findsNothing);
    expect(closes, 0);

    await back(tester);
    expect(find.text(hint), findsOneWidget);
    // A hint, not a success: no tick.
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    expect(closes, 0);

    await back(tester);
    expect(closes, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('the hint shows for 2 s; once it has gone, Back asks again, '
      'every time', (WidgetTester tester) async {
    await openApp(tester);
    for (int round = 0; round < 3; round++) {
      await back(tester);
      expect(find.text(hint), findsOneWidget, reason: 'round $round');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text(hint), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing);
    }
    expect(closes, 0);
  });

  testWidgets('another message replacing the hint disarms it', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await back(tester);
    expect(find.text(hint), findsOneWidget);
    showToast(tester.element(find.byType(FloatingNav)), 'Radius set to 2 km');
    await tester.pump();
    await back(tester);
    expect(closes, 0);
    expect(find.text(hint), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('opening Map while the hint shows takes it down', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await back(tester);
    expect(find.text(hint), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Map').last);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
    // Back from Map goes to Spin, then asks again rather than closing.
    await back(tester);
    expect(tab(tester), 0);
    await back(tester);
    expect(closes, 0);
    expect(find.text(hint), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('the app tells Android it handles Back on both tabs, so Android '
      'never closes it without the hint', (WidgetTester tester) async {
    // On Android 14 and later the app says in advance whether it handles
    // Back; that signal is only sent once the app is resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await openApp(tester);
    expect(handlesBack, isNotEmpty);
    expect(handlesBack, everyElement(isTrue));

    await tester.tap(find.bySemanticsLabel('Map').last);
    await tester.pumpAndSettle();
    await back(tester);
    await tester.pumpAndSettle();
    expect(handlesBack, everyElement(isTrue));
  });
}
