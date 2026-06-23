/// Page index of the current week in the swipeable week strip's [PageView].
/// A large base lets the strip page backwards (older weeks) and forwards
/// (future weeks) effectively without limit.
const int kWeekStripBasePage = 10000;

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Date-only Sunday of the calendar week containing [now].
DateTime currentWeekSunday(DateTime now) {
  final today = _dayKey(now);
  final daysFromSunday = now.weekday == 7 ? 0 : now.weekday;
  return today.subtract(Duration(days: daysFromSunday));
}

/// The 7 date-only days (Sun..Sat) for the week at [weekOffset] relative to
/// the week containing [now] (0 = current week, -1 = last week, etc.).
List<DateTime> weekDaysForOffset(DateTime now, int weekOffset) {
  final sunday = currentWeekSunday(now).add(Duration(days: weekOffset * 7));
  return List.generate(7, (i) => sunday.add(Duration(days: i)));
}

/// The [PageView] page index whose week contains [date].
int weekPageForDate(DateTime now, DateTime date) {
  final deltaDays =
      currentWeekSunday(date).difference(currentWeekSunday(now)).inDays;
  return kWeekStripBasePage + (deltaDays ~/ 7);
}
