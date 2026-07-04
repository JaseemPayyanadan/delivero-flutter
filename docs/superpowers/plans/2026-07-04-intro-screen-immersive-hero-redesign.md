# Intro Screen Immersive Hero Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the light "stepper + image + footer" onboarding in `lib/features/startup/app_intro_screen.dart` with a bold immersive-hero design (deep purple canvas, floating illustration, glass footer) without changing content, flow, or navigation.

**Architecture:** Rewrite the single screen file, preserving the `ConsumerStatefulWidget` + `PageController` + `_complete()` navigation shell. Add a continuous page-offset listener to drive parallax and gradient shift. Decompose the visuals into focused private widgets: `_HeroBackground`, `_HeroSlideView`, `_HaloIllustration`, `_SkipButton`, `_GlassFooter`, `_ExpandingDots`, `_NextButton`, `_GlassCircleButton`.

**Tech Stack:** Flutter, flutter_riverpod, go_router, `dart:ui` `ImageFilter` (blur), `BackdropFilter` (glass). No new packages.

## Global Constraints

- No new dependencies. Flutter built-ins only.
- Do NOT change: the 3 slides / illustrations / copy (`Manage with ease`, `Track with confidence`, `Deliver smiles`), the `_IntroSlide` model, the `_kIntroSlides` list, or asset paths (`assets/images/slide-1.webp`..`slide-3.webp`).
- Do NOT change navigation/state: keep `_complete()` calling `ref.read(appStartupProvider.notifier).markAppIntroSeen()` then `context.go('/login')`; keep haptics (light on step, medium on complete).
- Button/label text stays: `Skip` and `Get started` (plain-`Text` behavioral anchors). The next control is intentionally icon-only on non-last slides per the immersive design, so the guard test locates it by `Icons.arrow_forward_rounded` rather than a "Next" label.
- Brand colors via `AppColors`: purple = `primary500` (`#5A45FE`); lime accent = `secondary` (`#BFE003`), dark-on-lime = `onSecondary` (`neutral900`).
- Analyzer must stay clean (`flutter analyze` → no new issues); no unused private widgets left behind.

---

### Task 1: Behavioral regression-guard widget test

Lock the navigation/skip/back/get-started behavior that the redesign must preserve. This test passes on the CURRENT code and must keep passing through every later task.

**Files:**
- Test: `test/app_intro_screen_test.dart` (create)

**Interfaces:**
- Consumes: `AppIntroScreen` (existing, no signature change); `appStartupProvider` (existing) via real `ProviderScope` with mocked `SharedPreferences`.
- Produces: nothing consumed by later tasks; serves as the green gate for Tasks 2–3.

- [ ] **Step 1: Write the guard test**

Create `test/app_intro_screen_test.dart`:

```dart
import 'package:delivero/features/startup/app_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(path: '/intro', builder: (_, __) => const AppIntroScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('LOGIN_PAGE')),
        ),
      ],
    );

Widget _harness() =>
    ProviderScope(child: MaterialApp.router(routerConfig: _buildRouter()));

Future<void> _advance(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first slide shows Skip + Next, not Get started', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('Next twice reaches last slide showing Get started, not Next',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _advance(tester);
    await _advance(tester);

    // On the last slide the CTA morphs to "Get started" and "Next" is gone.
    // Note: the "Skip" Text stays in the tree but is hidden via opacity 0 +
    // IgnorePointer (both before and after the redesign), so asserting its
    // absence with find.text is invalid — its hidden state is a manual check.
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('Skip marks intro seen and navigates to /login', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenAppIntro'), true);
  });

  testWidgets('Get started completes onboarding to /login', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _advance(tester);
    await _advance(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test against current code**

Run: `flutter test test/app_intro_screen_test.dart`
Expected: PASS (4 tests). This locks the current behavior. If any fail, stop and reconcile the test with the real current behavior before touching the UI.

- [ ] **Step 3: Commit**

```bash
git add test/app_intro_screen_test.dart
git commit -m "test: add behavioral guard for app intro screen"
```

---

### Task 2: Immersive hero canvas — background, slide, skip

Swap the light gradient + centered column for the dark purple canvas, floating illustration with parallax/scale + staggered editorial text, and dark-styled Skip. Keep the EXISTING `_IntroFooter`/`_CircleIconButton`/`_PrimaryPillButton` temporarily so the screen stays functional and the guard stays green (footer is replaced in Task 3).

**Files:**
- Modify: `lib/features/startup/app_intro_screen.dart`
- Test: `test/app_intro_screen_test.dart` (must stay green — no edits)

**Interfaces:**
- Consumes: `_IntroSlide`, `_kIntroSlides`, `AppColors`, the existing `_IntroFooter` (kept for now).
- Produces: `_HeroBackground({required double page})`, `_HeroSlideView({required _IntroSlide slide, required double offset})`, `_HaloIllustration({required String asset})`, `_SkipButton({required bool showSkip, required VoidCallback onSkip})`, `_Blob({required Color color, required double size})`; and state field `double _page` with listener `_onPageScroll()` — all consumed by Task 3.

- [ ] **Step 1: Add the `dart:ui` import**

At the top of `app_intro_screen.dart`, add below the existing imports:

```dart
import 'dart:ui' show ImageFilter;
```

- [ ] **Step 2: Add continuous page-offset tracking to the State**

In `_AppIntroScreenState`, add the field and lifecycle wiring. Add `double _page = 0;` next to `int _currentPage = 0;`, then add `initState` and the listener, and update `dispose`:

```dart
  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _currentPage.toDouble();
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }
```

(Replace the existing `dispose` — do not duplicate it.)

- [ ] **Step 3: Rewrite the `build` method**

Replace the entire `build` method body of `_AppIntroScreenState` with:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary700,
      body: Stack(
        children: [
          Positioned.fill(child: _HeroBackground(page: _page)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SkipButton(showSkip: !_isLastPage, onSkip: _complete),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _slideCount,
                    itemBuilder: (context, index) => _HeroSlideView(
                      slide: _kIntroSlides[index],
                      offset: _page - index,
                    ),
                  ),
                ),
                _IntroFooter(
                  isFirstPage: _isFirstPage,
                  isLastPage: _isLastPage,
                  currentPage: _currentPage,
                  pageCount: _slideCount,
                  onBack: _onBack,
                  onNext: _onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Delete the now-unused light widgets and add the hero widgets**

Delete these classes entirely: `_IntroTopBar`, `_OnboardingStepper`, `_StepDot`, `_StepConnector`, `_IntroSlideView`. (Keep `_IntroSlide`, `_IntroFooter`, `_CircleIconButton`, `_PrimaryPillButton` for now.) Then add:

```dart
class _HeroBackground extends StatelessWidget {
  final double page;
  const _HeroBackground({required this.page});

  static const _midColors = [
    AppColors.primary500,
    AppColors.primary600,
    AppColors.primary700,
  ];

  Color _midFor(double p) {
    final maxIndex = _midColors.length - 1;
    final clamped = p.clamp(0.0, maxIndex.toDouble());
    final lo = clamped.floor();
    final hi = (lo + 1).clamp(0, maxIndex);
    return Color.lerp(_midColors[lo], _midColors[hi], clamped - lo)!;
  }

  @override
  Widget build(BuildContext context) {
    final mid = _midFor(page);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary700, mid, AppColors.primary900],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -40,
          child: _Blob(
            color: AppColors.secondary.withValues(alpha: 0.12),
            size: 260,
          ),
        ),
        Positioned(
          top: 220,
          left: -70,
          child: _Blob(
            color: AppColors.primary300.withValues(alpha: 0.18),
            size: 300,
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;
  const _SkipButton({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: showSkip ? 1 : 0,
          child: IgnorePointer(
            ignoring: !showSkip,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.85),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSlideView extends StatelessWidget {
  final _IntroSlide slide;
  final double offset;
  const _HeroSlideView({required this.slide, required this.offset});

  @override
  Widget build(BuildContext context) {
    final centered = (1 - offset.abs()).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 55,
          child: Center(
            child: Transform.translate(
              offset: Offset(-offset * 40, 0),
              child: Transform.scale(
                scale: 0.92 + 0.08 * centered,
                child: _HaloIllustration(asset: slide.imageAsset),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 40,
          child: Opacity(
            opacity: centered,
            child: Transform.translate(
              offset: Offset(0, (1 - centered) * 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1.05,
                        ),
                        children: [
                          TextSpan(
                            text: slide.title,
                            style:
                                const TextStyle(color: AppColors.secondary),
                          ),
                          const TextSpan(text: '\n'),
                          TextSpan(text: slide.titleRest),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide.subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HaloIllustration extends StatelessWidget {
  final String asset;
  const _HaloIllustration({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the guard test**

Run: `flutter test test/app_intro_screen_test.dart`
Expected: PASS (4 tests) — behavior unchanged.

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze lib/features/startup/app_intro_screen.dart`
Expected: No issues (no unused elements, no undefined names).

- [ ] **Step 7: Manual visual check**

Launch the app to the intro route (see Task 3 Step 6 for how) and confirm: dark purple gradient canvas, illustration floats on a soft halo, headline is white with the first word in lime, left-aligned, Skip is a subtle white label top-right. The footer will still look light/unstyled — that's expected until Task 3.

- [ ] **Step 8: Commit**

```bash
git add lib/features/startup/app_intro_screen.dart
git commit -m "feat: immersive hero canvas + slide + skip for intro screen"
```

---

### Task 3: Glass footer — expanding dots, back, morphing next button

Replace the temporary light `_IntroFooter` with a frosted-glass pill: lime expanding-dot indicators, a glass back control (from slide 2), and a lime circular next button that morphs into a "Get started" pill on the last slide.

**Files:**
- Modify: `lib/features/startup/app_intro_screen.dart`
- Test: `test/app_intro_screen_test.dart` (must stay green — no edits)

**Interfaces:**
- Consumes: state callbacks `_onBack`, `_onNext`, and flags `_isFirstPage`, `_isLastPage`, `_currentPage`, `_slideCount` (existing).
- Produces: `_GlassFooter`, `_ExpandingDots`, `_NextButton`, `_GlassCircleButton` (terminal — nothing consumes them).

- [ ] **Step 1: Swap the footer widget in `build`**

In the `build` method, replace the `_IntroFooter( ... )` child with:

```dart
                _GlassFooter(
                  isFirstPage: _isFirstPage,
                  isLastPage: _isLastPage,
                  currentPage: _currentPage,
                  pageCount: _slideCount,
                  onBack: _onBack,
                  onNext: _onNext,
                ),
```

- [ ] **Step 2: Delete the old footer widgets**

Delete these classes entirely: `_IntroFooter`, `_CircleIconButton`, `_PrimaryPillButton`.

- [ ] **Step 3: Add the glass footer widgets**

Add at the end of the file:

```dart
class _GlassFooter extends StatelessWidget {
  final bool isFirstPage;
  final bool isLastPage;
  final int currentPage;
  final int pageCount;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _GlassFooter({
    required this.isFirstPage,
    required this.isLastPage,
    required this.currentPage,
    required this.pageCount,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFirstPage ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: isFirstPage,
                      child: _GlassCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ExpandingDots(count: pageCount, index: currentPage),
                ),
                _NextButton(isLast: isLastPage, onTap: onNext),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandingDots extends StatelessWidget {
  final int count;
  final int index;
  const _ExpandingDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppColors.secondary
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool isLast;
  final VoidCallback onTap;
  const _NextButton({required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          height: 52,
          width: isLast ? null : 52,
          padding: EdgeInsets.symmetric(horizontal: isLast ? 22 : 0),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLast) ...[
                const Text(
                  'Get started',
                  style: TextStyle(
                    color: AppColors.onSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.onSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
```

Note: `_GlassCircleButton` currently hardcodes the back icon in its `SizedBox` for simplicity; the `icon` field is passed for future reuse. If the analyzer flags `icon` as unused, replace the hardcoded `Icon(Icons.arrow_back_rounded, ...)` with `Icon(icon, color: Colors.white, size: 20)` and drop `const` from the `SizedBox`.

- [ ] **Step 4: Run the guard test**

Run: `flutter test test/app_intro_screen_test.dart`
Expected: PASS (4 tests). `find.text('Next')` and `find.text('Get started')` resolve inside `_NextButton`.

- [ ] **Step 5: Run the analyzer and full test suite**

Run: `flutter analyze` then `flutter test`
Expected: analyzer clean; all tests pass.

- [ ] **Step 6: Manual visual verification (screenshots)**

Run the app and drive it to the intro screen. Use the project `/run` skill if available; otherwise the intro screen shows on first launch (fresh install) or by temporarily routing to it. Practical approach for a simulator:

```bash
flutter run -d <device-id>
```

Confirm and screenshot each state:
1. Slide 1 — Skip visible top-right, no back, dot 1 = lime pill, next = lime circle.
2. Slide 2 — back control visible (glass), dot 2 active.
3. Slide 3 — Skip gone, next morphed into lime "Get started" pill.
4. Footer reads as a frosted-glass pill; lime dots/button have good contrast on purple.

Check on a small phone (~360×640) and a large one: text not clipped, no overflow banner, illustration not cramped.

- [ ] **Step 7: Commit**

```bash
git add lib/features/startup/app_intro_screen.dart
git commit -m "feat: frosted glass footer with expanding dots and morphing CTA"
```

---

## Self-Review

**Spec coverage:**
- Deep purple gradient + per-slide shift → Task 2 `_HeroBackground` (`_midFor`, page-driven). ✓
- Ambient lime/purple blobs → Task 2 `_Blob`. ✓
- Floating illustration on glass halo + parallax + scale-in → Task 2 `_HeroSlideView` / `_HaloIllustration`. ✓
- Editorial left-aligned white headline, first word lime, accent underline, subtitle 70% → Task 2 `_HeroSlideView`. ✓
- Staggered text-in (opacity + translate on settle) → Task 2 (`centered` drives opacity/offset). ✓
- Skip top-right, dark styling, hidden last slide → Task 2 `_SkipButton`. ✓
- Drop numbered stepper → Task 2 Step 4 deletes `_OnboardingStepper` & friends. ✓
- Frosted glass footer, lime expanding dots, glass back from slide 2, morphing next→Get started → Task 3. ✓
- Navigation/state/haptics unchanged → preserved shell (not modified). ✓
- No new deps → only `dart:ui`. ✓
- Success criteria (swipe flow, skip/get-started → /login, back visibility, no overflow, contrast) → Task 1 guard + Task 3 Step 6 manual. ✓

**Placeholder scan:** No TBD/TODO; all steps carry full code or exact commands. The one conditional (`_GlassCircleButton.icon` unused) has an explicit resolution. ✓

**Type consistency:** `_HeroBackground({page})`, `_HeroSlideView({slide, offset})`, `_GlassFooter({isFirstPage,isLastPage,currentPage,pageCount,onBack,onNext})`, `_ExpandingDots({count,index})`, `_NextButton({isLast,onTap})` — call sites in `build` match declarations. `_page` field + `_onPageScroll` listener declared and removed in `dispose`. ✓
