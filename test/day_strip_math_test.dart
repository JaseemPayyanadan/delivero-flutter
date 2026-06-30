import 'package:delivero/core/orders/day_strip_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wed 24 Jun 2026, 3 PM. That week's Sunday is 21 Jun 2026.
  final now = DateTime(2026, 6, 24, 15);

  group('currentWeekSunday', () {
    test('returns the date-only Sunday of the given week', () {
      expect(currentWeekSunday(now), DateTime(2026, 6, 21));
    });

    test('a Sunday maps to itself', () {
      expect(currentWeekSunday(DateTime(2026, 6, 21, 9)), DateTime(2026, 6, 21));
    });
  });

  group('dayForIndex', () {
    test('the base index is today (date-only)', () {
      expect(dayForIndex(now, kDayStripBaseIndex), DateTime(2026, 6, 24));
    });

    test('+1 is tomorrow, -1 is yesterday', () {
      expect(dayForIndex(now, kDayStripBaseIndex + 1), DateTime(2026, 6, 25));
      expect(dayForIndex(now, kDayStripBaseIndex - 1), DateTime(2026, 6, 23));
    });

    test('returns date-only values (no time component)', () {
      final d = dayForIndex(now, kDayStripBaseIndex + 3);
      expect(d.hour, 0);
      expect(d.minute, 0);
      expect(d.second, 0);
    });
  });

  group('dayIndexForDate', () {
    test('today maps to the base index', () {
      expect(dayIndexForDate(now, DateTime(2026, 6, 24)), kDayStripBaseIndex);
    });

    test('future and past dates offset from the base index', () {
      expect(dayIndexForDate(now, DateTime(2026, 6, 29)), kDayStripBaseIndex + 5);
      expect(dayIndexForDate(now, DateTime(2026, 6, 21)), kDayStripBaseIndex - 3);
    });

    test('round-trips with dayForIndex', () {
      final date = DateTime(2026, 8, 5, 11);
      final index = dayIndexForDate(now, date);
      expect(dayForIndex(now, index), DateTime(2026, 8, 5));
    });
  });

  group('initialDayStripIndex', () {
    test('frames the strip on the current week (its Sunday)', () {
      // currentWeekSunday(now) is Sun 21 Jun -> 3 days before today.
      expect(initialDayStripIndex(now), kDayStripBaseIndex - 3);
    });
  });
}
