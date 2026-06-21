# Order Card Refactor + Lazy Sliver — Design Spec

**Date:** 2026-06-21
**Status:** Approved

---

## Problem

`_buildOrderCard` is a 348-line method inlined inside `_OrderListScreenState`. It is untestable as a unit, causes the entire list state to rebuild on any local state change, and is hard to maintain. Additionally, `SliverChildListDelegate` builds all order card widgets eagerly, which will degrade performance as order lists grow.

---

## Scope

Pure refactor — zero behavior change. No new features, no visual changes. Two bounded changes:
1. Extract `_buildOrderCard` into a standalone `_OrderCard` widget.
2. Switch grouped-order rendering to lazy `SliverChildBuilderDelegate`.

---

## Design

### New Widget: `_OrderCard`

**File:** `lib/features/owner/orders/widgets/order_card.dart`

A `ConsumerWidget` (needs `ref.watch` for `lastTouchedOrderProvider` and `orderRolloverHourProvider`).

Constructor parameters:
- `final Order order`
- `final List<Order> siblingOrders` (defaults to `const []`)

The widget body is the exact code currently in `_buildOrderCard` — no logic changes. The `onTap` navigation (`context.push('/owner/orders/${order.id}')`) stays as-is using `go_router` context extension.

Color helpers (`_getPaymentColor`, `_getStatusColor`, `_chipTextColor`) and `_displayOrderId` move into the widget file as private top-level functions (they have no state dependency).

### Lazy Sliver in `_buildGroupedOrderWidgets`

Currently the method returns `List<Widget>` and is passed to `SliverChildListDelegate`. Change to return a flat `List<Widget>` as before — but switch the sliver at the call site in `build()` from:

```dart
SliverList(
  delegate: SliverChildListDelegate(_buildGroupedOrderWidgets(...)),
)
```

to:

```dart
SliverList(
  delegate: SliverChildBuilderDelegate(
    (context, index) => widgets[index],
    childCount: widgets.length,
  ),
)
```

where `widgets` is the result of `_buildGroupedOrderWidgets(...)` stored in a local variable. This gives Flutter the child count it needs for viewport-aware lazy building while keeping the existing grouping logic intact.

### What Moves, What Stays

| Code | Destination |
|------|-------------|
| `_buildOrderCard` method body | `_OrderCard` widget in new file |
| `_getPaymentColor`, `_getStatusColor`, `_chipTextColor`, `_displayOrderId` | Private top-level functions in `order_card.dart` |
| `_buildGroupedOrderWidgets` | Stays in `order_list_screen.dart`; returns `List<Widget>` as before |
| All filter state, search state, date state | Stays in `_OrderListScreenState` |

### Files Changed

| File | Change |
|------|--------|
| `lib/features/owner/orders/widgets/order_card.dart` | Create — new `_OrderCard` widget + helper functions |
| `lib/features/owner/orders/order_list_screen.dart` | Remove `_buildOrderCard` + 4 helpers; replace call site with `_OrderCard(...)`; switch to `SliverChildBuilderDelegate` |

---

## Non-Goals

- No change to card visual design.
- No change to filter, search, or highlight logic.
- No change to routing or navigation.
- Do not make `_OrderCard` public — it is only used by `order_list_screen.dart`.
