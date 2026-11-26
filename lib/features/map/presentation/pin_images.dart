import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show CustomPainter;

import '../../../core/theme/app_tokens.dart';

/// The map's pins, drawn once as images for MapLibre: a round head on a
/// thin stem with a small shadow at its foot, as in theselawat. The image's
/// bottom edge is the point it stands on.
abstract final class PinImages {
  /// A place's pin, in logical pixels.
  static const ui.Size placeSize = ui.Size(30, 44);

  /// The pin dropped to search somewhere else: larger, in ink.
  static const ui.Size dropSize = ui.Size(40, 64);

  /// Draws a pin with a [head] colour as a PNG at [pixelRatio].
  static Future<Uint8List> draw({
    required ui.Color head,
    required ui.Size size,
    required double pixelRatio,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas c = ui.Canvas(recorder)..scale(pixelRatio);
    paint(c, size, head);
    final ui.Image image = await recorder.endRecording().toImage(
      (size.width * pixelRatio).ceil(),
      (size.height * pixelRatio).ceil(),
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Paints a pin [size] logical pixels big, standing on the bottom edge.
  static void paint(ui.Canvas c, ui.Size size, ui.Color head) {
    final double w = size.width;
    final double h = size.height;
    final double r = w * 0.36;
    final ui.Offset centre = ui.Offset(w / 2, r + 3);
    final double foot = h - 3;
    // Shadow where it stands.
    c.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(w / 2, foot),
        width: w * 0.4,
        height: 5,
      ),
      ui.Paint()
        ..color = const ui.Color(0x4D26241F)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2),
    );
    // Stem.
    c.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTRB(w / 2 - 1.1, centre.dy, w / 2 + 1.1, foot),
        const ui.Radius.circular(1.1),
      ),
      ui.Paint()..color = AppColors.ink,
    );
    // Head: a soft shadow, the colour, a white rim and a white centre.
    c.drawCircle(
      centre.translate(0, 1.5),
      r + 1,
      ui.Paint()
        ..color = const ui.Color(0x4026241F)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
    );
    c.drawCircle(centre, r, ui.Paint()..color = head);
    c.drawCircle(
      centre,
      r,
      ui.Paint()
        ..color = AppColors.surface
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w * 0.08,
    );
    c.drawCircle(centre, r * 0.32, ui.Paint()..color = AppColors.surface);
  }
}

/// The place pin as a Flutter widget's painter, the same drawing as the
/// map's pin images, for a pin Flutter animates over the map.
class PinPainter extends CustomPainter {
  const PinPainter(this.head);

  final ui.Color head;

  @override
  void paint(ui.Canvas canvas, ui.Size size) =>
      PinImages.paint(canvas, size, head);

  @override
  bool shouldRepaint(PinPainter old) => old.head != head;
}
