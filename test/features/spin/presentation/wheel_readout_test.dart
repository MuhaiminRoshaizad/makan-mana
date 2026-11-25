import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/spin/presentation/wheel_readout.dart';

const String longest =
    'The Memory Cafe | Taman Lagenda | Padang Serai | Kulim | Kedah | '
    'Chicken Chop | Kambing Grill | Shellout | Dessert';

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
  Future<void> show(
    WidgetTester tester,
    String name, {
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(412, 915), textScaler: scaler),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 372,
                height: 300,
                child: WheelReadout(
                  count: '20 places on the wheel',
                  name: name,
                  detail: '4.7 stars · 126 m away',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect count(WidgetTester tester) =>
      tester.getRect(find.text('20 places on the wheel'));
  Rect detail(WidgetTester tester) =>
      tester.getRect(find.text('4.7 stars · 126 m away'));
  Text name(WidgetTester tester, String n) => tester.widget<Text>(find.text(n));

  testWidgets('the count and the rating line stay put whether the name '
      'takes one line or many', (WidgetTester tester) async {
    await show(tester, 'Kedai Mamak');
    final Rect countBefore = count(tester);
    final Rect detailBefore = detail(tester);
    await show(tester, 'OLDTOWN White Coffee @ Bertam Perdana');
    expect(count(tester), countBefore);
    expect(detail(tester), detailBefore);
    await show(tester, longest);
    expect(count(tester), countBefore);
    expect(detail(tester), detailBefore);
  });

  testWidgets('a short name is large; a very long one gets smaller and stays '
      'between the two lines', (WidgetTester tester) async {
    await show(tester, 'Kedai Mamak');
    expect(name(tester, 'Kedai Mamak').style!.fontSize, FittedName.maxSize);

    await show(tester, longest);
    expect(tester.takeException(), isNull);
    expect(name(tester, longest).style!.fontSize, lessThan(FittedName.maxSize));
    final Rect n = tester.getRect(find.text(longest));
    expect(n.top, greaterThanOrEqualTo(count(tester).bottom));
    expect(n.bottom, lessThanOrEqualTo(detail(tester).top));
  });

  testWidgets('large system text still fits, with the name kept between the '
      'two lines', (WidgetTester tester) async {
    await show(tester, longest, scaler: const _DampedScaler());
    expect(tester.takeException(), isNull);
    final Rect n = tester.getRect(find.text(longest));
    expect(n.top, greaterThanOrEqualTo(count(tester).bottom));
    expect(n.bottom, lessThanOrEqualTo(detail(tester).top));
    expect(detail(tester).bottom, lessThanOrEqualTo(300));
  });
}
