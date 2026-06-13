import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';

const Duration _kMinSplashDuration = Duration(milliseconds: 1500);
const Duration _kFadeInDuration = Duration(milliseconds: 500);
const Duration _kPulseDuration = Duration(milliseconds: 1600);

class AppLauncherScreen extends ConsumerStatefulWidget {
  const AppLauncherScreen({super.key});

  @override
  ConsumerState<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends ConsumerState<AppLauncherScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  Timer? _minSplashTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);

      _minSplashTimer = Timer(_kMinSplashDuration, () {
        if (!mounted) return;
        ref.invalidate(routerProvider);
      });
    });
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Stack(
        children: [
          const Positioned(
            top: -160,
            right: -140,
            child: _SoftGlow(
              size: 320,
              color: AppColors.primary,
              opacity: 0.08,
            ),
          ),
          const Positioned(
            bottom: -180,
            left: -120,
            child: _SoftGlow(
              size: 300,
              color: AppColors.info,
              opacity: 0.06,
            ),
          ),
          SafeArea(
            child: Center(
              child: AnimatedOpacity(
                duration: _kFadeInDuration,
                curve: Curves.easeOut,
                opacity: _visible ? 1 : 0,
                child: ScaleTransition(
                  scale: _pulse,
                  child: const _LauncherContent(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedOpacity(
                duration: _kFadeInDuration,
                opacity: _visible ? 1 : 0,
                child: const _LauncherFooter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LauncherContent extends StatelessWidget {
  const _LauncherContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'app_logo',
          child: SvgPicture.asset(
            'assets/images/delivro-logo.svg',
            width: 220,
            height: 64,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Delivery, simplified',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _LauncherFooter extends StatelessWidget {
  const _LauncherFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Powered by Delivro',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SoftGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
