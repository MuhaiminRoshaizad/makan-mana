import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/features/places/domain/opening_hours.dart';
import 'package:makan_mana/features/places/presentation/hours_text.dart';

/// 24/11/2026 is a Tuesday.
DateTime tue(int h, [int m = 0]) => DateTime(2026, 11, 24, h, m);

void main() {
  // Closed Monday and Wednesday; lunch and dinner otherwise.
  const List<(int, int)> twoShifts = <(int, int)>[(660, 900), (1080, 1350)];
  const OpeningHours week = OpeningHours(<List<(int, int)>>[
    <(int, int)>[],
    twoShifts,
    <(int, int)>[],
    twoShifts,
    twoShifts,
    twoShifts,
    twoShifts,
  ]);

  test('open: it says until when, in 24-hour time', () {
    expect(hoursLine(week, tue(12)), 'Open until 15:00');
    expect(hoursLine(week, tue(19)), 'Open until 22:30');
  });

  test('closed: it says when it opens next, today, tomorrow or by day', () {
    expect(hoursLine(week, tue(16)), 'Closed, opens 18:00');
    // Tuesday night, closed Wednesday: next is Thursday.
    expect(hoursLine(week, tue(23)), 'Closed, opens Thu 11:00');
    // Monday morning: Tuesday is tomorrow.
    expect(
      hoursLine(week, DateTime(2026, 11, 23, 9)),
      'Closed, opens tomorrow 11:00',
    );
  });

  test('a place open round the clock says so', () {
    const OpeningHours always = OpeningHours(<List<(int, int)>>[
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
      <(int, int)>[(0, 1440)],
    ]);
    expect(hoursLine(always, tue(3)), 'Open 24 hours');
  });

  test('a review reads as how long ago it was written', () {
    final DateTime now = DateTime(2026, 11, 24);
    expect(monthsAgo(DateTime(2026, 11), now), 'This month');
    expect(monthsAgo(DateTime(2026, 10), now), 'Last month');
    expect(monthsAgo(DateTime(2026, 8), now), '3 months ago');
    expect(monthsAgo(DateTime(2025, 11), now), 'A year ago');
    expect(monthsAgo(DateTime(2022, 11), now), '4 years ago');
  });
}
