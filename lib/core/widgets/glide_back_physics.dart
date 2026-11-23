import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// iOS-style bouncing that keeps a flick made while the page is past its
/// edge.
///
/// Flutter's [BouncingScrollSimulation] only springs a page back to its
/// edge while it is overscrolled, dropping the speed of any flick made in
/// that moment, so a quick swipe back during the bounce died at the edge.
/// Here a flick back toward the content that is strong enough to reach it
/// glides on from where the page is, as on an iPhone; a weaker one springs
/// back as before, so the page never comes to rest past its edge.
class GlideBackPhysics extends BouncingScrollPhysics {
  const GlideBackPhysics({super.parent});

  @override
  GlideBackPhysics applyTo(ScrollPhysics? ancestor) =>
      GlideBackPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final double x = position.pixels;
    final double min = position.minScrollExtent;
    final double max = position.maxScrollExtent;
    final bool backIn = (x > max && velocity < 0) || (x < min && velocity > 0);
    if (backIn) {
      final double deceleration = switch (decelerationRate) {
        ScrollDecelerationRate.fast => 1400,
        ScrollDecelerationRate.normal => 0,
      };
      // Where the flick would carry the page with nothing in the way; the
      // same 0.135 drag BouncingScrollSimulation uses (UIScrollView's
      // normal deceleration).
      final double rest = FrictionSimulation(
        0.135,
        x,
        velocity,
        constantDeceleration: deceleration,
      ).finalX;
      final bool reachesContent = x > max ? rest < max : rest > min;
      if (reachesContent) {
        // Widening the extents to the page's position makes the simulation
        // start as a glide from here, still bouncing at the far edge.
        return BouncingScrollSimulation(
          spring: spring,
          position: x,
          velocity: velocity,
          leadingExtent: math.min(min, x),
          trailingExtent: math.max(max, x),
          tolerance: toleranceFor(position),
          constantDeceleration: deceleration,
        );
      }
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
