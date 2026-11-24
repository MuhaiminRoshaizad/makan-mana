import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/theme/wedge_colors.dart';
import 'package:makan_mana/features/spin/presentation/wheel_painter.dart';

void main() {
  test('neighbouring wedges never share a colour, even where the colours '
      'wrap round', () {
    for (int n = 2; n <= 20; n++) {
      for (int i = 0; i < n; i++) {
        expect(
          wedgeColorFor(i, n).fill,
          isNot(wedgeColorFor((i + 1) % n, n).fill),
          reason: 'wedges $i and ${(i + 1) % n} of $n',
        );
      }
    }
  });

  test('the wheel is redrawn only when its places or the win flash change', () {
    final WheelPainter a = WheelPainter(names: <String>['A', 'B']);
    expect(a.shouldRepaint(WheelPainter(names: <String>['A', 'B'])), isFalse);
    expect(a.shouldRepaint(WheelPainter(names: <String>['A', 'C'])), isTrue);
    expect(
      a.shouldRepaint(
        WheelPainter(names: <String>['A', 'B'], won: 1, flash: 0.5),
      ),
      isTrue,
    );
  });

  testWidgets('a long name is cut short with an ellipsis instead of running '
      'off the wheel', (WidgetTester tester) async {
    await tester.pumpWidget(
      Center(
        child: CustomPaint(
          size: const Size.square(370),
          painter: WheelPainter(
            names: <String>[
              'Restoran Nasi Kandar Pelita Sri Petaling Utama',
              'Warung Soto',
              'Kopitiam Lama',
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
