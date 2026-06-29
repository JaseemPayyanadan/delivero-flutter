# Per-Product Unit (Qty / Kg / Litre) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner mark each product as measured by quantity, kilogram, or litre, and show that unit everywhere the product's amount appears.

**Architecture:** A new `ProductUnit` enum centralises all unit labels and storage mapping. The unit is stored on `FoodItem` and snapshotted onto `OrderItem` (matching the existing name/price snapshot pattern), so historical orders keep their unit with zero migration. Display widgets read the snapshot and render `2x` for quantity (unchanged) or `2 kg` / `2 L` otherwise.

**Tech Stack:** Flutter / Dart, Riverpod, `flutter_test`. Package name is `delivero`.

## Global Constraints

- Quantities stay `int` everywhere — whole numbers only. No fractional amounts.
- Three units only: `quantity`, `kilogram`, `litre`. Form chip labels: `Qty`, `Kg`, `Litre`.
- Backward compatibility is mandatory: a missing/unknown stored `unit` MUST decode to `ProductUnit.quantity`, and `quantity` rendering MUST be byte-for-byte identical to today (`2x`, `₹50 × 2`, `12 units total`, `5 × 20 units`, price line `₹50`, picker `/ unit`).
- The "Order settings" screen is NOT touched.
- Run `flutter analyze` before every commit; it must report no new issues.

---

### Task 1: `ProductUnit` enum

**Files:**
- Create: `lib/data/models/product_unit.dart`
- Test: `test/product_unit_test.dart`

**Interfaces:**
- Produces:
  - `enum ProductUnit { quantity, kilogram, litre }`
  - `String get storageValue` → `'quantity' | 'kg' | 'litre'`
  - `static ProductUnit fromStorage(dynamic value)` → defaults to `quantity`
  - `String formatAmount(int n)` → `'${n}x'` (quantity) / `'$n kg'` / `'$n L'`
  - `String get priceSuffix` → `''` (quantity) / `'/ kg'` / `'/ L'`
  - `String get productionWord` → `'units'` (quantity) / `'kg'` / `'L'`
  - `String get chipLabel` → `'Qty' | 'Kg' | 'Litre'`

- [ ] **Step 1: Write the failing test**

Create `test/product_unit_test.dart`:

```dart
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductUnit.fromStorage', () {
    test('maps stored strings back to enum', () {
      expect(ProductUnit.fromStorage('quantity'), ProductUnit.quantity);
      expect(ProductUnit.fromStorage('kg'), ProductUnit.kilogram);
      expect(ProductUnit.fromStorage('litre'), ProductUnit.litre);
    });

    test('defaults to quantity for null/unknown', () {
      expect(ProductUnit.fromStorage(null), ProductUnit.quantity);
      expect(ProductUnit.fromStorage(''), ProductUnit.quantity);
      expect(ProductUnit.fromStorage('gallons'), ProductUnit.quantity);
    });

    test('round-trips through storageValue', () {
      for (final u in ProductUnit.values) {
        expect(ProductUnit.fromStorage(u.storageValue), u);
      }
    });
  });

  group('ProductUnit.formatAmount', () {
    test('quantity keeps the legacy Nx form', () {
      expect(ProductUnit.quantity.formatAmount(2), '2x');
    });
    test('kilogram and litre use a spaced suffix', () {
      expect(ProductUnit.kilogram.formatAmount(2), '2 kg');
      expect(ProductUnit.litre.formatAmount(2), '2 L');
    });
  });

  group('label getters', () {
    test('priceSuffix', () {
      expect(ProductUnit.quantity.priceSuffix, '');
      expect(ProductUnit.kilogram.priceSuffix, '/ kg');
      expect(ProductUnit.litre.priceSuffix, '/ L');
    });
    test('productionWord', () {
      expect(ProductUnit.quantity.productionWord, 'units');
      expect(ProductUnit.kilogram.productionWord, 'kg');
      expect(ProductUnit.litre.productionWord, 'L');
    });
    test('chipLabel', () {
      expect(ProductUnit.quantity.chipLabel, 'Qty');
      expect(ProductUnit.kilogram.chipLabel, 'Kg');
      expect(ProductUnit.litre.chipLabel, 'Litre');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/product_unit_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:delivero/data/models/product_unit.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/models/product_unit.dart`:

```dart
/// How a product is measured. Stored per-product on [FoodItem] and
/// snapshotted onto each order line.
enum ProductUnit {
  quantity,
  kilogram,
  litre;

  /// Value persisted to Firestore / JSON.
  String get storageValue => switch (this) {
        ProductUnit.quantity => 'quantity',
        ProductUnit.kilogram => 'kg',
        ProductUnit.litre => 'litre',
      };

  /// Decode a stored value. Unknown / null falls back to [quantity] so
  /// legacy products and order lines render exactly as before.
  static ProductUnit fromStorage(dynamic value) {
    switch (value?.toString()) {
      case 'kg':
        return ProductUnit.kilogram;
      case 'litre':
        return ProductUnit.litre;
      default:
        return ProductUnit.quantity;
    }
  }

  /// Renders an amount next to a number, e.g. `2x`, `2 kg`, `2 L`.
  String formatAmount(int n) => switch (this) {
        ProductUnit.quantity => '${n}x',
        ProductUnit.kilogram => '$n kg',
        ProductUnit.litre => '$n L',
      };

  /// Suffix appended to a price line, e.g. `₹50 / kg`. Empty for quantity.
  String get priceSuffix => switch (this) {
        ProductUnit.quantity => '',
        ProductUnit.kilogram => '/ kg',
        ProductUnit.litre => '/ L',
      };

  /// Noun used in production-summary totals (e.g. `12 units`, `12 kg`).
  String get productionWord => switch (this) {
        ProductUnit.quantity => 'units',
        ProductUnit.kilogram => 'kg',
        ProductUnit.litre => 'L',
      };

  /// Short label shown on the product form's selector chips.
  String get chipLabel => switch (this) {
        ProductUnit.quantity => 'Qty',
        ProductUnit.kilogram => 'Kg',
        ProductUnit.litre => 'Litre',
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/product_unit_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/product_unit.dart test/product_unit_test.dart
git commit -m "feat: add ProductUnit enum (qty/kg/litre)"
```

---

### Task 2: Add `unit` to `FoodItem`

**Files:**
- Modify: `lib/data/models/food_item.dart`
- Test: `test/food_item_unit_test.dart`

**Interfaces:**
- Consumes: `ProductUnit` from Task 1.
- Produces: `FoodItem` now has `final ProductUnit unit` (constructor default `ProductUnit.quantity`), serialized under JSON key `'unit'`.

- [ ] **Step 1: Write the failing test**

Create `test/food_item_unit_test.dart`:

```dart
import 'package:delivero/data/models/food_item.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 1, 1);

  FoodItem make(ProductUnit unit) => FoodItem(
        id: 'f1',
        factoryId: 'FAC',
        name: 'Rice',
        price: 50,
        unit: unit,
        createdAt: now,
        updatedAt: now,
      );

  test('defaults to quantity', () {
    final item = FoodItem(
      id: 'f1',
      factoryId: 'FAC',
      name: 'Rice',
      price: 50,
      createdAt: now,
      updatedAt: now,
    );
    expect(item.unit, ProductUnit.quantity);
  });

  test('JSON round-trips the unit', () {
    final json = make(ProductUnit.kilogram).toJson();
    expect(json['unit'], 'kg');
    expect(FoodItem.fromJson(json).unit, ProductUnit.kilogram);
  });

  test('legacy JSON with no unit decodes to quantity', () {
    final item = FoodItem.fromJson({
      'id': 'f1',
      'factoryId': 'FAC',
      'name': 'Rice',
      'price': 50,
      'createdAt': now,
      'updatedAt': now,
    });
    expect(item.unit, ProductUnit.quantity);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/food_item_unit_test.dart`
Expected: FAIL — `No named parameter with the name 'unit'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/models/food_item.dart`:

Add the import at the top (after the existing import):

```dart
import 'product_unit.dart';
```

Add the field after `final double price;`:

```dart
  final ProductUnit unit;
```

Add to the constructor (after `required this.price,`):

```dart
    this.unit = ProductUnit.quantity,
```

In `toJson()`, add after `'price': price,`:

```dart
      'unit': unit.storageValue,
```

In `fromJson`, add to the `FoodItem(...)` call after the `price:` line:

```dart
      unit: ProductUnit.fromStorage(json['unit']),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/food_item_unit_test.dart && flutter analyze`
Expected: tests PASS; analyze reports no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/food_item.dart test/food_item_unit_test.dart
git commit -m "feat: store unit on FoodItem"
```

---

### Task 3: Add `unit` to `OrderItem`

**Files:**
- Modify: `lib/data/models/order.dart` (class `OrderItem`, lines ~36–116)
- Test: `test/order_item_unit_test.dart`

**Interfaces:**
- Consumes: `ProductUnit` from Task 1.
- Produces: `OrderItem` now has `final ProductUnit unit` (constructor default `ProductUnit.quantity`), serialized under JSON key `'unit'`.

- [ ] **Step 1: Write the failing test**

Create `test/order_item_unit_test.dart`:

```dart
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to quantity', () {
    const item = OrderItem(
      id: 'l1',
      foodItemId: 'f1',
      foodItemName: 'Rice',
      quantity: 2,
      unitPrice: 50,
      totalPrice: 100,
    );
    expect(item.unit, ProductUnit.quantity);
  });

  test('JSON round-trips the unit', () {
    const item = OrderItem(
      id: 'l1',
      foodItemId: 'f1',
      foodItemName: 'Rice',
      quantity: 2,
      unitPrice: 50,
      totalPrice: 100,
      unit: ProductUnit.litre,
    );
    final json = item.toJson();
    expect(json['unit'], 'litre');
    expect(OrderItem.fromJson(json).unit, ProductUnit.litre);
  });

  test('legacy JSON with no unit decodes to quantity', () {
    final item = OrderItem.fromJson({
      'id': 'l1',
      'foodItemId': 'f1',
      'foodItemName': 'Rice',
      'quantity': 2,
      'unitPrice': 50,
      'totalPrice': 100,
    });
    expect(item.unit, ProductUnit.quantity);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/order_item_unit_test.dart`
Expected: FAIL — `No named parameter with the name 'unit'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/models/order.dart`:

Add at the top with the other model imports:

```dart
import 'product_unit.dart';
```

In `class OrderItem`, add the field after `final double totalPrice;`:

```dart
  final ProductUnit unit;
```

Add to the `const OrderItem({...})` constructor (after `required this.totalPrice,`):

```dart
    this.unit = ProductUnit.quantity,
```

In `toJson()`, add after `'totalPrice': totalPrice,`:

```dart
      'unit': unit.storageValue,
```

In `fromJson`, add to the returned `OrderItem(...)` after the `totalPrice: totalPrice,` line:

```dart
      unit: ProductUnit.fromStorage(json['unit']),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/order_item_unit_test.dart && flutter test test/order_merge_test.dart && flutter analyze`
Expected: new test PASS; existing `order_merge_test` still PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/order.dart test/order_item_unit_test.dart
git commit -m "feat: snapshot unit onto OrderItem"
```

---

### Task 4: Unit selector in the add/edit product dialog

**Files:**
- Modify: `lib/features/owner/food/food_items_screen.dart` (`_showAddEditDialog` ~409–502, `_FoodItemEditorDialog` ~505–634)

**Interfaces:**
- Consumes: `FoodItem.unit`, `ProductUnit` (Task 1–2).
- Produces: editor `onSave` signature becomes
  `Future<bool> Function(String name, double price, ProductUnit unit)`.

- [ ] **Step 1: Add the `ProductUnit` import**

At the top of `lib/features/owner/food/food_items_screen.dart`, add with the other model imports:

```dart
import '../../../data/models/product_unit.dart';
```

- [ ] **Step 2: Thread the unit through `_showAddEditDialog`**

Change the `onSave` callback (currently `onSave: (name, price) async {`) to accept the unit and pass it into both `FoodItem(...)` constructions:

```dart
          onSave: (name, price, unit) async {
            final factoryId = await ref.read(factoryIdProvider.future);
            if (factoryId == null || factoryId.isEmpty) return false;
            if (isEdit) {
              await ref.read(foodItemsProvider.notifier).updateFoodItem(
                    FoodItem(
                      id: item!.id,
                      factoryId: item.factoryId,
                      name: name,
                      price: price,
                      unit: unit,
                      createdAt: item.createdAt,
                      updatedAt: DateTime.now(),
                    ),
                  );
            } else {
              await ref.read(foodItemsProvider.notifier).addFoodItem(
                    FoodItem(
                      id: const Uuid().v4(),
                      factoryId: factoryId,
                      name: name,
                      price: price,
                      unit: unit,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
            }
            return true;
          },
```

- [ ] **Step 3: Update `_FoodItemEditorDialog` to hold and emit the unit**

Change the `onSave` field type:

```dart
  final Future<bool> Function(String name, double price, ProductUnit unit) onSave;
```

In `_FoodItemEditorDialogState`, add a selected-unit field initialized from the item:

```dart
  late ProductUnit _unit;
```

In `initState()` (after the controllers are created):

```dart
    _unit = widget.item?.unit ?? ProductUnit.quantity;
```

Extend `_hasUnsavedChanges` so changing the unit counts as a change:

```dart
  bool get _hasUnsavedChanges {
    return _nameController.text.trim() != widget.initialName.trim() ||
        _priceController.text.trim() != widget.initialPrice.trim() ||
        _unit != (widget.item?.unit ?? ProductUnit.quantity);
  }
```

- [ ] **Step 4: Add the chip selector and unit-aware price label**

In `build`, between the Name `TextField` and the `SizedBox(height: 20)` that precedes the price field, insert the selector. Then make the price `labelText` unit-aware. Replace the price `TextField`'s `decoration:` line `labelText: 'Unit Price (₹)',` with a computed label.

Insert after the Name field's closing `),` (the first `TextField`) and before `const SizedBox(height: 20)`:

```dart
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final u in ProductUnit.values)
                    ChoiceChip(
                      label: Text(u.chipLabel),
                      selected: _unit == u,
                      onSelected: (_) => setState(() => _unit = u),
                    ),
                ],
              ),
            ),
```

Change the price field's decoration to use a unit-aware label:

```dart
              decoration: InputDecoration(
                labelText: _unit == ProductUnit.quantity
                    ? 'Unit Price (₹)'
                    : 'Unit Price (₹ ${_unit.priceSuffix})',
                hintText: '0.00',
              ),
```

(Note: this `InputDecoration` is no longer `const` — remove the `const` keyword on it.)

- [ ] **Step 5: Pass the selected unit on save**

In the `ElevatedButton`'s `onPressed`, change the save call:

```dart
              final ok = await widget.onSave(name, price, _unit);
```

- [ ] **Step 6: Verify it compiles and run the app's product form**

Run: `flutter analyze`
Expected: no new issues.
Manual check (reviewer): open Add product → three chips `Qty / Kg / Litre` appear, default `Qty`; selecting `Kg` changes the price label to `Unit Price (₹ / kg)`; saving an item as Kg persists (reopen edit shows `Kg` selected).

- [ ] **Step 7: Commit**

```bash
git add lib/features/owner/food/food_items_screen.dart
git commit -m "feat: choose product unit in add/edit product dialog"
```

---

### Task 5: Unit-aware price line in the product catalog list

**Files:**
- Modify: `lib/features/owner/food/food_items_screen.dart` (price chip ~234–236)

**Interfaces:**
- Consumes: `FoodItem.unit`, `ProductUnit.priceSuffix`.

- [ ] **Step 1: Make the catalog price text show the unit suffix**

Replace the price `Text(...)` value (currently `'₹${NumberFormat.decimalPattern().format(item.price)}'`) with:

```dart
                    item.unit == ProductUnit.quantity
                        ? '₹${NumberFormat.decimalPattern().format(item.price)}'
                        : '₹${NumberFormat.decimalPattern().format(item.price)} ${item.unit.priceSuffix}',
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no new issues.
Manual check (reviewer): a Kg product shows `₹50 / kg`; a quantity product still shows `₹50`.

- [ ] **Step 3: Commit**

```bash
git add lib/features/owner/food/food_items_screen.dart
git commit -m "feat: show unit on product catalog price"
```

---

### Task 6: Unit-aware order item rows (owner + driver)

**Files:**
- Modify: `lib/features/owner/orders/order_details/widgets/order_detail_item_row.dart`

**Interfaces:**
- Consumes: `OrderItem.unit`, `ProductUnit.formatAmount`.
- Note: the driver order-details screen reuses `OrderDetailItemRow`
  (`lib/features/delivery/order_details/driver_order_details_screen.dart:204`),
  so this one change covers both surfaces.

- [ ] **Step 1: Replace the circular `Nx` badge with a unit-aware amount**

In `order_detail_item_row.dart`, change the badge `Text` value (currently `'${item.quantity}x'`) to:

```dart
              item.unit == ProductUnit.quantity
                  ? '${item.quantity}x'
                  : item.unit.formatAmount(item.quantity),
```

Add the import at the top:

```dart
import '../../../../../data/models/product_unit.dart';
```

- [ ] **Step 2: Make the price subtitle unit-aware**

Change the subtitle `Text` value (currently `'${money0.format(item.unitPrice)} × ${item.quantity}'`) to append the unit for non-quantity items:

```dart
                  item.unit == ProductUnit.quantity
                      ? '${money0.format(item.unitPrice)} × ${item.quantity}'
                      : '${money0.format(item.unitPrice)} × ${item.unit.formatAmount(item.quantity)}',
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no new issues.
Manual check (reviewer): an order line for a Kg product shows `2 kg` in the badge and `₹50 × 2 kg` subtitle, in both the owner and driver order-detail screens; quantity lines are unchanged (`2x`, `₹50 × 2`).

- [ ] **Step 4: Commit**

```bash
git add lib/features/owner/orders/order_details/widgets/order_detail_item_row.dart
git commit -m "feat: show unit on order item rows"
```

---

### Task 7: Carry the unit through create-order

**Files:**
- Modify: `lib/features/owner/orders/create_order/create_order_screen.dart` (4 `OrderItem(` sites: ~766, ~781, ~1760, ~2019)
- Modify: `lib/features/owner/orders/create_order/create_order_widgets.dart` (picker `/ unit` label ~1042; review-line model `_ReportLineItem` ~64–72 and its render ~363)

**Interfaces:**
- Consumes: `FoodItem.unit`, `OrderItem.unit`, `ProductUnit`.
- Produces: every `OrderItem` built during create/merge carries the product's unit.

- [ ] **Step 1: Pass `unit` into the "add new line" `OrderItem` (site ~766)**

In the `_selectedItems.forEach` block, the `addItem` is built from `foodItem`. Add `unit: foodItem.unit,` to that `OrderItem(...)`:

```dart
      final addItem = OrderItem(
        id: '',
        foodItemId: foodItemId,
        foodItemName: foodItem.name,
        quantity: qty,
        unitPrice: unitPrice,
        totalPrice: unitPrice * qty,
        unit: foodItem.unit,
        packLabel: null,
      );
```

- [ ] **Step 2: Preserve `unit` on the merge in the same block (site ~781)**

The merge rebuilds from `old`. Add `unit: old.unit,`:

```dart
        merged[i] = OrderItem(
          id: old.id,
          foodItemId: old.foodItemId,
          foodItemName: old.foodItemName,
          quantity: nextQty,
          unitPrice: unitPrice,
          totalPrice: unitPrice * nextQty,
          unit: old.unit,
          packLabel: old.packLabel,
        );
```

- [ ] **Step 3: Pass `unit` into the submit `OrderItem` (site ~1760)**

This block builds from `foodItem`. Add `unit: foodItem.unit,`:

```dart
          OrderItem(
            id: const Uuid().v4(),
            foodItemId: foodItemId,
            foodItemName: foodItem.name,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: total,
            unit: foodItem.unit,
            packLabel: null,
          ),
```

- [ ] **Step 4: Preserve `unit` on the second merge (site ~2019)**

This rebuilds from `old`. Add `unit: old.unit,`:

```dart
      merged[i] = OrderItem(
        id: old.id,
        foodItemId: old.foodItemId,
        foodItemName: old.foodItemName,
        quantity: nextQty,
        unitPrice: unitPrice,
        totalPrice: unitPrice * nextQty,
        unit: old.unit,
        packLabel: old.packLabel,
      );
```

- [ ] **Step 5: Make the picker per-unit price label unit-aware**

In `create_order_widgets.dart`, the picker tile renders `'${formatRupee(unitPrice)} / unit'` (~1042). The tile has the `FoodItem item` in scope (`item.name` is used just above at ~1026). Replace that text with:

```dart
                            item.unit == ProductUnit.quantity
                                ? '${formatRupee(unitPrice)} / unit'
                                : '${formatRupee(unitPrice)} ${item.unit.priceSuffix}',
```

Add the import at the top of `create_order_widgets.dart`:

```dart
import '../../../../data/models/product_unit.dart';
```

- [ ] **Step 6: Show the unit in the order review line**

In `create_order_widgets.dart`, add a `unit` field to the `_ReportLineItem` model (the class with `name`, `quantity`, `unitPrice` at ~64–72):

```dart
  final ProductUnit unit;
```

Add to its constructor (after `required this.quantity,` / alongside the other required params):

```dart
    this.unit = ProductUnit.quantity,
```

Find where `_ReportLineItem(` is constructed (in `create_order_screen.dart`, just after the `merged.sort(...)` at the end of the first forEach block — the `for (final m in merged) _ReportLineItem(...)` comprehension) and pass `unit: m.unit,`.

Then in the render (~363, currently `'${line.quantity}'`), replace with:

```dart
              line.unit == ProductUnit.quantity
                  ? '${line.quantity}'
                  : line.unit.formatAmount(line.quantity),
```

- [ ] **Step 7: Verify**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all existing tests still PASS.
Manual check (reviewer): in create-order, a Kg product shows `₹50 / kg` in the picker; after adding it the review line and the resulting order detail show `2 kg`.

- [ ] **Step 8: Commit**

```bash
git add lib/features/owner/orders/create_order/create_order_screen.dart lib/features/owner/orders/create_order/create_order_widgets.dart
git commit -m "feat: carry product unit through create-order"
```

---

### Task 8: Unit-aware production summary

**Files:**
- Modify: `lib/core/production/production_summary.dart`
- Test: `test/production_summary_test.dart` (add cases)
- Test helper: `test/helpers/production_test_data.dart` (allow setting unit)

**Interfaces:**
- Consumes: `OrderItem.unit`, `ProductUnit.productionWord`.
- Produces: `ProductionLineSummary` gains `final ProductUnit unit`; `formatProductionLine` and `formatPackBreakdownLines` render the per-line unit word.

- [ ] **Step 1: Write the failing test**

Add to `test/production_summary_test.dart` a new group:

```dart
  group('production summary units', () {
    test('kg product line uses kg wording', () {
      final orders = [
        productionTestOrder(
          id: 'kg-order',
          orderDate: DateTime(2025, 6, 20, 10),
          items: const [
            OrderItem(
              id: 'l1',
              foodItemId: 'rice',
              foodItemName: 'Rice',
              quantity: 12,
              unitPrice: 50,
              totalPrice: 600,
              unit: ProductUnit.kilogram,
            ),
          ],
        ),
      ];
      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      final line = summary.lines.single;
      expect(line.unit, ProductUnit.kilogram);
      expect(formatProductionLine(line), contains('12 kg total'));
    });

    test('quantity product keeps legacy units wording', () {
      final summary = buildProductionSummary(
        [productionTestOrder(orderDate: DateTime(2025, 6, 20, 10))],
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      expect(formatProductionLine(summary.lines.single), contains('units total'));
    });
  });
```

Add the import at the top of the test file:

```dart
import 'package:delivero/data/models/product_unit.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/production_summary_test.dart`
Expected: FAIL — `ProductionLineSummary` has no `unit` getter / `12 kg total` not found.

- [ ] **Step 3: Implement — thread unit through accumulation**

In `lib/core/production/production_summary.dart`:

Add import at the top:

```dart
import '../../data/models/product_unit.dart';
```

Add `unit` to `ProductionLineSummary` (after `final String productName;` group):

```dart
  final ProductUnit unit;
```

Add to its constructor:

```dart
    this.unit = ProductUnit.quantity,
```

Add `unit` to `_LineAccumulator` (a line is one product, so all items share a unit; take it from the first item via `putIfAbsent`):

```dart
  final ProductUnit unit;
```
```dart
  _LineAccumulator({required this.productName, this.foodItemId, this.unit = ProductUnit.quantity});
```

In `buildProductionSummary`, pass the item's unit into the accumulator on creation:

```dart
        () => _LineAccumulator(
          productName: displayNameWithPackLabel(baseName, item.packLabel),
          foodItemId: item.foodItemId.isNotEmpty ? item.foodItemId : null,
          unit: item.unit,
        ),
```

And carry it into the produced `ProductionLineSummary`:

```dart
        (acc) => ProductionLineSummary(
          productName: acc.productName,
          foodItemId: acc.foodItemId,
          unit: acc.unit,
          totalUnits: acc.totalUnits,
          orderLineCount: acc.orderLineCount,
          packBreakdown: Map.unmodifiable(acc.packBreakdown),
        ),
```

- [ ] **Step 4: Implement — unit-aware formatting**

Change `formatPackBreakdownLines` to take the unit word. Replace the function with:

```dart
/// One row per pack size, largest quantity first (e.g. "5 × 20 units").
List<String> formatPackBreakdownLines(
  Map<int, int> packBreakdown, {
  String word = 'units',
}) {
  if (packBreakdown.isEmpty) return const [];
  final entries = packBreakdown.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return [
    for (final e in entries) '${e.value} × ${e.key} $word',
  ];
}
```

Change `formatProductionLine` to use the line's unit word:

```dart
String formatProductionLine(ProductionLineSummary line) {
  final word = line.unit.productionWord;
  final buffer = StringBuffer(
    '${line.productName.toUpperCase()} — ${line.totalUnits} $word total',
  );
  for (final row in formatPackBreakdownLines(line.packBreakdown, word: word)) {
    buffer.writeln('  $row');
  }
  return buffer.toString().trim();
}
```

(The grand-total `Total units: ${summary.totalUnits}` line in `formatProductionSummaryText` stays unchanged — it is a cross-product count and keeps the generic "units" wording.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/production_summary_test.dart && flutter analyze`
Expected: new and existing production tests PASS; analyze clean.

- [ ] **Step 6: Check the PDF/sheet consumers compile**

The PDF (`production_summary_pdf.dart`) and sheet (`production_summary_sheet.dart`) consume `ProductionLineSummary`/`formatProductionLine`. They need no change (the new field has a default and the format helpers keep their names), but confirm:

Run: `flutter analyze`
Expected: no new issues in those files.

- [ ] **Step 7: Commit**

```bash
git add lib/core/production/production_summary.dart test/production_summary_test.dart
git commit -m "feat: unit-aware production summary lines"
```

---

## Final verification

- [ ] Run the full suite: `flutter test` — all PASS.
- [ ] `flutter analyze` — no new issues.
- [ ] Manual smoke (reviewer): create a Kg product → add it to an order → confirm `2 kg` shows in create-order review, owner order detail, driver order detail, and the production summary reads `… kg total`. Confirm a quantity product is visually identical to before.
