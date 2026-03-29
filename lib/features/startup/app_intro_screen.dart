import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';

class AppIntroScreen extends ConsumerStatefulWidget {
  const AppIntroScreen({super.key});

  @override
  ConsumerState<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends ConsumerState<AppIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_IntroSlide> _slides = const [
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutExpo,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    await ref.read(appStartupProvider.notifier).markAppIntroSeen();
    if (!mounted) return;
    context.go('/login');
  }

  void _goToIndex(int index) {
    final safe = index.clamp(0, _slides.length - 1);
    _pageController.animateToPage(
      safe,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentPage = safe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              children: [
                CustomPaint(
                  size: Size(width, height),
                  painter: _IntroBackgroundPainter(),
                ),
                Column(
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 220,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentPage = index),
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ArchedHero(
                                  width: width - 80,
                                  imageAsset: slide.imageAsset,
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      slide.title.characters.first,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        height: 1.06,
                                      ),
                                    ),
                                    Text(
                                      '${slide.title.substring(1)} ${slide.titleRest}',
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                        height: 1.06,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  slide.subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.55,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _complete,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(_slides.length, (i) {
                              final isActive = i == _currentPage;
                              return InkWell(
                                onTap: () => _goToIndex(i),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: isActive ? 32 : 24,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: isActive
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          _currentPage < _slides.length - 1
                              ? InkWell(
                                  onTap: _onNext,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: const [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _complete,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Get Started',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
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

class _ArchedHero extends StatelessWidget {
  final double width;
  final String imageAsset;

  const _ArchedHero({required this.width, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(width, 320), painter: _ArchFramePainter()),
          Positioned(
            top: 40,
            child: Image.asset(
              imageAsset,
              width: 240,
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

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

class _IntroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final primary = AppColors.primary;
    final accent = AppColors.accent;
    final light = AppColors.primaryLighter;

    void dot(double x, double y, double r, Color color, double opacity) {
      final p = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, p);
    }

    dot(size.width - 60, 100, 8, light, 0.3);
    dot(size.width - 40, 120, 6, light, 0.2);
    dot(size.width - 80, 140, 4, accent, 0.15);

    dot(40, size.height - 200, 10, light, 0.25);
    dot(60, size.height - 180, 7, primary, 0.1);
    dot(20, size.height - 160, 5, accent, 0.15);

    dot(size.width * 0.2, size.height * 0.4, 3, primary, 0.1);
    dot(size.width * 0.8, size.height * 0.35, 4, light, 0.2);
    dot(size.width * 0.15, size.height * 0.6, 5, accent, 0.12);
    dot(size.width * 0.85, size.height * 0.55, 3, primary, 0.15);

    final line1 = Paint()
      ..color = light.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.25,
        size.width * 0.6,
        size.height * 0.3,
      );
    canvas.drawPath(path1, line1);

    final line2 = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.75,
        size.width,
        size.height * 0.7,
      );
    canvas.drawPath(path2, line2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
