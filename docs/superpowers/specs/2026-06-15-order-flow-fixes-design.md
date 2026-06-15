# Order Flow Fixes — Design Spec
**Date:** 2026-06-15
**Status:** Approved

---

## Problem Summary

Two issues in the current order flow:

1. **Stale pending orders accumulate** — when the business day rolls over, daily orders that were never delivered remain `pending` indefinitely. Auto-recreation then creates a fresh order for today, leaving the owner with orphaned pending orders from past days cluttering the list.

2. **Week strip is locked to the current week** — the date filter bar only shows the current Sun–Sat week with no way to navigate to previous weeks or jump to a specific past date.

---

## Fix 1 — Auto-cancel stale daily orders at rollover

### Behaviour

When `runRolloverBatch` runs (at business day rollover), before creating tomorrow's orders it performs a **stale-order cleanup pass**:

- Scan all daily orders whose `orderDate` falls on `sourceDay` (yesterday's business day)
- Any order with status `pending`, `confirmed`, `preparing`, or `ready` at that point is auto-set to `cancelled`
- The normal recreation logic then runs and creates a fresh `pending` order for today from that same source

**What does NOT get cancelled:** orders already `delivered` or already `cancelled`.

### Why `cancelled` and not a new status

Reusing `cancelled` keeps the model simple. The owner can distinguish auto-cancelled stale orders from intentional cancellations by looking at the order date — a `cancelled` order dated yesterday that also has a fresh `pending` order today is clearly a stale rollover, not a deliberate cancellation.

### Implementation touch points

- `daily_order_recreation_service.dart` — add a `cancelStaleSourceOrders` step inside `runRolloverBatch`, called before `runBatchForTargetDay`
- The step takes `sourceDay`, the full `orders` list, and an `updateOrder` callback — same pattern as the existing sync layer
- Must run synchronously (all cancellations applied) before recreation starts, so the `hasPendingOrderForTargetDay` check sees a clean slate

### Edge cases

- If the owner manually cancelled yesterday's order before rollover, the cleanup step skips it (already `cancelled`)
- If an order is `delivered` at rollover time, it is NOT cancelled — recreation proceeds normally
- Backfill runs (multiple missed days) apply the cleanup for each `sourceDay` in sequence before creating that day's orders

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

