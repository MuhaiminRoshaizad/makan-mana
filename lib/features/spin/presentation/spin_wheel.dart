import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/wedge_colors.dart';
import '../domain/wheel_physics.dart';
import 'wedge_label.dart';
import 'wheel_painter.dart';

/// The lunch wheel: a big wheel rising from the bottom of its box, one
/// wedge per place, with the arrow at its top (docs/decisions.md 021).
/// [spin] throws it; it can also be grabbed and thrown, or dragged slowly
/// and let go to coast. Every peg the arrow passes clicks with a haptic
/// tick.
class SpinWheel extends StatefulWidget {
  const SpinWheel({
    super.key,
    required this.names,
    this.labelsEndAbove = 0,
    this.onCurrent,
    this.onLanded,
    this.onSpinning,
    this.random,
  });

  /// The places, in wedge order clockwise from the top.
  final List<String> names;

  /// How far above the box's bottom edge the names on the wedges must
  /// end, to stay clear of what floats over the wheel there.
  final double labelsEndAbove;

  /// The place under the arrow, whenever it changes, spinning or not.
  final ValueChanged<int>? onCurrent;

  /// The place a spin stopped on. A slow drag that coasts to a stop is not
  /// a spin and reports nothing.
  final ValueChanged<int>? onLanded;

  /// Whether a spin is under way.
  final ValueChanged<bool>? onSpinning;

  /// For a repeatable start angle and throw strength in tests.
  final math.Random? random;

  @override
  State<SpinWheel> createState() => SpinWheelState();
}

class SpinWheelState extends State<SpinWheel> with TickerProviderStateMixin {
  /// Throw speeds from the hub, in segments per second.
  static const double _tapMin = 10;
  static const double _tapRange = 5;

  /// A release slower than this coasts instead of counting as a spin.
  static const double _throwThreshold = 3;

  /// The arrow's largest bend, in degrees, at full flapper contact.
  static const double _bendDegrees = 24;

  late final math.Random _random = widget.random ?? math.Random();
  late WheelPhysics _wheel = _newWheel(null);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  bool _spinning = false;
  int _current = -1;

  /// The arrow's own swing after it slips off a peg, in degrees.
  double _flapAngle = 0;
  double _flapSpeed = 0;

  /// The wedge that just won, flashing.
  int? _won;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Dragging: where the finger last was, as an angle round the centre.
  double? _grabAngle;
  Offset _grabAt = Offset.zero;

  /// The box last laid out in, for the centre the finger turns round.
  Size _size = Size.zero;

  /// The names laid out for the current box, kept until it or the names
  /// change, since laying them out is the costly part of a frame.
  List<TextPainter> _labels = const <TextPainter>[];
  Object? _labelsFor;

  bool get spinning => _spinning;

  WheelPhysics _newWheel(double? keepTurn) => WheelPhysics(
    segments: math.max(1, widget.names.length),
    // The first rest is random, so no place is favoured by where the wheel
    // happens to start (docs/decisions.md 014).
    turn: keepTurn ?? _random.nextDouble() * math.max(1, widget.names.length),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportCurrent());
  }

  @override
  void didUpdateWidget(SpinWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.names.length != widget.names.length) {
      _stop();
      _wheel = _newWheel(_wheel.turn);
      _won = null;
      _reportCurrent();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flash.dispose();
    _disposeLabels();
    super.dispose();
  }

  void _disposeLabels() {
    for (final TextPainter tp in _labels) {
      tp.dispose();
    }
    _labels = const <TextPainter>[];
  }

  /// How far in from the rim the names start: clear of the pegs.
  static const double _labelRimGap = 30;

  List<TextPainter> _labelsIn(Size size) {
    final Object key = (
      Object.hashAll(widget.names),
      size,
      widget.labelsEndAbove,
    );
    if (key == _labelsFor) return _labels;
    _disposeLabels();
    _labelsFor = key;
    final int n = widget.names.length;
    if (n == 0) return _labels;
    final ArcGeometry g = ArcGeometry(size);
    // The names end where the box stops being clear, but never closer to
    // the centre than a third of the way in.
    final double outer = g.radius - _labelRimGap;
    final double inner = math.max(
      g.radius * 0.35,
      g.centre.dy - (size.height - widget.labelsEndAbove),
    );
    final double length = math.max(60, outer - inner);
    final double thickness = 2 * inner * math.sin(math.pi / n) - 6;
    _labels = <TextPainter>[
      for (int i = 0; i < n; i++)
        layoutWedgeLabel(
          widget.names[i],
          length: length,
          thickness: math.max(14, thickness),
          color: wedgeColorFor(i, n).label,
        ),
    ];
    return _labels;
  }

  /// Spins the wheel, as the Spin button does.
  void spin() {
    if (_spinning || widget.names.isEmpty) return;
    _throw(_tapMin + _random.nextDouble() * _tapRange);
  }

  void _throw(double speed) {
    _setSpinning(true);
    _won = null;
    _wheel.fling(speed);
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce Motion: the same physics runs to the end at once.
      while (!_wheel.advance(1 / 60).stopped) {}
      _flapAngle = 0;
      _flapSpeed = 0;
      setState(() {});
      _reportCurrent();
      _land();
      return;
    }
    _start();
  }

  void _start() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    _flapAngle = 0;
    _flapSpeed = 0;
    if (_spinning) _setSpinning(false);
  }

  void _setSpinning(bool value) {
    _spinning = value;
    widget.onSpinning?.call(value);
  }

  void _tick(Duration now) {
    final double dt = _last == Duration.zero
        ? 1 / 60
        : math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    final ({List<PegClick> clicks, bool stopped}) r = _wheel.advance(dt);
    for (final PegClick c in r.clicks) {
      _click(c.forward);
    }
    final double bend = _wheel.flapperBend;
    if (bend != 0) {
      _flapAngle = -_bendDegrees * bend;
      _flapSpeed = 0;
    } else {
      // The arrow swings back to rest on its own spring.
      _flapSpeed += (-420 * _flapAngle - 22 * _flapSpeed) * dt;
      _flapAngle += _flapSpeed * dt;
    }
    final bool settling = _flapAngle.abs() > 0.2 || _flapSpeed.abs() > 2;
    if (r.stopped && !settling) {
      _ticker.stop();
      _flapAngle = 0;
      _flapSpeed = 0;
    }
    setState(() {});
    _reportCurrent();
    if (r.stopped && _spinning) _land();
  }

  /// The arrow slips off a peg: it snaps back with a tick.
  void _click(bool forward) {
    _flapAngle = forward ? -26 : 26;
    _flapSpeed = forward ? 900 : -900;
    unawaited(HapticFeedback.selectionClick());
  }

  void _land() {
    _setSpinning(false);
    final int at = _wheel.segmentUnderArrow;
    _won = at;
    unawaited(HapticFeedback.mediumImpact());
    if (!MediaQuery.disableAnimationsOf(context)) _flash.forward(from: 0);
    widget.onLanded?.call(at);
  }

  void _reportCurrent() {
    if (!mounted || widget.names.isEmpty) return;
    final int now = _wheel.segmentUnderArrow;
    if (now == _current) return;
    _current = now;
    widget.onCurrent?.call(now);
  }

  double _angleAt(Offset local) {
    final Offset d = local - ArcGeometry(_size).centre;
    return math.atan2(d.dy, d.dx) * 180 / math.pi;
  }

  void _grab(DragStartDetails d) {
    if (widget.names.isEmpty) return;
    _stop();
    _won = null;
    _grabAngle = _angleAt(d.localPosition);
    _grabAt = d.localPosition;
  }

  void _move(DragUpdateDetails d) {
    final double? from = _grabAngle;
    if (from == null) return;
    final double to = _angleAt(d.localPosition);
    double delta = to - from;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _grabAngle = to;
    _grabAt = d.localPosition;
    final double segment = 360 / widget.names.length;
    for (final PegClick c in _wheel.drag(delta / segment)) {
      _click(c.forward);
    }
    // The arrow still swings back while the wheel is held.
    if (!_ticker.isActive) _start();
    setState(() {});
    _reportCurrent();
  }

  void _release(DragEndDetails d) {
    if (_grabAngle == null) return;
    _grabAngle = null;
    final double speed = throwSpeed(
      _grabAt - ArcGeometry(_size).centre,
      d.velocity.pixelsPerSecond,
      widget.names.length,
    );
    if (speed.abs() >= _throwThreshold) {
      // A little randomness, so the same flick never repeats a result.
      _throw(speed * (0.92 + _random.nextDouble() * 0.16));
    } else {
      _wheel.fling(speed);
      _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        _size = c.biggest;
        final List<TextPainter> labels = _labelsIn(_size);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Semantics(
                label: 'Lunch wheel',
                value: widget.names.isEmpty
                    ? null
                    : widget.names[_wheel.segmentUnderArrow],
                child: GestureDetector(
                  onPanStart: _grab,
                  onPanUpdate: _move,
                  onPanEnd: _release,
                  // Only the wheel repaints as it turns, not what floats
                  // over it.
                  // The circle runs far past the box; only the box shows.
                  child: ClipRect(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _flash,
                        builder: (BuildContext context, _) => CustomPaint(
                          size: _size,
                          painter: WheelPainter(
                            labels: labels,
                            turn: _wheel.turn,
                            labelRimGap: _labelRimGap,
                            won: _won,
                            flash: _won == null
                                ? 0
                                : math.sin(_flash.value * math.pi),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: _size.width / 2 - _Arrow.pivot.dx,
              top: ArcGeometry.rimTop - 22 - _Arrow.pivot.dy,
              child: Transform.rotate(
                angle: _flapAngle * math.pi / 180,
                alignment: Alignment(
                  _Arrow.pivot.dx / _Arrow.size.width * 2 - 1,
                  _Arrow.pivot.dy / _Arrow.size.height * 2 - 1,
                ),
                child: const _Arrow(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How fast a finger leaving the wheel at [fromCentre], moving at
/// [velocity] pixels per second, throws a wheel of [segments], in segments
/// per second, positive clockwise. Only the part of the movement across the
/// radius turns the wheel. Flutter's velocity tracker already reports zero
/// for a finger that stopped before lifting.
double throwSpeed(Offset fromCentre, Offset velocity, int segments) {
  final double r2 = fromCentre.distanceSquared;
  if (r2 < 1 || segments == 0) return 0;
  final double radiansPerSecond =
      (fromCentre.dx * velocity.dy - fromCentre.dy * velocity.dx) / r2;
  return radiansPerSecond / (2 * math.pi / segments);
}

/// The flapper: an ink teardrop with a white pin at its pivot.
class _Arrow extends StatelessWidget {
  const _Arrow();

  static const Size size = Size(28, 58);
  static const Offset pivot = Offset(14, 10);

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: size, painter: _ArrowPainter());
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // A teardrop pointing down: a circle of radius 10 round the pivot
    // narrowing to a tip at the bottom.
    final Path p = Path()
      ..moveTo(14, 56)
      ..lineTo(5, 17)
      ..arcToPoint(
        const Offset(23, 17),
        radius: const Radius.circular(10),
        largeArc: true,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.ink);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.surface,
    );
    canvas.drawCircle(_Arrow.pivot, 3.2, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}
