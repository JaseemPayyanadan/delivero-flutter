# Swipeable Week Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Orders-screen week strip swipeable across weeks (infinitely, both directions), with the month header following the visible week and the calendar picker jumping the strip to the picked date's week.

**Architecture:** Extract pure week-math helpers into a small testable file. Refactor `_WeekStrip` to render one explicit week (a `List<DateTime>`), then drive it with a `PageView.builder` whose page index maps to a week offset around a fixed base page (10000 = current week). State tracks the visible week offset and a `PageController`; the calendar picker animates the controller.

**Tech Stack:** Flutter, Dart, Riverpod (existing), `flutter_test`, `intl` (`DateFormat`).

## Global Constraints

- All UI changes live in `lib/features/owner/orders/order_list_screen.dart`; pure helpers in a new `lib/features/owner/orders/week_strip_math.dart`.
- Date model is calendar-date based (unchanged): days are date-only `DateTime(y, m, d)`; `_calendarDay` already exists for this.
- Follow existing file style: private widgets prefixed `_`, `AppColors` for colors, `DateFormat` for labels, `.withValues(alpha:)` for opacity.
- Do not change the order filter/grouping logic or any other filter.
- Verify with `flutter analyze` (no new issues) and `flutter test` (full suite stays green) for every task.

---

### Task 1: Pure week-math helpers + unit tests

**Files:**
- Create: `lib/features/owner/orders/week_strip_math.dart`
- Test: `test/week_strip_math_test.dart`

**Interfaces:**
- Produces:
  - `const int kWeekStripBasePage` (= 10000)
  - `DateTime currentWeekSunday(DateTime now)` — date-only Sunday of `now`'s week
  - `List<DateTime> weekDaysForOffset(DateTime now, int weekOffset)` — 7 date-only days (Sun..Sat) for the week at `weekOffset` (0 = current week)
  - `int weekPageForDate(DateTime now, DateTime date)` — `PageView` page index whose week contains `date`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/week_strip_math_test.dart`
Expected: FAIL — `week_strip_math.dart` / its functions not found (compile error).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/owner/orders/week_strip_math.dart

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/week_strip_math_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/week_strip_math.dart test/week_strip_math_test.dart
git commit -m "feat: add pure week-math helpers for swipeable week strip"
```

---

### Task 2: Make the week strip swipeable

Refactor `_WeekStrip` to render one explicit week, then drive it with a `PageView` plus a `PageController` and faint edge chevrons. After this task the strip swipes infinitely both ways and tapping a day in any visible week filters the list.

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`
- Test: `test/widget_test.dart` (existing smoke test must still pass — no new test added; widget behavior is verified by analyze + manual)

**Interfaces:**
- Consumes (from Task 1): `kWeekStripBasePage`, `weekDaysForOffset`.
- Produces (used by Tasks 3 & 4): state fields `PageController _weekPageController`, `int _visibleWeekOffset`; new top-level `const double _kWeekStripHeight`.

- [ ] **Step 1: Add the import**

At the top of `lib/features/owner/orders/order_list_screen.dart`, with the other relative imports (after the `widgets/order_card.dart` import):

```dart
import 'week_strip_math.dart';
```

- [ ] **Step 2: Add the strip-height constant**

Immediately above `class OrderListScreen extends ConsumerStatefulWidget {`:

```dart
/// Fixed height for the swipeable week strip (a [PageView] needs bounded
/// height). Sized to comfortably fit one `_WeekStrip` row.
const double _kWeekStripHeight = 88;
```

- [ ] **Step 3: Add controller + visible-week state and an initState**

In `_OrderListScreenState`, add fields after `Timer? _highlightClearTimer;`:

```dart
  late final PageController _weekPageController;
  int _visibleWeekOffset = 0;
```

Add an `initState` immediately before the existing `dispose()`:

```dart
  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: kWeekStripBasePage);
  }
```

And add the controller disposal inside the existing `dispose()` (before `super.dispose();`):

```dart
    _weekPageController.dispose();
```

- [ ] **Step 4: Refactor `_WeekStrip` to render one explicit week**

Replace the whole `_WeekStrip` class (currently the version that computes the week from `DateTime.now()`) with:

```dart
class _WeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime todayKey;
  final DateTime? selectedDate;
  final void Function(DateTime?) onDayTap;

  const _WeekStrip({
    required this.days,
    required this.todayKey,
    required this.selectedDate,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isToday = day == todayKey;
          final isSelected = selectedDate == day;
          final isPast = day.isBefore(todayKey);
          return _DayCell(
            day: day,
            isToday: isToday,
            isSelected: isSelected,
            isPast: isPast,
            onTap: () => onDayTap(isSelected ? null : day),
          );
        }).toList(),
      ),
    );
  }
}
```

(`_DayCell` is unchanged.)

- [ ] **Step 5: Replace the strip call site with the swipeable PageView**

In `_buildFilters`, replace the existing strip call:

```dart
        _WeekStrip(
          selectedDate: _selectedDate,
          onDayTap: (date) => setState(() => _selectedDate = date),
        ),
```

with:

```dart
        SizedBox(
          height: _kWeekStripHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _weekPageController,
                onPageChanged: (page) => setState(
                  () => _visibleWeekOffset = page - kWeekStripBasePage,
                ),
                itemBuilder: (context, page) {
                  final now = DateTime.now();
                  return _WeekStrip(
                    days: weekDaysForOffset(now, page - kWeekStripBasePage),
                    todayKey: _calendarDay(now),
                    selectedDate: _selectedDate,
                    onDayTap: (date) => setState(() => _selectedDate = date),
                  );
                },
              ),
              Positioned(
                left: 2,
                child: IgnorePointer(
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: AppColors.textLight.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                child: IgnorePointer(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textLight.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
```

- [ ] **Step 6: Analyze**

Run: `dart analyze lib/features/owner/orders/order_list_screen.dart lib/features/owner/orders/week_strip_math.dart`
Expected: `No issues found!`

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (the `widget_test.dart` smoke test confirms the screen still builds).

- [ ] **Step 8: Manual verification**

Launch the app, open Orders. Swipe the strip left (older weeks) and right (future weeks) — it should page one week at a time, infinitely both directions. Tap a day in a non-current week and confirm the list filters to that day. Check the console for no `RenderFlex`/overflow errors on the strip (if any appear, raise `_kWeekStripHeight`).

- [ ] **Step 9: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: make order-list week strip swipeable across weeks"
```

---

### Task 3: Month header follows the visible week

The month/year label shown when no date is selected currently reads `DateTime.now()`. Make it reflect the visible week so swiping across a month boundary updates it.

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`

**Interfaces:**
- Consumes: `_visibleWeekOffset` (Task 2), `weekDaysForOffset` (Task 1).

- [ ] **Step 1: Update the header label**

In `_buildFilters`, replace the no-date-selected branch:

```dart
                    : Text(
                        DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
```

with (uses the visible week's Wednesday — index 3 — so a month-straddling week shows the month containing most of it):

```dart
                    : Text(
                        DateFormat('MMMM yyyy').format(
                          weekDaysForOffset(
                            DateTime.now(),
                            _visibleWeekOffset,
                          )[3],
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
```

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/features/owner/orders/order_list_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Manual verification**

With no date selected, swipe from late June into July and back; the header label should switch between "June 2026" and "July 2026" as the visible week changes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: week-strip month header follows the visible week"
```

---

### Task 4: Calendar picker jumps the strip to the picked week

When a date is picked from the calendar icon, animate the strip to the week containing that date so the picked (now-selected) day lands in view.

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`

**Interfaces:**
- Consumes: `_weekPageController` (Task 2), `weekPageForDate` (Task 1).

- [ ] **Step 1: Animate the strip after picking a date**

In `_pickDate`, replace:

```dart
    if (picked != null && mounted) {
      setState(() => _selectedDate = _calendarDay(picked));
    }
```

with:

```dart
    if (picked != null && mounted) {
      setState(() => _selectedDate = _calendarDay(picked));
      final page = weekPageForDate(DateTime.now(), picked);
      if (_weekPageController.hasClients) {
        _weekPageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
```

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/features/owner/orders/order_list_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Manual verification**

Tap the calendar icon, pick a date several weeks in the past and then one in the future. Each time, the strip should animate to that date's week with the picked day highlighted, and the list should filter to it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: calendar picker jumps week strip to the picked date's week"
```

---

## Self-Review

**Spec coverage:**
- Swipe both directions, infinite, one week per page → Task 2 (`PageView.builder`, no `itemCount`, base page 10000). ✓
- `_WeekStrip` takes explicit `List<DateTime> days` → Task 2 Step 4. ✓
- Swipe does not change the filter; highlight only on visible week → Task 2 (only `onDayTap` mutates `_selectedDate`; `isSelected` is per visible cell). ✓
- Calendar jump animates to picked week → Task 4. ✓
- Header follows visible week (Wednesday/midpoint) → Task 3. ✓
- Faint non-tappable chevrons both edges → Task 2 Step 5 (`IgnorePointer`, low alpha). ✓
- Pure week-math unit tests → Task 1. ✓
- No change to filtering/grouping model → confirmed; no task touches `matchesDay` or grouping. ✓
- State: `PageController` (initialPage 10000), `_visibleWeekOffset`, disposed → Task 2 Steps 3. ✓

**Placeholder scan:** none — every code step shows complete code; every run step has an exact command and expected result.

**Type consistency:** `kWeekStripBasePage`, `weekDaysForOffset(now, offset)`, `weekPageForDate(now, date)`, `currentWeekSunday(now)` used identically across Tasks 1–4. `_WeekStrip` constructor params (`days`, `todayKey`, `selectedDate`, `onDayTap`) match the call site in Task 2 Step 5. `_kWeekStripHeight` defined (Step 2) before use (Step 5). ✓
