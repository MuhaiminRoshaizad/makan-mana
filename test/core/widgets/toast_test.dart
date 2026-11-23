import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/widgets/toast.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    void Function(BuildContext) show,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => show(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a toast shows at the top and leaves by itself', (
    WidgetTester tester,
  ) async {
    await open(tester, (BuildContext c) => showToast(c, 'Radius set to 2 km'));

    expect(find.text('Radius set to 2 km'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Radius set to 2 km')).dy,
      lessThan(
        tester.view.physicalSize.height / tester.view.devicePixelRatio / 4,
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Radius set to 2 km'), findsNothing);
  });

  testWidgets('a new toast replaces the one showing, which reports it has '
      'gone', (WidgetTester tester) async {
    int n = 0;
    int hidden = 0;
    await open(
      tester,
      (BuildContext c) =>
          showToast(c, 'Toast ${++n}', onHidden: () => hidden++),
    );
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);
    expect(hidden, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(hidden, 2);
  });

  testWidgets('the action runs and closes the toast', (
    WidgetTester tester,
  ) async {
    bool undone = false;
    await open(
      tester,
      (BuildContext c) => showToast(
        c,
        'Filters reset',
        actionLabel: 'Undo',
        onAction: () => undone = true,
      ),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.text('Filters reset'), findsNothing);
  });

  testWidgets('an upward flick sends it away early', (
    WidgetTester tester,
  ) async {
    await open(tester, (BuildContext c) => showToast(c, 'Pin dropped'));

    await tester.fling(find.text('Pin dropped'), const Offset(0, -60), 800);
    await tester.pumpAndSettle();

    expect(find.text('Pin dropped'), findsNothing);
  });
}
