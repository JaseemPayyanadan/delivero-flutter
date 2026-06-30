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
    imageAsset: 'assets/images/slide-1.jpg',
  ),
  _IntroSlide(
    title: 'Track',
    titleRest: 'with confidence',
    subtitle:
        'Real-time status, verified drop-offs and clear proof of delivery on every order.',
    imageAsset: 'assets/images/slide-2.jpg',
  ),
  _IntroSlide(
    title: 'Deliver',
    titleRest: 'smiles',
    subtitle:
        'Hassle-free deliveries, happy customers and growing your business.',
    imageAsset: 'assets/images/slide-3.jpg',
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              AppColors.primary50,
            ],
            stops: [0.0, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroTopBar(
                showSkip: !_isLastPage,
                onSkip: _complete,
              ),
              const SizedBox(height: 12),
              _OnboardingStepper(
                labels: _kIntroSlides.map((s) => s.title).toList(),
                currentIndex: _currentPage,
                onTap: _goToIndex,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _slideCount,
                  itemBuilder: (context, index) {
                    return _IntroSlideView(slide: _kIntroSlides[index]);
                  },
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
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(count * 2 - 1, (i) {
                if (i.isOdd) {
                  final leftIndex = i ~/ 2;
                  final reached = leftIndex < currentIndex;
                  return Expanded(child: _StepConnector(reached: reached));
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
          const SizedBox(height: 10),
          Row(
            children: List.generate(count, (i) {
              final isActive = i == currentIndex;
              final isDone = i < currentIndex;
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : isDone
                            ? AppColors.textSecondary
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
    final size = isActive ? 34.0 : 30.0;
    final filled = isDone || isActive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.primary : AppColors.neutral100,
              border: Border.all(
                color: filled ? AppColors.primary : AppColors.neutral300,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: isActive ? 14 : 13,
                      fontWeight: FontWeight.w800,
                      color: filled ? Colors.white : AppColors.textLight,
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
      height: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: reached ? AppColors.primary : AppColors.neutral200,
      ),
    );
  }
}

class _IntroSlideView extends StatelessWidget {
  final _IntroSlide slide;

  const _IntroSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Image.asset(
              slide.imageAsset,
              width: double.infinity,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.15,
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
              const SizedBox(height: 10),
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
                    color: isActive
                        ? AppColors.primary
                        : AppColors.neutral300,
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
