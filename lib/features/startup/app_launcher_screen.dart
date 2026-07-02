import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/launcher_animation.dart';
import '../../splash/splash_screen.dart';

/// App bootstrap splash — plays the Delivro launcher animation while
/// startup/auth providers initialize, then hands off to [GoRouter].
class AppLauncherScreen extends ConsumerStatefulWidget {
  const AppLauncherScreen({super.key});

  @override
  ConsumerState<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends ConsumerState<AppLauncherScreen> {
  bool _didMarkComplete = false;

  void _onAnimationComplete() {
    if (!mounted || _didMarkComplete) return;
    _didMarkComplete = true;
    ref.read(launcherAnimationCompleteProvider.notifier).markComplete();
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onAnimationComplete: _onAnimationComplete);
  }
}
