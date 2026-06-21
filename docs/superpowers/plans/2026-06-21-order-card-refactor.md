# Order Card Refactor + Lazy Sliver — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `_buildOrderCard` into a standalone `_OrderCard` widget and switch to lazy sliver rendering, with zero behaviour change.

**Architecture:** Move the 348-line `_buildOrderCard` method and its 4 private helper methods into a new file `lib/features/owner/orders/widgets/order_card.dart` as a `ConsumerWidget`. Helpers become private top-level functions. At the call site, replace `SliverChildListDelegate` with `SliverChildBuilderDelegate`.

**Tech Stack:** Flutter, Riverpod (flutter_riverpod), go_router, intl.

## Global Constraints

- `_OrderCard` must be private (prefixed `_`) — it is only used by `order_list_screen.dart`
- Zero behaviour change — no visual, navigation, or logic differences
- All 76 existing tests must pass after refactor
- Do not change `_buildGroupedOrderWidgets` return type — it stays `List<Widget>`

---

### Task 1: Create `order_card.dart` and update `order_list_screen.dart`

**Files:**
- Create: `lib/features/owner/orders/widgets/order_card.dart`
- Modify: `lib/features/owner/orders/order_list_screen.dart`

**Interfaces:**
- Produces: `_OrderCard({required Order order, List<Order> siblingOrders = const []})` — used by `_buildGroupedOrderWidgets` in `order_list_screen.dart`

- [ ] **Step 1: Create the widget file scaffold**

Create `lib/features/owner/orders/widgets/order_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../app/order_settings_provider.dart';
import '../../../../core/orders/split_order_label.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../data/models/order.dart';

class _OrderCard extends ConsumerWidget {
  final Order order;
  final List<Order> siblingOrders;

  const _OrderCard({
    required this.order,
    this.siblingOrders = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // body filled in Step 2
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 2: Move `_buildOrderCard` body into `_OrderCard.build`**

Copy the entire body of `_buildOrderCard` from `order_list_screen.dart` (lines 668–1016) verbatim into `_OrderCard.build`. Replace the two `ref.watch(...)` calls — they work unchanged since `_OrderCard` is a `ConsumerWidget` with `ref` in scope. Replace `context.push(...)` — `context` is the `build` method's `BuildContext`, so it works unchanged.

The body starts with:
```dart
final lastTouched = ref.watch(lastTouchedOrderProvider);
final shouldHighlight =
    lastTouched != null &&
    lastTouched.id == order.id &&
    DateTime.now().difference(lastTouched.at) <= const Duration(seconds: 8);
```
and ends with the closing `);` of the `Container(...)` return.

- [ ] **Step 3: Move the 4 helper methods as private top-level functions**

After the `_OrderCard` class in `order_card.dart`, add these as top-level private functions (remove the `this` receiver, they have no instance state):

```dart
String _displayOrderId(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty) return '#ORD-—';
  final upper = id.toUpperCase();
  if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
    return upper.startsWith('#') ? upper : '#$upper';
  }
  final short = upper.length > 4 ? upper.substring(0, 4) : upper;
  return '#ORD-$short';
}

Color _getPaymentColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid:
      return AppColors.success;
    case PaymentStatus.partial:
      return AppColors.warning;
    case PaymentStatus.unpaid:
      return AppColors.error;
  }
}

Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warning;
    case OrderStatus.delivered:
      return AppColors.success;
    case OrderStatus.cancelled:
      return AppColors.error;
    default:
      return AppColors.info;
  }
}

Color _chipTextColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  if (hsl.lightness > 0.6) {
    return hsl.withLightness(0.35).toColor();
  }
  return base;
}
```

- [ ] **Step 4: Update `order_list_screen.dart`**

**4a.** Add import at the top of `order_list_screen.dart`:
```dart
import 'widgets/order_card.dart';
```

**4b.** In `_buildGroupedOrderWidgets` (line 324), replace:
```dart
widgets.add(_buildOrderCard(o, siblingOrders: orders));
```
with:
```dart
widgets.add(_OrderCard(order: o, siblingOrders: orders));
```

**4c.** Switch the sliver at lines 279–289 from `SliverChildListDelegate` to `SliverChildBuilderDelegate`:
```dart
else
  SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
    sliver: Builder(
      builder: (context) {
        final widgets = _buildGroupedOrderWidgets(
          filteredOrders,
          rolloverHour: rolloverHour,
        );
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => widgets[index],
            childCount: widgets.length,
          ),
        );
      },
    ),
  ),
```

**4d.** Delete the `_buildOrderCard` method (lines 668–1016) and the 4 helper methods (`_displayOrderId`, `_getPaymentColor`, `_getStatusColor`, `_chipTextColor`, lines 1018–1059) from `order_list_screen.dart`.

- [ ] **Step 5: Run the full test suite**

```bash
flutter test --reporter expanded
```

Expected: `+76: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/widgets/order_card.dart \
        lib/features/owner/orders/order_list_screen.dart
git commit -m "refactor: extract _OrderCard widget and switch to lazy sliver

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

- ✅ Spec: `_OrderCard` private, `ConsumerWidget`, takes `order` + `siblingOrders`
- ✅ Spec: helpers become private top-level functions in the new file
- ✅ Spec: `SliverChildBuilderDelegate` used via `Builder` (avoids double call to `_buildGroupedOrderWidgets`)
- ✅ No behaviour change — all logic copied verbatim
- ✅ No placeholders
