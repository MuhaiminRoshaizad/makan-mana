import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/core/widgets/glide_back_physics.dart';

/// A page 1000 tall to scroll, pulled [pixels] down its length.
ScrollMetrics _at(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 1000,
  pixels: pixels,
  viewportDimension: 800,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 1,
);

void main() {
  const GlideBackPhysics glide = GlideBackPhysics();
  const BouncingScrollPhysics bounce = BouncingScrollPhysics();

  test('a quick flick back during the bounce carries the page into its '
      'content, where Flutter stopped it at the edge', () {
    // 60 past the end, flicked back up hard.
    final Simulation ours = glide.createBallisticSimulation(_at(1060), -3000)!;
    final Simulation flutters = bounce.createBallisticSimulation(
      _at(1060),
      -3000,
    )!;
    expect(ours.x(2), lessThan(800));
    expect(flutters.x(2), greaterThanOrEqualTo(999));
  });

  test('a gentle flick back still springs to the edge and never stops past '
      'it', () {
    final Simulation ours = glide.createBallisticSimulation(_at(1030), -60)!;
    expect(ours.x(5), closeTo(1000, 1));
  });

  test('the same holds at the top', () {
    final Simulation ours = glide.createBallisticSimulation(_at(-60), 3000)!;
    expect(ours.x(2), greaterThan(200));
  });

  test('inside the page a fling is exactly as before', () {
    final Simulation ours = glide.createBallisticSimulation(_at(500), -2000)!;
    final Simulation flutters = bounce.createBallisticSimulation(
      _at(500),
      -2000,
    )!;
    for (final double t in <double>[0.1, 0.5, 1, 2]) {
      expect(ours.x(t), flutters.x(t));
    }
  });

  testWidgets('a short flick up at the peak of the bounce scrolls the list, '
      'where stock bouncing let it fall back to the end', (tester) async {
    Future<double> travelled(ScrollPhysics physics) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            physics: physics,
            itemCount: 60,
            itemBuilder: (_, int i) => SizedBox(height: 80, child: Text('$i')),
          ),
        ),
      );
      final double max = controller.position.maxScrollExtent;
      controller.jumpTo(max - 400);
      await tester.pump();
      await tester.fling(find.byType(ListView), const Offset(0, -300), 8000);
      // Wait for the page to pass its end, then ride the bounce to its
      // peak, where the thumb meets it.
      for (int i = 0; i < 60 && controller.position.pixels <= max; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }
      double last = controller.position.pixels;
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        if (controller.position.pixels <= last) break;
        last = controller.position.pixels;
      }
      expect(last - max, greaterThan(60));
      await tester.fling(find.byType(ListView), const Offset(0, 100), 3000);
      await tester.pumpAndSettle();
      final double distance = max - controller.position.pixels;
      await tester.pumpWidget(const SizedBox());
      return distance;
    }

    expect(
      await travelled(
        const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics()),
      ),
      lessThan(1),
    );
    expect(
      await travelled(
        const GlideBackPhysics(parent: RangeMaintainingScrollPhysics()),
      ),
      greaterThan(500),
    );
  });
}
