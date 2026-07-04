# Intro Screen Redesign — Immersive Hero

**Date:** 2026-07-04
**File affected:** `lib/features/startup/app_intro_screen.dart`
**Type:** Full visual overhaul (visual/layout/motion only — no content, flow, or navigation changes)

## Goal

Replace the current light "stepper + image + title + footer" onboarding with a **bold, immersive hero** experience that feels premium and confident, built around the brand purple (`#5A45FE`) with a lime accent (`#BFE003`).

## Non-Goals / Constraints (do not change)

- Same 3 slides, illustrations, and copy: `Manage with ease`, `Track with confidence`, `Deliver smiles`.
- Same slide assets: `assets/images/slide-1.webp`, `slide-2.webp`, `slide-3.webp` (900×900, transparent).
- Same navigation & state: keep `ConsumerStatefulWidget`, `PageController`, `_complete()` which calls
  `ref.read(appStartupProvider.notifier).markAppIntroSeen()` then `context.go('/login')`.
- Keep haptics (light on step, medium on complete).
- No new packages. Use Flutter built-ins (`BackdropFilter` for glass, `AnimatedContainer`, `Transform`).

## Visual Direction

Deep-purple immersive canvas with a large floating illustration and editorial, left-aligned text.

### 1. Background — `_HeroBackground`

- Full-screen vertical gradient using the primary scale, e.g. `primary700 → primary500 → primary900`.
- Gradient **shifts subtly per slide** (interpolate the mid color across slides: slide 0 cooler/lighter,
  slide 2 richer/deeper). Cross-fade driven by `PageController` page offset for smoothness during swipe.
- Two large soft **blurred ambient blobs** behind the illustration:
  - one lime (`#BFE003`) at low opacity (~0.12), upper area
  - one lighter purple (`primary300`) at low opacity, opposite side
  - Rendered as blurred circles (Container + `ImageFiltered`/`BackdropFilter` or a simple blurred
    `DecoratedBox`). Static or very slow drift — keep cheap.

### 2. Slide content — `_HeroSlideView`

Layered layout, not a stacked column:

- **Illustration (upper ~55%):** the 900×900 art displayed large, centered horizontally, sitting on a
  soft translucent "halo" disc (white at low opacity, blurred/glassy) so it reads against the gradient.
  - On settle, illustration does a gentle **scale-in (0.92 → 1.0) + fade** and a subtle **parallax**
    (translates slower than the page swipe using the page offset).
- **Text zone (lower ~35%, left-aligned, padded ~28px):**
  - **Headline:** ~40–44px, `FontWeight.w800`, `letterSpacing ≈ -1.0`, `height 1.05`, white.
    First word (`Manage`/`Track`/`Deliver`) rendered in **lime `#BFE003`** as the accent.
  - **Accent underline:** short lime bar (~40×4, rounded) tucked directly under the headline.
  - **Subtitle:** 15px, white at ~70% opacity, `height 1.5`, up to ~2 lines.
  - Text animates **up + fade with a slight stagger** (headline first, then subtitle) on slide settle.

### 3. Top bar — Skip

- **Skip stays top-right** (matches current placement). Restyle for the dark canvas: white text
  ~70% opacity, subtle. Hidden on the last slide (existing `AnimatedOpacity` + `IgnorePointer` pattern).

### 4. Footer — `_GlassFooter`

- A **frosted-glass pill container** (`BackdropFilter` blur + translucent white fill, rounded) spanning
  the bottom with safe-area padding. Contains:
  - **Center:** expanding-pill dot indicators in **lime** (active = wide lime pill, inactive = small
    translucent-white dot). Reuse the existing animated-dot approach, recolored.
  - **Right:** a **circular lime button** with a dark arrow icon (`onSecondary` / `neutral900` for
    contrast on lime). On the **last slide** it morphs into a wider **"Get started"** pill
    (`AnimatedContainer` width/label change).
  - **Left:** a **back** control (circular, translucent-white/glass) shown from slide 2 onward
    (existing first-page hide pattern). On slide 1 the space is empty/transparent.
- Drop the numbered `_OnboardingStepper` entirely (too heavy for the immersive look).

### 5. Motion summary

- Page transition: illustration parallax + scale, headline/subtitle staggered slide-up + fade.
- Background mid-color cross-fades between slides.
- Timing ~350–420ms, `Curves.easeOutExpo` / `easeOutCubic`. No bounce.

## Code Structure

Rewrite `app_intro_screen.dart`, preserving the state/navigation shell. Replace old private widgets
(`_IntroTopBar`, `_OnboardingStepper`, `_StepDot`, `_StepConnector`, `_IntroSlideView`, `_IntroFooter`,
`_CircleIconButton`, `_PrimaryPillButton`) with focused new ones:

- `_HeroBackground` — gradient + ambient blobs, reacts to page offset.
- `_HeroSlideView` — illustration (halo + parallax/scale) + text block (staggered).
- `_SkipButton` — top-right, dark-canvas styling.
- `_GlassFooter` — frosted pill with dots + back + morphing next/Get-started button.
- `_ExpandingDots` — lime expanding-pill indicators (can live inside `_GlassFooter`).

Keep `_IntroSlide` data model and the `_kIntroSlides` list unchanged.

To drive parallax/gradient smoothly, track the continuous page offset (listen to `_pageController` or
use an `AnimatedBuilder` on it) in addition to the settled `_currentPage` index used for labels/state.

## Success Criteria

- Runs on the intro route with all 3 slides swiping smoothly; Next → Next → Get started → `/login`.
- Skip (slides 1–2) → `/login`; both paths call `markAppIntroSeen()`.
- Back appears from slide 2, hidden on slide 1.
- Haptics fire as before.
- No overflow on small (~360×640) and large phone sizes; text never clipped.
- Reads clearly: white/lime text has sufficient contrast on the purple gradient.
- No new dependencies; analyzer clean.

## Manual Verification

Run the app to the intro screen and screenshot each of the 3 slides plus the last-slide "Get started"
state to confirm layout, contrast, and the footer morph.
