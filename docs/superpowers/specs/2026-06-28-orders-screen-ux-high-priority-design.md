# Orders Screen — High-Priority UX Fixes (Design Spec)

**Date:** 2026-06-28
**Scope:** Orders list screen (`lib/features/owner/orders/order_list_screen.dart`) and the day-strip helper (`lib/features/owner/orders/day_strip_math.dart`).
**Status:** Draft for review. No implementation yet.

## Background

The Orders screen browses orders by day via a horizontal day strip, a single-date chip, a date-range picker, route chips, search, and payment/status filters. During recent work several gaps surfaced that make the screen feel unreliable — most notably, users cannot tell which days contain orders and an empty selected day reads like data loss.

This spec covers the six **high-priority** items from the UX gap analysis. Lower-priority polish items are out of scope here and tracked separately.

## Goals

- The screen should never *look* broken when data simply lives on another day.
- Every control should do what it appears to do (no false affordances).
- Loading and "genuinely empty" must be visually distinct.
- Every active filter must be visible and reversible from the main screen.

## Non-goals (this spec)

- Redesigning the date model (business-day vs calendar-day) — already settled (calendar day).
- Card layout / status-badge redesign (lower priority).
- Bulk-select discoverability, route totals, accessibility pass — separate spec.

---

## Item 1 — Day markers: show which days have orders

**Problem:** Day cells show only the date number. Nothing distinguishes a day with orders from an empty one, so users scroll the strip blindly and conclude orders are missing.

**Current:** `_DayCell` renders the weekday, the number, and a single dot that is shown only for "today". The strip is an infinite horizontal `ListView.builder` (`dayForIndex`).

**Proposed:**
- Build a `Set<DateTime>` of calendar days that contain at least one order, derived once per build from the in-memory orders list (`_calendarDay(order.orderDate)`), so per-cell lookup is O(1).
- In `_DayCell`, when the cell's day is in that set, render a small **"has orders" dot** beneath the number.
- Keep "today" visually distinct from "has orders": today retains its emphasis (tinted cell / primary number); the has-orders dot is a neutral/secondary color so the two signals don't collide. A day that is both today and has orders shows both treatments.
- Selected day: the dot remains visible against the selected (solid) background — choose a dot color with contrast on both selected and unselected cells.

**Edge cases:**
- Future days that already have pre-created orders correctly show a dot.
- Days outside the loaded range simply have no dot (we only know loaded orders).
- Respect any active route filter? **Decision needed (D1):** dots reflect *all* orders vs dots reflect the *currently filtered* set. Recommendation: reflect the **route-filtered** set so the strip matches what tapping a day will show; ignore payment/status/search for dot purposes to keep it stable.

**Acceptance criteria:**
- A day with ≥1 (route-filtered) order shows a marker; an empty day does not.
- Today is still identifiable whether or not it has orders.
- Marker is visible on selected and unselected cells.

---

## Item 2 — Empty-day guidance (don't dead-end)

**Problem:** Selecting a day/range with no orders shows a generic "No transactions found / Try adjusting your filters or search terms," even when orders clearly exist on other days. It reads as data loss and offers no way forward.

**Current:** `_buildEmptyState(hasAnyOrders:)` renders two variants: zero-data ("No orders yet / Create order") and filtered-empty ("No transactions found / Try adjusting…").

**Proposed:** Introduce a third, **date-aware** empty state used when a specific day or range is selected and yields nothing, *but the account has orders on other days*:
- Title: `No orders for <selected date / range>`.
- Subtitle: `Your most recent orders are on <nearest day with orders>.` (compute the closest day that has orders — prefer the most recent day on/before the selection; otherwise the soonest after).
- Primary action: **`View <that date>`** → selects that day and scrolls the strip to it.
- Secondary action (only when the selected day is today and auto-recreate applies): **`Generate daily orders`** → triggers the same gap-fill as Settings → Generate now (surfacing recovery where the user notices the problem; addresses gap #27).

**Keep existing behavior for:**
- Truly zero orders in the account → "No orders yet / Create order".
- Empty because of payment/status/search filters (not date) → keep "Try adjusting your filters," but ensure the active filters are visible (see Item 6) so the cause is obvious.

**Decision needed (D2):** Should the "Generate daily orders" shortcut appear on the empty Orders screen, or stay only in Settings? Recommendation: show it on an empty *today* when auto-recreate is on.

**Acceptance criteria:**
- Empty selected day with data elsewhere shows the date-specific message + a working "View <date>" jump.
- Account with no orders still shows the create-first-order state.

---

## Item 3 — Day-strip chevrons: real or gone

**Problem:** The ‹ › chevrons on the strip are wrapped in `IgnorePointer` — they look tappable but do nothing.

**Proposed (recommended):** Make them **functional week-steppers** — tapping ‹ scrolls the strip back one week, › forward one week (animated), updating the visible-lead-date header. They already signal horizontal scrollability, so making them work matches the affordance.

**Alternative:** Remove them entirely and rely on swipe. Lower effort, but loses the discoverability cue.

**Decision needed (D3):** functional vs remove. Recommendation: **functional**.

**Acceptance criteria:**
- Either tapping a chevron moves the strip by one week, or the chevrons are removed. No inert tappable-looking element remains.

---

## Item 4 — Distinguish loading from empty

**Problem:** During slow/large Firestore sync the screen can show the zero-data state ("No orders yet / Create order") and even collapse the strip/filters, so loading reads as "all data gone."

**Current:** `if (!ordersLoaded && orders.isEmpty)` → spinner; `else if (filteredOrders.isEmpty)` → empty state. `noOrdersYet = orders.isEmpty` hides the filter/strip block.

**Proposed:**
- While orders are loading (not yet loaded, or a known in-flight refresh), show a **list skeleton** (placeholder order cards) instead of either empty state. Reuse the existing skeleton widget if available (`delivero_skeleton`).
- Do **not** collapse the day strip + filters during loading; keep the chrome stable so the screen doesn't visibly restructure when data arrives.
- Ensure `ordersLoaded` only becomes true after a real first snapshot, so a transient empty snapshot never flips into the zero-data CTA. (Verify the loaded-flag timing in the orders provider.)

**Decision needed (D4):** confirm whether the orders provider can briefly emit `loaded == true` with an empty list during a large re-sync; if so, the skeleton should also key off an "is refreshing" signal, not just `ordersLoaded`.

**Acceptance criteria:**
- During initial load and refresh, a skeleton (not the empty CTA) is shown.
- The strip/filter chrome stays in place during loading.
- The "No orders yet" CTA appears only when loading is complete and the account truly has zero orders.

---

## Item 5 — "Jump to today" affordance

**Problem:** After scrolling the strip away or selecting a far date/range, there's no quick way back to today.

**Proposed:**
- Show a compact **`Today`** pill when the user is not currently on today — i.e., when `_selectedDate != today`, or a range is active, or the strip's visible lead week differs from the current week.
- Tapping it: clears any range, selects today, and animates the strip to today's week.
- Placement: inline in the header row (near the date chip / month label) so it doesn't fight the FAB. Hidden when already on today with the current week in view.

**Acceptance criteria:**
- The Today pill appears whenever the view is off today, and is hidden when on today.
- Tapping returns selection + strip to today in one action.

---

## Item 6 — Make active filters visible and reversible

**Problem:** Search shows a chip and the date shows a chip, but **payment/status filters set in the bottom sheet leave no trace** on the main screen, and the filter icon has no active indicator. Results get hidden with no visible cause.

**Current:** `_selectedPaymentStatus` / `_selectedOrderStatus` live only in the sheet; the date chip and search chip render separately; route chips are a separate inline row.

**Proposed:**
- Add an **active-filter indicator** (dot/badge) on the filter (tune) icon whenever any payment/status filter is set.
- Render **removable chips** for each active payment/status filter in the existing chip area, matching the date and search chips (tap ✕ to remove that one filter).
- Consolidate the chip row so all active filters read as one consistent, dismissible set: `Date/Range · Payment · Status · Search` (route stays as its own selector row, or also becomes a chip — **Decision needed D5**).
- Optional: a single **"Clear all"** affordance when 2+ filters are active.

**Decision needed (D5):** unify route into the same chip row, or keep route chips separate. Recommendation: keep route chips as-is for now (separate concern), just make payment/status/date/search consistent.

**Acceptance criteria:**
- Any active payment/status filter is shown as a removable chip on the main screen.
- The filter icon shows an active state when filters are applied.
- Removing a chip clears exactly that filter.

---

## Cross-cutting notes

- **Single source of "days with orders":** Items 1 and 2 both need to know which days have orders and the nearest non-empty day. Compute one helper (e.g., a sorted set of calendar days with orders) per build and reuse for the strip dots, the empty-state "nearest day," and the Today pill's week comparison.
- **Consistency:** Items 2 and 6 should share the chip and empty-state visual language already used by the date/search chips.

## Open decisions to confirm before implementation

- **D1:** Day-dots reflect all orders or route-filtered orders? (rec: route-filtered)
- **D2:** Surface "Generate daily orders" on the empty *today* screen? (rec: yes)
- **D3:** Chevrons functional or removed? (rec: functional week-step)
- **D4:** Can the provider emit `loaded==true` + empty mid-resync? (needs verification; affects skeleton trigger)
- **D5:** Fold route filter into the unified chip row? (rec: no, keep separate for now)

## Suggested implementation order

1. Item 4 (loading skeleton) and Item 1 (day dots) — biggest perceived-reliability wins, low risk.
2. Item 6 (visible filters) and Item 2 (empty-day guidance) — clarity of state.
3. Item 5 (Today pill) and Item 3 (chevrons) — navigation polish.
