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
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isFirstPage ? 0 : 1,
              child: IgnorePointer(
                ignoring: isFirstPage,
                child: _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) {
                final isActive = index == currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.neutral300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
          ),
          _PrimaryPillButton(
            label: isLastPage ? 'Get started' : 'Next',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neutral200, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
