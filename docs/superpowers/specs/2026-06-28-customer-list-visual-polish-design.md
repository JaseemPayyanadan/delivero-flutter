# Customer List — Visual Polish Design

**Date:** 2026-06-28
**Scope:** Visual-only redesign of the customer list screen
(`lib/features/owner/customers/customer_list_screen.dart`). No logic, data,
navigation, grouping, sorting, search, or filtering behavior changes.

## Goal

Lift the customer list from a flat divided-row list into refined **discrete
cards**, so the screen reads as a polished B2B surface and overdue accounts pop
while scanning. Same information per customer; restyled presentation. One small
additive: the already-computed pending amount is surfaced on the card.

## Current State

Customers render inside a `SliverList.separated` wrapped per-row in
`Material(color: surface)` + `InkWell`, separated by 1px dividers. Each row:
- 34×34 primary-tinted initials avatar
- name + schedule pill (Daily / One-time / Special / "No orders yet")
- phone line
- a payment status pill (UNPAID / PARTIAL / PAID), shown only when there are
  pending dues, plus an "Assign route" button when the customer has no route

Rows are grouped by route under an uppercase `_GroupHeader` (label + count).
Route filter chips (`_RouteChipsRow`) sit at the top. The card has no shape,
elevation, or breathing room — it reads as a plain list.

## Design

### 1. Card shell (core change)

Replace the divided-list treatment with one rounded card per customer:

- Surface: `AppColors.surface`, **16px** corner radius.
- Border: **1px `AppColors.border`**.
- Shadow: a single soft `AppColors.shadow` box shadow (low blur, small
  y-offset) so the card floats off the white scaffold background.
- Spacing: `~10px` vertical gap between cards (replaces the dividers).
- Ripple: `InkWell` clipped to the rounded corners (use `Material` +
  `borderRadius` clip so the ripple respects the card shape).
- Internal padding: grow from the cramped `(4,10)` to a comfortable `~14px`
  on all sides.

The `SliverList.separated` keeps building one entry per customer, but the
`separatorBuilder` divider is removed; the inter-card gap comes from the card's
own bottom margin (or a `SizedBox` separator of ~10px).

### 2. Pending-dues accent edge

Cards for customers with pending money (`hasPending == true`) get a **3px
colored left edge** inside the rounded card:
- Unpaid (latest status unpaid / null) → `AppColors.error`
- Partial → `AppColors.warning`

Cards with no dues have no edge. The edge is inset so it follows the card's
rounded corners (e.g. a left-aligned colored strip clipped by the card radius).

### 3. Payment line

Replace the bare payment pill with a **small colored dot + amount**:
- `● ₹1,240 due` where the dot color matches the accent edge (error/warning).
- Amount uses the existing `formatRupee(pendingAmount)` helper from
  `lib/core/utils/currency_format.dart`, with `pendingAmount` already computed
  in `_buildGroupedCustomerSlivers`.
- Shown only when `hasPending`. Fully-paid / no-order customers show no payment
  line (unchanged from today — no PAID pill is shown today either, since the
  pill only renders when `hasPending`).

This is the one additive change: the rupee amount is newly surfaced. It uses
data already computed in the file; no new queries.

### 4. Avatar & schedule pill

- Initials avatar nudges **34 → 40px** to balance the roomier card; keeps the
  primary-tinted (`primary @ 12%`) squircle and `_customerInitials` text.
- Schedule pill stays top-right with its current `_Pill` styling (Daily /
  One-time / Special, or the muted "No orders yet" variant). Unchanged.

### 5. Assign-route button

Unchanged in behavior and styling — the pill-shaped `TextButton.icon` shown on
the bottom row when `hasRoute == false`. It continues to sit opposite the
payment line on the action row.

### 6. Group header & chips

- `_GroupHeader` keeps its uppercase label + "N Customers" count; only its
  surrounding padding is tuned so it sits cleanly above the card stack (the
  cards now carry their own horizontal inset).
- `_RouteChipsRow` and the route/search/filter sheets are untouched.

## Out of Scope

- No changes to grouping, sorting, search, filtering, or the assign-route flow.
- No changes to navigation or providers.
- No changes to the route chips, search sheet, route filter sheet, or assign
  route sheet.
- No new data sources — `pendingAmount` is already computed locally.

## Affected Code

`lib/features/owner/customers/customer_list_screen.dart` only:
- `_buildGroupedCustomerSlivers` — drop the divider separator, pass
  `pendingAmount` and the pending kind (unpaid vs partial) into the card.
- `_CustomerListCard` — new card shell (rounded + border + shadow + clipped
  ripple), accent edge, roomier padding, larger avatar, dot+amount payment line.
- `_GroupHeader` — padding tweak only.
- Import `formatRupee` from `core/utils/currency_format.dart`.

## Verification

- Run the app to the customer list (owner shell → Customers).
- Confirm: cards are discrete and rounded with visible separation; customers
  with dues show a colored left edge + `● ₹amount due`; paid/no-order customers
  show no edge/payment line; avatar, name, schedule pill, phone, and
  assign-route button all render correctly; grouping by route and the route
  chips still behave as before.
- Spot-check a customer with no phone (phone line hidden) and a customer with
  no route (assign-route button shown).
