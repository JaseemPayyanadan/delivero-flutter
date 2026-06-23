// test/week_strip_math_test.dart
import 'package:delivero/features/owner/orders/week_strip_math.dart';
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

  group('weekDaysForOffset', () {
    test('offset 0 is the current Sun..Sat week', () {
      final days = weekDaysForOffset(now, 0);
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 6, 21));
      expect(days.last, DateTime(2026, 6, 27));
    });

    test('offset -1 is the previous week', () {
      expect(weekDaysForOffset(now, -1).first, DateTime(2026, 6, 14));
    });

    test('offset +1 crosses the month boundary', () {
      final days = weekDaysForOffset(now, 1);
      expect(days.first, DateTime(2026, 6, 28));
      expect(days.last, DateTime(2026, 7, 4));
    });
  });

  group('weekPageForDate', () {
    test('a date in the current week maps to the base page', () {
      expect(weekPageForDate(now, DateTime(2026, 6, 23)), kWeekStripBasePage);
    });

    test('a future week maps forward from the base page', () {
      // 1 Jul 2026 is in the week of Sun 28 Jun -> one week ahead.
      expect(weekPageForDate(now, DateTime(2026, 7, 1)), kWeekStripBasePage + 1);
    });

    test('a past week maps backward from the base page', () {
      // 10 Jun 2026 is in the week of Sun 7 Jun -> two weeks behind.
      expect(weekPageForDate(now, DateTime(2026, 6, 10)), kWeekStripBasePage - 2);
    });

    test('round-trips: the page for a date contains that date', () {
      final date = DateTime(2026, 8, 5);
      final page = weekPageForDate(now, date);
      final days = weekDaysForOffset(now, page - kWeekStripBasePage);
      expect(days.contains(DateTime(2026, 8, 5)), isTrue);
    });
  });
}
