# Fillo Visual Language — Pilot (Profile screen)

**Date:** 2026-07-04
**Status:** Design approved, spec under review

## Goal

Bring the "Fillo Parcel" mockup's visual language into the Delivero app. The
palette already matches (purple `primary500 #5A45FE`, lime `secondary #BFE003`,
amber `accent #F59E0B`). What is missing is the *style language*: bold purple
gradient headers, soft rounded cards, lime pill CTAs, and tinted status chips.

This spec covers **only the pilot**: the Profile / Settings screen
(`lib/features/profile/settings_screen.dart`). We prove the look on one screen,
get sign-off, then roll the reusable pieces out to the other ~19 screens in
follow-up work. Each rollout screen is out of scope here.

### Three signatures we are adopting (user-selected)

1. Soft rounded cards (already largely present — consolidate into one widget).
2. Lime pill buttons + tinted status chips.
3. Bold purple gradient headers (full banner, like the mockup — user's choice
   over a compact bar).

The full-bleed illustration onboarding style was explicitly **excluded**.

## Reusable pieces (added to `lib/core/widgets/`, `delivero_` prefix)

These follow the existing naming convention (`delivero_button.dart`, etc.) and
build on existing widgets where possible.

### 1. `DeliveroGradientHeader` (`delivero_gradient_header.dart`)

A bold purple gradient banner that fills the top of the screen behind the app
bar. The mockup's signature move: an avatar/leading element overlaps the bottom
edge of the banner onto the white content below.

- Gradient: `AppColors.primaryGradientStart → primaryGradientEnd`
  (`primary500 → primary700`), ~160° diagonal.
- **Chosen layout: "Straddle" (option A).** Banner height ~130px (tunable
  constant). The circular avatar straddles the banner's bottom edge — roughly
  half on purple, half on the white content below — left-aligned. Name, phone,
  and status chip sit left-aligned on white directly under the avatar.
- White title text + back button on the gradient.
- Exposes a slot for the overlapping avatar child so callers don't
  re-implement the Stack. Avatar has a white ring + soft shadow to read against
  both the purple and the white.

**What it is:** the screen's top chrome + hero banner.
**How you use it:** wrap the screen body; pass `title`, optional `overlapChild`.
**Depends on:** `AppColors`, `AppTextStyles`.

### 2. `DeliveroCard` (`delivero_card.dart`)

Extracts the radius-24 + border + soft-shadow `BoxDecoration` currently repeated
~4× in `settings_screen.dart` (`_SettingsGroupCard`, `_ProfileHeroCard`, plan
card, vehicle card) into one widget. Purely visual; no behavior change.

- radius 24, `AppColors.surface`, `border`, shadow `blurRadius: 22, offset (0,8)`.
- Optional `clipBehavior`, `padding`.

**What it is:** the standard content surface.
**How you use it:** `DeliveroCard(child: ...)`.
**Depends on:** `AppColors`.

### 3. `DeliveroStatusChip` (`delivero_status_chip.dart`)

The tinted pill used for Driver / Available / Off-duty badges.

- Tone enum: `neutral | success | info | warning | primary`.
- Each tone maps to a tint fill + border + text color already in `AppColors`
  (e.g. success → `successLighter` fill, `success` text).
- Rounded 999, uppercase-ish bold small label.

**What it is:** a status/label pill.
**How you use it:** `DeliveroStatusChip(label: 'Available', tone: .success)`.
**Depends on:** `AppColors`.

### 4. Lime pill CTA

`DeliveroButton` already accepts `backgroundColor` / `foregroundColor`, so the
lime CTA is a **preset**, not a new widget: `backgroundColor: AppColors.secondary`,
`foregroundColor: AppColors.onSecondary` (dark text on lime). Add a named
constructor or static helper `DeliveroButton.lime(...)` for ergonomics and
consistent reuse across the rollout.

## Profile screen changes (`settings_screen.dart`)

| Element | Now | After |
|---|---|---|
| Screen top | `DeliveroAppBar` + faint purple wash inside white hero card | `DeliveroGradientHeader` bold purple banner; avatar overlaps onto white |
| Avatar | Inside hero card | Circular avatar overlapping the gradient banner's bottom edge |
| Name / phone / company | In hero card | Sits in white area directly below the overlapping avatar |
| Group cards (Preferences/Orders/Support) | `_SettingsGroupCard` bespoke decoration | Re-based on `DeliveroCard`; visually unchanged |
| Vehicle / plan cards | Bespoke decorations | `DeliveroCard` |
| Chips (Driver / Available / Off duty) | Ad-hoc containers | `DeliveroStatusChip` |
| "Generate now" button (OrderSettings) | Purple `FilledButton` | Lime `DeliveroButton.lime` |
| Sign out | Outlined red | **Unchanged** — destructive stays de-emphasized; lime would misread as primary |

Notes:
- The `OrderSettingsScreen` in the same file also uses `_SettingsGroupCard` and
  `_ProfileSwitchRow`/`_ProfileTimeRow`; those shared row widgets stay as-is and
  keep working since only the card wrapper changes.
- Loading skeleton (`_ProfileHeroSkeleton`) is updated to match the new header
  layout (avatar overlap position) so there is no layout jump.
- No provider, preference, or navigation logic changes. This is presentation
  only.

## Testing

- Existing widget tests for the settings screen must still pass. Run the
  project's Flutter test suite.
- Add/adjust a widget test asserting: gradient header renders the title, the
  avatar/initials render, and a `DeliveroStatusChip` appears for a delivery user.
- Manual verification: run the app, open Profile as both an owner and a delivery
  user; confirm the overlapping avatar, lime button on Order settings, and chips
  render correctly, and that large text scale does not overflow the header
  (consistent with the recent intro-screen overflow guard work).

## Out of scope

- The other ~19 screens (separate rollout, one follow-up plan).
- The full-bleed illustration onboarding style.
- Any color *value* changes — the palette stays as-is.
- Dark theme behavior beyond what already exists.

## Rollout after pilot

Once approved on Profile, the four pieces (`DeliveroGradientHeader`,
`DeliveroCard`, `DeliveroStatusChip`, `DeliveroButton.lime`) become the vocabulary
for applying the same look to dashboards, order details, lists, and auth — each
its own small change reusing these widgets.
