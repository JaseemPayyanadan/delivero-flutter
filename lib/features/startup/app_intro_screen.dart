import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';

const List<_IntroSlide> _kIntroSlides = [
  _IntroSlide(
    title: 'Fast',
    titleRest: 'delivery',
    subtitle: 'Get your orders delivered quickly and efficiently',
    imageAsset: 'assets/images/slide-1.webp',
  ),
  _IntroSlide(
    title: 'Track',
    titleRest: 'your orders',
    subtitle: 'Monitor your deliveries in real-time',
    imageAsset: 'assets/images/slide-2.webp',
  ),
  _IntroSlide(
    title: 'Fresh',
    titleRest: 'food always',
    subtitle: 'Quality ingredients delivered to your door',
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

  int get _slideCount => _kIntroSlides.length;
  bool get _isLastPage => _currentPage >= _slideCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    if (_isLastPage) {
      _complete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutExpo,
    );
  }

  void _goToIndex(int index) {
    final safe = index.clamp(0, _slideCount - 1);
    _pageController.animateToPage(
      safe,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentPage = safe);
  }

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await ref.read(appStartupProvider.notifier).markAppIntroSeen();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroWidth = (constraints.maxWidth - 80).clamp(240.0, 360.0);
            return Column(
              children: [
                const SizedBox(height: 18),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _slideCount,
                    itemBuilder: (context, index) {
                      return _IntroSlideView(
                        slide: _kIntroSlides[index],
                        heroWidth: heroWidth,
                      );
                    },
                  ),
                ),
                _IntroFooter(
                  pageCount: _slideCount,
                  currentPage: _currentPage,
                  isLastPage: _isLastPage,
                  onSkip: _complete,
                  onDotTap: _goToIndex,
                  onNext: _onNext,
                ),
              ],
            );
          },
        ),
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
  final double heroWidth;

  const _IntroSlideView({required this.slide, required this.heroWidth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _ArchedHero(
                width: heroWidth,
                imageAsset: slide.imageAsset,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${slide.title} ${slide.titleRest}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _IntroFooter extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final bool isLastPage;
  final VoidCallback onSkip;
  final ValueChanged<int> onDotTap;
  final VoidCallback onNext;

  const _IntroFooter({
    required this.pageCount,
    required this.currentPage,
    required this.isLastPage,
    required this.onSkip,
    required this.onDotTap,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _FooterTextButton(label: 'Skip', onTap: onSkip, isPrimary: false),
          _PageDots(
            count: pageCount,
            current: currentPage,
            onTap: onDotTap,
          ),
          _FooterTextButton(
            label: isLastPage ? 'Get started' : 'Next',
            onTap: onNext,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _FooterTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _FooterTextButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPrimary) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            'Skip',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  const _PageDots({
    required this.count,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == current;
        return InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 28 : 18,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive ? AppColors.primary : AppColors.border,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ArchedHero extends StatelessWidget {
  final double width;
  final String imageAsset;

  const _ArchedHero({required this.width, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;
        final frameHeight = maxHeight.clamp(180.0, 320.0).toDouble();
        final imageSize = (frameHeight * 0.75).clamp(120.0, 240.0).toDouble();
        final top = (frameHeight - imageSize) * 0.15;

        return SizedBox(
          width: width,
          height: frameHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(width, frameHeight),
                painter: _ArchFramePainter(),
              ),
              Positioned(
                top: top,
                child: Image.asset(
                  imageAsset,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 80)
      ..quadraticBezierTo(size.width / 2, 0, size.width, 80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
