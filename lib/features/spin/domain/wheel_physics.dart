import 'dart:math' as math;

/// A peg the flapper slipped past, for a tick of sound and haptics.
class PegClick {
  const PegClick({required this.forward, required this.speed});

  /// True when the wheel was turning clockwise.
  final bool forward;

  /// The wheel's speed at that moment, in segments per second.
  final double speed;
}

/// The wheel as a small physics model (docs/decisions.md 014).
///
/// [turn] is how far the wheel has turned clockwise, in segments: a peg sits
/// at every whole number. Friction slows it steadily. Over the last [reach]
/// of each segment the flapper bends against the coming peg like a spring,
/// and the energy it stored is lost when the peg slips past. A wheel that
/// runs out of speed against a peg is pushed back by the flapper, so the
/// near-miss happens on its own and no spin is decided in advance.
class WheelPhysics {
  WheelPhysics({
    required this.segments,
    required this._turn,
    this.stiffness = 10,
    this.friction = 2.0,
    this.reach = 0.35,
    this.maxSpeed = 18,
  }) : assert(segments > 0);

  /// Places on the wheel.
  final int segments;

  /// The flapper's spring constant, in segments/s² per segment of bend.
  final double stiffness;

  /// Steady slowdown, in segments/s².
  final double friction;

  /// How far before a peg the flapper starts to resist, in segments.
  final double reach;

  /// A harder throw is capped here, in segments per second.
  final double maxSpeed;

  /// One substep: small enough that the flapper's spring stays stable at
  /// any stiffness used here.
  static const double _step = 1 / 1000;

  /// Below this speed, with the flapper no longer pushing harder than
  /// friction holds, the wheel has stopped.
  static const double _restSpeed = 0.03;

  double _turn;
  double _speed = 0;
  _Contact? _contact;

  /// How far the wheel has turned clockwise, in segments.
  double get turn => _turn;

  /// Segments per second; positive is clockwise.
  double get speed => _speed;

  bool get isMoving => _speed != 0 || _contact != null;

  /// The segment under an arrow at the top. Segment i is drawn clockwise
  /// from the top over [i, i + 1), so turning the wheel by [turn] brings
  /// segment floor(-turn) under the arrow (Dart's % is never negative).
  int get segmentUnderArrow => (-_turn).floor() % segments;

  /// How far the flapper is bent, from -1 to 1, positive when a clockwise
  /// wheel pushes it.
  double get flapperBend {
    final _Contact? c = _contact;
    if (c == null) return 0;
    return c.side * math.min(1, _depth(c) / reach);
  }

  /// Starts the wheel at [speed] segments per second, clockwise if positive.
  void fling(double speed) {
    _speed = speed.clamp(-maxSpeed, maxSpeed).toDouble();
  }

  /// Turns the wheel by hand, as when a finger drags it, and reports each
  /// peg crossed on the way. Dragging stops it spinning.
  List<PegClick> drag(double by) {
    _speed = 0;
    _contact = null;
    final double before = _turn;
    _turn += by;
    final int crossed = (_turn.floor() - before.floor()).abs();
    return <PegClick>[
      for (int i = 0; i < crossed; i++) PegClick(forward: by > 0, speed: 6),
    ];
  }

  /// Moves time on by [seconds]. Returns the pegs passed meanwhile, and
  /// whether the wheel came to rest.
  ({List<PegClick> clicks, bool stopped}) advance(double seconds) {
    final List<PegClick> clicks = <PegClick>[];
    if (!isMoving) return (clicks: clicks, stopped: true);
    final int steps = math.max(1, (seconds / _step).ceil());
    final double h = seconds / steps;
    for (int i = 0; i < steps; i++) {
      final double v = _speed;
      final double x = _turn;
      if (_contact == null) {
        if (v > 0) {
          final int peg = x.floor() + 1;
          if (x > peg - reach) _contact = _Contact(peg, 1);
        } else if (v < 0) {
          final int peg = x.ceil() - 1;
          if (x < peg + reach) _contact = _Contact(peg, -1);
        }
      }
      double spring = 0;
      final _Contact? c = _contact;
      if (c != null) {
        final double depth = _depth(c);
        if (depth <= 0) {
          _contact = null;
        } else if (c.side > 0 ? x >= c.peg : x <= c.peg) {
          // The peg slipped past the flapper, which snaps back with a click.
          _contact = null;
          clicks.add(PegClick(forward: c.side > 0, speed: v.abs()));
        } else {
          spring = -c.side * stiffness * depth;
        }
      }
      if (v.abs() < _restSpeed && spring.abs() <= friction) {
        _speed = 0;
        _contact = null;
        return (clicks: clicks, stopped: true);
      }
      final double drag = v > 0
          ? -friction
          : v < 0
          ? friction
          : -spring.sign * friction;
      double next = v + (spring + drag) * h;
      // Friction alone stops a wheel; it never turns it round.
      if (spring == 0 && v != 0 && next.sign != v.sign) next = 0;
      _speed = next;
      _turn = x + next * h;
    }
    return (clicks: clicks, stopped: false);
  }

  double _depth(_Contact c) =>
      c.side > 0 ? _turn - (c.peg - reach) : (c.peg + reach) - _turn;
}

/// The flapper resting against [peg], pushed from [side]: 1 by a clockwise
/// wheel, -1 by an anticlockwise one.
class _Contact {
  const _Contact(this.peg, this.side);
  final int peg;
  final int side;
}
