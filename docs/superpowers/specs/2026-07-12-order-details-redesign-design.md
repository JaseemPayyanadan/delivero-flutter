# Order Details Screen Redesign (Fillo mockup)

**Date:** 2026-07-12
**Screen:** `lib/features/owner/orders/order_details/order_details_screen.dart` + its `widgets/`
**Reference:** User-supplied mockup (purple header, split hero card, separate customer card, read-only payment card, sticky bottom bar). Uses our existing palette (`AppColors`) — brand purple `primary500 #5A45FE`, no new colors.

## Goal

Restructure the owner Order Details screen to match the mockup while keeping all existing behavior (call, maps, view customer, copy ID, mark delivered, cancel, edit, delete, pull-to-refresh). One deliberate behavior change: the payment card becomes read-only; payment is recorded via the Mark-as-Delivered confirmation, plus a post-delivery "Update payment" sheet.

## Layout (top to bottom)

### 1. Header
- Purple header (existing `DeliveroGradientHeader`), title **"Order Details"** with the display order ID (e.g. `#ORD-4583`) as a subtitle line beneath it.
- Back arrow left, kebab menu right (unchanged: Edit order / Delete order).
- The hero card overlaps the header bottom edge, as today.

### 2. Hero card (order summary)
- Top row: status pill left (existing colors per status, e.g. amber "Pending"), copy-ID icon button right (copies display ID, shows snackbar — existing behavior, moved here).
- Body is a two-column split with a vertical divider:
  - **Left:** "Order Total" caption, large amount in brand purple, and — when balance due > 0 — "₹X due" in red (`AppColors.error`) below (partial keeps "balance due" wording in warning color, as today).
  - **Right:** two icon rows — calendar icon + full date ("Sunday, 12 Jul 2026"), and repeat icon + order type label ("Daily Order" / "One-time Order" / "Special Order").
- Delivered orders keep the green "Delivered · date · time" line at the bottom of this card (existing element).

### 3. Customer card (new — extracted from hero card)
- Left: circular avatar with the customer's first initial on `primaryLighter` background, purple text.
- Right of avatar: "Customer" caption + customer name.
- Below: phone | address in two columns with a vertical divider; phone row tappable to call, address row tappable to open maps (replaces the separate Navigate button).
- Route line (if any) stays as a small icon row under the name.
- Bottom: "View customer →" link (hidden when no customer ID).
- Card hidden entirely if there is no customer info at all.

### 4. Items card
- Card header row inside the card: "Items" title left, "N Items" count in purple right (moves in from the current external section header).
- Item rows: qty badge becomes a rounded-square chip (`primaryLighter` bg, purple bold text, ~radius 10) instead of a circle. Name, optional pack label, "₹price × qty" line, and right-aligned line total unchanged. Non-quantity units keep `unit.formatAmount`.

### 5. Payment card (read-only)
- Header row: "Payment" title left, status pill right (UNPAID red-tinted / PAID green-tinted / PARTIAL amber-tinted — existing status colors).
- Status row: colored dot + status word left, amount right (balance due for unpaid/partial, total for paid).
- Method row: wallet icon + method label (Cash/UPI/Card/Online). Hidden if unpaid with no method recorded.
- Dashed divider.
- Subtotal and Delivery Fee rows (existing computed values from `ResolvedOrderDetail`).
- **Total Amount** row highlighted with a `primary50` background strip, label bold dark, amount bold purple.
- **Removed:** inline Paid/Unpaid/Partial chips, method picker, partial amount text field on this screen.
- **Post-delivery escape hatch:** when the order is delivered and payment is not fully paid, show an "Update payment →" link on this card that opens a bottom sheet reusing the existing payment controls (`OrderDetailPaymentSection` internals) with Save/Cancel.

### 6. Info banner
- Soft `primary50` rounded banner: shield icon in purple + "You can update payment details after marking the order as delivered." Shown only while the order is not yet delivered. No "Learn more" link (nothing to link to).

### 7. Sticky bottom bar
- Fixed bar (SafeArea, surface background with top hairline), outside the scroll view:
  - **"Mark as Delivered"** filled purple button (disabled/green-tinted "Delivered" state when already delivered — existing behavior).
  - **"More"** outlined pill beside it, opening a bottom sheet: Navigate (if address), Cancel order (if cancellable), Edit order (if editable), Delete order. Kebab menu in the header keeps Edit/Delete as a shortcut; the sheet is the full list.
- Scroll content gets bottom padding so the last card clears the bar.

## Behavior notes
- Mark-as-Delivered confirmation sheet is unchanged — it already collects payment status/method/amount; since the screen no longer holds payment drafts, the sheet seeds from the order's current payment fields instead of screen draft state.
- The screen's payment draft state (`_draftPaymentStatus` etc.) moves out of the screen; the update-payment bottom sheet owns its own local draft state.
- Pull-to-refresh, order-not-found fallback, snackbars, and cancel/delete dialogs unchanged.

## Components
- Reuse: `DeliveroGradientHeader`, `OrderDetailCard`, `OrderDetailStatusPill`, `OrderDetailSummaryRow`, `ResolvedOrderDetail`, `showConfirmMarkDeliveredDialog`.
- Rework: `OrderDetailSummaryCard` (split-column hero, customer content removed), `OrderDetailItemRow` (square qty chip), `OrderDetailPaymentSection` (read-only card + extracted editable sheet), `OrderDetailBottomActions` (sticky bar + More sheet).
- New: `OrderDetailCustomerCard`, info banner widget (small, can live in the screen file).

## Out of scope
- Driver order details screen (`driver_order_details_screen.dart`) — separate pass later, consistent with the screen-by-screen Fillo rollout.
- Any data/model changes. Purely presentational plus the payment-editing relocation.

## Testing
- `flutter analyze` clean.
- Existing widget/unit tests still pass (`flutter test`).
- Manual verify: pending order (banner + editable via delivered sheet), delivered unpaid order (Update payment sheet works), partial payment display, order without customer info, long item lists, copy ID, call/maps/view-customer taps.
