/// A place's usual week: for each day, the spans it is open, in minutes
/// from that day's midnight. A span may run past 1440, into the next day.
class OpeningHours {
  const OpeningHours(this.days);

  /// Seven days, Monday first, as [DateTime.weekday] counts from 1.
  final List<List<(int, int)>> days;

  /// Whether it is open at [time], counting a late span from the day before.
  bool isOpenAt(DateTime time) {
    final int minute = time.hour * 60 + time.minute;
    final int today = time.weekday - 1;
    final int yesterday = (today + 6) % 7;
    for (final (int open, int close) in days[today]) {
      if (minute >= open && minute < close) return true;
    }
    for (final (int _, int close) in days[yesterday]) {
      if (close > 1440 && minute < close - 1440) return true;
    }
    return false;
  }

  /// When the span holding [time] ends, or null when closed then.
  DateTime? closesAfter(DateTime time) {
    final DateTime midnight = DateTime(time.year, time.month, time.day);
    final int minute = time.hour * 60 + time.minute;
    final int today = time.weekday - 1;
    for (final (int open, int close) in days[today]) {
      if (minute >= open && minute < close) {
        return midnight.add(Duration(minutes: close));
      }
    }
    final int yesterday = (today + 6) % 7;
    for (final (int _, int close) in days[yesterday]) {
      if (close > 1440 && minute < close - 1440) {
        return midnight.add(Duration(minutes: close - 1440));
      }
    }
    return null;
  }

  /// The next opening after [time] within a week, or null if it never opens.
  DateTime? opensAfter(DateTime time) {
    final DateTime midnight = DateTime(time.year, time.month, time.day);
    final int minute = time.hour * 60 + time.minute;
    for (int ahead = 0; ahead < 7; ahead++) {
      final int day = (time.weekday - 1 + ahead) % 7;
      final List<int> opens = days[day].map(((int, int) s) => s.$1).toList()
        ..sort();
      for (final int open in opens) {
        if (ahead > 0 || open > minute) {
          return midnight.add(Duration(days: ahead, minutes: open));
        }
      }
    }
    return null;
  }
}
