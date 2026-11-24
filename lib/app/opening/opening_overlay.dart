import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../system_style.dart';
import 'reels_art.dart';

/// The opening, over the app (docs/decisions.md 020). Flutter's first frame
/// draws exactly what the system splash shows, the reels rolling on ink in
/// the splash icon's place; the reels then stop one after another, the
/// sparks flash, and the whole screen rolls on like the next reel while the
/// app rolls up from below.
class OpeningOverlay extends StatefulWidget {
  const OpeningOverlay({super.key, required this.enabled, required this.child});

  /// Off in tests and anywhere the app is not starting cold.
  final bool enabled;
  final Widget child;

  @override
  State<OpeningOverlay> createState() => _OpeningOverlayState();
}

/// How the opening is timed, in milliseconds.
abstract final class OpeningTiming {
  /// On iPhone the launch screen is plain ink, so the reels fade in first.
  static const int fadeIn = 160;
  static const int roll = 1000;
  static const int hold = 150;
  static const int exit = 620;

  /// With Reduce Motion: the reels shown stopped, then a fade.
  static const int still = 250;
}

class _OpeningOverlayState extends State<OpeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late bool _done = !widget.enabled;
  bool _started = false;
  bool _still = false;
  int _fadeIn = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    if (widget.enabled) {
      SystemChrome.setSystemUIOverlayStyle(openingSystemStyle);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Starts once the screen has a size: Android can hand Flutter its first
  /// frame before it does, and a plan made at zero size would be wrong.
  void _start() {
    if (_started || _done) return;
    _started = true;
    _still = MediaQuery.disableAnimationsOf(context);
    _fadeIn = !_still && defaultTargetPlatform == TargetPlatform.iOS
        ? OpeningTiming.fadeIn
        : 0;
    _c.duration = Duration(
      milliseconds: _still
          ? OpeningTiming.still
          : _fadeIn +
                OpeningTiming.roll +
                OpeningTiming.hold +
                OpeningTiming.exit,
    );
    _c.forward().whenComplete(() {
      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(appSystemStyle);
      setState(() => _done = true);
    });
  }

  double get _ms => _c.value * (_c.duration?.inMilliseconds ?? 0);

  /// Where the reels are, 0 to 1.
  double get _reels {
    if (_still) return 1;
    return ((_ms - _fadeIn) / OpeningTiming.roll).clamp(0.0, 1.0);
  }

  /// How far the screen has rolled on, 0 to 1.
  double get _exit {
    if (_still) return 0;
    final int start = _fadeIn + OpeningTiming.roll + OpeningTiming.hold;
    return ((_ms - start) / OpeningTiming.exit).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size size = box.biggest;
        if (!_done && !_started && !size.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _start();
          });
        }
        return AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (BuildContext context, Widget? app) {
            final double e = _exit;
            final double h = size.height;
            // The app rolls up from below and settles with a small overshoot.
            final double arrive = e < 0.85
                ? Curves.easeInOutCubic.transform(e / 0.85) * 1.02
                : 1.02 - 0.02 * ((e - 0.85) / 0.15);
            return Stack(
              children: <Widget>[
                Transform.translate(
                  offset: Offset(0, _done || e == 0 ? 0 : h * (1 - arrive)),
                  child: ExcludeSemantics(excluding: !_done, child: app),
                ),
                if (!_done)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: _still ? 1 - _c.value : 1,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -h * Curves.easeInOutCubic.transform(e),
                            ),
                            child: size.isEmpty
                                ? const ColoredBox(color: ReelsArt.ink)
                                : CustomPaint(
                                    size: size,
                                    painter: OpeningPainter(
                                      t: _reels,
                                      fade: _fadeIn == 0
                                          ? 1
                                          : (_ms / _fadeIn).clamp(0.0, 1.0),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Ink, with the reels at [t] where Android's splash puts its icon: the
/// 108-unit canvas as a 288 dp square in the middle of the screen.
class OpeningPainter extends CustomPainter {
  const OpeningPainter({required this.t, this.fade = 1});

  final double t;

  /// How far the reels have faded in, on iPhone.
  final double fade;

  static const double iconDp = 288;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ReelsArt.ink);
    if (fade <= 0) return;
    const double scale = iconDp / 108;
    final Offset origin = size.center(Offset.zero) - const Offset(144, 144);
    if (fade < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, math.max(0, fade)),
      );
    }
    paintReels(canvas, t: t, scale: scale, origin: origin);
    if (fade < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(OpeningPainter old) => old.t != t || old.fade != fade;
}
