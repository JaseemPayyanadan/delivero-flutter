# Swipeable week strip — design

**Date:** 2026-06-23
**Status:** Approved (pending spec review)
**Supersedes:** the "Fix 2 — Swipeable week strip" section of
`docs/superpowers/specs/2026-06-15-order-flow-fixes-design.md` (the calendar-jump
icon from that spec is already implemented; the swipe behavior was not).

## Context

The Orders screen (`lib/features/owner/orders/order_list_screen.dart`) shows a
horizontal week strip (`_WeekStrip`) of Sun–Sat day cells for tapping a day to
filter the list. Today it is **static**: it always renders the current calendar
week computed from `DateTime.now()`, so there is no way to reach other weeks by
gesture. A calendar icon + `_pickDate()` already lets the owner jump to an
arbitrary date via `showDatePicker`.

Date handling across the screen is **calendar-date based** (the filter compares
`_calendarDay(order.orderDate) == _selectedDate`, and grouping buckets by
`_calendarDay`). This feature does not change that.

## Goal

Let the owner swipe the week strip left/right to move between weeks, in both
directions without limit, and have the calendar picker jump the strip to the
chosen date's week.

## Behavior

### Swipe navigation

- The week strip is wrapped in a horizontal `PageView` (`PageView.builder`).
- Each page renders exactly one Sun–Sat week of 7 day cells.
- Paging is effectively infinite in **both** directions: a large
  `initialPage` (10000) represents the current week. For any page index, the
  week offset is `index - 10000`, and the page's Sunday is
  `currentWeekSunday.add(Duration(days: weekOffset * 7))`.
- `currentWeekSunday` is derived from `DateTime.now()` the same way `_WeekStrip`
  does today: `todayKey = _calendarDay(now)`,
  `daysFromSunday = now.weekday == 7 ? 0 : now.weekday`,
  `sunday = todayKey.subtract(Duration(days: daysFromSunday))`.
- Swiping changes only which week is visible. It does **not** change the active
  day filter (`_selectedDate`). There is no auto-deselect on swipe.

### Selecting a day

- Tapping a day cell sets `_selectedDate` to that day; tapping the already
  selected day clears it (existing `onDayTap` semantics — unchanged).
- A day cell shows its "selected" highlight only when its week is the visible
  page. If the user swipes to a different week, the filter remains active but no
  cell is highlighted (the selected day simply isn't on screen).
- "Today" highlighting (`isToday`) and past styling (`isPast`) are computed per
  day cell against `todayKey` exactly as today.

### Calendar-picker jump

- The existing calendar icon / `_pickDate()` is unchanged in how it picks a date
  (`showDatePicker`, `firstDate: DateTime(2023)`,
  `lastDate: now + 365 days`).
- On a date being picked, in addition to setting
  `_selectedDate = _calendarDay(picked)`, the strip animates to the page whose
  week contains that date, so the picked day lands highlighted in view.
- The target page is computed from the whole-week delta between the picked
  date's Sunday and `currentWeekSunday`.

### Header label follows the visible week

- The month/year label shown above the strip when no date is selected
  (currently `DateFormat('MMMM yyyy').format(DateTime.now())`) instead reflects
  the **currently visible week**.
- The visible week is tracked in state via the `PageView`'s `onPageChanged`.
- The label uses a representative day of the visible week (its Wednesday/
  midpoint, `visibleSunday.add(Duration(days: 3))`) so a week spanning a
  month boundary shows the month that contains most of it.
- When a date **is** selected, the existing selected-date chip (with the clear
  "×") is shown instead, unchanged.

### Discoverability — chevron hints

- Faint, non-tappable chevron icons sit at the left and right edges of the strip
  (e.g. `Icons.chevron_left_rounded` / `chevron_right_rounded`,
  low opacity, `IgnorePointer`).
- Both are always shown, since paging is unbounded in both directions.
- They are purely visual cues that the strip is swipeable; they are not buttons.

## Implementation notes

All changes are in `lib/features/owner/orders/order_list_screen.dart`.

### State (`_OrderListScreenState`)

- Add `late final PageController _weekPageController;` initialized in
  `initState` with `initialPage: 10000` (add an `initState` — the class does not
  have one yet).
- Add `int _visibleWeekOffset = 0;` updated in `onPageChanged`.
- Dispose `_weekPageController` in the existing `dispose()`.

### Widget structure

- A new small helper computes the 7 `DateTime` day-keys for a given week offset.
- `_WeekStrip` is refactored to accept an explicit `List<DateTime> days` (plus
  `selectedDate`, `todayKey`, `onDayTap`) instead of computing the week from
  `now`. The day-cell rendering (`_DayCell`) is unchanged.
- The strip area becomes: a fixed-height `SizedBox` containing a `Stack` of the
  `PageView.builder` (building one `_WeekStrip` per page) with the two faint
  edge chevrons overlaid via `IgnorePointer`/`Positioned`.
- A fixed height is required because `PageView` needs bounded height; size it to
  the current strip's intrinsic height so layout is visually unchanged.

### Filtering

- No change. `matchesDay` already filters on `_selectedDate`, and `_selectedDate`
  is still set only by tapping a day or picking a date.

## Out of scope

- No change to how orders are grouped, sorted, or to the calendar-date filter
  model.
- No change to route/payment/status filters or the search sheet.
- No persistence of the visible week across screen rebuilds/navigation (the
  strip resets to the current week when the screen is re-entered).
- No month-level (as opposed to week-level) swiping.

## Testing

- Unit-test the pure week-math helpers with deterministic inputs:
  - week offset → list of 7 day-keys (correct Sunday start, 7 consecutive days,
    correct offset).
  - picked date → target page index (round-trips: page for offset 0 is 10000;
    a date N weeks ahead/behind maps to 10000 ± N).
- Manual verification on device: swipe back/forward across month boundaries,
  confirm header month updates; tap a day in a non-current week and confirm the
  list filters; pick a future date from the calendar and confirm the strip jumps
  with the day highlighted.
