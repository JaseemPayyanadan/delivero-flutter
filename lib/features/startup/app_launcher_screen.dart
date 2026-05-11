import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_gradient_background.dart';

const Duration _kMinSplashDuration = Duration(milliseconds: 1500);
const Duration _kFadeInDuration = Duration(milliseconds: 450);
const Duration _kPulseDuration = Duration(milliseconds: 1400);

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
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);

      // Keep splash visible for a minimum duration to avoid flicker,
      // then ask the router to re-evaluate redirect targets.
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
      body: DeliveroGradientBackground(
        glowTop: 140,
        child: SafeArea(
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 220,
            height: 56,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Delivery, simplified',
          style: TextStyle(
            color: AppColors.surface.withValues(alpha: 0.85),
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.surface.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
