# Owner Setup Wizard — Fillo Reskin + UX Pass

**Date:** 2026-07-05
**Status:** Design approved
**File:** `lib/features/onboarding/onboarding_screen.dart`

## Goal

Improve the owner first-run setup wizard (Profile → Routes → Customers →
Products) on two fronts in one pass:

1. **Visual:** move it onto the Fillo purple/lime visual language already rolled
   out on the Profile pilot, using the existing reusable widgets.
2. **UX:** two targeted flow fixes — inline field validation (replacing
   transient snackbars) and a discoverable Skip on the optional step.

This is a **presentation + validation + skip** pass only. The single-item-per-step
flow is deliberately kept.

## Explicitly out of scope

- **No multi-add.** One entry per step stays (user decision). We are NOT adding
  "add another" lists, item chips, or bottom-sheet add forms.
- **No logic changes.** `_saveProfile`, `_saveInlineRoute/Customer/Product`, the
  dedupe-on-return checks, `factoryId` handling, `_firstIncompleteIndex` /
  initial-jump logic, `completeOnboarding()`, and routing to `/owner` all stay
  exactly as they are.
- **No palette value changes.** Uses existing `AppColors` tokens.
- No changes to the App Intro carousel (`app_intro_screen.dart`).

## Reusable Fillo pieces used (already exist in `lib/core/widgets/`)

- `DeliveroGradientHeader({required title, actions, ...})` — purple gradient
  banner. Used as plain banner (no avatar/overlapChild).
- `DeliveroCard({required child, padding, radius})` — radius-24 soft surface.
- `DeliveroStatusChip({required label, tone})` — tones:
  `neutral | success | info | warning | primary`.
- `DeliveroButton.lime({required label, required onPressed, icon, isLoading, ...})`
  — lime pill CTA (dark text on lime).

## Changes

### 1. Top chrome — gradient header

| Now | After |
|---|---|
| Plain white `AppBar`: title `Business setup` + trailing `Step N of 4` text | `DeliveroGradientHeader` purple banner: title `Business setup`; `Step N of 4` rendered as a white-text action on the banner |

- No back button on the header (`automaticallyImplyLeading:false` today; the
  header's `onBack` stays null — step-back is handled by the bottom nav's circle
  button, unchanged).
- The `Step N of 4` action must respect the large-text-scale overflow guard used
  elsewhere (clamp text scaling) so it never overflows the banner.

### 2. Progress stepper

Keep the existing tappable dot+label stepper (`_StepperHeader` / `_StepDot`),
positioned on white directly below the banner. Behaviour unchanged (tap to a
completed/current step, locked steps disabled). Visual alignment only:

- Active dot: purple fill + purple glow (already the case).
- Completed dot: `AppColors.success` with white check (already the case).
- Labels: active → purple, completed → success, pending → `textLight`
  (already the case). Confirm connector color uses `success` when reached,
  `border` otherwise (already the case). No structural change expected here;
  this section is a verification pass, not a rewrite.

### 3. Step content surface

Wrap each step page's form (the fields block, not the whole scroll view) in a
`DeliveroCard`. `_StepScaffold` keeps the outer scroll + padding; the
`_StepHeader` (icon tile + title + description + status chip) can sit above the
card or as the card's first block — implementer's choice, but consistent across
all four steps.

### 4. Accent unification

The three step-header icon tiles currently use different accents:

| Step | Now | After |
|---|---|---|
| Profile | `primary` | `primary` (purple) |
| Routes | `primary` | `primary` (purple) |
| Customers | `info` (blue) | `primary` (purple) |
| Products | `warning` (amber) | `primary` (purple) |

All icon tiles use the Fillo purple accent so the flow reads as one system.

### 5. Status chip

Replace the ad-hoc `_StatusChip` container with `DeliveroStatusChip`:

| State | Tone |
|---|---|
| Completed | `success` (label "Done") |
| Required (not done) | `primary` (label "Required") — **moved off red** |
| Optional (not done) | `neutral` (label "Optional") |

### 6. CTAs (bottom nav)

- Forward button (`Save & next` / `Next` / `Launch dashboard`) →
  `DeliveroButton.lime`. This replaces the current purple/green gradient
  `_PrimaryButton` in the bottom nav.
- Loading state uses the button's `isLoading` (shows spinner, keeps label per
  existing "Saving…" text or the button's built-in spinner — keep the "Saving…"
  label text for continuity).
- Back button: keep `_CircleIconButton`, restyle border to Fillo `border` token
  (already close). No behaviour change.
- The final-step "Launch dashboard" uses lime as well (celebration lives in the
  completion dialog).

### 7. Inline validation (replaces snackbars)

Today invalid/missing required fields trigger transient `_showSnack(...)`
messages. Move these to **inline error text** shown under the specific field
when the forward button is tapped with invalid input, cleared as soon as that
field is edited.

Mechanism: add per-field error state (nullable error strings) to
`_OnboardingScreenState`; the step page widgets take optional `errorText` and
render it via the `TextField`'s `InputDecoration.errorText`. On forward-tap,
`_goNext` sets the relevant error(s) instead of calling `_showSnack`; the
existing form-change listeners (extended to the route/customer/product
controllers) clear the corresponding error on edit.

Per step:

- **Profile (`_saveProfile`):** name empty → error under name; business empty →
  error under business. (Currently two separate snackbars.)
- **Routes (`_goNext` case 1):** partial data → error on the empty field(s);
  "no data and no existing routes" → error under the fields prompting entry.
- **Products (`_goNext` case 3):** partial data → error on empty field(s);
  invalid price (`double.tryParse` fails / negative) → error under price;
  "no data and no existing products" → error prompting entry.
- **Customers (case 2):** optional — no blocking validation.

Snackbars remain **only** for rare non-field failures (e.g. `factoryId` null /
save exception paths) where there is no specific field to attach to.

### 8. Discoverable Skip (Customers step only)

Customers is the only optional step. Add an explicit **"Skip for now"**
secondary text button (in the step body under the card, or in the bottom nav as
a secondary action — implementer's choice, kept visually secondary to the lime
CTA). Tapping it advances to Products with no input required — behaviourally
identical to today's "leave blank + Next", just discoverable. Only rendered on
step index 2.

### 9. Completion dialog

Light touch:

- Keep the green `_SuccessBadge` + checkmark animation (semantic "all set").
- Keep the `_ReadyHighlights` rows.
- Reskin the `Open dashboard` button to `DeliveroButton.lime`.
- Card can adopt `DeliveroCard` styling (radius 24 already matches) — optional,
  visual parity only.

## Testing

- Existing tests must still pass (run the Flutter test suite).
- Add/adjust widget tests asserting:
  - The gradient header renders the `Business setup` title.
  - Tapping the forward button on the Profile step with an empty name surfaces
    an **inline** `errorText` (not a snackbar) under the name field.
  - The "Skip for now" button appears on the Customers step and advances to
    Products.
  - The completion dialog renders its heading and `Open dashboard` button.
- Manual: run as an owner through all four steps; confirm the purple banner,
  purple step accents, lime CTAs, inline errors, Skip, and the completion dialog
  render correctly, and that large text scale does not overflow the banner.
