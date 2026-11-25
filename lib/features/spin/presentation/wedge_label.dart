import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Largest and smallest label sizes on a wedge.
const double wedgeLabelMaxSize = 17;
const double wedgeLabelMinSize = 11;
const double _lineHeight = 1.12;

/// Lays out a place's name to run along its wedge: [length] is the room
/// from the rim inwards, [thickness] the wedge's width where it is
/// narrowest. A name keeps the largest size and wraps onto two lines; only
/// a name too long for two lines gets smaller, then takes a third, and past
/// that ends in an ellipsis (docs/decisions.md 021).
///
/// The wheel is a drawing at a fixed size, so its labels do not grow with
/// system text; the name above the wheel does.
TextPainter layoutWedgeLabel(
  String name, {
  required double length,
  required double thickness,
  required Color color,
}) {
  for (final int lines in const <int>[2, 3]) {
    for (
      double size = wedgeLabelMaxSize;
      size >= wedgeLabelMinSize;
      size -= 1
    ) {
      final TextPainter tp = _painter(name, size, color)
        ..layout(maxWidth: length);
      if (tp.computeLineMetrics().length <= lines && tp.height <= thickness) {
        return tp;
      }
      tp.dispose();
    }
  }
  final int fit = math.max(
    1,
    math.min(3, (thickness / (wedgeLabelMinSize * _lineHeight)).floor()),
  );
  return _painter(name, wedgeLabelMinSize, color, maxLines: fit)
    ..layout(maxWidth: length);
}

TextPainter _painter(String name, double size, Color color, {int? maxLines}) =>
    TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: size,
          height: _lineHeight,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
      textDirection: TextDirection.ltr,
    );
