import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/wheel_physics.dart';
import 'wheel_painter.dart';

/// The lunch wheel: one wedge per place, an arrow on top, and a hub that
/// spins it. It can also be grabbed and thrown, or dragged slowly and let
/// go to coast. Every peg the arrow passes clicks with a haptic tick.
class SpinWheel extends StatefulWidget {
  const SpinWheel({
    super.key,
    required this.names,
    required this.diameter,
    this.onCurrent,
    this.onLanded,
    this.onSpinning,
    this.random,
  });

  /// The places, in wedge order clockwise from the top.
  final List<String> names;

  /// The wheel's diameter; the arrow above it adds [arrowRoom].
  final double diameter;

  /// The place under the arrow, whenever it changes, spinning or not.
  final ValueChanged<int>? onCurrent;

  /// The place a spin stopped on. A slow drag that coasts to a stop is not
  /// a spin and reports nothing.
  final ValueChanged<int>? onLanded;

  /// Whether a spin is under way.
  final ValueChanged<bool>? onSpinning;

  /// For a repeatable start angle and throw strength in tests.
  final math.Random? random;

  /// Room above the wheel for the arrow: its pivot sits 22 above the rim.
  static const double arrowRoom = 32;

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
    super.dispose();
  }

  /// Spins the wheel as the hub does.
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
    final Offset c = Offset(widget.diameter / 2, widget.diameter / 2);
    final Offset d = local - c;
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
      _grabAt - Offset(widget.diameter / 2, widget.diameter / 2),
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
    final double d = widget.diameter;
    final double rotation =
        _wheel.turn * 2 * math.pi / math.max(1, widget.names.length);
    return SizedBox(
      width: d,
      height: d + SpinWheel.arrowRoom,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: SpinWheel.arrowRoom,
            width: d,
            height: d,
            child: Semantics(
              label: 'Lunch wheel',
              value: widget.names.isEmpty
                  ? null
                  : widget.names[_wheel.segmentUnderArrow],
              child: GestureDetector(
                onPanStart: _grab,
                onPanUpdate: _move,
                onPanEnd: _release,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x2E26241F),
                        blurRadius: 34,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: rotation,
                    // The drawing is cached; only its rotation changes
                    // each frame.
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _flash,
                        builder: (BuildContext context, _) => CustomPaint(
                          size: Size.square(d),
                          painter: WheelPainter(
                            names: widget.names,
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
          ),
          Positioned(
            left: d / 2 - _Arrow.pivot.dx,
            top: SpinWheel.arrowRoom - 22 - _Arrow.pivot.dy,
            child: Transform.rotate(
              angle: _flapAngle * math.pi / 180,
              alignment: Alignment(
                _Arrow.pivot.dx / _Arrow.size.width * 2 - 1,
                _Arrow.pivot.dy / _Arrow.size.height * 2 - 1,
              ),
              child: const _Arrow(),
            ),
          ),
          Positioned(
            left: d / 2 - _Hub.size / 2,
            top: SpinWheel.arrowRoom + d / 2 - _Hub.size / 2,
            child: _Hub(
              spinning: _spinning,
              enabled: widget.names.isNotEmpty,
              onTap: spin,
            ),
          ),
        ],
      ),
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

/// The Spin button in the middle of the wheel.
class _Hub extends StatefulWidget {
  const _Hub({
    required this.spinning,
    required this.enabled,
    required this.onTap,
  });

  static const double size = 88;

  final bool spinning;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Hub> createState() => _HubState();
}

class _HubState extends State<_Hub> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && !widget.spinning;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.spinning ? 'Spinning' : 'Spin',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: active ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: AppMotion.short,
          curve: AppMotion.enter,
          child: Container(
            width: _Hub.size,
            height: _Hub.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _down
                  ? Color.lerp(AppColors.ink, AppColors.surface, 0.08)
                  : AppColors.ink,
              border: Border.all(color: AppColors.surface, width: 5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x4026241F),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              widget.spinning ? 'Spinning' : 'Spin',
              maxLines: 1,
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.15),
              style: TextStyle(
                fontSize: widget.spinning ? 13 : 17,
                fontWeight: FontWeight.w800,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
