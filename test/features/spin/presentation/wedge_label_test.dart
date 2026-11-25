import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/spin/presentation/wedge_label.dart';

/// The longest name in the scraped places: a listing stuffed with
/// keywords, 114 characters.
const String longest =
    'The Memory Cafe | Taman Lagenda | Padang Serai | Kulim | Kedah | '
    'Chicken Chop | Kambing Grill | Shellout | Dessert';

void main() {
  group('names on the wedges', () {
    int lines(TextPainter tp) => tp.computeLineMetrics().length;
    double size(TextPainter tp) => (tp.text! as TextSpan).style!.fontSize!;

    test('a short name stays on one line at full size', () {
      final TextPainter tp = layoutWedgeLabel(
        'Kedai Mamak',
        length: 300,
        thickness: 100,
        color: Colors.white,
      );
      expect(lines(tp), 1);
      expect(size(tp), wedgeLabelMaxSize);
    });

    test('a longer name wraps onto two lines before it gets any smaller', () {
      final TextPainter tp = layoutWedgeLabel(
        'Restoran Selera Kampung',
        length: 300,
        thickness: 100,
        color: Colors.white,
      );
      expect(lines(tp), 2);
      expect(size(tp), wedgeLabelMaxSize);
    });

    test('the longest name never runs past its wedge, in length or across '
        'it', () {
      for (final double thickness in <double>[14, 40, 120]) {
        final TextPainter tp = layoutWedgeLabel(
          longest,
          length: 300,
          thickness: thickness,
          color: Colors.white,
        );
        expect(tp.width, lessThanOrEqualTo(300));
        expect(lines(tp), lessThanOrEqualTo(3));
        // One line always shows, even on the thinnest wedge.
        expect(
          tp.height,
          lessThanOrEqualTo(
            thickness < 20 ? wedgeLabelMinSize * 1.2 : thickness,
          ),
        );
      }
    });
  });
}
