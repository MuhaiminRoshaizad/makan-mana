import '../domain/opening_hours.dart';

const List<String> _weekdays = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// 24-hour time, as the app shows every time: 09:30, 21:30.
String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// One line on whether [hours] has the place open at [now]: "Open until
/// 21:30", "Closed, opens 18:00", "Closed, opens tomorrow 11:00" or "Closed,
/// opens Tue 11:00".
String hoursLine(OpeningHours hours, DateTime now) {
  final bool allDay = hours.days.every(
    (List<(int, int)> d) =>
        d.length == 1 && d.first.$1 == 0 && d.first.$2 >= 1440,
  );
  if (allDay) return 'Open 24 hours';
  final DateTime? closes = hours.closesAfter(now);
  if (closes != null) return 'Open until ${formatTime(closes)}';
  final DateTime? opens = hours.opensAfter(now);
  if (opens == null) return 'Closed';
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int days = DateTime(
    opens.year,
    opens.month,
    opens.day,
  ).difference(today).inDays;
  final String when = switch (days) {
    0 => '',
    1 => 'tomorrow ',
    _ => '${_weekdays[opens.weekday - 1]} ',
  };
  return 'Closed, opens $when${formatTime(opens)}';
}

/// How long ago a review was written, from the month it is known by.
String monthsAgo(DateTime month, DateTime now) {
  final int months = (now.year - month.year) * 12 + now.month - month.month;
  if (months <= 0) return 'This month';
  if (months == 1) return 'Last month';
  if (months < 12) return '$months months ago';
  final int years = months ~/ 12;
  return years == 1 ? 'A year ago' : '$years years ago';
}
