import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/domain/opening_hours.dart';

/// 24/11/2026 is a Tuesday.
DateTime tue(int h, [int m = 0]) => DateTime(2026, 11, 24, h, m);

void main() {
  // Closed Monday; lunch and dinner on other days; a late Friday.
  const OpeningHours week = OpeningHours(<List<(int, int)>>[
    <(int, int)>[],
    <(int, int)>[(660, 900), (1080, 1380)],
    <(int, int)>[(660, 900), (1080, 1380)],
    <(int, int)>[(660, 900), (1080, 1380)],
    <(int, int)>[(660, 1560)], // 11:00 to 02:00 Saturday
    <(int, int)>[(660, 1380)],
    <(int, int)>[(660, 1380)],
  ]);

  test('open inside a span, closed between spans and on its day off', () {
    expect(week.isOpenAt(tue(12)), isTrue);
    expect(week.isOpenAt(tue(16)), isFalse);
    expect(week.isOpenAt(tue(19, 30)), isTrue);
    expect(week.isOpenAt(DateTime(2026, 11, 23, 12)), isFalse);
  });

  test('a span that runs past midnight counts into the next morning', () {
    expect(week.isOpenAt(DateTime(2026, 11, 28, 1, 30)), isTrue); // Sat
    expect(week.isOpenAt(DateTime(2026, 11, 28, 2, 30)), isFalse);
  });

  test('a span starts open and ends closed, to the minute', () {
    expect(week.isOpenAt(tue(11)), isTrue);
    expect(week.isOpenAt(tue(15)), isFalse);
  });

  test('it says when it closes, and when it next opens', () {
    expect(week.closesAfter(tue(12)), tue(15));
    expect(week.closesAfter(tue(16)), isNull);
    expect(week.opensAfter(tue(16)), tue(18));
    // From Monday, closed all day, it next opens on Tuesday at 11:00.
    expect(week.opensAfter(DateTime(2026, 11, 23, 9)), tue(11));
    expect(
      week.closesAfter(DateTime(2026, 11, 27, 23)),
      DateTime(2026, 11, 28, 2),
    );
  });
}
