import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/wedge_colors.dart';

/// Where the wheel sits in a box: a big circle whose top edge, the rim,
/// meets the arrow near the top of the box and whose centre is far below
/// it, so only the top of the wheel shows (docs/decisions.md 021).
class ArcGeometry {
  ArcGeometry(Size size)
    : radius = size.width * radiusPerWidth,
      centre = Offset(size.width / 2, rimTop + size.width * radiusPerWidth);

  /// The wheel's radius for each unit of the box's width: the flatter of
  /// the shapes tried, 720 on a 412 dp phone.
  static const double radiusPerWidth = 720 / 412;

  /// Room above the rim for the arrow: its pivot sits 22 above the rim.
  static const double rimTop = 32;

  final double radius;
  final Offset centre;

  Rect get disc => Rect.fromCircle(center: centre, radius: radius);
}

/// Draws the part of the wheel that shows: the wedges, their names, the
/// pegs on the rim and the rim. [turn] is how far the wheel has turned, in
/// wedges; wedge i spans clockwise from the top when [turn] is 0.
class WheelPainter extends CustomPainter {
  WheelPainter({
    required this.labels,
    required this.turn,
    required this.labelRimGap,
    this.won,
    this.flash = 0,
  });

  /// Each wedge's name, already laid out by its owner.
  final List<TextPainter> labels;
  final double turn;

  /// How far in from the rim the names start.
  final double labelRimGap;

  /// The winning wedge, lit by [flash] from 0 to 1.
  final int? won;
  final double flash;

  static final Paint _fill = Paint();
  static final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = AppColors.surface;
  static final Paint _peg = Paint()..color = AppColors.surface;
  static final Paint _pegEdge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = AppColors.ink;
  static final Paint _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = AppColors.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = labels.length;
    if (n == 0) return;
    final ArcGeometry g = ArcGeometry(size);
    final Offset c = g.centre;
    final double r = g.radius;
    final double seg = 2 * math.pi / n;
    // Only wedges that reach the screen are drawn.
    final double reach = math.asin(math.min(1, (size.width / 2 + 8) / r)) + seg;
    for (int i = 0; i < n; i++) {
      final double start = -math.pi / 2 + (i + turn) * seg;
      final double mid = start + seg / 2;
      if (_offTop(mid).abs() > reach) continue;
      final WedgeColor w = wedgeColorFor(i, n);
      _fill.color = i == won && flash > 0
          ? Color.lerp(w.fill, AppColors.surface, 0.45 * flash)!
          : w.fill;
      canvas.drawArc(g.disc, start, seg, true, _fill);
      canvas.drawArc(g.disc, start, seg, true, _edge);
      // The name reads from the rim towards the middle.
      final TextPainter tp = labels[i];
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(mid)
        ..translate(r - labelRimGap, 0)
        ..rotate(math.pi);
      tp.paint(canvas, Offset(0, -tp.height / 2));
      canvas.restore();
    }
    for (int j = 0; j < n; j++) {
      final double a = -math.pi / 2 + (j + turn) * seg;
      if (_offTop(a).abs() > reach) continue;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * (r - 11);
      canvas.drawCircle(p, 4.5, _peg);
      canvas.drawCircle(p, 4.5, _pegEdge);
    }
    canvas.drawCircle(c, r, _rim);
  }

  /// How far [angle] is from straight up, from -pi to pi.
  static double _offTop(double angle) {
    final double a = angle + math.pi / 2;
    return math.atan2(math.sin(a), math.cos(a));
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
      old.turn != turn ||
      old.won != won ||
      old.flash != flash ||
      old.labelRimGap != labelRimGap ||
      !identical(old.labels, labels);
}
