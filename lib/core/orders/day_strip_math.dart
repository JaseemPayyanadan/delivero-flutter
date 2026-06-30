/// Index of "today" in the day strip's infinite horizontal scroll list. A large
/// base lets the strip scroll far into the past (index 0 is this many days
/// before today) and unbounded into the future.
const int kDayStripBaseIndex = 10000;

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Normalizes [value] to a date-only key (midnight local).
DateTime calendarDayKey(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Date-only Sunday of the calendar week containing [now].
DateTime currentWeekSunday(DateTime now) {
  final today = _dayKey(now);
  final daysFromSunday = today.weekday == 7 ? 0 : today.weekday;
  return today.subtract(Duration(days: daysFromSunday));
}

/// The date-only day shown at list [index] ([kDayStripBaseIndex] is today).
DateTime dayForIndex(DateTime now, int index) {
  return _dayKey(now).add(Duration(days: index - kDayStripBaseIndex));
}

/// The list index that shows [date].
int dayIndexForDate(DateTime now, DateTime date) {
  return kDayStripBaseIndex + _dayKey(date).difference(_dayKey(now)).inDays;
}

/// First day index to show when the strip opens: the Sunday of the current
/// week, so the strip is framed on this week with today in view.
int initialDayStripIndex(DateTime now) {
  return dayIndexForDate(now, currentWeekSunday(now));
}

/// Nearest calendar day in [days] to [from], preferring the same day or earlier.
DateTime? nearestDayWithOrders(DateTime from, Set<DateTime> days) {
  if (days.isEmpty) return null;
  final sorted = days.toList()..sort();
  DateTime? before;
  DateTime? after;
  for (final d in sorted) {
    if (!d.isAfter(from)) {
      before = d;
    } else {
      after ??= d;
    }
  }
  return before ?? after;
}
