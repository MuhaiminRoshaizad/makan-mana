import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'wheel_colors.dart';

/// Draws the wedges, their labels, the rim and a peg between every two
/// wedges, unrotated: wedge i spans clockwise from the top.
class WheelPainter extends CustomPainter {
  WheelPainter({required this.names, this.won, this.flash = 0});

  final List<String> names;

  /// The winning wedge, lit by [flash] from 0 to 1.
  final int? won;
  final double flash;

  /// Labels start just outside the hub and run out towards the rim.
  static const double labelStart = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = names.length;
    if (n == 0) return;
    final double r = size.width / 2;
    final Offset c = Offset(r, r);
    final double seg = 2 * math.pi / n;
    final Rect disc = Rect.fromCircle(center: c, radius: r - 4);
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.surface;
    for (int i = 0; i < n; i++) {
      final WedgeColor w = wedgeColorFor(i, n);
      final double start = -math.pi / 2 + i * seg;
      final Color fill = i == won && flash > 0
          ? Color.lerp(w.fill, AppColors.surface, 0.45 * flash)!
          : w.fill;
      canvas.drawArc(disc, start, seg, true, Paint()..color = fill);
      canvas.drawArc(disc, start, seg, true, edge);
      _label(canvas, c, r, start + seg / 2, names[i], w.label);
    }
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = AppColors.surface,
    );
    final Paint peg = Paint()..color = AppColors.surface;
    final Paint pegEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x5926241F);
    for (int j = 0; j < n; j++) {
      final double a = -math.pi / 2 + j * seg;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * (r - 9);
      canvas.drawCircle(p, 3.5, peg);
      canvas.drawCircle(p, 3.5, pegEdge);
    }
  }

  void _label(
    Canvas canvas,
    Offset c,
    double r,
    double angle,
    String name,
    Color color,
  ) {
    // The wheel is a drawing at a fixed size, so its labels do not grow
    // with system text; the name above the wheel does.
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r - labelStart - 16);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(angle);
    tp.paint(canvas, Offset(labelStart, -tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
      old.won != won || old.flash != flash || !_sameNames(old.names);

  bool _sameNames(List<String> other) {
    if (identical(other, names)) return true;
    if (other.length != names.length) return false;
    for (int i = 0; i < names.length; i++) {
      if (other[i] != names[i]) return false;
    }
    return true;
  }
}
