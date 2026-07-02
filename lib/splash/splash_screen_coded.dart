import 'package:flutter/material.dart';

import 'animation_controller.dart';
import 'splash_layout.dart';
import 'widgets/background.dart';
import 'widgets/city.dart';
import 'widgets/hills.dart';
import 'widgets/location_pin.dart';
import 'widgets/logo.dart';
import 'widgets/road.dart';
import 'widgets/shield.dart';
import 'widgets/truck.dart';

/// Coded SVG fallback when the launcher video asset is unavailable.
class SplashScreenCoded extends StatefulWidget {
  const SplashScreenCoded({
    super.key,
    required this.onAnimationComplete,
  });

  final VoidCallback onAnimationComplete;

  @override
  State<SplashScreenCoded> createState() => _SplashScreenCodedState();
}

class _SplashScreenCodedState extends State<SplashScreenCoded>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final SplashAnimations _animations;
  bool _didNotifyComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = SplashAnimations.createController(this);
    _animations = SplashAnimations(controller: _controller);

    _controller.addStatusListener(_onStatusChanged);
    _controller.forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _didNotifyComplete) return;
    _didNotifyComplete = true;
    widget.onAnimationComplete();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = SplashLayout(MediaQuery.sizeOf(context));

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final a = _animations;
          final settleScale = 1.0 - (a.settle.value * 0.015);

          return Transform.scale(
            scale: settleScale,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SplashBackground(greenFade: a.backgroundGreen.value),
                _LandscapeLayer(
                  layout: layout,
                  cityOpacity: a.cityOpacity.value,
                  citySlide: a.citySlide.value,
                  hillsOpacity: a.hillsOpacity.value,
                  roadProgress: a.roadProgress.value,
                  truckProgress: a.truckProgress.value,
                  wheelRotation: a.wheelRotationFor(a.truckProgress.value),
                  suspensionOffset:
                      a.truckSuspensionOffset(a.truckProgress.value),
                ),
                Positioned(
                  left: layout.shieldPosition.dx,
                  top: layout.shieldPosition.dy,
                  child: SplashShield(
                    scale: a.shieldScale.value,
                    opacity: a.shieldOpacity.value,
                    glowStrength: a.shieldGlow.value,
                    size: layout.shieldSize,
                  ),
                ),
                Positioned(
                  left: layout.pinPosition.dx,
                  top: layout.pinPosition.dy,
                  child: SplashLocationPin(
                    bounceProgress: a.pinProgress.value,
                    opacity: a.pinOpacity.value,
                    size: layout.pinSize,
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: layout.height * 0.18),
                    child: SplashLogo(
                      opacity: a.logoOpacity.value,
                      scale: a.logoScale.value,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LandscapeLayer extends StatelessWidget {
  const _LandscapeLayer({
    required this.layout,
    required this.cityOpacity,
    required this.citySlide,
    required this.hillsOpacity,
    required this.roadProgress,
    required this.truckProgress,
    required this.wheelRotation,
    required this.suspensionOffset,
  });

  final SplashLayout layout;
  final double cityOpacity;
  final double citySlide;
  final double hillsOpacity;
  final double roadProgress;
  final double truckProgress;
  final double wheelRotation;
  final double suspensionOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: layout.landscapeTop,
      height: layout.landscapeHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SplashHills(opacity: hillsOpacity),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SplashCity(
              opacity: cityOpacity,
              slideOffset: citySlide,
            ),
          ),
          Positioned(
            left: 0,
            top: layout.roadCanvasTop - layout.landscapeTop,
            child: SplashRoad(
              progress: roadProgress,
              canvasSize: layout.roadCanvasSize,
            ),
          ),
          Positioned(
            left: 0,
            top: layout.roadCanvasTop - layout.landscapeTop,
            width: layout.roadCanvasSize.width,
            height: layout.roadCanvasSize.height,
            child: SplashTruck(
              progress: truckProgress,
              wheelRotation: wheelRotation,
              suspensionOffset: suspensionOffset,
              roadCanvasSize: layout.roadCanvasSize,
            ),
          ),
        ],
      ),
    );
  }
}
