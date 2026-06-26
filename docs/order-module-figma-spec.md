# Delivero Order Module — Figma Design Package

**Product:** Delivero — B2B food production & delivery management for factory owners and delivery drivers in India.

**Platform:** Mobile-first (iOS/Android), Flutter-style UI. Portrait orientation. Touch-optimized for busy kitchen/operations staff.

**Design language:** Premium B2B SaaS — clean, confident, data-dense but scannable. White surfaces, soft shadows, rounded cards (16–20px radius), pill badges, bold typography (w800–w900), tight letter-spacing on headings.

**Artboard:** 390 × 844 (iPhone 14)  
**Grid:** 4px base, 16px margins  
**Auto Layout:** Required on all components

---

## 1. Figma File Structure

```
📁 Delivero / Orders
├── 🎨 Foundations
│   ├── Colors
│   ├── Typography
│   ├── Spacing (4px grid)
│   ├── Radius
│   ├── Shadows
│   └── Icons (Material Rounded)
├── 🧩 Components
│   ├── Atoms
│   ├── Molecules
│   ├── Cards
│   ├── Sheets
│   └── Navigation
├── 📱 Owner — Orders
├── 📱 Owner — Create Order
├── 📱 Owner — Order Details
├── 📱 Driver — Orders
└── 🔄 Prototypes
```

---

## 2. Foundations

### Colors (create as Figma color styles)

| Style name | Hex | Usage |
|------------|-----|-------|
| `primary/default` | `#2563EB` | FAB, totals, selected day |
| `primary/light` | `#60A5FA` | Hover/secondary accent |
| `primary/lighter` | `#DBEAFE` | Tinted backgrounds |
| `secondary/default` | `#0F172A` | Nav, headings |
| `bg/primary` | `#FFFFFF` | Page background |
| `bg/secondary` | `#F8FAFC` | Card insets, chips |
| `bg/tertiary` | `#F1F5F9` | Dividers |
| `border/default` | `#E2E8F0` | Card borders |
| `text/primary` | `#0F172A` | Headlines |
| `text/secondary` | `#475569` | Labels |
| `text/light` | `#94A3B8` | Meta, timestamps |
| `status/success` | `#059669` | Delivered, Paid |
| `status/warning` | `#D97706` | Pending, Partial |
| `status/error` | `#DC2626` | Unpaid, Cancelled |
| `status/info` | `#0284C7` | Confirmed |
| `shadow/soft` | `#000000` @ 6% | Card elevation |

### Typography (create as text styles)

| Style | Size | Weight | Tracking | Color |
|-------|------|--------|----------|-------|
| `heading/app-bar` | 20 | 900 | −0.5 | text/primary |
| `heading/section` | 14 | 900 | −0.2 | text/primary |
| `heading/card-title` | 16 | 900 | −0.45 | text/primary |
| `heading/total` | 16 | 900 | −0.35 | primary/default |
| `body/default` | 14 | 600 | 0 | text/secondary |
| `body/line-item` | 13 | 700 | −0.1 | text/primary |
| `caption/meta` | 11 | 700 | 0 | text/light |
| `caption/micro` | 10 | 800 | +0.9 | text/light (uppercase) |
| `caption/badge` | 11 | 800 | +0.05 | contextual |
| `button/label` | 16 | 800 | +0.5 | on-primary |

### Spacing tokens

| Token | Value |
|-------|-------|
| `space/1` | 4px |
| `space/2` | 8px |
| `space/3` | 12px |
| `space/4` | 16px |
| `space/5` | 20px |
| `space/6` | 24px |
| `space/8` | 32px |

### Radius tokens

| Token | Value |
|-------|-------|
| `radius/sm` | 8px |
| `radius/md` | 14px |
| `radius/lg` | 16px |
| `radius/xl` | 20px |
| `radius/2xl` | 28px |
| `radius/pill` | 999px |

### Shadow (card)

- Blur: 18
- Y: 6
- Color: `#000000` @ 6%

### Currency

Indian Rupee (₹), no decimals (e.g. ₹1,250). Locale: `en_IN`.

---

## 3. User Personas

1. **Factory Owner** — manages daily recurring orders, routes, payments, production lists. Needs speed: filter by day/route, bulk mark delivered/paid, kitchen production summary.
2. **Delivery Driver** — sees assigned-route orders only, updates delivery status, can create orders for customers on their route.

---

## 4. Component Spec

### Atoms

#### `Badge/Status`

- **Layout:** Auto layout horizontal, padding 12×4, radius pill
- **Background:** status color @ 32% opacity
- **Text:** `caption/badge`, foreground = darker status tone
- **Variants:**
  - Status: Pending | Confirmed | Preparing | Ready | Delivered | Cancelled
  - Size: Default

#### `Badge/Payment`

- Same structure as Status
- **Variants:** Paid | Unpaid | Partial
- **Border:** 1px, payment color @ 35%

#### `Badge/Type`

- Background: `bg/secondary`, border 1px `border/default`
- Padding: 8×3, radius 8
- Text: 10px/w800, `text/secondary`
- Example: "Morning · Daily"

#### `Chip/Filter`

- **Default:** bg secondary, border, 12px/w700 text
- **Selected:** primary lighter bg, primary border, primary text
- **Variants:** Route | Status | Payment
- Height: 36px, horizontal padding 14px

#### `DayCell`

- Width: `screen width ÷ 7` (~55px on 390)
- Height: 72px
- **Anatomy:** weekday (10px/w700) + day number (18px/w900)
- **Variants:** Default | Today | Selected | Past | Today+Selected
- Today: primary ring or dot
- Selected: solid primary fill, white text
- Past: `text/light`

#### `Checkbox/Selection`

- 24×24 circle
- Selected: `check_circle_rounded`, primary
- Unselected: `radio_button_unchecked_rounded`, text/light

#### `IconContainer/Order`

- 44×44, radius 14
- Background: primary @ 10%, border primary @ 12%
- Icon: `receipt_long_rounded` 22px, primary

---

### Molecules

#### `DayStrip`

- Height: 88px fixed
- Horizontal scroll, 7 cells visible
- Left/right faint chevrons (opacity 30%, non-interactive)
- Header above: month/year OR selected-date chip with ×
- Continuous day scroll (no week snapping); opens framed on current week

#### `DateSectionHeader`

- Row: "Today" (14/w900) | "8 orders" (caption) | "₹12,450" (14/w800 primary, right)
- Margin bottom: 8px

#### `FilterRow`

- Horizontal scroll chips
- Groups: Routes → Status → Payment
- Gap: 8px

#### `BulkActionBar`

- Height: ~64px + safe area
- Two equal `FilledButton`s side by side
- Left: "Mark delivered" — success green
- Right: "Mark paid" — primary blue
- Disabled state: 40% opacity

#### `SearchSheet`

- Bottom sheet, radius top 28px
- Search field: 48px height, radius 14, search icon left
- Live results list below

#### `StepIndicator` (Create Order)

- 4 steps: Customer → Schedule → Menu → Review
- Active: primary dot + label
- Complete: check icon
- Upcoming: grey dot

---

### Cards

#### `OrderCard` (primary component)

**Dimensions:** Fill width (358px content), auto height, margin bottom 12px

**Structure (Auto Layout vertical):**

```
┌─ Card (radius 20, border 1, shadow) ─────────────────────┐
│ ┌─ Header row (padding 16,14,16,10) ──────────────────┐ │
│ │ [Icon 44] [Customer + Meta] [Status + Type badges] │ │
│ └──────────────────────────────────────────────────────┘ │
│ ┌─ Inset panel (bg secondary, radius 16, margin 12) ──┐ │
│ │ Payment label + chip  |  Total label + ₹ amount     │ │
│ │ ───────── divider ─────────                         │ │
│ │ LINE ITEMS (micro label)                            │ │
│ │ Idli x4 · Dosa x2 · +3 more                         │ │
│ └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Component properties (Figma variants):**

| Property | Values |
|----------|--------|
| Status | Pending, Confirmed, Preparing, Ready, Delivered, Cancelled |
| Payment | Paid, Unpaid, Partial |
| OrderType | Daily, OneTime, Special |
| DeliveryRun | Morning, Afternoon, Evening, Night |
| Selection | None, Selected, Selectable |
| Highlight | None, Created, Updated |
| LineItems | Empty, Preview, Many |

**Highlight variant:** 2px border (success or primary), background tint @ 6%

**Selection variant:** Checkbox overlay top-left (absolute position)

**Flutter mapping:** `lib/features/owner/orders/widgets/order_card.dart`

---

#### `OrderDetailSummaryCard`

- Customer name 20/w900
- Phone row (tappable, primary icon)
- Address row (maps icon)
- Route + driver pills
- Large status badge
- Financial block: Total | Paid | Balance due
- "View customer" text link

**Flutter mapping:** `lib/features/owner/orders/order_details/widgets/order_detail_summary_card.dart`

---

#### `OrderDetailItemRow`

- Row: Item name + pack label | qty × price | line total
- Divider between rows
- Footer: Subtotal, Discount, Grand total

**Flutter mapping:** `lib/features/owner/orders/order_details/widgets/order_detail_item_row.dart`

---

#### `PaymentEditor`

- Segmented: Paid / Unpaid / Partial
- Method chips: Cash | UPI | Card | Online
- Partial amount input field
- Save button (enabled when dirty)

**Flutter mapping:** `lib/features/owner/orders/order_details/widgets/order_detail_payment_section.dart`

---

#### `FoodItemRow` (Create Order step 3)

- Name + unit price
- Qty stepper (− / number / +) or text input
- Selected state: primary left border

---

#### `CustomerPickerRow`

- Avatar initials circle
- Name + phone
- Route badge
- Selected: primary border + check icon

---

### Sheets

#### `ProductionSummarySheet`

- Drag handle 44×5
- Title: "Production list"
- Date + route scope
- Table: Item name | Total qty
- Footer actions: WhatsApp share (green outline) | Download PDF

**Flutter mapping:** `lib/features/owner/orders/production_summary_sheet.dart`

---

#### `UnresolvedOrdersSheet`

- Warning header (amber icon)
- Order rows with inline actions
- Actions per row: Deliver | Cancel | Recreate

**Flutter mapping:** `lib/features/owner/orders/unresolved_orders_sheet.dart`

---

#### `FilterSheet`

- Route picker
- Payment status picker
- Order status picker
- Reset + Apply buttons

---

### Navigation

#### `AppBar/Orders`

- Height: 56px + status bar
- Title: "Orders" OR "N selected"
- Actions: Production icon | Search | Filter
- Selection mode: Close (×) only

**Flutter mapping:** `DeliveroAppBar` in `lib/core/widgets/delivero_sliver_header.dart`

---

#### `FAB/CreateOrder`

- 56×56 circle, primary, elevation 10
- Icon: `add_rounded` 26px
- Position: bottom-right, 16px from edges, above bottom nav

---

#### `BottomNav/Owner`

- 5 tabs: Dashboard | **Orders** | Customers | Reports | Settings
- Active: primary icon + label
- Height: 56px + safe area

**Flutter mapping:** `lib/features/owner/owner_shell.dart`

---

## 5. Screen-by-Screen Frame List

### Owner — Order List (8 frames)

| # | Frame name | State |
|---|------------|-------|
| 1 | `Orders / Default` | Today visible, mixed orders, no filters |
| 2 | `Orders / Day Selected` | Day strip highlight + filtered list |
| 3 | `Orders / Route Filter` | Route chip active |
| 4 | `Orders / Status Filter` | e.g. "Pending" chip active |
| 5 | `Orders / Selection Mode` | 3 cards selected + bulk bar |
| 6 | `Orders / Empty` | No orders yet + CTA |
| 7 | `Orders / No Results` | Filters active, zero matches |
| 8 | `Orders / Loading` | Skeleton cards |

**Flutter mapping:** `lib/features/owner/orders/order_list_screen.dart`

---

### Owner — Create Order (6 frames)

| # | Frame name | State |
|---|------------|-------|
| 9 | `Create / Step 1 — Customer` | Customer list, one selected |
| 10 | `Create / Step 2 — Schedule` | Daily + Morning + date |
| 11 | `Create / Step 3 — Menu` | Items with quantities |
| 12 | `Create / Step 4 — Review` | Summary + Place order CTA |
| 13 | `Create / Edit Mode` | Pre-filled from existing order |
| 14 | `Create / Driver Variant` | Route-filtered customers |

**Steps:** Customer → Schedule → Menu items → Order details (review)

**Flutter mapping:** `lib/features/owner/orders/create_order/create_order_screen.dart`

---

### Owner — Order Details (5 frames)

| # | Frame name | State |
|---|------------|-------|
| 15 | `Details / Pending` | Awaiting confirmation |
| 16 | `Details / In Progress` | Preparing, status actions visible |
| 17 | `Details / Delivered Unpaid` | Payment editor active |
| 18 | `Details / Paid Complete` | All green, read-only feel |
| 19 | `Details / Cancelled` | Muted, no edit actions |

**Flutter mapping:** `lib/features/owner/orders/order_details/order_details_screen.dart`

---

### Sheets & Modals (5 frames)

| # | Frame name | State |
|---|------------|-------|
| 20 | `Sheet / Production Summary` | Aggregated qty table |
| 21 | `Sheet / Unresolved Orders` | Warning + action rows |
| 22 | `Sheet / Search` | Active query + results |
| 23 | `Sheet / Filters` | All filter controls |
| 24 | `Sheet / Delete Confirm` | Destructive dialog |

---

### Driver — Orders (4 frames)

| # | Frame name | State |
|---|------------|-------|
| 25 | `Driver / Order List` | Active tab, route-scoped |
| 26 | `Driver / Delivered Tab` | Completed deliveries |
| 27 | `Driver / Order Details` | Confirm delivery CTA |
| 28 | `Driver / Create Order` | Route customer picker |

**Flutter mapping:**
- `lib/features/delivery/order_status_list_screen.dart`
- `lib/features/delivery/order_details/driver_order_details_screen.dart`
- `lib/features/delivery/driver_create_order_screen.dart`

**Total: 28 frames**

---

## 6. Prototype Flows

Link these in Figma Prototype mode:

### Flow A — Daily order lifecycle

```
Orders Default → tap card → Details Pending → Mark Confirmed →
Mark Preparing → Mark Ready → Mark Delivered → Mark Paid
```

### Flow B — Bulk morning close-out

```
Orders Default → long-press card → Selection Mode →
select 5 cards → Mark Delivered → snackbar → back to list
```

### Flow C — Create new order

```
Orders → FAB → Step 1 → 2 → 3 → 4 → Place →
highlighted new card on list
```

### Flow D — Production handoff

```
Orders → Production icon → Summary sheet → Share WhatsApp
```

### Flow E — Day filter

```
Orders → swipe day strip → tap Wednesday →
filtered list → tap × clear filter
```

### Flow F — Unresolved rollover

```
App open → Unresolved sheet → Mark Delivered → sheet auto-dismisses
```

---

## 7. Interaction Patterns

| Gesture | Action |
|---------|--------|
| Tap order card | Navigate to order details |
| Long-press order card | Enter bulk selection mode (haptic feedback) |
| Tap day cell | Toggle day filter (tap again to clear) |
| Swipe day strip | Scroll through calendar days smoothly |
| Pull down on list | Refresh orders |
| Tap × on selected date | Clear day filter |
| Tap calendar icon | Open date picker, scroll strip to picked date |

**Feedback:**
- Snackbar confirmations for bulk actions ("12 orders marked as delivered")
- Card highlight fade (~8s) for newly created/updated orders
- Bulk bar slide-up animation (200ms)
- Tab transitions: fade + slight slide (300ms)

---

## 8. Status & Payment Color Mapping

### Order status

| Status | Color | Notes |
|--------|-------|-------|
| Pending | Warning `#D97706` | Amber chip |
| Confirmed | Info `#0284C7` | Sky blue |
| Preparing | Primary `#2563EB` | Blue |
| Ready | Success `#059669` | Green |
| Delivered | Success `#059669` | Muted green |
| Cancelled | Error `#DC2626` | Red |

### Payment status

| Status | Color |
|--------|-------|
| Paid | Success `#059669` |
| Unpaid | Error `#DC2626` |
| Partial | Warning `#D97706` |

### Order types

| Type | Label |
|------|-------|
| Daily | Recurring subscription-style |
| One-time | Single occurrence |
| Special | Exception/ad-hoc |

### Delivery runs

Morning · Afternoon · Evening · Night

---

## 9. Redesign Brief (optional visual refresh)

### Keep (don't change)

- Information hierarchy on order cards (customer → status → payment → items)
- Day strip as primary date navigation
- 4-step create flow
- Bulk selection via long-press
- Status/payment color semantics
- ₹ formatting, Indian B2B context

### Improve (design opportunities)

| Area | Current | Proposed direction |
|------|---------|-------------------|
| **Day strip** | Functional scroll | Add subtle snap-to-day, dot indicator for days with orders |
| **Order cards** | Dense but long | Collapse line items by default; expand on tap |
| **Status progression** | Chips + buttons | Horizontal timeline stepper on details screen |
| **Filters** | Many chip rows | Single "Filters (3)" pill → unified filter sheet |
| **Production summary** | Text table | Visual qty bars + print-optimized layout |
| **Empty states** | Basic | Illustrated states per context (no orders vs no results) |
| **Driver cards** | Similar to owner | Simpler: address-first, swipe-to-deliver gesture |
| **Search** | Bottom sheet | Inline expandable search in app bar |

### Visual polish targets

- Consistent 20px card radius everywhere
- Reduce visual noise: fewer borders, more whitespace between sections
- Motion: card highlight fade (8s), bulk bar slide-up (200ms), day strip scroll snap
- Dark mode: defer (light-only for v1)

### Accessibility

- Minimum 44×44 touch targets
- Status never color-only: always include text label
- Contrast ratio ≥ 4.5:1 on all badge text

---

## 10. Sample Content

Use this realistic data across all frames:

**Customers:** Hotel Annapurna, Canteen Block B, Sri Krishna Tiffin, Metro Foods Pvt Ltd

**Routes:** Route 1 — North Zone, Route 2 — Industrial Area, Route 3 — City Center

**Items:** Idli (₹8), Dosa (₹40), Chapati (₹6), Sambar Rice (₹55), Biryani (₹120)

**Order IDs:** #A1B2C3, #D4E5F6 (short hex display)

**Amounts:** ₹240, ₹1,250, ₹3,480

---

## 11. Figma AI Prompt

Paste into Figma Make / AI:

```
Design a mobile order management module for Delivero, a B2B Indian food factory app.

Style: Premium enterprise SaaS. White backgrounds (#FFFFFF, #F8FAFC). Primary blue #2563EB. Bold typography (w800-w900). Rounded cards (20px radius), soft shadows, pill badges.

Screens needed:
1. Order list with horizontal scrollable day strip (7 days visible), filter chips for routes/status/payment, grouped order cards by date
2. Order card component with customer name, status pill, payment chip, line items preview, ₹ total
3. 4-step create order wizard (customer, schedule, menu, review)
4. Order details with summary card, items list, payment editor, status actions
5. Production summary bottom sheet with aggregated quantities
6. Bulk selection mode with bottom action bar

Use realistic Indian food business data. 390×844 mobile frames. Material Rounded icons. Light mode only.
```

---

## 12. Flutter ↔ Figma Component Map

| Figma component | Flutter file |
|-----------------|--------------|
| `OrderCard` | `lib/features/owner/orders/widgets/order_card.dart` |
| `DayStrip` / `DayCell` | `lib/features/owner/orders/order_list_screen.dart` |
| `DayStrip` math | `lib/features/owner/orders/day_strip_math.dart` |
| `Orders` screen | `lib/features/owner/orders/order_list_screen.dart` |
| `Create Order` wizard | `lib/features/owner/orders/create_order/create_order_screen.dart` |
| `Order Details` | `lib/features/owner/orders/order_details/order_details_screen.dart` |
| `ProductionSummarySheet` | `lib/features/owner/orders/production_summary_sheet.dart` |
| `UnresolvedOrdersSheet` | `lib/features/owner/orders/unresolved_orders_sheet.dart` |
| `DeliveroAppBar` | `lib/core/widgets/delivero_sliver_header.dart` |
| `DeliveroEmptyState` | `lib/core/widgets/delivero_empty_state.dart` |
| `DeliveroSkeleton` | `lib/core/widgets/delivero_skeleton.dart` |
| Color tokens | `lib/core/theme/app_colors.dart` |
| Text styles | `lib/core/theme/app_text_styles.dart` |
| Order model / enums | `lib/data/models/order.dart` |
| Driver order list | `lib/features/delivery/order_status_list_screen.dart` |
| Driver order details | `lib/features/delivery/order_details/driver_order_details_screen.dart` |
| Owner shell + FAB | `lib/features/owner/owner_shell.dart` |

---

## 13. Related Design Specs (in repo)

- `docs/superpowers/specs/2026-06-21-order-card-refactor-design.md`
- `docs/superpowers/specs/2026-06-21-bulk-order-actions-design.md`
- `docs/superpowers/specs/2026-06-21-order-date-picker-design.md`
- `docs/superpowers/specs/2026-06-23-swipeable-week-strip-design.md`
- `docs/superpowers/specs/2026-06-15-order-flow-fixes-design.md`
