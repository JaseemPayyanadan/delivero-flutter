# Order Flow Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two order flow problems — show a manual review popup for unresolved daily orders before rollover recreation runs, and replace the static week strip with a swipeable PageView version with a calendar jump button.

**Architecture:** Fix 1 adds `findUnresolvedSourceOrders()` to the recreation service, a new `UnresolvedOrdersSheet` ConsumerWidget that watches live provider state, and gates `_runDailyRecreationCatchUp()` in `main.dart` to show the sheet first. Fix 2 refactors `_WeekStrip` to accept an explicit day list, wraps it in a `PageView` for swipe navigation, and adds a calendar icon that calls `showDatePicker` and jumps the controller.

**Tech Stack:** Flutter, Riverpod (`ConsumerWidget`, `ref.watch(ordersProvider)`), `PageView` + `PageController`, `showDatePicker`, `showModalBottomSheet`

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `lib/core/orders/daily_order_recreation_service.dart` | Add `findUnresolvedSourceOrders()` |
| Create | `lib/features/owner/orders/unresolved_orders_sheet.dart` | Bottom sheet with per-order Mark Delivered / Cancel |
| Modify | `lib/main.dart` | Show sheet before recreation |
| Modify | `lib/features/owner/orders/order_list_screen.dart` | Swipeable week strip + calendar icon |
| Modify | `test/daily_order_recreation_test.dart` | Tests for new helper |

---

## Task 1: Add `findUnresolvedSourceOrders` to the recreation service

**Files:**
- Modify: `lib/core/orders/daily_order_recreation_service.dart`
- Modify: `test/daily_order_recreation_test.dart`

- [ ] **Step 1: Write four failing tests**

Open `test/daily_order_recreation_test.dart`. At the bottom of `main()`, after all existing groups, add:

```dart
group('findUnresolvedSourceOrders', () {
  const rolloverHour = 7;
  final sourceDay = DateTime(2025, 6, 20);

  test('returns pending daily order on source day', () {
    final order = productionTestOrder(
      id: 'o1',
      orderDate: DateTime(2025, 6, 20, 9),
      status: OrderStatus.pending,
    );
    final result = findUnresolvedSourceOrders(
      orders: [order],
      sourceBusinessDay: sourceDay,
      rolloverHour: rolloverHour,
    );
    expect(result.length, 1);
    expect(result.first.id, 'o1');
  });

  test('excludes delivered and cancelled orders', () {
    final delivered = productionTestOrder(
      id: 'o2',
      orderDate: DateTime(2025, 6, 20, 9),
      status: OrderStatus.delivered,
    );
    final cancelled = productionTestOrder(
      id: 'o3',
      orderDate: DateTime(2025, 6, 20, 9),
      status: OrderStatus.cancelled,
    );
    final result = findUnresolvedSourceOrders(
      orders: [delivered, cancelled],
      sourceBusinessDay: sourceDay,
      rolloverHour: rolloverHour,
    );
    expect(result, isEmpty);
  });

  test('excludes orders on a different business day', () {
    final wrongDay = productionTestOrder(
      id: 'o4',
      orderDate: DateTime(2025, 6, 19, 9),
      status: OrderStatus.pending,
    );
    final result = findUnresolvedSourceOrders(
      orders: [wrongDay],
      sourceBusinessDay: sourceDay,
      rolloverHour: rolloverHour,
    );
    expect(result, isEmpty);
  });

  test('excludes non-daily orders', () {
    final oneTime = productionTestOrder(
      id: 'o5',
      orderDate: DateTime(2025, 6, 20, 9),
      status: OrderStatus.pending,
    ).copyWith(orderType: OrderType.oneTime);
    final result = findUnresolvedSourceOrders(
      orders: [oneTime],
      sourceBusinessDay: sourceDay,
      rolloverHour: rolloverHour,
    );
    expect(result, isEmpty);
  });
});
```

- [ ] **Step 2: Run tests — expect compile error**

```bash
flutter test test/daily_order_recreation_test.dart
```

Expected: compile error — `findUnresolvedSourceOrders` not defined.

- [ ] **Step 3: Implement `findUnresolvedSourceOrders`**

Open `lib/core/orders/daily_order_recreation_service.dart`. Add this constant and function after the existing imports block, before `isCustomerActiveForRecreation`:

```dart
const _unresolvedStatuses = {
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
};

/// Returns daily orders on [sourceBusinessDay] that were never delivered
/// or cancelled — i.e. still need the owner to act on them.
List<Order> findUnresolvedSourceOrders({
  required List<Order> orders,
  required DateTime sourceBusinessDay,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final normalized = DateTime(
    sourceBusinessDay.year,
    sourceBusinessDay.month,
    sourceBusinessDay.day,
  );
  return orders.where((o) {
    if (o.orderType != OrderType.daily) return false;
    if (!_unresolvedStatuses.contains(o.status)) return false;
    final key = businessDayKey(o.orderDate, rolloverHour: rolloverHour);
    return DateTime(key.year, key.month, key.day) == normalized;
  }).toList();
}
```

- [ ] **Step 4: Run tests — expect all to pass**

```bash
flutter test test/daily_order_recreation_test.dart
```

Expected: all tests pass, no failures.

- [ ] **Step 5: Commit**

```bash
git add lib/core/orders/daily_order_recreation_service.dart test/daily_order_recreation_test.dart
git commit -m "feat: add findUnresolvedSourceOrders helper with tests"
```

---

## Task 2: Build `UnresolvedOrdersSheet`

**Files:**
- Create: `lib/features/owner/orders/unresolved_orders_sheet.dart`

- [ ] **Step 1: Create the widget file**

Create `lib/features/owner/orders/unresolved_orders_sheet.dart` with this full content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/orders/daily_order_recreation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

class UnresolvedOrdersSheet extends ConsumerWidget {
  /// IDs of yesterday's unresolved orders to track. The sheet watches live
  /// provider state so rows disappear as the owner resolves each one.
  final List<String> orderIds;

  const UnresolvedOrdersSheet({super.key, required this.orderIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOrders = ref.watch(ordersProvider);
    final unresolved = allOrders
        .where(
          (o) =>
              orderIds.contains(o.id) &&
              _unresolvedStatuses.contains(o.status),
        )
        .toList();

    if (unresolved.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
    }

    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Unresolved orders from yesterday',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Review and update each order before today's orders are created.",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: unresolved.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'All resolved — tap Done to continue.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: unresolved.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _UnresolvedOrderRow(
                        order: unresolved[i],
                        money0: money0,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                child: const Text("Done — create today's orders"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnresolvedOrderRow extends ConsumerWidget {
  final Order order;
  final NumberFormat money0;

  const _UnresolvedOrderRow({required this.order, required this.money0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemSummary = order.items.isEmpty
        ? '—'
        : order.items
                .take(2)
                .map((i) => '${i.foodItemName} x${i.quantity}')
                .join(', ') +
            (order.items.length > 2
                ? ' +${order.items.length - 2} more'
                : '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName.trim().isEmpty
                      ? 'Unknown'
                      : order.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                money0.format(order.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            itemSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    try {
                      HapticFeedback.lightImpact();
                    } catch (_) {}
                    ref.read(ordersProvider.notifier).updateOrder(
                          order.copyWith(
                            status: OrderStatus.cancelled,
                            updatedAt: DateTime.now(),
                          ),
                        );
                  },
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    try {
                      HapticFeedback.mediumImpact();
                    } catch (_) {}
                    final now = DateTime.now();
                    ref.read(ordersProvider.notifier).updateOrder(
                          order.copyWith(
                            status: OrderStatus.delivered,
                            deliveryTime: order.deliveryTime ?? now,
                            deliveryDate: order.deliveryDate ?? now,
                            updatedAt: now,
                          ),
                        );
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                  ),
                  label: const Text('Delivered'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze` — expect no errors**

```bash
flutter analyze lib/features/owner/orders/unresolved_orders_sheet.dart
```

Expected: no issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/owner/orders/unresolved_orders_sheet.dart
git commit -m "feat: add UnresolvedOrdersSheet for manual rollover review"
```

---

## Task 3: Wire the sheet into `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add missing imports to `main.dart`**

Open `lib/main.dart`. Check existing imports and add any of these that are missing:

```dart
import 'app/order_settings_provider.dart';
import 'core/orders/business_day.dart';
import 'core/orders/daily_order_recreation_service.dart';
import 'features/owner/orders/unresolved_orders_sheet.dart';
```

- [ ] **Step 2: Add `_unresolvedSheetShown` flag to `_DeliveroAppState`**

Inside `_DeliveroAppState`, add this field directly after the class declaration line (before `initState`):

```dart
bool _unresolvedSheetShown = false;
```

- [ ] **Step 3: Replace `_runDailyRecreationCatchUp` body**

Find the method `_runDailyRecreationCatchUp` in `lib/main.dart`. Replace its entire body with:

```dart
Future<void> _runDailyRecreationCatchUp({required bool showFeedback}) async {
  final user = ref.read(authProvider).user;
  final factoryId = user?.factoryId;
  if (factoryId == null || factoryId.isEmpty) return;
  if (!ref.read(ordersLoadedProvider)) return;
  if (!ref.read(customersLoadedProvider)) return;

  if (!_unresolvedSheetShown && mounted) {
    _unresolvedSheetShown = true;
    final rolloverHour = ref.read(orderRolloverHourProvider);
    final now = DateTime.now();
    if (hasPassedBusinessDayRollover(now, rolloverHour: rolloverHour)) {
      final currentKey = currentBusinessDayKey(
        reference: now,
        rolloverHour: rolloverHour,
      );
      final sourceDay = DateTime(
        currentKey.year,
        currentKey.month,
        currentKey.day,
      ).subtract(const Duration(days: 1));
      final orders = ref.read(ordersProvider);
      final unresolved = findUnresolvedSourceOrders(
        orders: orders,
        sourceBusinessDay: sourceDay,
        rolloverHour: rolloverHour,
      );
      if (unresolved.isNotEmpty && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => UnresolvedOrdersSheet(
            orderIds: unresolved.map((o) => o.id).toList(),
          ),
        );
      }
    }
  }

  final result = await ref
      .read(ordersProvider.notifier)
      .runDailyRecreationCatchUp(factoryId);

  if (!showFeedback || !result.hasChanges || !mounted) return;
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  final message = switch (result.createdCount) {
    0 => 'Daily orders synced for today',
    1 => '1 daily order auto-created for today',
    _ => '${result.createdCount} daily orders auto-created for today',
  };
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

- [ ] **Step 4: Run `flutter analyze` — expect no errors**

```bash
flutter analyze lib/main.dart
```

Expected: no issues found.

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: show unresolved orders sheet before daily recreation rollover"
```

---

## Task 4: Swipeable week strip + calendar icon

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart`

- [ ] **Step 1: Refactor `_WeekStrip` to accept an explicit `days` list**

Find the `_WeekStrip` class in `order_list_screen.dart` (search for `class _WeekStrip`). Replace the entire class with:

```dart
class _WeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final DateTime? selectedDate;
  final void Function(DateTime?) onDayTap;

  const _WeekStrip({
    required this.days,
    required this.selectedDate,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isToday = day == todayKey;
          final isSelected = selectedDate == day;
          final isPast = day.isBefore(todayKey);
          return _DayCell(
            day: day,
            isToday: isToday,
            isSelected: isSelected,
            isPast: isPast,
            onTap: () => onDayTap(isSelected ? null : day),
          );
        }).toList(),
      ),
    );
  }
}
```

Leave `_DayCell` unchanged.

- [ ] **Step 2: Add `PageController`, `_weekOffset`, and helper methods to `_OrderListScreenState`**

Find `_OrderListScreenState`. Add these fields after `Timer? _highlightClearTimer;`:

```dart
static const int _kInitialWeekPage = 10000;
late final PageController _weekPageController;
int _weekOffset = 0;
```

Find the existing `initState` override and add the controller initialisation:

```dart
@override
void initState() {
  super.initState();
  _weekPageController = PageController(initialPage: _kInitialWeekPage);
}
```

Find the existing `dispose` override and add disposal (keep existing lines):

```dart
@override
void dispose() {
  _highlightClearTimer?.cancel();
  _weekPageController.dispose();
  _searchController.dispose();
  super.dispose();
}
```

Add this helper method anywhere inside `_OrderListScreenState`:

```dart
List<DateTime> _daysForWeekOffset(int offset) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysFromSunday = now.weekday == 7 ? 0 : now.weekday;
  final thisSunday = today.subtract(Duration(days: daysFromSunday));
  final sunday = thisSunday.add(Duration(days: offset * 7));
  return List.generate(7, (i) => sunday.add(Duration(days: i)));
}
```

- [ ] **Step 3: Replace the week strip in `_buildFilters` with the swipeable version + calendar icon**

Find `_buildFilters`. It currently has a `Column` whose first child is a `_WeekStrip(...)` inside a `Padding`. Replace that `Padding` wrapping the `_WeekStrip` with:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: SizedBox(
          height: 80,
          child: Stack(
            children: [
              PageView.builder(
                controller: _weekPageController,
                onPageChanged: (page) {
                  final offset = page - _kInitialWeekPage;
                  if (offset > 0) {
                    _weekPageController.jumpToPage(_kInitialWeekPage);
                    return;
                  }
                  final days = _daysForWeekOffset(offset);
                  setState(() {
                    _weekOffset = offset;
                    if (_selectedDate != null &&
                        !days.contains(_selectedDate)) {
                      _selectedDate = null;
                    }
                  });
                },
                itemBuilder: (context, page) {
                  final offset = page - _kInitialWeekPage;
                  return _WeekStrip(
                    days: _daysForWeekOffset(offset),
                    selectedDate: _selectedDate,
                    onDayTap: (date) =>
                        setState(() => _selectedDate = date),
                  );
                },
              ),
              // Left chevron — always present as a swipe hint
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 14,
                      color: AppColors.textLight.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              // Right chevron — only when not on current week
              if (_weekOffset < 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.textLight.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: 'Jump to date',
        icon: const Icon(
          Icons.calendar_month_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onPressed: () async {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final initial = _selectedDate ?? today;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2023, 1, 1),
            lastDate: today,
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
              ),
              child: child!,
            ),
          );
          if (picked == null || !mounted) return;
          final pickedDay = DateTime(picked.year, picked.month, picked.day);
          final daysFromSunday = now.weekday == 7 ? 0 : now.weekday;
          final thisSunday = today.subtract(Duration(days: daysFromSunday));
          final pickedDaysFromSunday =
              pickedDay.weekday == 7 ? 0 : pickedDay.weekday;
          final pickedSunday =
              pickedDay.subtract(Duration(days: pickedDaysFromSunday));
          final offset =
              pickedSunday.difference(thisSunday).inDays ~/ 7;
          setState(() {
            _weekOffset = offset;
            _selectedDate = pickedDay;
          });
          _weekPageController.jumpToPage(_kInitialWeekPage + offset);
        },
      ),
    ],
  ),
),
```

- [ ] **Step 4: Run `flutter analyze` — expect no errors**

```bash
flutter analyze lib/features/owner/orders/order_list_screen.dart
```

Expected: no issues found.

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: swipeable week strip with calendar jump on order list"
```

---

## Self-Review

**Spec coverage:**
- ✅ `findUnresolvedSourceOrders` added (Task 1)
- ✅ `UnresolvedOrdersSheet` with Mark Delivered + Cancel per order (Task 2)
- ✅ Sheet auto-closes when all orders resolved via `addPostFrameCallback` (Task 2)
- ✅ Done button always available (Task 2)
- ✅ Sheet shown once per session, gated by `_unresolvedSheetShown` (Task 3)
- ✅ Rollover guard — sheet only shown when rollover has passed (Task 3)
- ✅ Recreation runs after sheet is dismissed via `await showModalBottomSheet` (Task 3)
- ✅ `_WeekStrip` swipeable via `PageView` (Task 4)
- ✅ Swipe clamped at current week — future weeks blocked (Task 4)
- ✅ Chevron hints as `IgnorePointer` overlays — visual only (Task 4)
- ✅ Right chevron hidden when on current week (`_weekOffset < 0` guard) (Task 4)
- ✅ Selected date clears on week change if not in visible week (Task 4)
- ✅ Calendar icon opens `showDatePicker` (Task 4)
- ✅ Date pick jumps `PageView` to correct week and sets `_selectedDate` (Task 4)
- ✅ `firstDate: DateTime(2023, 1, 1)`, `lastDate: today` (Task 4)
- ✅ Existing `matchesDay` filter logic untouched (no changes needed)

**Type consistency:**
- `findUnresolvedSourceOrders` returns `List<Order>` — used as `.map((o) => o.id).toList()` in Task 3 ✅
- `_unresolvedStatuses` defined in service, referenced in `UnresolvedOrdersSheet` via import ✅
- `_weekOffset` int used consistently across Task 4 state, PageView callback, and chevron guard ✅
- `_kInitialWeekPage = 10000` used consistently in `PageController`, `jumpToPage`, and offset math ✅
