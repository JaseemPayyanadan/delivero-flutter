# Date Section Revenue Totals — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the daily revenue total next to the order count in each date section header.

**Architecture:** Add `dayTotal` parameter to `_DateSectionHeader` widget and compute it via `fold` in `_buildGroupedOrderWidgets`. One file only.

**Tech Stack:** Flutter, Dart.

## Global Constraints

- Only change: `lib/features/owner/orders/order_list_screen.dart`
- Display format: `'${formatRupee(dayTotal)} · $count ${count == 1 ? 'Order' : 'Orders'}'` — single `Text` widget, same style as current count text
- `formatRupee` is already imported via `core/utils/currency_format.dart`
- Computation: `orders.fold(0.0, (sum, o) => sum + o.totalAmount)` — reflects only the filtered orders in that section

---

### Task 1: Add `dayTotal` unit test

**Files:**
- Create: `test/date_section_revenue_test.dart`

**Interfaces:**
- Produces: test file verifying the fold computation logic

- [ ] **Step 1: Write the test**

Create `test/date_section_revenue_test.dart`:

```dart
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('date section revenue totals', () {
    test('fold sums totalAmount across orders in a group', () {
      final orders = [
        productionTestOrder(id: 'a'),
        productionTestOrder(id: 'b'),
        productionTestOrder(id: 'c'),
      ];
      // productionTestOrder sets totalAmount to 200.0
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, 600.0);
    });

    test('empty order list yields dayTotal of 0', () {
      final orders = <Order>[];
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, 0.0);
    });

    test('single order day total equals its totalAmount', () {
      final order = productionTestOrder(id: 'solo');
      final dayTotal = [order].fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, order.totalAmount);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it passes**

```bash
flutter test test/date_section_revenue_test.dart --reporter expanded
```

Expected: `+3: All tests passed!`

The test exercises the exact `fold` expression used in the implementation — if `productionTestOrder` returns `totalAmount: 200.0`, the first test expects `600.0`. Adjust the expectation if the actual default differs.

- [ ] **Step 3: Commit the test**

```bash
git add test/date_section_revenue_test.dart
git commit -m "test: add day revenue total fold computation tests

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Add `dayTotal` to `_DateSectionHeader` and `_buildGroupedOrderWidgets`

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`
  - `_DateSectionHeader` widget (lines 1302–1342)
  - `_buildGroupedOrderWidgets` (lines 296–329)

**Interfaces:**
- Consumes: `formatRupee` (already imported), `Order.totalAmount` (double field on `Order`)

- [ ] **Step 1: Add `dayTotal` field to `_DateSectionHeader`**

Find the `_DateSectionHeader` widget class (around line 1302). Its current constructor looks like:

```dart
class _DateSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _DateSectionHeader({
    required this.title,
    required this.count,
  });
```

Change it to:

```dart
class _DateSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final double dayTotal;

  const _DateSectionHeader({
    required this.title,
    required this.count,
    required this.dayTotal,
  });
```

- [ ] **Step 2: Update the count `Text` in `_DateSectionHeader.build`**

Inside `_DateSectionHeader`'s `build` method, find the right-side `Text` widget that currently reads:

```dart
Text(
  '$count ${count == 1 ? 'Order' : 'Orders'}',
  style: ...,
),
```

Replace the string with:

```dart
Text(
  '${formatRupee(dayTotal)} · $count ${count == 1 ? 'Order' : 'Orders'}',
  style: ...,
),
```

Keep all other style properties identical (color, fontWeight, fontSize, etc.).

- [ ] **Step 3: Compute and pass `dayTotal` in `_buildGroupedOrderWidgets`**

In `_buildGroupedOrderWidgets` (around line 296), find the block that adds the section header and orders. It currently looks like:

```dart
widgets.add(_DateSectionHeader(
  title: _formatBusinessDaySection(day, todayKey),
  count: orders.length,
));
```

Replace it with:

```dart
final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
widgets.add(_DateSectionHeader(
  title: _formatBusinessDaySection(day, todayKey),
  count: orders.length,
  dayTotal: dayTotal,
));
```

- [ ] **Step 4: Run the full test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass (count ≥ 79, including the 3 new ones from Task 1).

- [ ] **Step 5: Hot-restart and verify visually**

1. Open Orders screen with orders present.
2. Each date section header should now show e.g. `₹4,200 · 5 Orders` on the right.
3. With active filters (e.g. route or payment status filter), confirm the total reflects only the visible orders.
4. A single-order day should show `₹200 · 1 Order` (singular).

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: show daily revenue total in date section headers

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

- ✅ Spec: `dayTotal` added as required param to `_DateSectionHeader`
- ✅ Spec: display format `'${formatRupee(dayTotal)} · $count ${count == 1 ? 'Order' : 'Orders'}'`
- ✅ Spec: fold computation `orders.fold(0.0, (sum, o) => sum + o.totalAmount)`
- ✅ Spec: reflects only filtered orders in that section (since `_buildGroupedOrderWidgets` already operates on filtered list)
- ✅ Only one file changed
- ✅ Tests cover fold logic, empty group, and single-order cases
