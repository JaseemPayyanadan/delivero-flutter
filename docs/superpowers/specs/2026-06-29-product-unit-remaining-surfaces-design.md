# Product Unit — Remaining Display Surfaces — Design

Date: 2026-06-29

## Problem

The per-product unit feature (quantity / kg / gram / litre) shows the unit on
the product catalog, order-detail rows, create-order flow, and production
summary. Several other screens that display a product's quantity still show a
bare count (e.g. `Rice x2` for a 2 kg item). This extends the unit to those
remaining surfaces so kg/gram/litre is consistent everywhere a quantity appears.

## Scope

Six surfaces flagged by the feature's final review, in three groups by where
the unit value comes from.

## Non-goals

- No change to quantity entry or storage — quantities remain `int`.
- No data migration. Anything without a unit reads as `ProductUnit.quantity`.
- Any cross-product aggregate that sums quantities across *different* products
  (mixing kg + litre + count) stays **unlabeled** — a single unit word there
  would be meaningless. Same decision as the production-summary grand total.
- The already-shipped surfaces (catalog, order-detail rows, create-order,
  production summary) are not touched.

## Mandatory backward compatibility

For `ProductUnit.quantity`, every surface below MUST render byte-for-byte
identical to today:
- preview rows keep `x2`
- dashboard keeps `qty`
- reports keep `units` / `units sold`
- favorites keep `units each order`

## New helper

Add to `ProductUnit` (in `lib/data/models/product_unit.dart`):

```dart
/// Compact amount for dense preview rows: `x2` for quantity (unchanged),
/// `2 kg` / `2 g` / `2 L` otherwise.
String compactAmount(int n) =>
    this == ProductUnit.quantity ? 'x$n' : formatAmount(n);
```

(`formatAmount` already yields `'$n kg'` / `'$n g'` / `'$n L'`.)

## Group A — order-line previews (unit on `OrderItem.unit`)

Each iterates `OrderItem` directly, so `i.unit` is in scope. Replace the
`x${i.quantity}` fragment with `${i.unit.compactAmount(i.quantity)}`.

| File | Current fragment | New |
|---|---|---|
| `lib/features/owner/orders/widgets/order_card.dart` (~90) | `'${displayNameWithPackLabel(i.foodItemName, i.packLabel)} x${i.quantity}'` | `'${displayNameWithPackLabel(i.foodItemName, i.packLabel)} ${i.unit.compactAmount(i.quantity)}'` |
| `lib/features/delivery/order_status_list_screen.dart` (~297) | `'${i.foodItemName} x${i.quantity}'` | `'${i.foodItemName} ${i.unit.compactAmount(i.quantity)}'` |
| `lib/features/owner/orders/unresolved_orders_sheet.dart` (~177) | `'${i.foodItemName} x${i.quantity}'` | `'${i.foodItemName} ${i.unit.compactAmount(i.quantity)}'` |

These files reference the `order.dart` library (which now exports `ProductUnit`
via `OrderItem.unit`); add an explicit `product_unit.dart` import only if the
analyzer requires it.

## Group B — `ProductSalesData` aggregation

`ProductSalesData` (`lib/app/reports_provider.dart:50`) is the shared model
behind the dashboard top-products card AND the reports surfaces. It is built in
the product-breakdown loop (`reports_provider.dart:131-146`), keyed by
`item.foodItemName`.

**Model change:** add `final ProductUnit unit;` (required) to `ProductSalesData`.

**Aggregation change:** in the breakdown loop, set `unit: item.unit` when first
creating a `ProductSalesData` for a name; on the merge branch reuse
`existing.unit` (keep the first-seen unit). Import `product_unit.dart` in
`reports_provider.dart`.

**Render changes:**

| File | Current | New |
|---|---|---|
| `lib/features/owner/dashboard/owner_dashboard_screen.dart` (~2417) | `'$pctLabel · ${item.quantity} qty'` | `'$pctLabel · ${item.quantity} ${item.unit == ProductUnit.quantity ? 'qty' : item.unit.productionWord}'` |
| `lib/features/owner/reports/reports_screen.dart` drilldown (~183) | `'${p.quantity} units sold'` | `'${p.quantity} ${p.unit.productionWord} sold'` |
| `lib/features/owner/reports/reports_screen.dart` product list (~1395) | `'${product.quantity} units'` | `'${product.quantity} ${product.unit.productionWord}'` |

(For quantity, `productionWord` is `'units'`, so the reports rows are unchanged;
the dashboard conditional preserves `'qty'`.)

If `reports_export.dart` emits a per-product quantity row, apply the same
`productionWord` treatment there; if it only emits cross-product totals, leave
it (non-goal). This is confirmed during planning by reading the file.

## Group C — customer detail (unit resolved by product id)

The favorites and recurring rows are built from `customer.products`
(`List<CustomerProduct>`), which has **no unit**. Resolve the unit the same way
the screen already resolves price: build a `Map<String, ProductUnit> unitById`
from `foodItemsProvider` alongside the existing `catalogPriceById`
(`customer_details_screen.dart:215`), and look up by `p.id`, defaulting to
`ProductUnit.quantity` when absent.

| Location | Current | New |
|---|---|---|
| Favorite products (~798) | `'${p.quantity} units each order'` | `'${p.quantity} ${(unitById[p.id] ?? ProductUnit.quantity).productionWord} each order'` |
| `_RecurringItemRow` pill (~1239) | `'x$quantity'` | `'${unit.compactAmount(quantity)}'` — add a `final ProductUnit unit` param (default `ProductUnit.quantity`) to `_RecurringItemRow` and pass the resolved unit at the call site (~572). |

## Testing

- Unit test `ProductUnit.compactAmount`: quantity → `'x2'`; kilogram → `'2 kg'`;
  gram → `'2 g'`; litre → `'2 L'`.
- Extend `reports_provider` test (or add one) asserting `ProductSalesData.unit`
  is populated from the order item's unit and that the first-seen unit is kept
  across the merge branch.
- The UI render changes have no widget-test harness in this project; verify via
  `dart analyze` (no new issues) and `flutter test` (no regressions), plus the
  manual checks listed per task in the plan.

## Files touched (summary)

- `lib/data/models/product_unit.dart` — add `compactAmount`.
- `lib/app/reports_provider.dart` — `ProductSalesData.unit` + aggregation.
- `lib/features/owner/orders/widgets/order_card.dart`
- `lib/features/delivery/order_status_list_screen.dart`
- `lib/features/owner/orders/unresolved_orders_sheet.dart`
- `lib/features/owner/dashboard/owner_dashboard_screen.dart`
- `lib/features/owner/reports/reports_screen.dart`
- `lib/features/owner/reports/reports_export.dart` (only if it has a per-product row)
- `lib/features/owner/customers/customer_details_screen.dart`
- Tests: `test/product_unit_test.dart`, `test/reports_provider_test.dart` (new or extended).
