import 'dart:math' as math;
import 'dart:ui';

/// The app's icon: a slot machine of three food reels on ink, drawn once
/// here. The launcher icons, the system splash and the in-app opening all
/// come from this one drawing, so they cannot drift apart
/// (docs/decisions.md 020).
///
/// Everything is in Android's adaptive-icon units: a 108 × 108 canvas whose
/// middle 72 shows, and whose middle 66 is safe from any launcher's mask.
abstract final class ReelsArt {
  static const Color ink = Color(0xFF26241F);
  static const Color white = Color(0xFFFDFDFB);
  static const Color divider = Color(0x2426241F);
  static const Color spark = Color(0xFFF0B83C);
  static const Color lettuce = Color(0xFF357A40);

  /// Bowl, burger, cup and laksa, in the wheel's colours.
  static const List<Color> food = <Color>[
    Color(0xFFC8452A),
    Color(0xFFE07B1F),
    Color(0xFF2F6FC9),
    Color(0xFF357A40),
  ];

  /// Where each reel comes to rest: the row in the middle of its window.
  /// With symbol (row + 2 × reel) mod 4, that is bowl, burger, cup.
  static const List<int> stops = <int>[0, 3, 2];

  /// How many rows each reel rolls past before it stops.
  static const List<int> travel = <int>[6, 8, 10];

  static const double rowGap = 16;
  static double reelX(int j) => 38 + 16.0 * j;
  static const double windowMid = 56;
  static Rect window(int j) => Rect.fromLTWH(30.5 + 16.0 * j, 44, 15, 24);

  static int symbolAt(int row, int reel) => ((row + 2 * reel) % 4 + 4) % 4;

  /// The frame, pointer and dividers: everything that does not move.
  static List<ArtShape> body({bool outline = false}) => <ArtShape>[
    ArtShape(
      ArtPath.roundRect(24.7, 38.7, 58.6, 34.6, 10.3),
      fill: outline ? null : white,
      stroke: outline ? white : null,
      strokeWidth: 2.6,
    ),
    for (int j = 0; j < 2; j++)
      ArtShape(ArtPath.rect(45.5 + 16.0 * j, 44, 1, 24), fill: divider),
    ArtShape(
      ArtPath()
        ..moveTo(49, 31)
        ..lineTo(59, 31)
        ..lineTo(54, 38)
        ..close(),
      fill: white,
      stroke: white,
      strokeWidth: 1.6,
    ),
  ];

  /// The two short strokes that flash when the reels stop. Kept inside the
  /// safe circle, so no launcher's mask cuts them off.
  static List<ArtShape> sparks() => <ArtShape>[
    ArtShape(
      ArtPath()
        ..moveTo(69, 34)
        ..lineTo(72, 29.5),
      stroke: spark,
      strokeWidth: 2.4,
    ),
    ArtShape(
      ArtPath()
        ..moveTo(74, 38)
        ..lineTo(78.5, 35.5),
      stroke: spark,
      strokeWidth: 2.4,
    ),
  ];

  /// Symbol [k] (bowl, burger, cup, laksa) centred on ([x], [y]).
  static List<ArtShape> symbol(int k, double x, double y) {
    final Color c = food[k];
    switch (k) {
      case 0:
        return <ArtShape>[
          ArtShape(
            ArtPath()
              ..moveTo(x - 6, y - 1)
              ..lineTo(x + 6, y - 1)
              ..arcTo(6, 6, x - 6, y - 1)
              ..close(),
            fill: c,
          ),
          for (final double dx in <double>[-2, 2])
            ArtShape(
              ArtPath()
                ..moveTo(x + dx, y - 4)
                ..quadTo(x + dx + 1, y - 6, x + dx, y - 8),
              stroke: c,
              strokeWidth: 1.1,
            ),
        ];
      case 1:
        return <ArtShape>[
          ArtShape(
            ArtPath()
              ..moveTo(x - 6, y - 1)
              ..arcTo(6, 4.5, x + 6, y - 1)
              ..close(),
            fill: c,
          ),
          ArtShape(
            ArtPath.roundRect(x - 6.4, y, 12.8, 1.6, 0.8),
            fill: lettuce,
          ),
          ArtShape(ArtPath.roundRect(x - 6, y + 2.2, 12, 2, 1), fill: c),
          ArtShape(
            ArtPath()
              ..moveTo(x - 6, y + 5)
              ..lineTo(x + 6, y + 5)
              ..arcTo(1, 1, x + 5, y + 6.5)
              ..lineTo(x - 5, y + 6.5)
              ..arcTo(1, 1, x - 6, y + 5)
              ..close(),
            fill: c,
          ),
        ];
      case 2:
        return <ArtShape>[
          ArtShape(
            ArtPath()
              ..moveTo(x - 4, y - 4)
              ..lineTo(x + 4, y - 4)
              ..lineTo(x + 3, y + 6)
              ..lineTo(x - 3, y + 6)
              ..close(),
            fill: c,
          ),
          ArtShape(
            ArtPath()
              ..moveTo(x + 1, y - 4)
              ..lineTo(x + 3, y - 8),
            stroke: c,
            strokeWidth: 1.1,
          ),
          ArtShape(ArtPath.roundRect(x - 4.6, y - 5, 9.2, 1.4, 0.7), fill: c),
        ];
      default:
        return <ArtShape>[
          ArtShape(ArtPath.circle(x, y, 5.2), stroke: c, strokeWidth: 1.6),
          for (final double dy in <double>[-1.5, 1.5])
            ArtShape(
              ArtPath()
                ..moveTo(x - 2.5, y + dy)
                ..quadTo(x, y + dy - 2, x + 2.5, y + dy),
              stroke: c,
              strokeWidth: 1.1,
            ),
        ];
    }
  }

  /// Reel [j]'s symbols with the reel at [position], in rows: a whole
  /// number puts that row in the middle of the window.
  static List<ArtShape> reel(int j, double position) {
    final int first = position.floor() - 1;
    return <ArtShape>[
      for (int row = first; row <= first + 3; row++)
        ...symbol(
          symbolAt(row, j),
          reelX(j),
          windowMid + rowGap * (row - position),
        ),
    ];
  }

  /// Where reel [j] is at [t] of the opening, from 0 (rolling, as the
  /// system splash shows it) to 1 (stopped). Reels stop one after another,
  /// each settling with a small kick back.
  static double reelPosition(int j, double t) {
    const List<double> ends = <double>[0.5, 0.7, 0.88];
    final double s = ((t - 0.05) / (ends[j] - 0.05)).clamp(0.0, 1.0);
    final double eased = 1 - math.pow(1 - s, 3).toDouble();
    double p = stops[j] + travel[j] * (1 - eased);
    if (s >= 1) {
      final double k = ((t - ends[j]) / 0.08).clamp(0.0, 1.0);
      p -= 0.15 * math.sin(math.pi * k) * (1 - k);
    }
    return p;
  }

  /// How strongly the sparks show at [t]: they flash once the last reel
  /// has stopped.
  static double sparkOpacity(double t) => ((t - 0.9) / 0.1).clamp(0.0, 1.0);
}

/// One filled and/or stroked path.
class ArtShape {
  const ArtShape(this.path, {this.fill, this.stroke, this.strokeWidth = 1});

  final ArtPath path;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
}

/// A path recorded once and played back two ways: as a Flutter [Path], and
/// as SVG path data for Android's vector drawables.
class ArtPath {
  ArtPath();

  factory ArtPath.rect(double x, double y, double w, double h) => ArtPath()
    ..moveTo(x, y)
    ..lineTo(x + w, y)
    ..lineTo(x + w, y + h)
    ..lineTo(x, y + h)
    ..close();

  factory ArtPath.roundRect(double x, double y, double w, double h, double r) =>
      ArtPath()
        ..moveTo(x + r, y)
        ..lineTo(x + w - r, y)
        ..arcTo(r, r, x + w, y + r)
        ..lineTo(x + w, y + h - r)
        ..arcTo(r, r, x + w - r, y + h)
        ..lineTo(x + r, y + h)
        ..arcTo(r, r, x, y + h - r)
        ..lineTo(x, y + r)
        ..arcTo(r, r, x + r, y)
        ..close();

  factory ArtPath.circle(double cx, double cy, double r) => ArtPath()
    ..moveTo(cx - r, cy)
    ..arcTo(r, r, cx + r, cy)
    ..arcTo(r, r, cx - r, cy)
    ..close();

  final List<void Function(Path)> _ops = <void Function(Path)>[];
  final StringBuffer _data = StringBuffer();

  static String _n(double v) {
    final String s = v.toStringAsFixed(2);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  void _write(String command, List<double> args) {
    if (_data.isNotEmpty) _data.write(' ');
    _data.write('$command${args.map(_n).join(' ')}');
  }

  void moveTo(double x, double y) {
    _ops.add((Path p) => p.moveTo(x, y));
    _write('M', <double>[x, y]);
  }

  void lineTo(double x, double y) {
    _ops.add((Path p) => p.lineTo(x, y));
    _write('L', <double>[x, y]);
  }

  void quadTo(double cx, double cy, double x, double y) {
    _ops.add((Path p) => p.quadraticBezierTo(cx, cy, x, y));
    _write('Q', <double>[cx, cy, x, y]);
  }

  /// A short clockwise elliptical arc to ([x], [y]).
  void arcTo(double rx, double ry, double x, double y) {
    _ops.add(
      (Path p) => p.arcToPoint(Offset(x, y), radius: Radius.elliptical(rx, ry)),
    );
    // SVG: rx ry rotation large-arc sweep x y; sweep 1 is clockwise on
    // screen, which is what Flutter's arcToPoint does by default.
    if (_data.isNotEmpty) _data.write(' ');
    _data.write('A${_n(rx)} ${_n(ry)} 0 0 1 ${_n(x)} ${_n(y)}');
  }

  void close() {
    _ops.add((Path p) => p.close());
    if (_data.isNotEmpty) _data.write(' ');
    _data.write('Z');
  }

  Path toPath() {
    final Path p = Path();
    for (final void Function(Path) op in _ops) {
      op(p);
    }
    return p;
  }

  String get data => _data.toString();
}

/// Paints the reels at [t] of the opening on the 108-unit canvas, scaled
/// to [size]. [sparks] adds the flash; [background] fills behind.
void paintReels(
  Canvas canvas, {
  required double t,
  required double scale,
  required Offset origin,
  bool sparks = true,
  Color? background,
}) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.scale(scale);
  if (background != null) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 108, 108),
      Paint()..color = background,
    );
  }
  void draw(ArtShape s, [double opacity = 1]) {
    final Path path = s.path.toPath();
    if (s.fill case final Color c) {
      canvas.drawPath(
        path,
        Paint()..color = c.withValues(alpha: c.a * opacity),
      );
    }
    if (s.stroke case final Color c) {
      canvas.drawPath(
        path,
        Paint()
          ..color = c.withValues(alpha: c.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  final List<ArtShape> body = ReelsArt.body();
  draw(body.first);
  for (int j = 0; j < 3; j++) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(ReelsArt.window(j), const Radius.circular(3)),
    );
    ReelsArt.reel(j, ReelsArt.reelPosition(j, t)).forEach(draw);
    canvas.restore();
  }
  body.skip(1).forEach(draw);
  if (sparks) {
    final double o = ReelsArt.sparkOpacity(t);
    if (o > 0) {
      for (final ArtShape s in ReelsArt.sparks()) {
        draw(s, o);
      }
    }
  }
  canvas.restore();
}
