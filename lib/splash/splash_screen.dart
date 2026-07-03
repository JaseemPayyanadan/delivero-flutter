import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:video_player/video_player.dart';

import 'splash_constants.dart';
import 'splash_screen_coded.dart';

/// Plays the reference launcher video (`delivero-launcher.mp4`) full-screen.
/// Falls back to the coded SVG animation if the asset fails to load.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onAnimationComplete});

  final VoidCallback onAnimationComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _useFallback = false;
  bool _didNotifyComplete = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(
      SplashConstants.launcherVideoAsset,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_onVideoUpdate);

      setState(() => _controller = controller);
      FlutterNativeSplash.remove();
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      FlutterNativeSplash.remove();
      setState(() => _useFallback = true);
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null || _didNotifyComplete) return;

    final value = controller.value;
    if (!value.isInitialized) return;

    final finished =
        value.isCompleted ||
        (value.duration > Duration.zero &&
            value.position >=
                value.duration - const Duration(milliseconds: 120));

    if (finished) {
      _notifyComplete();
    }
  }

  void _notifyComplete() {
    if (_didNotifyComplete) return;
    _didNotifyComplete = true;
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useFallback) {
      return SplashScreenCoded(onAnimationComplete: widget.onAnimationComplete);
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: SplashConstants.skyBackground,
        body: ColoredBox(color: SplashConstants.skyBackground),
      );
    }

    final size = controller.value.size;

    return Scaffold(
      backgroundColor: SplashConstants.skyBackground,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
