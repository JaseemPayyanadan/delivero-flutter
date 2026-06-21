# Bulk Order Actions — Design Spec

**Date:** 2026-06-21
**Status:** Approved

---

## Problem

Owners must open each order individually to mark it delivered or paid. For a morning run of 20 orders, this is 20 × 2–3 taps. Bulk selection would reduce that to a single action.

---

## Scope

Multi-select mode on the order list with "Mark delivered" and "Mark paid" bulk actions.

---

## Design

### Selection State

Add to `_OrderListScreenState`:
```dart
Set<String> _selectedIds = {};
bool get _isSelecting => _selectedIds.isNotEmpty;
```

No separate `bool _selectionMode` flag — selection mode is simply `_selectedIds.isNotEmpty`.

### Entering Selection Mode

Long-press on any `_OrderCard` enters selection mode and selects that order. Uses `onLongPress` on the card's `InkWell` (the same tap target as navigation). Haptic feedback: `HapticFeedback.mediumImpact()`.

### Order Card in Selection Mode

`_OrderCard` receives two new parameters:
- `final bool isSelected`
- `final VoidCallback? onToggleSelect`

When `onToggleSelect != null` (i.e. selection mode is active):
- The card's `onTap` calls `onToggleSelect` instead of navigating.
- A circular checkbox overlay appears in the top-left corner of the card:
  - Selected: filled `Icons.check_circle_rounded` in `AppColors.primary`
  - Unselected: `Icons.radio_button_unchecked_rounded` in `AppColors.textLight`
  - Overlaid using a `Stack` wrapping the existing card content.

When `onToggleSelect == null` (normal mode): card behaves exactly as today.

### App Bar in Selection Mode

When `_isSelecting`, replace the normal app bar title and actions with:
- Title: `'${_selectedIds.length} selected'`
- Leading: `IconButton(Icons.close_rounded)` → clears `_selectedIds`
- Actions: none (the bulk action bar handles actions)

Use the existing `DeliveroAppBar` — pass the dynamic title.

### Bulk Action Bar

A `BottomAppBar`-style container that slides up from the bottom when `_isSelecting` (via `AnimatedSwitcher` or `AnimatedContainer` height). Fixed above the FAB area with `SafeArea`.

Contains two full-width buttons stacked vertically, or side-by-side if space allows:

**Mark delivered** (`FilledButton`, `AppColors.success` background):
- Disabled if all selected orders are already delivered.
- On tap: for each `id` in `_selectedIds`, update `order.status = OrderStatus.delivered`, set `deliveryTime` and `deliveryDate` to `DateTime.now()` if not already set. Calls `ref.read(ordersProvider.notifier).updateOrder(updated)` per order. Shows snack bar: `'${n} orders marked as delivered'`. Clears `_selectedIds`.

**Mark paid** (`FilledButton`, `AppColors.primary` background):
- Disabled if all selected orders are already paid.
- On tap: for each `id` in `_selectedIds`, update `order.paymentStatus = PaymentStatus.paid`, set `paymentMethod` to existing method or `PaymentMethod.cash` if null, set `paymentTime` to `DateTime.now()`. Calls `updateOrder`. Shows snack bar: `'${n} orders marked as paid'`. Clears `_selectedIds`.

### Exiting Selection Mode

- Tap the × in the app bar leading position.
- Hardware back button (handled via `PopScope` already in `OrderListScreen` — `canPop` should return `false` when selecting, with `onPopInvokedWithResult` clearing `_selectedIds`).

### Files Changed

| File | Change |
|------|--------|
| `lib/features/owner/orders/widgets/order_card.dart` | Add `isSelected` + `onToggleSelect` params; add checkbox overlay; swap `onTap` in selection mode |
| `lib/features/owner/orders/order_list_screen.dart` | Add `_selectedIds` state; pass `isSelected`/`onToggleSelect` to cards; conditional app bar; bulk action bar; `PopScope` integration |

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Selecting a cancelled order | Allowed in selection; "Mark delivered" skips cancelled orders silently |
| All selected orders already delivered | "Mark delivered" button is disabled |
| All selected orders already paid | "Mark paid" button is disabled |
| Filters change while selecting | `_selectedIds` may contain IDs no longer visible — harmless, they won't appear in the filtered view but the count badge reflects the full set |
| Navigation while selecting | Pushing to order details and returning preserves `_selectedIds` |

---

## Non-Goals

- No "select all" button (YAGNI — adds complexity, debatable value).
- No bulk cancel or bulk delete.
- No bulk payment method selection (always sets to existing method or cash).
- No undo for bulk actions (consistent with existing single-order behaviour).
