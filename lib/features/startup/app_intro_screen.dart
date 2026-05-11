import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';

const List<_IntroSlide> _kIntroSlides = [
  _IntroSlide(
    title: 'Manage',
    titleRest: 'every delivery',
    subtitle:
        'Organize orders, assign drivers, and dispatch your team with a single tap.',
    imageAsset: 'assets/images/slide-1.webp',
  ),
  _IntroSlide(
    title: 'Track',
    titleRest: 'with confidence',
    subtitle:
        'Real-time status, verified drop-offs, and clear proof of delivery on every order.',
    imageAsset: 'assets/images/slide-2.webp',
  ),
  _IntroSlide(
    title: 'Deliver',
    titleRest: 'on time',
    subtitle:
        'Smart routes and live updates keep your fleet moving and customers happy.',
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
  bool get _isFirstPage => _currentPage == 0;

  @override
  void dispose() {
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

  void _goToIndex(int index) {
    final safe = index.clamp(0, _slideCount - 1);
    if (safe == _currentPage) return;
    _hapticLight();
    _pageController.animateToPage(
      safe,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
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
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroWidth = (constraints.maxWidth - 80).clamp(240.0, 360.0);
            return Column(
              children: [
                _IntroTopBar(
                  showSkip: !_isLastPage,
                  onSkip: _complete,
                ),
                const SizedBox(height: 14),
                _OnboardingStepper(
                  labels: _kIntroSlides.map((s) => s.title).toList(),
                  currentIndex: _currentPage,
                  onTap: _goToIndex,
                ),
                const SizedBox(height: 4),
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
                  isFirstPage: _isFirstPage,
                  isLastPage: _isLastPage,
                  onBack: _onBack,
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

class _IntroTopBar extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;

  const _IntroTopBar({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 140,
            height: 40,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showSkip ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepper extends StatelessWidget {
  final List<String> labels;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _OnboardingStepper({
    required this.labels,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = labels.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(count * 2 - 1, (i) {
                if (i.isOdd) {
                  final leftIndex = i ~/ 2;
                  final reached = leftIndex < currentIndex;
                  return Expanded(
                    child: _StepConnector(reached: reached),
                  );
                }
                final stepIndex = i ~/ 2;
                return _StepDot(
                  index: stepIndex,
                  currentIndex: currentIndex,
                  onTap: () => onTap(stepIndex),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(count, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textLight,
                    letterSpacing: 0.2,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _StepDot({
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final isDone = index < currentIndex;
    final size = isActive ? 32.0 : 26.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone || isActive
                  ? AppColors.primary
                  : AppColors.surface,
              border: Border.all(
                color: isDone || isActive
                    ? AppColors.primary
                    : AppColors.border,
                width: 1.4,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: isActive ? 14 : 12,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? Colors.white
                          : AppColors.textLight,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool reached;
  const _StepConnector({required this.reached});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: reached ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

class _IntroSlideView extends StatelessWidget {
  final _IntroSlide slide;
  final double heroWidth;

  const _IntroSlideView({
    required this.slide,
    required this.heroWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _ArchedHero(
                width: heroWidth,
                imageAsset: slide.imageAsset,
              ),
            ),
          ),
          const SizedBox(height: 18),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
                height: 1.05,
              ),
              children: [
                TextSpan(
                  text: slide.title,
                  style: const TextStyle(color: AppColors.primary),
                ),
                const TextSpan(text: ' '),
                TextSpan(text: slide.titleRest),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
  final bool isFirstPage;
  final bool isLastPage;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _IntroFooter({
    required this.isFirstPage,
    required this.isLastPage,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Row(
        children: [
          AnimatedOpacity(
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
          const Spacer(),
          _PrimaryPillButton(
            label: isLastPage ? 'Get started' : 'Continue',
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
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryGradientStart,
                AppColors.primaryGradientEnd,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
              const SizedBox(width: 10),
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
        final imageSize = (frameHeight * 0.78).clamp(140.0, 260.0).toDouble();
        final top = (frameHeight - imageSize) * 0.18;

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
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, 80)
      ..quadraticBezierTo(size.width / 2, 0, size.width, 80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
