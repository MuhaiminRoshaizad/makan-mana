import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/spin/presentation/spin_wheel.dart';

const List<String> places = <String>[
  'Nasi Kandar Pelita',
  'Warung Soto',
  'Kedai Nasi Ayam',
  'Restoran Mamak',
  'Gerai Laksa',
  'Kopitiam Lama',
  'Restoran Daun Pisang',
  'Kedai Mee Rebus',
  'Restoran Tomyam',
  'Gerai Roti Canai',
];

void main() {
  final List<String> haptics = <String>[];

  setUp(() {
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  late List<int> landed;
  late List<int> current;
  late List<bool> spinning;
  final GlobalKey<SpinWheelState> wheelKey = GlobalKey<SpinWheelState>();

  Future<void> show(WidgetTester tester, {bool reduceMotion = false}) async {
    landed = <int>[];
    current = <int>[];
    spinning = <bool>[];
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(412, 915),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: Column(
              children: <Widget>[
                const SizedBox(height: 380),
                Expanded(
                  child: SpinWheel(
                    key: wheelKey,
                    names: places,
                    labelsEndAbove: 120,
                    random: math.Random(4),
                    onLanded: landed.add,
                    onCurrent: current.add,
                    onSpinning: spinning.add,
                  ),
                ),
                // Stands in for the screen's Spin button, without an ink
                // ripple that would keep asking for frames.
                GestureDetector(
                  onTap: () => wheelKey.currentState!.spin(),
                  child: const SizedBox(height: 48, child: Text('Spin')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> runOut(WidgetTester tester) async {
    for (int i = 0; i < 12 * 60 && landed.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Spin spins the wheel, which lands on the place under the '
      'arrow', (WidgetTester tester) async {
    await show(tester);
    expect(current, hasLength(1));

    await tester.tap(find.text('Spin'));
    await tester.pump();
    expect(spinning, <bool>[true]);

    await runOut(tester);
    expect(landed, hasLength(1));
    expect(spinning, <bool>[true, false]);
    // The place it reported landing on is the one it last showed under the
    // arrow, so the name above the wheel and the result always agree.
    expect(landed.single, current.last);
    expect(current.length, greaterThan(places.length));
  });

  testWidgets('each peg ticks, and the landing has its own heavier tap', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Spin'));
    await tester.pump();
    await runOut(tester);
    final int ticks = haptics
        .where((String h) => h == 'HapticFeedbackType.selectionClick')
        .length;
    expect(ticks, greaterThan(places.length));
    expect(haptics.last, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets('spinning again does nothing while the wheel is spinning', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Spin'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Spin'));
    await tester.pump();
    expect(spinning, <bool>[true]);
    await runOut(tester);
    expect(landed, hasLength(1));
  });

  testWidgets('once it has stopped, the wheel asks for no more frames', (
    WidgetTester tester,
  ) async {
    await show(tester);
    await tester.tap(find.text('Spin'));
    await tester.pump();
    await runOut(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('with Reduce Motion the result comes at once, from the same '
      'physics', (WidgetTester tester) async {
    await show(tester, reduceMotion: true);
    await tester.tap(find.text('Spin'));
    await tester.pump();
    expect(landed, hasLength(1));
    expect(landed.single, current.last);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a fast flick across the wheel throws a spin', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final Rect wheel = tester.getRect(find.bySemanticsLabel('Lunch wheel'));
    // Down the right-hand side: clockwise.
    await tester.flingFrom(
      wheel.centerRight - const Offset(40, 80),
      const Offset(0, 200),
      4000,
    );
    await tester.pump();
    expect(spinning, <bool>[true]);
    await runOut(tester);
    expect(landed, hasLength(1));
  });

  testWidgets('a slow drag turns the wheel but is not a spin', (
    WidgetTester tester,
  ) async {
    await show(tester);
    final int before = current.last;
    final Rect wheel = tester.getRect(find.bySemanticsLabel('Lunch wheel'));
    final TestGesture g = await tester.startGesture(
      wheel.centerRight - const Offset(40, 100),
    );
    for (int i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pumpAndSettle();
    expect(current.last, isNot(before));
    expect(spinning, isEmpty);
    expect(landed, isEmpty);
  });

  test('a finger moving clockwise round the centre throws clockwise', () {
    // Right of centre, moving down: clockwise on screen.
    expect(
      throwSpeed(const Offset(100, 0), const Offset(0, 300), 10),
      greaterThan(0),
    );
    // Left of centre, moving down: anticlockwise.
    expect(
      throwSpeed(const Offset(-100, 0), const Offset(0, 300), 10),
      lessThan(0),
    );
    // Straight out along the radius turns nothing.
    expect(throwSpeed(const Offset(100, 0), const Offset(300, 0), 10), 0);
    // 3 rad/s on a 10-place wheel is 3 / (2pi / 10) segments a second.
    expect(
      throwSpeed(const Offset(100, 0), const Offset(0, 300), 10),
      closeTo(3 / (2 * math.pi / 10), 1e-9),
    );
  });
}
