# Product Unit — Remaining Display Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the per-product unit (quantity/kg/gram/litre) on the six remaining screens that still display a bare count.

**Architecture:** A new `ProductUnit.compactAmount` helper renders dense preview rows. Order-line preview surfaces read `OrderItem.unit` directly. The dashboard + reports surfaces share `ProductSalesData`, which gains a `unit` field populated during aggregation. Customer-detail rows resolve the unit by product id from the food catalog.

**Tech Stack:** Flutter / Dart, Riverpod, `flutter_test`. Package name is `delivero`.

## Global Constraints

- Quantities stay `int`. Unit is a display label only.
- Backward compatibility is mandatory: for `ProductUnit.quantity`, every surface renders byte-for-byte identical to today — preview rows `x2`, dashboard `qty`, reports `units` / `units sold`, favorites `units each order`.
- Cross-product aggregates (sums across different products) stay unlabeled — do not add a unit word to any "total items" figure.
- Run `dart analyze` on changed dirs before each commit; no new issues. Run `flutter test` after model/logic tasks; no regressions.
- Disk note: if any flutter command fails with "No space left on device", run `rm -rf build` at repo root, then retry.

---

### Task 1: `ProductUnit.compactAmount` helper

**Files:**
- Modify: `lib/data/models/product_unit.dart`
- Test: `test/product_unit_test.dart`

**Interfaces:**
- Produces: `String ProductUnit.compactAmount(int n)` → `'x$n'` for quantity, else `formatAmount(n)` (`'$n kg'` / `'$n g'` / `'$n L'`).

- [ ] **Step 1: Write the failing test**

Add this group to `test/product_unit_test.dart` (after the existing `label getters` group, inside `main`):

```dart
  group('ProductUnit.compactAmount', () {
    test('quantity keeps the leading-x form', () {
      expect(ProductUnit.quantity.compactAmount(2), 'x2');
    });
    test('weight/volume read naturally', () {
      expect(ProductUnit.kilogram.compactAmount(2), '2 kg');
      expect(ProductUnit.gram.compactAmount(2), '2 g');
      expect(ProductUnit.litre.compactAmount(2), '2 L');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/product_unit_test.dart`
Expected: FAIL — `The method 'compactAmount' isn't defined`.

- [ ] **Step 3: Add the helper**

In `lib/data/models/product_unit.dart`, add inside the enum (after the `chipLabel` getter, before the closing `}`):

```dart

  /// Compact amount for dense preview rows: `x2` for quantity (unchanged),
  /// `2 kg` / `2 g` / `2 L` otherwise.
  String compactAmount(int n) =>
      this == ProductUnit.quantity ? 'x$n' : formatAmount(n);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/product_unit_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/product_unit.dart test/product_unit_test.dart
git commit -m "feat: add ProductUnit.compactAmount for preview rows"
```

---

### Task 2: `ProductSalesData.unit` + aggregation

**Files:**
- Modify: `lib/app/reports_provider.dart` (class `ProductSalesData` ~50; loop ~131-146)
- Test: `test/reports_provider_test.dart` (new)

**Interfaces:**
- Consumes: `ProductUnit` (Task 1), `OrderItem.unit`.
- Produces: `ProductSalesData` gains `final ProductUnit unit` (required); `computeReports` populates it from the first-seen `item.unit` per product name and preserves it on merge.

- [ ] **Step 1: Write the failing test**

Create `test/reports_provider_test.dart`:

```dart
import 'package:delivero/app/reports_provider.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(List<OrderItem> items) => Order(
      id: 'o1',
      factoryId: 'FAC',
      orderType: OrderType.oneTime,
      deliveryRun: DeliveryRun.morning,
      customerId: 'c1',
      customerName: 'Test',
      customerEmail: '',
      customerPhone: '',
      customerAddress: '',
      items: items,
      subtotal: 0,
      discountAmount: 0,
      totalAmount: 0,
      status: OrderStatus.delivered,
      paymentStatus: PaymentStatus.paid,
      orderDate: DateTime(2025, 6, 20),
      createdAt: DateTime(2025, 6, 20),
      updatedAt: DateTime(2025, 6, 20),
    );

OrderItem _item(String name, int qty, ProductUnit unit) => OrderItem(
      id: name,
      foodItemId: name,
      foodItemName: name,
      quantity: qty,
      unitPrice: 10,
      totalPrice: 10 * qty,
      unit: unit,
    );

void main() {
  test('ProductSalesData carries the product unit', () {
    final data = computeReports([
      _order([_item('Rice', 2, ProductUnit.kilogram)]),
    ]);
    expect(data.productSales['Rice']!.unit, ProductUnit.kilogram);
  });

  test('merged lines keep the first-seen unit and sum quantity', () {
    final data = computeReports([
      _order([_item('Rice', 2, ProductUnit.kilogram)]),
      _order([_item('Rice', 3, ProductUnit.kilogram)]),
    ]);
    final rice = data.productSales['Rice']!;
    expect(rice.quantity, 5);
    expect(rice.unit, ProductUnit.kilogram);
  });
}
```

> Before running, open `lib/data/models/order.dart` and confirm the `Order(...)`
> constructor parameter names used above match (especially `orderDate`,
> `amountPaid` optionality, `paymentStatus`). Adjust the helper to the real
> required params if they differ — the test's point is only that
> `productSales['Rice'].unit` is populated.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reports_provider_test.dart`
Expected: FAIL — `ProductSalesData` has no `unit` (and the constructor call in step 3 not yet updated).

- [ ] **Step 3: Add `unit` to `ProductSalesData` and populate it**

In `lib/app/reports_provider.dart`:

Add the import near the top with the other model imports:

```dart
import '../data/models/product_unit.dart';
```

In `class ProductSalesData`, add the field after `final int quantity;`:

```dart
  final ProductUnit unit;
```

Add to the constructor (after `required this.quantity,`):

```dart
    required this.unit,
```

In the product-breakdown loop, update BOTH `ProductSalesData(...)` constructions. The merge branch (where `existing != null`):

```dart
        productSalesMap[item.foodItemName] = ProductSalesData(
          name: item.foodItemName,
          quantity: existing.quantity + item.quantity,
          revenue: existing.revenue + item.totalPrice,
          unit: existing.unit,
        );
```

The first-seen branch (`else`):

```dart
        productSalesMap[item.foodItemName] = ProductSalesData(
          name: item.foodItemName,
          quantity: item.quantity,
          revenue: item.totalPrice,
          unit: item.unit,
        );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/reports_provider_test.dart && flutter test`
Expected: new test PASS; full suite PASS (no regressions).

- [ ] **Step 5: Commit**

```bash
git add lib/app/reports_provider.dart test/reports_provider_test.dart
git commit -m "feat: carry product unit in ProductSalesData aggregation"
```

---

### Task 3: Group A — order-line preview rows

**Files:**
- Modify: `lib/features/owner/orders/widgets/order_card.dart` (~90)
- Modify: `lib/features/delivery/order_status_list_screen.dart` (~297)
- Modify: `lib/features/owner/orders/unresolved_orders_sheet.dart` (~177)

**Interfaces:**
- Consumes: `OrderItem.unit`, `ProductUnit.compactAmount` (Task 1).

Each maps over `OrderItem` (loop var `i`). Replace the `x${i.quantity}` fragment with `${i.unit.compactAmount(i.quantity)}`. For quantity items this yields `x2` byte-for-byte; for kg/g/L it yields `2 kg` etc.

- [ ] **Step 1: order_card.dart**

Replace:

```dart
              (i) =>
                  '${displayNameWithPackLabel(i.foodItemName, i.packLabel)} x${i.quantity}',
```

with:

```dart
              (i) =>
                  '${displayNameWithPackLabel(i.foodItemName, i.packLabel)} ${i.unit.compactAmount(i.quantity)}',
```

- [ ] **Step 2: order_status_list_screen.dart**

Replace:

```dart
            ...previewItems.map((i) => '${i.foodItemName} x${i.quantity}'),
```

with:

```dart
            ...previewItems.map(
              (i) => '${i.foodItemName} ${i.unit.compactAmount(i.quantity)}',
            ),
```

- [ ] **Step 3: unresolved_orders_sheet.dart**

Replace:

```dart
                .map((i) => '${i.foodItemName} x${i.quantity}')
```

with:

```dart
                .map((i) => '${i.foodItemName} ${i.unit.compactAmount(i.quantity)}')
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/features/owner/orders/ lib/features/delivery/`
Expected: no new issues. (If analyze reports `ProductUnit` undefined in any file, add `import '../../../data/models/product_unit.dart';` with the correct relative depth for that file.)
Manual check (reviewer): an order containing a 2 kg product shows `Rice 2 kg` on the order list card, driver status list, and unresolved sheet; quantity products still show `Rice x2`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/widgets/order_card.dart lib/features/delivery/order_status_list_screen.dart lib/features/owner/orders/unresolved_orders_sheet.dart
git commit -m "feat: show unit on order-line preview rows"
```

---

### Task 4: Group B — dashboard + reports render sites

**Files:**
- Modify: `lib/features/owner/dashboard/owner_dashboard_screen.dart` (~2417)
- Modify: `lib/features/owner/reports/reports_screen.dart` (~183, ~1395)

**Interfaces:**
- Consumes: `ProductSalesData.unit` (Task 2), `ProductUnit.productionWord`, `ProductUnit.quantity`.

- [ ] **Step 1: Dashboard top-products (preserve `qty` for quantity)**

In `owner_dashboard_screen.dart`, add the import with the other imports (it already imports `reports_provider.dart`; add the model import for the `ProductUnit.quantity` literal):

```dart
import '../../../data/models/product_unit.dart';
```

Replace:

```dart
              '$pctLabel · ${item.quantity} qty',
```

with:

```dart
              '$pctLabel · ${item.quantity} ${item.unit == ProductUnit.quantity ? 'qty' : item.unit.productionWord}',
```

- [ ] **Step 2: Reports drilldown subtitle**

In `reports_screen.dart`, replace:

```dart
              subtitle: '${p.quantity} units sold',
```

with:

```dart
              subtitle: '${p.quantity} ${p.unit.productionWord} sold',
```

- [ ] **Step 3: Reports product list**

In `reports_screen.dart`, replace:

```dart
              '${product.quantity} units',
```

with:

```dart
              '${product.quantity} ${product.unit.productionWord}',
```

(For quantity, `productionWord == 'units'`, so both reports rows are unchanged.)

- [ ] **Step 4: Verify**

Run: `dart analyze lib/features/owner/dashboard/ lib/features/owner/reports/`
Expected: no new issues. (If `reports_screen.dart` reports `productionWord` unresolved, add `import '../../../data/models/product_unit.dart';`.)
Manual check (reviewer): a kg product reads `… · 12 kg` on the dashboard top-products row, `12 kg sold` in the reports drilldown, and `12 kg` in the reports product list; quantity products read `… · 12 qty`, `12 units sold`, `12 units` exactly as before.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/dashboard/owner_dashboard_screen.dart lib/features/owner/reports/reports_screen.dart
git commit -m "feat: show unit on dashboard top-products and reports"
```

---

### Task 5: Group C — customer detail (favorites + recurring)

**Files:**
- Modify: `lib/features/owner/customers/customer_details_screen.dart`

**Interfaces:**
- Consumes: `FoodItem.unit`, `ProductUnit`, `ProductUnit.compactAmount`, `ProductUnit.productionWord`.

The favorites list and recurring rows come from `customer.products` (no unit). Resolve the unit by product id from the food catalog, mirroring the existing `catalogPriceById` map.

- [ ] **Step 1: Build a `unitById` map next to `catalogPriceById`**

Find (in the main `build`, ~215):

```dart
    final Map<String, double> catalogPriceById = {
      for (final FoodItem item in foodItems) item.id: item.price,
    };
```

Add immediately after it:

```dart
    final Map<String, ProductUnit> unitById = {
      for (final FoodItem item in foodItems) item.id: item.unit,
    };
```

Confirm `product_unit.dart` is imported in this file; if not, add `import '../../../data/models/product_unit.dart';`.

- [ ] **Step 2: Recurring row — add a `unit` param and use compactAmount**

In `_RecurringItemRow` (class ~1201), add a field and constructor param:

```dart
  final int quantity;
  final ProductUnit unit;
  const _RecurringItemRow({
    required this.name,
    required this.quantity,
    this.unit = ProductUnit.quantity,
  });
```

In its `build`, replace the pill text:

```dart
              'x$quantity',
```

with:

```dart
              unit.compactAmount(quantity),
```

At the call site (~572), pass the resolved unit. Replace:

```dart
                            _RecurringItemRow(
                              name: item.name,
                              quantity: item.quantity,
                            ),
```

with:

```dart
                            _RecurringItemRow(
                              name: item.name,
                              quantity: item.quantity,
                              unit: unitById[item.id] ?? ProductUnit.quantity,
                            ),
```

> Confirm the recurring loop variable is named `item` and exposes `.id`
> (it is a `CustomerProduct`). If the field is not `id`, use the actual
> id field. `unitById` is in scope here because it is declared in the same
> `build` method.

- [ ] **Step 3: Favorites list — thread `unitById` in and use productionWord**

The favorites list is rendered by a separate widget/method that already
receives `catalogPriceById` (parameter ~661). Add a matching
`Map<String, ProductUnit> unitById` parameter to that widget/method, pass
`unitById` from the call site in `build`, and replace the favorites caption
(~798):

```dart
                            '${p.quantity} units each order',
```

with:

```dart
                            '${p.quantity} ${(unitById[p.id] ?? ProductUnit.quantity).productionWord} each order',
```

> Read the favorites widget's constructor and its call site to thread the new
> parameter exactly the way `catalogPriceById` is threaded. `p` is a
> `CustomerProduct` with `.id`.

- [ ] **Step 4: Verify**

Run: `dart analyze lib/features/owner/customers/`
Expected: no new issues.
Manual check (reviewer): for a customer whose recurring/favorite product is kg, the recurring pill reads `2 kg` and the favorites caption reads `12 kg each order`; quantity products read `x2` and `12 units each order` exactly as before.

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/customers/customer_details_screen.dart
git commit -m "feat: show unit on customer recurring and favorite rows"
```

---

## Final verification

- [ ] `flutter test` — all pass.
- [ ] `dart analyze` on all changed dirs — no new issues.
- [ ] Manual smoke (reviewer): one kg product appearing across an order, the dashboard top-products, reports, and a customer's recurring/favorites all show `kg`; a quantity product is visually identical to before everywhere.
