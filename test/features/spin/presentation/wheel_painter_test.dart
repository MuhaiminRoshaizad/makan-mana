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

  test('the wheel is redrawn when it turns, its places change or the win '
      'flash changes, and not otherwise', () {
    final List<TextPainter> labels = <TextPainter>[];
    WheelPainter at(double turn, {int? won, List<TextPainter>? names}) =>
        WheelPainter(
          labels: names ?? labels,
          turn: turn,
          labelRimGap: 30,
          won: won,
        );
    expect(at(1).shouldRepaint(at(1)), isFalse);
    expect(at(1).shouldRepaint(at(1.1)), isTrue);
    expect(at(1).shouldRepaint(at(1, won: 2)), isTrue);
    expect(at(1).shouldRepaint(at(1, names: <TextPainter>[])), isTrue);
  });

  test('the wheel is a big circle whose top meets the arrow near the top '
      'of its box', () {
    final ArcGeometry g = ArcGeometry(const Size(412, 500));
    expect(g.radius, closeTo(720, 1e-9));
    expect(g.centre.dx, 206);
    expect(g.centre.dy - g.radius, ArcGeometry.rimTop);
  });
}
