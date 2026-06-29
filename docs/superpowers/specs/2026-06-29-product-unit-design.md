# Per-Product Unit (Qty / Kg / Litre) — Design

Date: 2026-06-29

## Problem

Products (`FoodItem`) currently carry only a name and a price. There is no
notion of how a product is measured. The owner wants to mark each product as
sold by **quantity (count)**, by **kilogram**, or by **litre**, and have that
unit appear wherever the product's amount is shown.

## Scope

- **Per-product unit.** Each product gets its own unit, chosen when the product
  is created or edited. There is no factory-wide default setting.
- **Three units only:** `quantity`, `kilogram`, `litre`.
- **Whole numbers only.** Order quantities remain integers. The unit is purely a
  display label next to the number — no fractional amounts (no 1.5 kg).

## Non-goals

- No change to how quantities are entered or stored numerically (stays `int`).
- No data migration. A product or order line with no stored unit reads as
  `quantity`.
- No new option under the "Order settings" screen. The unit lives on the
  product, not in factory-wide settings.

## Data model

### New enum: `ProductUnit`

Location: `lib/data/models/` (new file `product_unit.dart`).

```
enum ProductUnit { quantity, kilogram, litre }
```

Helpers on the enum:

- `String get storageValue` → `'quantity' | 'kg' | 'litre'`.
- `static ProductUnit fromStorage(dynamic value)` → maps stored string back;
  **returns `ProductUnit.quantity` for null / unknown / missing** (backward
  compatibility).
- `String get amountLabel` → the suffix shown after a number:
  - `quantity` → `'x'`  (keeps today's `2x` display)
  - `kilogram` → `'kg'`
  - `litre`    → `'L'`
- `String get priceSuffix` → for price lines / labels:
  - `quantity` → `''` (no suffix)
  - `kilogram` → `'/ kg'`
  - `litre`    → `'/ L'`
- `String get chipLabel` → form selector label: `'Qty' | 'Kg' | 'Litre'`.

> Display rule: for `quantity`, the amount renders exactly as today (`2x`,
> `₹50 × 2`). For `kilogram`/`litre`, the amount renders as `2 kg` / `2 L`.

### `FoodItem` (`lib/data/models/food_item.dart`)

- Add `final ProductUnit unit;`
- Constructor: `this.unit = ProductUnit.quantity` (default).
- `toJson`: add `'unit': unit.storageValue`.
- `fromJson`: `unit: ProductUnit.fromStorage(json['unit'])`.

### `OrderItem` (`lib/data/models/order.dart`)

The unit is **snapshotted onto the order line**, matching how `foodItemName`
and `unitPrice` are already snapshotted, so historical orders keep the unit
they were created with even if the product is later edited or deleted.

- Add `final ProductUnit unit;`
- Constructor: `this.unit = ProductUnit.quantity` (default).
- `toJson`: add `'unit': unit.storageValue`.
- `fromJson`: `unit: ProductUnit.fromStorage(json['unit'])`.

## Where the owner sets it

In the **add/edit product sheet** in `lib/features/owner/food/food_items_screen.dart`:

- Add a 3-option choice-chip selector (**Qty · Kg · Litre**) placed between the
  **Name** field and the **Unit Price** field.
- The selected unit defaults to the product's current unit when editing, and to
  `quantity` when adding.
- The **Unit Price** label becomes unit-aware: `Unit Price (₹)` for quantity,
  `Unit Price (₹ / kg)` / `Unit Price (₹ / L)` for the others.
- The sheet's `onSave` signature gains the unit:
  `Future<bool> Function(String name, double price, ProductUnit unit)`.
- `addFoodItem` / `updateFoodItem` calls construct `FoodItem` with the chosen
  unit.

## Where the unit shows up

1. **Product catalog list** (`food_items_screen.dart`): the price line becomes
   unit-aware, e.g. `₹50 / kg`. For `quantity` products it is unchanged
   (`₹50`).
2. **Order item rows** — owner (`order_details/widgets/order_detail_item_row.dart`)
   and the equivalent driver order-detail row:
   - `${item.quantity}x` → `2x` (quantity) / `2 kg` / `2 L` using
     `item.unit.amountLabel`.
   - The `₹50 × 2` subtitle gains the unit for kg/litre lines.
3. **Create-order** (`create_order/` screens + widgets): the quantity stepper
   shows the product's unit label so the owner sees they are adding kg/litre,
   not pieces. The 4 `OrderItem(...)` construction sites in
   `create_order_screen.dart` pass the product's `unit` through to the line.
4. **Production summary** (`lib/core/production/production_summary*.dart` +
   `production_summary_sheet.dart`): per-product totals display with the unit
   suffix so an aggregated row reads e.g. `12 kg` rather than a bare `12`.

## What does not change

- Quantity stays an `int` everywhere; stepper still increments by whole units.
- Totals remain `unitPrice × quantity`.
- The "Order settings" screen is untouched.
- No backfill/migration: legacy products and order lines read as `quantity`,
  preserving today's exact appearance.

## Construction sites that must pass `unit`

- `create_order_screen.dart` — 4 `OrderItem(` sites (add line, merge, recreate-
  derived line, merge). Each must source the unit from the selected `FoodItem`.
- Order merge / daily-recreation paths copy existing `OrderItem`s via
  JSON, so the snapshotted `unit` survives automatically once it is in
  `toJson`/`fromJson`.

## Testing

- `ProductUnit.fromStorage` round-trips each value and defaults unknown/null to
  `quantity`.
- `FoodItem` / `OrderItem` JSON round-trip preserves the unit, and a JSON
  payload with no `unit` key decodes as `quantity`.
- Amount-label rendering: a `quantity` line renders `2x`; a `kilogram` line
  renders `2 kg`; a `litre` line renders `2 L`.
- Create-order: adding a `kg` product produces an `OrderItem` whose `unit` is
  `kilogram`.
