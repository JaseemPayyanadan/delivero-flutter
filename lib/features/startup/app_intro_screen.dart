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
    imageAsset: 'assets/images/introscreen-1.jpg',
  ),
  _IntroSlide(
    title: 'Track',
    titleRest: 'with confidence',
    subtitle:
        'Real-time status, verified drop-offs and clear proof of delivery on every order.',
    imageAsset: 'assets/images/introscreen-2.jpg',
  ),
  _IntroSlide(
    title: 'Deliver',
    titleRest: 'smiles',
    subtitle:
        'Hassle-free deliveries, happy customers and growing your business.',
    imageAsset: 'assets/images/introscreen-3.jpg',
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
  bool _completing = false;

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
    if (_completing) return;
    _completing = true;
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
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed swipeable slide backgrounds (image + top headline).
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slideCount,
            itemBuilder: (context, index) => _IntroSlideView(
              slide: _kIntroSlides[index],
              offset: _page - index,
            ),
          ),
          // Overlaid controls: Skip pinned top-right, footer pinned bottom.
          SafeArea(
            child: Column(
              children: [
                _SkipButton(showSkip: !_isLastPage, onSkip: _complete),
                const Spacer(),
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

class _IntroSlideView extends StatelessWidget {
  final _IntroSlide slide;
  final double offset;
  const _IntroSlideView({required this.slide, required this.offset});

  @override
  Widget build(BuildContext context) {
    final centered = (1 - offset.abs()).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed artwork. Slightly over-scaled so the gentle parallax
        // translate never reveals an empty edge during a swipe.
        Transform.scale(
          scale: 1.1,
          child: Transform.translate(
            offset: Offset(-offset * 14, 0),
            child: Image.asset(slide.imageAsset, fit: BoxFit.cover),
          ),
        ),
        // Soft light scrim at the top keeps the dark headline legible over the
        // faint skyline without washing out the artwork below.
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 340,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD9FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ),
        // Headline + subtitle, centered and seated in the clean upper band so
        // they read as a deliberate group above the artwork (not pinned to the
        // status bar with a void beneath).
        SafeArea(
          bottom: false,
          child: Align(
            alignment: const Alignment(0, -0.58),
            child: Opacity(
              opacity: centered,
              child: Transform.translate(
                offset: Offset(0, (1 - centered) * 20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                            children: [
                              TextSpan(
                                text: slide.title,
                                style: const TextStyle(color: AppColors.primary),
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
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
                foregroundColor: AppColors.textSecondary,
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

class _IntroFooter extends StatelessWidget {
  final bool isFirstPage;
  final bool isLastPage;
  final int currentPage;
  final int pageCount;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _IntroFooter({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(36),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowDeep,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
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
                  child: _CircleNavButton(
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
            color: active ? AppColors.primary : AppColors.neutral300,
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
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLast) ...[
                  const Text(
                    'Get started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
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

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neutral200, width: 1.2),
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
        ),
      ),
    );
  }
}
