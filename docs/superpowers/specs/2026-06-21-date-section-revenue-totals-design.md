# Date Section Revenue Totals — Design Spec

**Date:** 2026-06-21
**Status:** Approved

---

## Problem

The `_DateSectionHeader` shows order count per day but no revenue total, so owners cannot see daily revenue at a glance without opening individual orders.

---

## Scope

Add a formatted revenue total to each date section header. One new parameter on `_DateSectionHeader`, populated at grouping time in `_buildGroupedOrderWidgets`.

---

## Design

### `_DateSectionHeader` change

Add a `final double dayTotal` parameter. Display it as a second line (or inline after the order count) using `formatRupee(dayTotal)`.

Updated display layout — single row, right side:

```
TODAY                          ₹4,200 · 5 Orders
```

Specifically: the existing right-side `Text` becomes two parts separated by ` · `:
- `formatRupee(dayTotal)` in `AppColors.primary` weight w900
- `$count ${count == 1 ? 'Order' : 'Orders'}` in `AppColors.primary` weight w900

Both in the same `Text` widget as a single string:
```dart
'${formatRupee(dayTotal)} · $count ${count == 1 ? 'Order' : 'Orders'}'
```

`formatRupee` is already imported in `order_list_screen.dart` via `core/utils/currency_format.dart`.

### Populating `dayTotal` in `_buildGroupedOrderWidgets`

When building each day group, sum `order.totalAmount` across all orders in that group:

```dart
final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
widgets.add(_DateSectionHeader(
  title: _formatBusinessDaySection(day, todayKey),
  count: orders.length,
  dayTotal: dayTotal,
));
```

### Files Changed

| File | Change |
|------|--------|
| `lib/features/owner/orders/order_list_screen.dart` | Add `dayTotal` param to `_DateSectionHeader`; compute and pass it in `_buildGroupedOrderWidgets` |

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| All orders in a day have `totalAmount: 0` | Shows `₹0` — correct |
| Filtered view (only some orders visible) | Total reflects only filtered orders shown in that section |
| Single order | `₹500 · 1 Order` (singular) |

---

## Non-Goals

- No breakdown by payment status (paid vs unpaid total).
- No grand total across all days.
- No currency other than ₹ (existing `formatRupee` convention).
