import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/spin/domain/wheel_physics.dart';

/// Runs a spin to rest at 60 frames a second, as the screen does.
({double seconds, int clicks, bool rolledBack}) spinToRest(WheelPhysics w) {
  double seconds = 0;
  int clicks = 0;
  bool rolledBack = false;
  while (seconds < 30) {
    final ({List<PegClick> clicks, bool stopped}) r = w.advance(1 / 60);
    seconds += 1 / 60;
    clicks += r.clicks.length;
    if (w.speed < 0) rolledBack = true;
    if (r.stopped) break;
  }
  return (seconds: seconds, clicks: clicks, rolledBack: rolledBack);
}

void main() {
  test('the arrow reads the segment the wheel has turned under it', () {
    WheelPhysics at(double turn) => WheelPhysics(segments: 14, turn: turn);
    expect(at(0).segmentUnderArrow, 0);
    expect(at(-0.5).segmentUnderArrow, 0);
    expect(at(-1.2).segmentUnderArrow, 1);
    // Turned clockwise, the segment before 0 comes under the arrow.
    expect(at(0.5).segmentUnderArrow, 13);
    expect(at(14.5).segmentUnderArrow, 13);
  });

  test('a tap spin turns about two times and stops within 4 to 8 seconds', () {
    final math.Random rng = math.Random(7);
    for (int i = 0; i < 40; i++) {
      final WheelPhysics w = WheelPhysics(
        segments: 14,
        turn: rng.nextDouble() * 14,
      )..fling(10 + rng.nextDouble() * 5);
      final ({double seconds, int clicks, bool rolledBack}) r = spinToRest(w);
      expect(r.seconds, inInclusiveRange(3, 8), reason: 'spin $i');
      expect(r.clicks, inInclusiveRange(14, 60), reason: 'spin $i');
      expect(w.isMoving, isFalse);
    }
  });

  test('some spins stall against a peg and roll back: the near-miss is not '
      'scripted', () {
    final math.Random rng = math.Random(3);
    int back = 0;
    const int runs = 300;
    for (int i = 0; i < runs; i++) {
      final WheelPhysics w = WheelPhysics(
        segments: 14,
        turn: rng.nextDouble() * 14,
      )..fling(10 + rng.nextDouble() * 5);
      if (spinToRest(w).rolledBack) back++;
    }
    // The simulation found about a third; anything clearly above zero and
    // short of always is the behaviour wanted.
    expect(back / runs, inInclusiveRange(0.15, 0.6));
  });

  test('every place has the same chance (chi-square under the 5% critical '
      'value)', () {
    const int n = 14;
    const int runs = 2800;
    final math.Random rng = math.Random(11);
    final List<int> counts = List<int>.filled(n, 0);
    for (int i = 0; i < runs; i++) {
      final WheelPhysics w = WheelPhysics(
        segments: n,
        turn: rng.nextDouble() * n,
      )..fling(10 + rng.nextDouble() * 5);
      spinToRest(w);
      counts[w.segmentUnderArrow]++;
    }
    const double expected = runs / n;
    final double chi = counts.fold<double>(
      0,
      (double sum, int c) => sum + (c - expected) * (c - expected) / expected,
    );
    // 13 degrees of freedom.
    expect(chi, lessThan(22.36), reason: '$counts');
  });

  test('a wheel at rest is never left pushed by the flapper harder than '
      'friction holds', () {
    final math.Random rng = math.Random(5);
    for (int i = 0; i < 100; i++) {
      final WheelPhysics w = WheelPhysics(
        segments: 9,
        turn: rng.nextDouble() * 9,
      )..fling(3 + rng.nextDouble() * 15);
      spinToRest(w);
      expect(w.flapperBend, 0);
      final double before = w.turn;
      w.advance(1);
      expect(w.turn, before, reason: 'it must stay where it stopped');
    }
  });

  test('a throw is capped at the top speed, in either direction', () {
    final WheelPhysics w = WheelPhysics(segments: 10, turn: 0)..fling(90);
    expect(w.speed, 18);
    w.fling(-90);
    expect(w.speed, -18);
  });

  test('the flapper bends as a peg comes and clicks once as it slips past', () {
    final WheelPhysics w = WheelPhysics(segments: 10, turn: 0.5)..fling(4);
    double most = 0;
    int clicks = 0;
    while (w.turn < 1) {
      final ({List<PegClick> clicks, bool stopped}) r = w.advance(1 / 240);
      most = math.max(most, w.flapperBend);
      clicks += r.clicks.length;
      if (r.stopped) break;
    }
    expect(most, greaterThan(0.5));
    expect(clicks, 1);
  });

  test('dragging by hand stops the spin and clicks for each peg crossed', () {
    final WheelPhysics w = WheelPhysics(segments: 10, turn: 0.2)..fling(12);
    final List<PegClick> clicks = w.drag(2.5);
    expect(w.speed, 0);
    expect(clicks.length, 2);
    expect(clicks.every((PegClick c) => c.forward), isTrue);
    expect(w.drag(-1).single.forward, isFalse);
  });

  test('a bigger wheel spins as many times round, in the same time, with '
      'the same near-misses', () {
    ({double turns, double seconds, double rolledBack}) average(int n) {
      final math.Random rng = math.Random(13);
      const int runs = 300;
      double turns = 0, seconds = 0, back = 0;
      for (int i = 0; i < runs; i++) {
        final WheelPhysics w = WheelPhysics(
          segments: n,
          turn: rng.nextDouble() * n,
        )..fling((10 + rng.nextDouble() * 5) * WheelPhysics.scaleFor(n));
        final double from = w.turn;
        final ({double seconds, int clicks, bool rolledBack}) r = spinToRest(w);
        turns += (w.turn - from) / n;
        seconds += r.seconds;
        if (r.rolledBack) back++;
      }
      return (
        turns: turns / runs,
        seconds: seconds / runs,
        rolledBack: back / runs,
      );
    }

    final ({double turns, double seconds, double rolledBack}) tuned = average(
      WheelPhysics.tunedFor,
    );
    for (final int n in <int>[20, 40, 100]) {
      final ({double turns, double seconds, double rolledBack}) big = average(
        n,
      );
      expect(big.turns, closeTo(tuned.turns, 0.15), reason: '$n places');
      expect(big.seconds, closeTo(tuned.seconds, 0.5), reason: '$n places');
      expect(
        big.rolledBack,
        closeTo(tuned.rolledBack, 0.08),
        reason: '$n places',
      );
    }
  });

  test('a wheel of 40 places is still fair (chi-square under the 5% '
      'critical value)', () {
    const int n = 40;
    const int runs = 4000;
    final math.Random rng = math.Random(17);
    final List<int> counts = List<int>.filled(n, 0);
    for (int i = 0; i < runs; i++) {
      final WheelPhysics w = WheelPhysics(
        segments: n,
        turn: rng.nextDouble() * n,
      )..fling((10 + rng.nextDouble() * 5) * WheelPhysics.scaleFor(n));
      spinToRest(w);
      counts[w.segmentUnderArrow]++;
    }
    const double expected = runs / n;
    final double chi = counts.fold<double>(
      0,
      (double sum, int c) => sum + (c - expected) * (c - expected) / expected,
    );
    // 39 degrees of freedom.
    expect(chi, lessThan(54.57), reason: '$counts');
  });

  test('a wheel of 14 places or fewer keeps the tuned speeds', () {
    expect(WheelPhysics.scaleFor(5), 1);
    expect(WheelPhysics.scaleFor(14), 1);
    expect(WheelPhysics.scaleFor(28), 2);
    final WheelPhysics big = WheelPhysics(segments: 28, turn: 0)..fling(90);
    expect(big.speed, 36);
  });
}
