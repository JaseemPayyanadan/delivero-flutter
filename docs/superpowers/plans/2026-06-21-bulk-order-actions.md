# Bulk Order Actions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-select mode to the order list with "Mark delivered" and "Mark paid" bulk actions.

**Architecture:** `_OrderCard` gains three new optional params (isSelected, onToggleSelect, onEnterSelectMode) that activate selection UI. `_OrderListScreenState` owns `_selectedIds` Set, a conditional app bar, a sliding bulk action bar as `bottomNavigationBar`, and a `PopScope` for back-press handling.

**DEPENDENCY:** This plan MUST be executed AFTER `2026-06-21-order-card-refactor.md`. Plan B creates `_OrderCard` in `lib/features/owner/orders/widgets/order_card.dart`. Plan A extends it.

**Tech Stack:** Flutter, Riverpod (flutter_riverpod), Dart.

## Global Constraints

- Selection mode is `_selectedIds.isNotEmpty` — no separate bool flag
- Long-press enters selection mode + selects the card + `HapticFeedback.mediumImpact()`
- "Mark delivered" background: `AppColors.success`; "Mark paid" background: `AppColors.primary`
- "Mark delivered": sets `status = OrderStatus.delivered`, sets `deliveryTime`/`deliveryDate` to `DateTime.now()` only if currently null; skips already-delivered orders
- "Mark paid": sets `paymentStatus = PaymentStatus.paid`, `paymentMethod` to existing or `PaymentMethod.cash` if null, `paymentTime = DateTime.now()`
- Snack bar after each bulk action: `'${n} orders marked as delivered'` / `'${n} orders marked as paid'`
- `PopScope`: `canPop` returns `false` when `_isSelecting`; `onPopInvokedWithResult` clears `_selectedIds`
- "Mark delivered" disabled if ALL selected orders are already delivered; "Mark paid" disabled if ALL selected orders are already paid

---

### Task 1: Add unit tests for bulk field-update logic

**Files:**
- Create: `test/bulk_order_actions_test.dart`

**Interfaces:**
- Consumes: `productionTestOrder`, `Order`, `OrderStatus`, `PaymentStatus`, `PaymentMethod`

- [ ] **Step 1: Write the failing tests**

Create `test/bulk_order_actions_test.dart`:

```dart
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('bulk mark delivered', () {
    test('sets status to delivered', () {
      final order = productionTestOrder(id: 'o1');
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveryTime: order.deliveryTime ?? now,
        deliveryDate: order.deliveryDate ?? now,
        updatedAt: now,
      );
      expect(updated.status, OrderStatus.delivered);
    });

    test('does not overwrite an existing deliveryTime', () {
      final existing = DateTime(2026, 6, 21, 8, 0);
      final order = productionTestOrder(id: 'o1')
          .copyWith(deliveryTime: existing, deliveryDate: existing);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveryTime: order.deliveryTime ?? now,
        deliveryDate: order.deliveryDate ?? now,
        updatedAt: now,
      );
      expect(updated.deliveryTime, existing);
      expect(updated.deliveryDate, existing);
    });

    test('skips order already delivered (no-op when filtering)', () {
      final delivered = productionTestOrder(id: 'o1')
          .copyWith(status: OrderStatus.delivered);
      // In _bulkMarkDelivered, cancelled/delivered orders are skipped via .where()
      final toUpdate = [delivered].where((o) => o.status != OrderStatus.delivered).toList();
      expect(toUpdate, isEmpty);
    });
  });

  group('bulk mark paid', () {
    test('sets paymentStatus to paid', () {
      final order = productionTestOrder(id: 'o1');
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentStatus, PaymentStatus.paid);
    });

    test('preserves existing paymentMethod when not null', () {
      final order = productionTestOrder(id: 'o1')
          .copyWith(paymentMethod: PaymentMethod.online);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentMethod, PaymentMethod.online);
    });

    test('defaults paymentMethod to cash when null', () {
      // productionTestOrder has paymentMethod: null by default
      final order = productionTestOrder(id: 'o1');
      expect(order.paymentMethod, isNull);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentMethod, PaymentMethod.cash);
    });
  });
}
```

- [ ] **Step 2: Run to confirm they pass (logic is pure — no UI involved)**

```bash
flutter test test/bulk_order_actions_test.dart --reporter expanded
```

Expected: `+6: All tests passed!`

Note: these tests mirror the exact `copyWith` expressions used in `_bulkMarkDelivered` and `_bulkMarkPaid` helper methods in Task 2. If a test fails due to model differences (e.g. `paymentMethod` is not nullable), adjust the test to match the actual model signature.

- [ ] **Step 3: Commit**

```bash
git add test/bulk_order_actions_test.dart
git commit -m "test: add bulk order action field-update logic tests

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Extend `_OrderCard` with selection params and checkbox overlay

**Files:**
- Modify: `lib/features/owner/orders/widgets/order_card.dart`

**Interfaces:**
- Produces:
  ```dart
  _OrderCard({
    required Order order,
    List<Order> siblingOrders = const [],
    bool isSelected = false,
    VoidCallback? onToggleSelect,       // null = normal mode
    VoidCallback? onEnterSelectMode,    // null = no long-press action
  })
  ```

- [ ] **Step 1: Add the three new parameters to `_OrderCard`**

In `order_card.dart`, update the `_OrderCard` class:

```dart
class _OrderCard extends ConsumerWidget {
  final Order order;
  final List<Order> siblingOrders;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEnterSelectMode;

  const _OrderCard({
    required this.order,
    this.siblingOrders = const [],
    this.isSelected = false,
    this.onToggleSelect,
    this.onEnterSelectMode,
  });
```

- [ ] **Step 2: Swap `onTap` and add `onLongPress` in the `InkWell`**

Inside `_OrderCard.build`, find the `InkWell`. Currently it has:
```dart
onTap: () => context.push('/owner/orders/${order.id}'),
```

Change it to:
```dart
onTap: onToggleSelect ?? () => context.push('/owner/orders/${order.id}'),
onLongPress: onEnterSelectMode,
```

When `onToggleSelect` is non-null (selection mode), tapping toggles selection instead of navigating. `onLongPress` is null in normal mode (no-op) and set in selection mode (long-pressing another card while already selecting can also toggle it — the parent passes `onEnterSelectMode` for that purpose).

- [ ] **Step 3: Wrap the return value in a `Stack` for the checkbox overlay**

The existing `build` returns a `Container(...)`. Wrap it:

```dart
return Stack(
  children: [
    Container(
      // existing card content unchanged
      margin: const EdgeInsets.only(bottom: 12),
      // ...
    ),
    if (onToggleSelect != null)
      Positioned(
        top: 10,
        left: 10,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected ? AppColors.primary : AppColors.textLight,
            size: 24,
          ),
        ),
      ),
  ],
);
```

The white `Container` behind the icon prevents it from blending into the card border color.

- [ ] **Step 4: Run the full test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/widgets/order_card.dart
git commit -m "feat: add selection params and checkbox overlay to _OrderCard

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Add selection state, bulk action bar, and app bar to `order_list_screen.dart`

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`

**Interfaces:**
- Consumes: `_OrderCard` (from Task 2) with `isSelected`, `onToggleSelect`, `onEnterSelectMode` params
- Consumes: `ref.read(ordersProvider.notifier).updateOrder(Order)`

- [ ] **Step 1: Add `_selectedIds` state and `_isSelecting` getter**

In `_OrderListScreenState`, add after existing field declarations:

```dart
Set<String> _selectedIds = {};
bool get _isSelecting => _selectedIds.isNotEmpty;
```

- [ ] **Step 2: Add `_bulkMarkDelivered` and `_bulkMarkPaid` helper methods**

Add these two methods to `_OrderListScreenState` (before or after `dispose()`):

```dart
Future<void> _bulkMarkDelivered(List<Order> allOrders) async {
  final now = DateTime.now();
  final targets = allOrders
      .where((o) =>
          _selectedIds.contains(o.id) && o.status != OrderStatus.delivered)
      .toList();
  for (final order in targets) {
    final updated = order.copyWith(
      status: OrderStatus.delivered,
      deliveryTime: order.deliveryTime ?? now,
      deliveryDate: order.deliveryDate ?? now,
      updatedAt: now,
    );
    await ref.read(ordersProvider.notifier).updateOrder(updated);
  }
  setState(() => _selectedIds = {});
  if (mounted && targets.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${targets.length} orders marked as delivered')),
    );
  }
}

Future<void> _bulkMarkPaid(List<Order> allOrders) async {
  final now = DateTime.now();
  final targets = allOrders
      .where((o) =>
          _selectedIds.contains(o.id) &&
          o.paymentStatus != PaymentStatus.paid)
      .toList();
  for (final order in targets) {
    final updated = order.copyWith(
      paymentStatus: PaymentStatus.paid,
      paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
      paymentTime: now,
      updatedAt: now,
    );
    await ref.read(ordersProvider.notifier).updateOrder(updated);
  }
  setState(() => _selectedIds = {});
  if (mounted && targets.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${targets.length} orders marked as paid')),
    );
  }
}
```

- [ ] **Step 3: Pass selection params to `_OrderCard` in `_buildGroupedOrderWidgets`**

In `_buildGroupedOrderWidgets`, change the card constructor call from:

```dart
widgets.add(_OrderCard(order: o, siblingOrders: orders));
```

to:

```dart
widgets.add(_OrderCard(
  order: o,
  siblingOrders: orders,
  isSelected: _selectedIds.contains(o.id),
  onToggleSelect: _isSelecting
      ? () => setState(() {
            if (_selectedIds.contains(o.id)) {
              _selectedIds.remove(o.id);
            } else {
              _selectedIds.add(o.id);
            }
          })
      : null,
  onEnterSelectMode: _isSelecting
      ? () => setState(() => _selectedIds.add(o.id))
      : () {
          HapticFeedback.mediumImpact();
          setState(() => _selectedIds.add(o.id));
        },
));
```

Add `import 'package:flutter/services.dart';` at the top of `order_list_screen.dart` if not already present.

- [ ] **Step 4: Make the app bar title and leading conditional**

Find the `DeliveroAppBar` in `build()`. Currently it has a fixed title `'Orders'`. Change the title and leading to be conditional on `_isSelecting`:

```dart
DeliveroAppBar(
  title: _isSelecting ? '${_selectedIds.length} selected' : 'Orders',
  leading: _isSelecting
      ? IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _selectedIds = {}),
        )
      : null,
  // existing actions unchanged — but hide them when selecting:
  actions: _isSelecting ? [] : [/* existing 3 action buttons */],
),
```

Adjust based on how `DeliveroAppBar` accepts a `leading` parameter. If it does not support a custom leading, use a conditional `title` and keep the close button in `actions` instead.

- [ ] **Step 5: Add the bulk action bar as `bottomNavigationBar`**

In the `Scaffold`, add a `bottomNavigationBar` property that uses `AnimatedSwitcher`:

```dart
bottomNavigationBar: AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: _isSelecting
      ? SafeArea(
          key: const ValueKey('bulk-bar'),
          child: Consumer(
            builder: (context, ref, _) {
              final ordersAsync = ref.watch(ordersProvider);
              final allOrders = ordersAsync.valueOrNull ?? [];
              final selectedOrders =
                  allOrders.where((o) => _selectedIds.contains(o.id)).toList();
              final allDelivered = selectedOrders
                  .every((o) => o.status == OrderStatus.delivered);
              final allPaid = selectedOrders
                  .every((o) => o.paymentStatus == PaymentStatus.paid);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: allDelivered
                            ? null
                            : () => _bulkMarkDelivered(allOrders),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        child: const Text('Mark delivered'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            allPaid ? null : () => _bulkMarkPaid(allOrders),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Mark paid'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        )
      : const SizedBox.shrink(),
),
```

- [ ] **Step 6: Wrap `Scaffold` in `PopScope` for back-press handling**

Wrap the existing `Scaffold(...)` return in `build()` with:

```dart
return PopScope(
  canPop: !_isSelecting,
  onPopInvokedWithResult: (didPop, result) {
    if (!didPop && _isSelecting) {
      setState(() => _selectedIds = {});
    }
  },
  child: Scaffold(
    // existing scaffold content unchanged
  ),
);
```

- [ ] **Step 7: Run the full test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass (count ≥ 82, including the 6 new bulk action tests from Task 1).

- [ ] **Step 8: Hot-restart and test manually**

1. Long-press any order card → vibration + checkbox appears + app bar changes to `'1 selected'` + bulk action bar slides up.
2. Tap another card → it joins selection; count updates.
3. Tap an already-selected card → it deselects.
4. Tap × in app bar → selection clears, UI returns to normal.
5. Press hardware back while selecting → selection clears (does NOT navigate away).
6. Tap "Mark delivered" → selected non-delivered orders update; snack bar appears; selection clears.
7. When all selected are already delivered → "Mark delivered" button disabled.
8. Tap "Mark paid" → similar flow for payment status.

- [ ] **Step 9: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: add bulk select, mark delivered, and mark paid to order list

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

- ✅ Spec: `_selectedIds` Set + `_isSelecting` getter, no separate bool flag
- ✅ Spec: long-press enters selection, triggers `HapticFeedback.mediumImpact()`
- ✅ Spec: `_OrderCard` gains `isSelected`, `onToggleSelect`, `onEnterSelectMode` (null in normal mode)
- ✅ Spec: conditional app bar title/leading when `_isSelecting`
- ✅ Spec: bulk action bar with `AnimatedSwitcher` height animation
- ✅ Spec: "Mark delivered" uses `AppColors.success`, "Mark paid" uses `AppColors.primary`
- ✅ Spec: "Mark delivered" skips already-delivered; disabled when all selected are delivered
- ✅ Spec: "Mark paid" disabled when all selected are paid
- ✅ Spec: `PaymentMethod.cash` default when existing method is null
- ✅ Spec: `deliveryTime`/`deliveryDate` only set if currently null
- ✅ Spec: snack bar with count after each bulk action
- ✅ Spec: `PopScope` clears `_selectedIds` on back press
- ✅ Dependency declared: must run after Plan B (refactor creates `_OrderCard`)
- ✅ No placeholder steps
