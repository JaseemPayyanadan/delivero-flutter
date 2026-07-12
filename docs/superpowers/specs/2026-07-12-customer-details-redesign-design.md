# Customer Details Redesign

**Date:** 2026-07-12
**Status:** Approved

## Goal

Bring `lib/features/owner/customers/customer_details_screen.dart` onto the same
visual language as the newly redesigned Order Details screen: gradient header
with an overlapping identity card, inset-header cards, and a sticky bottom
action bar. Presentation only — no provider, model, or data-flow changes.

## Current state

- Centered avatar hero on a grey band, then four visually identical
  `_ProfileCard`s: Contact & Info, Financial Overview, Recurring Order, Order
  history.
- A floating extended "New order" FAB that overlaps the last order row.
- Edit / Delete live in the `DeliveroAppBar` actions.
- The file is 1771 lines; ~700 of them are unreachable legacy widgets.

## Target design

### Header + identity card

`DeliveroGradientHeader` (as used on Order Details) with:

- `title: 'Customer'`, `subtitle:` the customer's name.
- Back arrow via `context.pop()`.
- `actions:` overflow menu with Edit customer and Delete customer.
- `overlapChild:` a new **customer identity card**:
  - Initials avatar (left), name + route label + Active/Inactive pill beside it.
  - A row of tappable contact columns below: Call, Email, Navigate. Each column
    is omitted when the underlying field is empty; the whole row is omitted when
    all three are empty.

### Sections (in order, below the identity card)

1. **Financial** — four tiles: Outstanding, Lifetime value, Total orders, Last
   order. Outstanding renders in `AppColors.error` only when the value exceeds
   0.004, otherwise `AppColors.success`.
2. **Recurring Order** — up to 3 item rows, a "+N more items" line, then the
   Frequency / Estimated total meta pair. Empty state: "No recurring items set
   yet."
3. **Order History** — up to 10 recent orders; a "View all (N)" action in the
   section header when there are more than 10.
4. **Contact & Info** — owner/manager, discount, customer since, full address
   text. Demoted to last because Call/Email/Navigate are already one tap away in
   the identity card.

### Bottom bar

Replaces the FAB. Filled purple **New order** (routes to
`/owner/orders/create` with the customer id as `extra`) plus a **More** pill
opening a sheet with: Edit customer, Call, Navigate, Delete customer. Same
`Container` + top border + `SafeArea` treatment as
`OrderDetailBottomBar`.

## Shared surfaces

`OrderDetailCard` and `OrderDetailSectionHeader` in
`lib/features/owner/orders/order_details/widgets/order_detail_surfaces.dart` are
exactly the surfaces this page needs, but they are trapped in the orders
feature. Promote them:

- New file `lib/core/widgets/detail_surfaces.dart` exporting `DetailCard` and
  `DetailSectionHeader` (identical implementations, renamed).
- Update every order-details call site to the new names and import.
- Leave `OrderDetailStatusPill`, `OrderDetailPillBadge`,
  `OrderDetailSummaryRow`, and `OrderDetailLabeledDropdown` where they are —
  the customer page does not need them.

## Dead code removal

Delete the unreachable legacy widgets and helpers from
`customer_details_screen.dart`: `_buildConfigurationCard`, `_CustomerHeroCard`,
`_MergedContactRow`, `_KpiStrip`, `_KpiItem`, `_SectionCard`, `_PaymentPill`,
`_PaymentMiniPill`, and any helper that becomes unused as a result.

## File layout

Mirror the order-details folder shape:

```
lib/features/owner/customers/customer_details/
  customer_details_screen.dart          # screen + data wiring
  widgets/
    customer_identity_card.dart         # overlapChild
    customer_financial_card.dart
    customer_recurring_card.dart
    customer_order_history_card.dart
    customer_contact_card.dart
    customer_detail_bottom_actions.dart
```

The route in the router points at the same screen class, so the import path
updates but the route string does not change.

## Unchanged

All data and logic: the customers / orders / routes / foodItems provider
lookups, `_estimatePerDelivery`, `_inferScheduleLabel`, `sortOrdersByDate`, the
outstanding-revenue fold, the delete confirmation dialog, and the phone / email
/ maps launchers.

## Testing

- Widget test: the screen renders for a customer with every field populated and
  for a minimal customer (no phone, email, address, recurring items, or orders)
  without overflow, at a narrow width.
- Widget test: the bottom bar's New order button is present and the More sheet
  opens.
- Existing tests must continue to pass.
