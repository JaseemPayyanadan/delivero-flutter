# Order Details Redesign (Fillo mockup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the owner Order Details screen to the approved mockup: split hero card, separate customer card, read-only payment card with post-delivery update sheet, info banner, and a sticky bottom bar with a More sheet.

**Architecture:** Purely presentational rework of `order_details_screen.dart` and its `widgets/` folder, plus one additive change to the shared `DeliveroGradientHeader` (optional subtitle). Payment editing moves out of the screen into (a) the existing Mark-as-Delivered dialog (already seeds from the order when no draft is passed) and (b) a new post-delivery "Update payment" bottom sheet.

**Tech Stack:** Flutter, Riverpod (existing `ordersProvider`), `intl`. No new dependencies, no model changes.

**Spec:** `docs/superpowers/specs/2026-07-12-order-details-redesign-design.md`

## Global Constraints

- Colors ONLY from `lib/core/theme/app_colors.dart` (`AppColors.*`). No new hex values.
- Brand purple = `AppColors.primary` (`#5A45FE`); highlighted total row uses `AppColors.primary50`; qty chips/avatar use `AppColors.primaryLighter`.
- Do not touch `lib/features/delivery/order_details/driver_order_details_screen.dart` (out of scope).
- Existing behaviors must survive: pull-to-refresh, copy ID, call, maps, view customer, edit/delete kebab, cancel order, mark delivered, order-not-found fallback.
- `flutter analyze` must be clean and `flutter test` green after every task.
- Widget tests live in `test/order_details_widgets_test.dart` (new file, grows across tasks).

## Test Fixture (used by several tasks)

Every test task uses this helper at the top of `test/order_details_widgets_test.dart` — create it in Task 2 and reuse afterwards:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:delivero/core/widgets/delivero_gradient_header.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_summary_card.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_customer_card.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_payment_section.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_bottom_actions.dart';

final money0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

Order makeOrder({
  OrderStatus status = OrderStatus.pending,
  PaymentStatus? paymentStatus = PaymentStatus.unpaid,
  PaymentMethod? paymentMethod,
  double? amountPaid,
  double totalAmount = 1824,
}) {
  final now = DateTime(2026, 7, 12, 9);
  return Order(
    id: 'ORD-4583',
    factoryId: 'f1',
    orderType: OrderType.daily,
    customerId: 'c1',
    customerName: 'wbc',
    customerEmail: '',
    customerPhone: '9876543210',
    customerAddress: 'Ottappalam, Palakkad, Kerala',
    items: const [
      OrderItem(
        id: 'l1',
        foodItemId: 'i1',
        foodItemName: 'appam',
        quantity: 100,
        unitPrice: 12,
        totalPrice: 1200,
      ),
    ],
    subtotal: totalAmount,
    discountAmount: 0,
    totalAmount: totalAmount,
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    amountPaid: amountPaid,
    status: status,
    orderDate: now,
    deliveryTime: status == OrderStatus.delivered ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpCard(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
```

Check `pubspec.yaml` `name:` — if the package is not `delivero`, adjust the `package:` imports accordingly.

---

### Task 1: Gradient header subtitle + screen header

**Files:**
- Modify: `lib/core/widgets/delivero_gradient_header.dart`
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (the `DeliveroGradientHeader(...)` call, ~line 135)
- Test: `test/delivero_gradient_header_test.dart` (create)

**Interfaces:**
- Produces: `DeliveroGradientHeader` gains optional `final String? subtitle;` constructor param, rendered under the title in the banner. All existing call sites unaffected.

- [ ] **Step 1: Write the failing test**

Create `test/delivero_gradient_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/core/widgets/delivero_gradient_header.dart';

void main() {
  testWidgets('gradient header renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveroGradientHeader(
              title: 'Order Details',
              subtitle: '#ORD-4583',
              overlapChild: SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('#ORD-4583'), findsOneWidget);
  });

  testWidgets('gradient header without subtitle renders title only', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveroGradientHeader(
              title: 'Order Details',
              overlapChild: SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Order Details'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/delivero_gradient_header_test.dart`
Expected: FAIL — `No named parameter with the name 'subtitle'`.

- [ ] **Step 3: Add subtitle support**

In `delivero_gradient_header.dart`, add the field + constructor param:

```dart
  final String? subtitle;
```

Constructor: add `this.subtitle,` after `this.onBack,`.

In `_banner`, replace the `Expanded(child: Text(title, ...))` block with:

```dart
              Expanded(
                child: subtitle == null
                    ? Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.appBarTitle.copyWith(
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.appBarTitle.copyWith(
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
              ),
```

- [ ] **Step 4: Point the screen at the new header shape**

In `order_details_screen.dart`, change the header call:

```dart
              DeliveroGradientHeader(
                title: 'Order Details',
                subtitle: orderDetailDisplayId(order.id),
                onBack: Navigator.of(context).canPop()
                    ? () => context.pop()
                    : null,
                horizontalPadding: 20,
                bannerHeight: 104,
                overlap: 36,
                actions: [_buildOverflowMenu(context, ref, order)],
                overlapChild: OrderDetailSummaryCard(
                  // ... unchanged for now
                ),
              ),
```

- [ ] **Step 5: Run tests and analyzer**

Run: `flutter test test/delivero_gradient_header_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/delivero_gradient_header.dart lib/features/owner/orders/order_details/order_details_screen.dart test/delivero_gradient_header_test.dart
git commit -m "feat(order-details): header title + order id subtitle"
```

---

### Task 2: Hero card — split total/date layout, customer info removed

**Files:**
- Rewrite: `lib/features/owner/orders/order_details/widgets/order_detail_summary_card.dart`
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (summary card call site)
- Test: `test/order_details_widgets_test.dart` (create with fixture from header section)

**Interfaces:**
- Produces: `OrderDetailSummaryCard({required Order order, required String orderIdDisplay, required NumberFormat money0, required PaymentStatus paymentStatus, required double balanceDue})`. Status pill colors are computed internally via `orderDetailStatusBg/Fg` + `orderDetailHumanize`. The old params `routeLabel, paymentColor, statusBg, statusFg, statusLabel, onPhoneTap, onViewCustomer` are gone (Task 3 re-homes customer info).
- Consumes: `OrderDetailCard`, `OrderDetailStatusPill` from `order_detail_surfaces.dart`; formatting helpers from `order_detail_formatting.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/order_details_widgets_test.dart` with the fixture from the plan header, then add:

```dart
void main() {
  group('OrderDetailSummaryCard', () {
    testWidgets('shows total, due, date and order type', (tester) async {
      final order = makeOrder();
      await pumpCard(
        tester,
        OrderDetailSummaryCard(
          order: order,
          orderIdDisplay: '#ORD-4583',
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          balanceDue: 1824,
        ),
      );
      expect(find.text('Order Total'), findsOneWidget);
      expect(find.text('₹1,824'), findsOneWidget);
      expect(find.text('₹1,824 due'), findsOneWidget);
      expect(find.text('Sunday, 12 Jul 2026'), findsOneWidget);
      expect(find.text('Daily Order'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('paid order hides due line', (tester) async {
      final order = makeOrder(paymentStatus: PaymentStatus.paid, amountPaid: 1824);
      await pumpCard(
        tester,
        OrderDetailSummaryCard(
          order: order,
          orderIdDisplay: '#ORD-4583',
          money0: money0,
          paymentStatus: PaymentStatus.paid,
          balanceDue: 0,
        ),
      );
      expect(find.textContaining('due'), findsNothing);
    });
  });
}
```

(Leave the customer-card and payment-card imports in place; they will resolve in later tasks — if the analyzer complains now, comment them out and restore in Task 3/5.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_details_widgets_test.dart`
Expected: FAIL — new constructor shape doesn't exist yet.

- [ ] **Step 3: Rewrite the summary card**

Replace the entire contents of `order_detail_summary_card.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';

/// Hero card straddling the purple header: status + copy ID on top, then a
/// two-column split — order total / balance due on the left, date and order
/// type on the right.
class OrderDetailSummaryCard extends StatelessWidget {
  final Order order;
  final String orderIdDisplay;
  final NumberFormat money0;
  final PaymentStatus paymentStatus;
  final double balanceDue;

  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    required this.orderIdDisplay,
    required this.money0,
    required this.paymentStatus,
    required this.balanceDue,
  });

  void _copyId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: orderIdDisplay));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$orderIdDisplay copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLine = DateFormat('EEEE, d MMM yyyy').format(order.orderDate);
    final orderTypeLabel = switch (order.orderType) {
      OrderType.daily => 'Daily Order',
      OrderType.oneTime => 'One-time Order',
      OrderType.special => 'Special Order',
    };
    final showDue = paymentStatus != PaymentStatus.paid && balanceDue > 0.004;
    final dueColor = paymentStatus == PaymentStatus.unpaid
        ? AppColors.error
        : AppColors.warning;
    final captionMuted = context.appTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
    );
    final isDelivered = order.status == OrderStatus.delivered;

    return OrderDetailCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrderDetailStatusPill(
                label: orderDetailHumanize(order.status.name),
                bg: orderDetailStatusBg(order.status),
                fg: orderDetailStatusFg(order.status),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _copyId(context),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Order Total', style: captionMuted),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money0.format(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1.1,
                            height: 1.05,
                          ),
                        ),
                      ),
                      if (showDue) ...[
                        const SizedBox(height: 6),
                        Text(
                          paymentStatus == PaymentStatus.partial
                              ? '${money0.format(balanceDue)} balance due'
                              : '${money0.format(balanceDue)} due',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: dueColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.divider,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconInfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: dateLine,
                      ),
                      const SizedBox(height: 12),
                      _IconInfoRow(
                        icon: Icons.autorenew_rounded,
                        label: orderTypeLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isDelivered && order.deliveryTime != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivered · ${DateFormat('d MMM yyyy · HH:mm').format(order.deliveryTime!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconInfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Update the call site**

In `order_details_screen.dart`, replace the `overlapChild:` block with:

```dart
                overlapChild: OrderDetailSummaryCard(
                  order: order,
                  orderIdDisplay: orderDetailDisplayId(order.id),
                  money0: money0,
                  paymentStatus: resolved.paymentStatus,
                  balanceDue: resolved.balanceDue,
                ),
```

Also delete the now-unused locals `statusBg`, `statusFg` (keep `paymentColor` — the payment card still uses it) and remove the now-unused `_handleCallCustomer` ONLY IF the analyzer flags it — Task 3 rewires it, so prefer leaving it in place.

- [ ] **Step 5: Run tests + analyzer**

Run: `flutter test test/order_details_widgets_test.dart && flutter analyze`
Expected: PASS. If the fixture's unresolved imports (customer card / payment card) break analysis, comment those two imports until their tasks.

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_summary_card.dart lib/features/owner/orders/order_details/order_details_screen.dart test/order_details_widgets_test.dart
git commit -m "feat(order-details): split hero card with total and date columns"
```

---

### Task 3: Customer card

**Files:**
- Create: `lib/features/owner/orders/order_details/widgets/order_detail_customer_card.dart`
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (insert card, wire taps)
- Test: `test/order_details_widgets_test.dart` (append group)

**Interfaces:**
- Produces: `OrderDetailCustomerCard({required String name, required String phone, required String address, required String routeLabel, VoidCallback? onCall, VoidCallback? onOpenAddress, VoidCallback? onViewCustomer})`.
- Consumes: `OrderDetailCard` from `order_detail_surfaces.dart`; screen wires `onCall` → `_handleCallCustomer`, `onOpenAddress` → `_openMaps`, `onViewCustomer` → `context.push('/owner/customers/<id>')`.

- [ ] **Step 1: Write the failing test**

Append to `test/order_details_widgets_test.dart` (restore/enable the customer-card import):

```dart
  group('OrderDetailCustomerCard', () {
    testWidgets('shows initial avatar, name, phone, address and link', (tester) async {
      var viewed = false;
      await pumpCard(
        tester,
        OrderDetailCustomerCard(
          name: 'wbc',
          phone: '9876543210',
          address: 'Ottappalam, Palakkad, Kerala',
          routeLabel: '',
          onViewCustomer: () => viewed = true,
        ),
      );
      expect(find.text('W'), findsOneWidget);
      expect(find.text('wbc'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Ottappalam, Palakkad, Kerala'), findsOneWidget);
      await tester.tap(find.text('View customer'));
      expect(viewed, isTrue);
    });

    testWidgets('hides view-customer link when callback is null', (tester) async {
      await pumpCard(
        tester,
        const OrderDetailCustomerCard(
          name: 'wbc',
          phone: '',
          address: '',
          routeLabel: '',
        ),
      );
      expect(find.text('View customer'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_details_widgets_test.dart`
Expected: FAIL — `order_detail_customer_card.dart` doesn't exist.

- [ ] **Step 3: Create the widget**

Create `order_detail_customer_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'order_detail_surfaces.dart';

/// Standalone customer card: avatar + name, phone | address columns, and a
/// "View customer" link. All contact rows are tappable when a handler is set.
class OrderDetailCustomerCard extends StatelessWidget {
  final String name;
  final String phone;
  final String address;
  final String routeLabel;
  final VoidCallback? onCall;
  final VoidCallback? onOpenAddress;
  final VoidCallback? onViewCustomer;

  const OrderDetailCustomerCard({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    required this.routeLabel,
    this.onCall,
    this.onOpenAddress,
    this.onViewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Customer' : name.trim();
    final initial = displayName.characters.first.toUpperCase();
    final hasPhone = phone.trim().isNotEmpty;
    final hasAddress = address.trim().isNotEmpty;
    final captionMuted = context.appTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
    );

    return OrderDetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLighter,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer', style: captionMuted),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (routeLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    routeLabel.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasPhone || hasAddress) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasPhone)
                    Expanded(
                      child: _ContactCell(
                        icon: Icons.phone_rounded,
                        label: phone.trim(),
                        onTap: onCall,
                        semanticsLabel: 'Call ${phone.trim()}',
                      ),
                    ),
                  if (hasPhone && hasAddress)
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppColors.divider,
                    ),
                  if (hasAddress)
                    Expanded(
                      flex: hasPhone ? 2 : 1,
                      child: _ContactCell(
                        icon: Icons.location_on_rounded,
                        label: address.trim(),
                        onTap: onOpenAddress,
                        semanticsLabel: 'Open ${address.trim()} in maps',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (onViewCustomer != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onViewCustomer,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View customer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const _ContactCell({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Semantics(button: true, label: semanticsLabel, child: row),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Insert into the screen**

In `order_details_screen.dart`, add the import:

```dart
import 'widgets/order_detail_customer_card.dart';
```

Inside the content `Padding > Column`, insert the customer card BEFORE the Items section header:

```dart
                    if (order.customerName.trim().isNotEmpty ||
                        order.customerPhone.trim().isNotEmpty ||
                        order.customerAddress.trim().isNotEmpty) ...[
                      OrderDetailCustomerCard(
                        name: order.customerName,
                        phone: order.customerPhone,
                        address: order.customerAddress,
                        routeLabel: resolved.summaryRouteLabel,
                        onCall: order.customerPhone.trim().isEmpty
                            ? null
                            : () {
                                try {
                                  HapticFeedback.selectionClick();
                                } catch (_) {}
                                _handleCallCustomer(
                                  context,
                                  order.customerPhone,
                                );
                              },
                        onOpenAddress: order.customerAddress.trim().isEmpty
                            ? null
                            : () => _openMaps(context, order.customerAddress),
                        onViewCustomer: order.customerId.trim().isEmpty
                            ? null
                            : () => context.push(
                                '/owner/customers/${order.customerId}',
                              ),
                      ),
                      const SizedBox(height: 22),
                    ],
```

- [ ] **Step 5: Run tests + analyzer**

Run: `flutter test test/order_details_widgets_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_customer_card.dart lib/features/owner/orders/order_details/order_details_screen.dart test/order_details_widgets_test.dart
git commit -m "feat(order-details): standalone customer card with contact columns"
```

---

### Task 4: Items card — header inside, square qty chip

**Files:**
- Modify: `lib/features/owner/orders/order_details/widgets/order_detail_item_row.dart` (chip shape)
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (items section)

**Interfaces:**
- Consumes: `OrderDetailItemRow({required OrderItem item})` — signature unchanged, only the badge visual changes.

- [ ] **Step 1: Change the qty badge to a rounded square**

In `order_detail_item_row.dart`, replace the leading `Container` (the circle) with:

```dart
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.unit == ProductUnit.quantity
                  ? '${item.quantity}x'
                  : item.unit.formatAmount(item.quantity),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
```

- [ ] **Step 2: Move the section header inside the card**

In `order_details_screen.dart`, replace this block:

```dart
                    OrderDetailSectionHeader(
                      title: 'Items',
                      trailing: '${order.items.length} Items',
                    ),
                    const SizedBox(height: 10),
                    OrderDetailCard(
                      child: Column(
                        children: [
                          for (...) ...
                        ],
                      ),
                    ),
```

with:

```dart
                    OrderDetailCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OrderDetailSectionHeader(
                            title: 'Items',
                            trailing:
                                '${order.items.length} ${order.items.length == 1 ? 'Item' : 'Items'}',
                          ),
                          const SizedBox(height: 4),
                          for (
                            int idx = 0;
                            idx < order.items.length;
                            idx++
                          ) ...[
                            OrderDetailItemRow(item: order.items[idx]),
                            if (idx != order.items.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.divider,
                              ),
                          ],
                        ],
                      ),
                    ),
```

Then in `order_detail_item_row.dart`, since the card now provides horizontal padding, change the row's own padding to `EdgeInsets.symmetric(vertical: 12)`.

- [ ] **Step 3: Run tests + analyzer**

Run: `flutter test && flutter analyze`
Expected: All green, clean.

- [ ] **Step 4: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_item_row.dart lib/features/owner/orders/order_details/order_details_screen.dart
git commit -m "feat(order-details): items card with inset header and square qty chips"
```

---

### Task 5: Read-only payment card + post-delivery update sheet

**Files:**
- Rewrite: `lib/features/owner/orders/order_details/widgets/order_detail_payment_section.dart`
- Create: `lib/features/owner/orders/order_details/widgets/order_detail_update_payment_sheet.dart`
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (drop all payment-draft state)
- Test: `test/order_details_widgets_test.dart` (append group)

**Interfaces:**
- Produces: `OrderDetailPaymentCard({required Order order, required NumberFormat money0, required PaymentStatus paymentStatus, required Color paymentColor, required double deliveryFee, required double effectivePaid, required double balanceDue, VoidCallback? onUpdatePayment})` — pure display; the "Update payment" link renders only when `onUpdatePayment != null`.
- Produces: `Future<void> showOrderDetailUpdatePaymentSheet({required BuildContext context, required WidgetRef ref, required Order order})` — bottom sheet owning its own draft state; Save persists via `ordersProvider.updateOrder` with the same normalization/validation the old inline editor used.
- Consumes: `OrderDetailCard`, `OrderDetailSectionHeader`, `OrderDetailPillBadge`, `OrderDetailSummaryRow`, `OrderDetailLabeledDropdown` from `order_detail_surfaces.dart`; `orderDetailHumanize`, `orderDetailPaymentColor` from `order_detail_formatting.dart`.

- [ ] **Step 1: Write the failing test**

Append to `test/order_details_widgets_test.dart` (enable the payment-section import):

```dart
  group('OrderDetailPaymentCard', () {
    testWidgets('read-only card shows totals and no editor controls', (tester) async {
      final order = makeOrder();
      await pumpCard(
        tester,
        OrderDetailPaymentCard(
          order: order,
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          paymentColor: const Color(0xFFDC2626),
          deliveryFee: 0,
          effectivePaid: 0,
          balanceDue: 1824,
        ),
      );
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('UNPAID'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Update payment'), findsNothing);
    });

    testWidgets('shows update link when callback provided', (tester) async {
      var tapped = false;
      final order = makeOrder(status: OrderStatus.delivered);
      await pumpCard(
        tester,
        OrderDetailPaymentCard(
          order: order,
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          paymentColor: const Color(0xFFDC2626),
          deliveryFee: 0,
          effectivePaid: 0,
          balanceDue: 1824,
          onUpdatePayment: () => tapped = true,
        ),
      );
      await tester.tap(find.text('Update payment'));
      expect(tapped, isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_details_widgets_test.dart`
Expected: FAIL — `OrderDetailPaymentCard` doesn't exist.

- [ ] **Step 3: Rewrite the payment section as a read-only card**

Replace the entire contents of `order_detail_payment_section.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';

/// Read-only payment summary card. Payment is recorded via the
/// Mark-as-Delivered flow; after delivery, [onUpdatePayment] (when set)
/// exposes an "Update payment" link for collecting outstanding balance.
class OrderDetailPaymentCard extends StatelessWidget {
  final Order order;
  final NumberFormat money0;
  final PaymentStatus paymentStatus;
  final Color paymentColor;
  final double deliveryFee;
  final double effectivePaid;
  final double balanceDue;
  final VoidCallback? onUpdatePayment;

  const OrderDetailPaymentCard({
    super.key,
    required this.order,
    required this.money0,
    required this.paymentStatus,
    required this.paymentColor,
    required this.deliveryFee,
    required this.effectivePaid,
    required this.balanceDue,
    this.onUpdatePayment,
  });

  @override
  Widget build(BuildContext context) {
    final statusAmount = paymentStatus == PaymentStatus.paid
        ? order.totalAmount
        : balanceDue;
    final showMethod =
        paymentStatus != PaymentStatus.unpaid || order.paymentMethod != null;

    return OrderDetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderDetailSectionHeader(
            title: 'Payment',
            trailingWidget: OrderDetailPillBadge(
              label: orderDetailHumanize(paymentStatus.name).toUpperCase(),
              background: paymentColor == AppColors.error
                  ? AppColors.errorLighter.withValues(alpha: 0.68)
                  : paymentColor.withValues(alpha: 0.096),
              foreground: paymentColor,
              border: paymentColor.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: paymentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  orderDetailHumanize(paymentStatus.name),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                money0.format(statusAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (showMethod) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _methodIcon(order.paymentMethod),
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  orderDetailHumanize(
                    (order.paymentMethod ?? PaymentMethod.cash).name,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const _DashedDivider(),
          const SizedBox(height: 14),
          OrderDetailSummaryRow(label: 'Subtotal', value: order.subtotal),
          if (order.discountAmount > 0.004) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Discount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
                Text(
                  '−${money0.format(order.discountAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          OrderDetailSummaryRow(label: 'Delivery Fee', value: deliveryFee),
          if (paymentStatus == PaymentStatus.partial) ...[
            const SizedBox(height: 10),
            OrderDetailSummaryRow(label: 'Paid Amount', value: effectivePaid),
            const SizedBox(height: 10),
            OrderDetailSummaryRow(label: 'Balance Due', value: balanceDue),
          ],
          if (order.paymentTime != null &&
              order.paymentStatus != PaymentStatus.unpaid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collected at',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(order.paymentTime!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  money0.format(order.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (onUpdatePayment != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUpdatePayment,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Update payment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.border),
              ),
            ),
          ),
        );
      },
    );
  }
}

IconData _methodIcon(PaymentMethod? method) => switch (method) {
  PaymentMethod.cash => Icons.payments_rounded,
  PaymentMethod.upi => Icons.qr_code_rounded,
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.online => Icons.language_rounded,
  null => Icons.payments_rounded,
};
```

- [ ] **Step 4: Create the update-payment bottom sheet**

Create `order_detail_update_payment_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';

/// Bottom sheet for recording payment on an already-delivered order.
Future<void> showOrderDetailUpdatePaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Order order,
}) async {
  final money0 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _UpdatePaymentSheet(
        order: order,
        money0: money0,
        onSave: (status, method, amountPaid) {
          final next = order.copyWith(
            paymentStatus: status,
            paymentMethod: method,
            amountPaid: amountPaid,
            paymentTime: status == PaymentStatus.unpaid
                ? null
                : DateTime.now(),
            updatedAt: DateTime.now(),
          );
          ref.read(ordersProvider.notifier).updateOrder(next);
          ref
              .read(lastTouchedOrderProvider.notifier)
              .set(id: next.id, wasCreated: false);
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Payment status updated',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _UpdatePaymentSheet extends StatefulWidget {
  final Order order;
  final NumberFormat money0;
  final void Function(
    PaymentStatus status,
    PaymentMethod method,
    double? amountPaid,
  ) onSave;

  const _UpdatePaymentSheet({
    required this.order,
    required this.money0,
    required this.onSave,
  });

  @override
  State<_UpdatePaymentSheet> createState() => _UpdatePaymentSheetState();
}

class _UpdatePaymentSheetState extends State<_UpdatePaymentSheet> {
  late PaymentStatus _status;
  late PaymentMethod _method;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _status = widget.order.paymentStatus ?? PaymentStatus.unpaid;
    _method = widget.order.paymentMethod ?? PaymentMethod.cash;
    final amount = widget.order.amountPaid ?? 0;
    _amountController = TextEditingController(
      text: _status == PaymentStatus.partial && amount > 0
          ? amount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final order = widget.order;
    double? amountPaid;
    if (_status == PaymentStatus.unpaid) {
      amountPaid = null;
    } else if (_status == PaymentStatus.paid) {
      amountPaid = order.totalAmount;
    } else {
      final parsed = double.tryParse(
        _amountController.text.trim().replaceAll(',', ''),
      );
      final clamped = (parsed ?? 0).clamp(0.0, order.totalAmount);
      if (clamped <= 0 || clamped >= order.totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter an amount between ${widget.money0.format(1)} and ${widget.money0.format(order.totalAmount - 1)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warning,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      amountPaid = clamped;
    }
    widget.onSave(_status, _method, amountPaid);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update payment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Order total ${widget.money0.format(widget.order.totalAmount)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OrderDetailLabeledDropdown<PaymentStatus>(
                    label: 'STATUS',
                    value: _status,
                    items: const [
                      PaymentStatus.unpaid,
                      PaymentStatus.paid,
                      PaymentStatus.partial,
                    ],
                    itemLabel: (v) => orderDetailHumanize(v.name),
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OrderDetailLabeledDropdown<PaymentMethod>(
                    label: 'METHOD',
                    value: _method,
                    items: const [
                      PaymentMethod.cash,
                      PaymentMethod.upi,
                      PaymentMethod.card,
                      PaymentMethod.online,
                    ],
                    itemLabel: (v) => orderDetailHumanize(v.name),
                    onChanged: (v) => setState(() => _method = v),
                  ),
                ),
              ],
            ),
            if (_status == PaymentStatus.partial) ...[
              const SizedBox(height: 14),
              const Text(
                'AMOUNT PAID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: widget.money0.format(widget.order.totalAmount),
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Strip payment-draft state from the screen**

In `order_details_screen.dart`:

1. Delete the fields `_draftPaymentStatus`, `_draftPaymentMethod`, `_draftAmountPaid`, `_lastServerPaymentStatus`, `_lastServerPaymentMethod`, `_lastServerAmountPaid`, `_partialAmountController`, the `_resetPaymentDrafts` method, the `dispose` override, and the entire draft-sync block inside `build` (lines starting `final serverStatus = ...` through the partial-seed `if`).
2. Add import: `import 'widgets/order_detail_update_payment_sheet.dart';`
3. Replace the `OrderDetailPaymentSection(...)` call with:

```dart
                    OrderDetailPaymentCard(
                      order: order,
                      money0: money0,
                      paymentStatus: resolved.paymentStatus,
                      paymentColor: paymentColor,
                      deliveryFee: resolved.deliveryFee,
                      effectivePaid: resolved.effectivePaid,
                      balanceDue: resolved.balanceDue,
                      onUpdatePayment:
                          order.status == OrderStatus.delivered &&
                              resolved.paymentStatus != PaymentStatus.paid
                          ? () => showOrderDetailUpdatePaymentSheet(
                              context: context,
                              ref: ref,
                              order: order,
                            )
                          : null,
                    ),
```

4. Simplify the mark-delivered call — the dialog seeds from the order itself when no draft is passed:

```dart
                      onMarkDelivered: () => showConfirmMarkDeliveredDialog(
                        context: context,
                        ref: ref,
                        order: order,
                      ),
```

Remove the now-unused `ConfirmMarkDeliveredPaymentDraft` import reference if the analyzer flags it (the import of `confirm_mark_delivered.dart` stays — `showConfirmMarkDeliveredDialog` is still used).

- [ ] **Step 6: Run tests + analyzer**

Run: `flutter test && flutter analyze`
Expected: All green, clean.

- [ ] **Step 7: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_payment_section.dart lib/features/owner/orders/order_details/widgets/order_detail_update_payment_sheet.dart lib/features/owner/orders/order_details/order_details_screen.dart test/order_details_widgets_test.dart
git commit -m "feat(order-details): read-only payment card with post-delivery update sheet"
```

---

### Task 6: Info banner + sticky bottom bar with More sheet

**Files:**
- Rewrite: `lib/features/owner/orders/order_details/widgets/order_detail_bottom_actions.dart`
- Modify: `lib/features/owner/orders/order_details/order_details_screen.dart` (banner, `bottomNavigationBar`, More sheet)
- Test: `test/order_details_widgets_test.dart` (append group)

**Interfaces:**
- Produces: `OrderDetailBottomBar({required bool isDelivered, required VoidCallback onMarkDelivered, required VoidCallback onMore})` — a Row for embedding in the screen's `bottomNavigationBar`.
- Consumes: screen supplies `onMore` opening a modal sheet with Navigate / Edit order / Cancel order / Delete order.

- [ ] **Step 1: Write the failing test**

Append to `test/order_details_widgets_test.dart` (enable the bottom-actions import):

```dart
  group('OrderDetailBottomBar', () {
    testWidgets('fires callbacks and disables when delivered', (tester) async {
      var delivered = false;
      var more = false;
      await pumpCard(
        tester,
        OrderDetailBottomBar(
          isDelivered: false,
          onMarkDelivered: () => delivered = true,
          onMore: () => more = true,
        ),
      );
      await tester.tap(find.text('Mark as Delivered'));
      await tester.tap(find.text('More'));
      expect(delivered, isTrue);
      expect(more, isTrue);

      await pumpCard(
        tester,
        OrderDetailBottomBar(
          isDelivered: true,
          onMarkDelivered: () {},
          onMore: () {},
        ),
      );
      expect(find.text('Delivered'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_details_widgets_test.dart`
Expected: FAIL — `OrderDetailBottomBar` doesn't exist.

- [ ] **Step 3: Rewrite the bottom actions widget**

Replace the entire contents of `order_detail_bottom_actions.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Sticky bottom action bar: primary "Mark as Delivered" plus a "More" pill
/// that opens the secondary-actions sheet.
class OrderDetailBottomBar extends StatelessWidget {
  final bool isDelivered;
  final VoidCallback onMarkDelivered;
  final VoidCallback onMore;

  const OrderDetailBottomBar({
    super.key,
    required this.isDelivered,
    required this.onMarkDelivered,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isDelivered ? null : onMarkDelivered,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: AppColors.successLighter,
              disabledForegroundColor: AppColors.success,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            icon: Icon(
              isDelivered
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
            ),
            label: Text(isDelivered ? 'Delivered' : 'Mark as Delivered'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          label: const Text('More'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Restructure the screen — banner, sticky bar, More sheet**

In `order_details_screen.dart`:

1. Replace the `OrderDetailBottomActions(...)` block inside the scroll content with the info banner (shown only pre-delivery/pre-cancel):

```dart
                    if (order.status != OrderStatus.delivered &&
                        order.status != OrderStatus.cancelled) ...[
                      const SizedBox(height: 18),
                      const _PaymentInfoBanner(),
                    ],
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
```

2. Add `bottomNavigationBar` to the `Scaffold` (order is available since the null-check returns earlier):

```dart
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: OrderDetailBottomBar(
              isDelivered: order.status == OrderStatus.delivered,
              onMarkDelivered: () => showConfirmMarkDeliveredDialog(
                context: context,
                ref: ref,
                order: order,
              ),
              onMore: () => _showMoreSheet(context, ref, order),
            ),
          ),
        ),
      ),
```

3. Add the More sheet method to the state class:

```dart
  void _showMoreSheet(BuildContext context, WidgetRef ref, Order order) {
    final canEdit =
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;
    final canCancel = canEdit;
    final hasAddress = order.customerAddress.trim().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAddress)
              ListTile(
                leading: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Navigate to address',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMaps(context, order.customerAddress);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'Edit order',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/owner/orders/edit/${order.id}');
                },
              ),
            if (canCancel)
              ListTile(
                leading: const Icon(
                  Icons.close_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Cancel order',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmCancelOrder(context, ref, order);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete order',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleDelete(context, ref, order);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
```

4. Add the banner widget at the bottom of the file:

```dart
class _PaymentInfoBanner extends StatelessWidget {
  const _PaymentInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You can update payment details after marking the order as delivered.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

5. Keep the kebab menu in the header as-is (Edit/Delete shortcut).

- [ ] **Step 5: Run full tests + analyzer**

Run: `flutter test && flutter analyze`
Expected: All green, clean.

- [ ] **Step 6: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_bottom_actions.dart lib/features/owner/orders/order_details/order_details_screen.dart test/order_details_widgets_test.dart
git commit -m "feat(order-details): info banner and sticky bottom bar with more sheet"
```

---

### Task 7: Verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full suite**

Run: `flutter test && flutter analyze`
Expected: all tests pass, zero analyzer issues.

- [ ] **Step 2: Manual verification in the running app**

Launch the app and open an order from the Orders list. Verify against the mockup:

1. Pending order: purple header shows "Order Details" + `#ORD-…`; hero card shows status pill, copy icon, total left / date + type right; red "due" line when unpaid.
2. Customer card: avatar initial, name, phone (tap → dialer), address (tap → maps), "View customer →" navigates.
3. Items card: "Items" + count inside the card, square purple qty chips.
4. Payment card: read-only, no dropdowns/text field; highlighted purple Total Amount row; dashed divider present.
5. Info banner visible on pending order, gone after delivery.
6. Bottom bar sticky while scrolling; "Mark as Delivered" opens the Check-payment dialog seeded with the order's current payment; confirming delivers.
7. On the now-delivered unpaid order: banner gone, "Update payment →" link on payment card opens the sheet; saving Paid/Cash updates the card and pill.
8. More sheet: Navigate/Edit/Cancel/Delete rows appear per order state; delivered order hides Edit + Cancel.
9. Kebab menu still offers Edit/Delete.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A && git commit -m "fix(order-details): polish from manual verification"
```
