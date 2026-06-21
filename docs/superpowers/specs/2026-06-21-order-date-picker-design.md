# Order Date Picker on Create/Edit — Design Spec

**Date:** 2026-06-21
**Status:** Approved

---

## Problem

`orderDate` is always set to `DateTime.now()` at submit time. Businesses routinely need to:
- Create advance orders (e.g. "deliver Thursday")
- Enter yesterday's orders retroactively

There is no way to set the delivery date during order creation or editing.

---

## Scope

Single focused change: add a date picker to the Schedule step of `CreateOrderScreen`. No changes to other screens, the model, or the data layer.

---

## Design

### New State Variable

Add `DateTime _orderDate` to `_CreateOrderScreenState`.

- **Default:** `DateTime.now()` normalized to calendar-day midnight via the existing `_calendarDay()` helper.
- **Edit init:** In the `addPostFrameCallback` block that seeds form state from an existing order, also set `_orderDate = _calendarDay(existing.orderDate)`.

### Schedule Step UI (`_buildSchedulePicker`)

Add a **"Delivery date"** row at the **top** of the schedule picker, above the delivery run pills.

- Displayed as a tappable chip: calendar icon + formatted date (e.g. `Mon, 23 Jun 2026`).
- On tap: open `showDatePicker` with:
  - `initialDate: _orderDate`
  - `firstDate: DateTime(2023)`
  - `lastDate: DateTime.now().add(const Duration(days: 365))`
  - Themed with `AppColors.primary` (matching the existing production day picker pattern in `OrderListScreen`).
- If `_orderDate` differs from today: show a small secondary hint line:
  > *"Orders for this date won't auto-merge with today's orders."*
- If `_orderDate` equals today: no hint (zero friction for the common case).

### Merge Logic Adjustment (`_findMergeTarget`)

Currently passes `referenceTime: DateTime.now()`. Change to `referenceTime: _orderDate`.

This ensures that when a user picks a past or future date, the merge search looks for an existing order on that business day rather than always today. If none exists, a new order is created normally.

### Submit Logic (`_submitOrder`)

Change:
```dart
// before
orderDate: now,

// after
orderDate: _orderDate,
```

`createdAt` and `updatedAt` remain `now` — they track DB record timestamps, not the business delivery date.

### What Does Not Change

- The 4-step wizard structure.
- The merge toggle UI and "Create separate order" switch.
- `createdAt` / `updatedAt` fields.
- The rollover edit guard in `canModifyOrderItems` — it already uses the stored `order.orderDate`, not a local variable.
- The driver flow (`forDriver: true`) — no special handling needed; drivers always create today's orders in practice, but picking a date still works correctly.

---

## Files to Change

| File | Change |
|------|--------|
| `lib/features/owner/orders/create_order/create_order_screen.dart` | Add `_orderDate` state; seed from edit init; update `_buildSchedulePicker`; update `_findMergeTarget`; update `_submitOrder` |

No other files require changes.

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| User picks today | No hint shown; merge logic unchanged from current behaviour |
| User picks a past date | Hint shown; merge searches that day's orders; `orderDate` set to past date |
| User picks a future date | Hint shown; merge finds nothing (no future orders exist); new order created |
| User is in edit mode | `_orderDate` seeded from existing `orderDate`; can be changed freely |
| User navigates back from step 3 to step 2 | `_orderDate` preserved in state; picker shows previously selected date |
| User changes customer (resets items) | `_orderDate` is not reset — date is independent of customer choice |

---

## Non-Goals

- Changing the `orderDate` from the Order Details screen (separate feature).
- Date validation against business hours or route schedules.
- Repeating/recurring order scheduling.
