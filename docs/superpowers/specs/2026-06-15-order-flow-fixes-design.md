# Order Flow Fixes — Design Spec
**Date:** 2026-06-15
**Status:** Approved

---

## Problem Summary

Two issues in the current order flow:

1. **Stale pending orders accumulate** — when the business day rolls over, daily orders that were never delivered remain `pending` indefinitely. Auto-recreation then creates a fresh order for today, leaving the owner with orphaned pending orders from past days cluttering the list.

2. **Week strip is locked to the current week** — the date filter bar only shows the current Sun–Sat week with no way to navigate to previous weeks or jump to a specific past date.

---

## Fix 1 — Unresolved orders summary popup at rollover

### Behaviour

When the app detects a new business day (rollover has passed) and there are daily orders from yesterday still in an unresolved state (`pending`, `confirmed`, `preparing`, or `ready`), it shows a **bottom sheet summary** before auto-recreation runs.

The popup:
- Lists each unresolved order from yesterday: customer name, items summary, total, current status
- For each order the owner can tap **Mark Delivered** or **Cancel**
- A **Done** button at the bottom dismisses the sheet and triggers the normal auto-recreation pass
- If there are no unresolved orders, the popup is skipped entirely and recreation runs silently

The owner stays in control — the app does not auto-cancel or auto-deliver anything. Recreation only runs after the owner dismisses the popup (or if there is nothing to review).

### When it appears

- On app foreground/resume, after rollover is detected and before `runRolloverBatch` fires
- Only shown once per business day (gated by the same `lastRunDay` preference already used by the recreation service)
- If the owner force-quits without acting, it reappears the next time they open the app on the same day

### Implementation touch points

- `daily_order_recreation_service.dart` — add a `findUnresolvedSourceOrders(sourceDay, orders)` helper that returns daily orders from yesterday with status not in `{delivered, cancelled}`
- New widget `UnresolvedOrdersSheet` — a `DraggableScrollableSheet` bottom sheet with the order list and per-order action buttons
- The sheet is shown from wherever rollover is currently triggered (the app startup / foreground hook that calls `runRolloverBatch`). Recreation is deferred until the sheet is dismissed.
- Per-order actions call the existing `ordersProvider.notifier.updateOrder(...)` — no new data layer needed

### Edge cases

- If the owner marks an order delivered from the sheet, it disappears from the list immediately
- If all orders are resolved before tapping Done, the Done button auto-triggers and recreation runs
- Backfill runs (app opened after multiple missed days): show the popup for the oldest unresolved day first, then proceed day by day

---

## Fix 2 — Swipeable week strip with calendar jump

### Week strip — swipe navigation

Replace the current static `_WeekStrip` (always shows the current week) with a swipeable version:

- The strip is wrapped in a `PageView` with infinite backwards paging and forward paging capped at the current week
- Swiping left moves to the previous week, swiping right moves to a later week (disabled/clamped at current week)
- Small faint left/right chevron icons sit at the edges of the strip as discoverability hints; they are not tappable buttons — they are purely visual indicators that the strip is swipeable
- Right chevron is hidden when already on the current week (nothing to swipe forward to)
- Selected date (the active day filter) persists across week changes; if the selected date is not in the newly visible week it deselects automatically

### Calendar icon — month picker

A small calendar icon (`Icons.calendar_month_rounded`) sits to the right of the week strip row, outside the swipeable area:

- Tapping it opens Flutter's `showDatePicker` with:
  - `initialDate`: the currently selected date, or today
  - `firstDate`: `DateTime(2023, 1, 1)`
  - `lastDate`: today (no future jumping)
- On date picked: the week strip jumps to the week containing that date, and that date becomes the active day filter
- The calendar icon styling matches the existing filter icons in the app bar (same color, same size)

### State changes in `_OrderListScreenState`

- Add `int _weekOffset` (0 = current week, -1 = last week, etc.) to drive the `PageView`
- `_selectedDate` already exists — no change needed
- When a date is picked from the month picker, compute `_weekOffset` from the delta between that date's week and the current week

### No changes to filtering logic

The existing `matchesDay` filter in `filteredOrders` already compares against `_selectedDate`. No changes needed there.

---

## Out of scope

- Status progression UI (`confirmed`, `preparing`, `ready` intermediate states) — separate concern, not part of this fix
- Payment auto-update on delivery — separate concern
- Any changes to the driver-side order flow

