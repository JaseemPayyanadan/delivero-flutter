# Order Date Picker on Create/Edit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a delivery date picker to the Schedule step of `CreateOrderScreen` so users can create orders for any date, not just today.

**Architecture:** Single file change (`create_order_screen.dart`). Add `_orderDate` state defaulting to calendar-day midnight of today; seed from existing order on edit; expose a tappable date chip at the top of `_buildSchedulePicker`; pass `_orderDate` as `referenceTime` to `_findMergeTarget` and as `orderDate` to `_submitOrder`.

**Tech Stack:** Flutter, Riverpod (flutter_riverpod), go_router, `intl` (DateFormat), Material `showDatePicker`.

## Global Constraints

- `firstDate` for the picker: `DateTime(2023)`
- `lastDate` for the picker: `DateTime.now().add(const Duration(days: 365))`
- `_orderDate` is always calendar-day midnight — no time component
- `createdAt` and `updatedAt` always stay as `DateTime.now()` — only `orderDate` uses `_orderDate`
- Date picker themed with `AppColors.primary` (same pattern as `OrderListScreen._pickProductionDay`)
- All changes in one file; no new files except the test

---

### Task 1: Logic — state variable, edit-mode seeding, submit and merge wiring

**Files:**
- Modify: `lib/features/owner/orders/create_order/create_order_screen.dart`
- Test: `test/order_date_picker_test.dart`

**Interfaces:**
- Produces: `_orderDate` (`DateTime`, calendar-day midnight) on `_CreateOrderScreenState`
- Consumes: `findMergeTargetOrder` (existing, in `lib/core/orders/order_merge.dart`) — `referenceTime` param already accepts `DateTime`

- [ ] **Step 1: Write the failing test**

Create `test/order_date_picker_test.dart`:

```dart
import 'package:delivero/core/orders/order_merge.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  group('order date picker — merge logic', () {
    // When _orderDate is a future date, findMergeTargetOrder must return null
    // even if an order exists for today. This is the core correctness guarantee
    // of passing _orderDate as referenceTime instead of DateTime.now().
    test('future referenceTime does not merge with today\'s order', () {
      final todayOrder = productionTestOrder(
        id: 'today',
        orderDate: DateTime(2026, 6, 21, 9),
        deliveryRun: DeliveryRun.morning,
      );
      // referenceTime = tomorrow; today's order is on a different business day
      final result = findMergeTargetOrder(
        orders: [todayOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 22, 9),
      );
      expect(result, isNull);
    });

    test('same-day referenceTime merges as before', () {
      final todayOrder = productionTestOrder(
        id: 'today',
        orderDate: DateTime(2026, 6, 21, 9),
        deliveryRun: DeliveryRun.morning,
      );
      final result = findMergeTargetOrder(
        orders: [todayOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 21, 11),
      );
      expect(result?.id, 'today');
    });

    test('past referenceTime merges with matching past order', () {
      final pastOrder = productionTestOrder(
        id: 'yesterday',
        orderDate: DateTime(2026, 6, 20, 9),
        deliveryRun: DeliveryRun.morning,
      );
      final result = findMergeTargetOrder(
        orders: [pastOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 20, 14),
      );
      expect(result?.id, 'yesterday');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails (or passes — these test existing behaviour)**

```bash
cd /Users/pickcel/Jaseem/GitWorks/delivero-flutter
flutter test test/order_date_picker_test.dart --reporter expanded
```

Expected: all 3 tests PASS. (These verify `findMergeTargetOrder` already supports `referenceTime` correctly — the bug is solely in the caller passing `DateTime.now()` instead of `_orderDate`. Confirming the tests pass now means they will continue to pass after the caller change.)

- [ ] **Step 3: Add `_orderDate` state field**

In `lib/features/owner/orders/create_order/create_order_screen.dart`, after line 61 (`Order? _editingOrder;`), add:

```dart
  DateTime _orderDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
```

Full context after the edit (lines 58–66 area):

```dart
  bool _initializedFromOrder = false;
  bool _initializedFromPreselect = false;
  Order? _editingOrder;
  DateTime _orderDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime? _reviewEnteredAt;
```

- [ ] **Step 4: Seed `_orderDate` in the edit-init `addPostFrameCallback` block**

Find the `addPostFrameCallback` block (~line 135) that initialises the form from an existing order. Add `_orderDate` seeding inside the `setState` call:

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initializedFromOrder) return;
      setState(() {
        _editingOrder = existing;
        _selectedCustomer = customer;
        _orderType = existing.orderType;
        _deliveryRun = existing.deliveryRun;
        _orderDate = DateTime(                       // ← add this
          existing.orderDate.year,
          existing.orderDate.month,
          existing.orderDate.day,
        );
        _selectedItems = {
          for (final i in existing.items)
            orderLineKey(i.foodItemId, i.packLabel): i.quantity,
        };
        _customUnitPrices = {
          for (final i in existing.items)
            orderLineKey(i.foodItemId, i.packLabel): i.unitPrice,
        };
        _initializedFromOrder = true;
      });
    });
```

- [ ] **Step 5: Update `_findMergeTarget` to use `_orderDate`**

Find the `_findMergeTarget` method (~line 766). Change `referenceTime: DateTime.now()` to `referenceTime: _orderDate`:

```dart
  Order? _findMergeTarget() {
    final customer = _selectedCustomer;
    if (customer == null) return null;
    final orderType = _orderType;
    if (orderType == null) return null;
    return findMergeTargetOrder(
      orders: ref.read(ordersProvider),
      customerId: customer.id,
      orderType: orderType,
      deliveryRun: _deliveryRun,
      referenceTime: _orderDate,          // ← was DateTime.now()
      rolloverHour: ref.read(orderRolloverHourProvider),
      forDriver: widget.forDriver,
    );
  }
```

- [ ] **Step 6: Update `_submitOrder` to use `_orderDate`**

Find the `Order(...)` constructor inside `_submitOrder` (~line 1784 — the one for new order creation, inside the `(null, null)` branch of the switch). Change `orderDate: now` to `orderDate: _orderDate`:

```dart
      (null, null) => (
        Order(
          id: const Uuid().v4(),
          factoryId: _selectedCustomer!.factoryId,
          orderType: orderType,
          deliveryRun: _deliveryRun,
          customerId: _selectedCustomer!.id,
          customerName: _selectedCustomer!.name,
          customerEmail: _selectedCustomer!.email,
          customerPhone: _selectedCustomer!.phone,
          customerAddress: _selectedCustomer!.address,
          items: items,
          subtotal: subtotal,
          discountAmount: discountAmount,
          totalAmount: totalAmount,
          status: OrderStatus.pending,
          assignedRoute: normalizedRouteId,
          assignedDriver: assignedDriver,
          orderDate: _orderDate,          // ← was: now
          createdAt: now,
          updatedAt: now,
        ),
        true,
      ),
```

Do NOT change `orderDate` in the `existing.copyWith(...)` branch — that branch already preserves the edit form's state correctly because `_orderDate` is now seeded from the existing order in Step 4.

- [ ] **Step 7: Run existing tests to confirm nothing regressed**

```bash
flutter test --reporter expanded
```

Expected: all existing tests pass. The app still creates orders with today's date by default (no behaviour change yet since `_orderDate` defaults to today).

- [ ] **Step 8: Commit**

```bash
git add lib/features/owner/orders/create_order/create_order_screen.dart \
        test/order_date_picker_test.dart
git commit -m "feat: wire _orderDate into merge lookup and order submit

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: UI — date chip in Schedule step

**Files:**
- Modify: `lib/features/owner/orders/create_order/create_order_screen.dart`

**Interfaces:**
- Produces: `_isToday(DateTime)` → `bool`; `_pickOrderDate()` → `Future<void>`
- Consumes: `_orderDate` (from Task 1); `AppColors.primary`, `AppColors.backgroundSecondary`, `AppColors.border`, `AppColors.textSecondary`, `AppColors.textPrimary` (all existing); `context.appTextStyles.caption` (existing); `DateFormat` from `package:intl/intl.dart` (already imported)

- [ ] **Step 1: Add `_isToday` and `_pickOrderDate` helpers**

Place these after the `dispose()` method (~line 411). Add:

```dart
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _orderDate = picked);
    }
  }
```

- [ ] **Step 2: Add the date chip at the top of `_buildSchedulePicker`**

Find `_buildSchedulePicker` (~line 1500). The method returns a `Column`. Add the date chip section as the **first children** of that Column, before the existing `'Delivery run'` text:

```dart
  Widget _buildSchedulePicker() {
    // ... existing pill helper ...

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Delivery date ────────────────────────────────────────────
        Text(
          'Delivery date',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickOrderDate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, d MMM y').format(_orderDate),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_isToday(_orderDate)) ...[
          const SizedBox(height: 8),
          Text(
            "Orders for this date won't auto-merge with today's orders.",
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // ── Delivery run ─────────────────────────────────────────────
        Text(
          'Delivery run',
          // ... rest of existing content unchanged ...
```

- [ ] **Step 3: Run full test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass.

- [ ] **Step 4: Manual smoke test**

Run the app and verify:

1. Open **Create order**, advance to **Step 2 (Schedule)**
2. The date chip shows today's date (e.g. `Sat, 21 Jun 2026`) — no hint text below it
3. Tap the chip — a date picker dialog opens themed in the app's primary colour
4. Pick a future date — chip updates to the new date; hint text appears below
5. Pick today again — hint text disappears
6. Advance to **Step 4 (Review)** — the merge preview shows the correct state (no merge target for a future date if no order exists for that day)
7. Confirm the order — verify `orderDate` in Firestore/backend reflects the selected date, not today

**Edit mode check:**

8. Open an existing order with a date in the past, tap **Edit**
9. Advance to **Step 2 (Schedule)** — chip shows the order's original date, hint text visible
10. Change the date — review step reflects the updated date on confirm

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/create_order/create_order_screen.dart
git commit -m "feat: add delivery date picker to Schedule step on create/edit order

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- ✅ `_orderDate` state defaulting to today — Task 1 Step 3
- ✅ Seed from edit init — Task 1 Step 4
- ✅ Date chip in Schedule step — Task 2 Step 2
- ✅ `showDatePicker` with correct bounds + theming — Task 2 Step 1
- ✅ Hint when date ≠ today — Task 2 Step 2 (`if (!_isToday(_orderDate))`)
- ✅ `_findMergeTarget` uses `_orderDate` — Task 1 Step 5
- ✅ `_submitOrder` uses `_orderDate` — Task 1 Step 6
- ✅ `createdAt`/`updatedAt` unchanged — confirmed in Step 6 code (both remain `now`)
- ✅ Edit copyWith branch unaffected — noted explicitly in Step 6

**Placeholder scan:** No TBDs, no "handle edge cases", all steps have code.

**Type consistency:**
- `_orderDate: DateTime` used as `referenceTime: DateTime` in `findMergeTargetOrder` ✅
- `_orderDate: DateTime` used as `orderDate: DateTime` in `Order(...)` ✅
- `_isToday(DateTime) → bool` called with `_orderDate` in the UI ✅
- `_pickOrderDate()` sets `_orderDate` to `picked` which is `DateTime?` — guarded with `if (picked != null)` ✅
