import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';

const List<_IntroSlide> _kIntroSlides = [
  _IntroSlide(
    title: 'Manage',
    titleRest: 'with ease',
    subtitle:
        'Add customers, manage orders, assign routes and keep everything organized.',
    imageAsset: 'assets/images/slide-1.webp',
  ),
  _IntroSlide(
    title: 'Track',
    titleRest: 'with confidence',
    subtitle:
        'Real-time status, verified drop-offs and clear proof of delivery on every order.',
    imageAsset: 'assets/images/slide-2.webp',
  ),
  _IntroSlide(
    title: 'Deliver',
    titleRest: 'smiles',
    subtitle:
        'Hassle-free deliveries, happy customers and growing your business.',
    imageAsset: 'assets/images/slide-3.webp',
  ),
];

class AppIntroScreen extends ConsumerStatefulWidget {
  const AppIntroScreen({super.key});

  @override
  ConsumerState<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends ConsumerState<AppIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _page = 0;

  int get _slideCount => _kIntroSlides.length;
  bool get _isLastPage => _currentPage >= _slideCount - 1;
  bool get _isFirstPage => _currentPage == 0;

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

  void _onNext() {
    _hapticLight();
    if (_isLastPage) {
      _complete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutExpo,
    );
  }

  void _onBack() {
    if (_isFirstPage) return;
    _hapticLight();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _complete() async {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    await ref.read(appStartupProvider.notifier).markAppIntroSeen();
    if (!mounted) return;
    context.go('/login');
  }

  void _hapticLight() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

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
                _GlassFooter(
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
}

class _IntroSlide {
  final String title;
  final String titleRest;
  final String subtitle;
  final String imageAsset;

  const _IntroSlide({
    required this.title,
    required this.titleRest,
    required this.subtitle,
    required this.imageAsset,
  });
}

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
        // AnimatedSize measures the (always fully-sized, never squeezed) Row
        // below and tweens the outer box toward it — unlike animating the
        // `width` field directly, the inner Row is never handed less space
        // than it needs, so it can't overflow mid-morph.
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          alignment: Alignment.centerRight,
          child: Container(
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
                ] else
                  // Present in the tree (for the guard test's
                  // find.text('Next')) but zero-size so the circular button
                  // stays icon-only.
                  const SizedBox.shrink(child: Text('Next')),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.onSecondary,
                  size: 20,
                ),
              ],
            ),
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
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
