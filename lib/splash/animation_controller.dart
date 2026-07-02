import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

import 'splash_constants.dart';

/// Normalized timeline markers (0.0–1.0) for the ~5s fallback splash sequence.
abstract final class SplashTimeline {
  static const _ms = 5042.0;

  static const backgroundGreenStart = 430 / _ms;
  static const backgroundGreenEnd = 860 / _ms;

  static const cityStart = 860 / _ms;
  static const cityEnd = 1290 / _ms;

  static const hillsStart = 1290 / _ms;
  static const hillsEnd = 1720 / _ms;

  static const roadStart = 1720 / _ms;
  static const roadEnd = 2300 / _ms;

  static const truckStart = 2300 / _ms;
  static const truckEnd = 3170 / _ms;

  static const pinStart = 3170 / _ms;
  static const pinEnd = 3600 / _ms;

  static const shieldStart = 3600 / _ms;
  static const shieldEnd = 4030 / _ms;

  static const logoStart = 4030 / _ms;
  static const logoEnd = 4610 / _ms;

  static const settleStart = 4610 / _ms;
  static const settleEnd = 1.0;
}

/// All splash [Animation]s derived from a single master [AnimationController].
class SplashAnimations {
  SplashAnimations({required AnimationController controller})
      : _controller = controller {
    backgroundGreen = _interval(
      SplashTimeline.backgroundGreenStart,
      SplashTimeline.backgroundGreenEnd,
      curve: Curves.easeInOut,
    );

    cityOpacity = _interval(
      SplashTimeline.cityStart,
      SplashTimeline.cityEnd,
      curve: Curves.easeOut,
    );
    citySlide = _interval(
      SplashTimeline.cityStart,
      SplashTimeline.cityEnd,
      curve: Curves.easeOutCubic,
    );

    hillsOpacity = _interval(
      SplashTimeline.hillsStart,
      SplashTimeline.hillsEnd,
      curve: Curves.easeOut,
    );

    roadProgress = _interval(
      SplashTimeline.roadStart,
      SplashTimeline.roadEnd,
      curve: Curves.easeInOutCubic,
    );

    truckProgress = _interval(
      SplashTimeline.truckStart,
      SplashTimeline.truckEnd,
      curve: Curves.easeInOutCubic,
    );

    pinProgress = _interval(
      SplashTimeline.pinStart,
      SplashTimeline.pinEnd,
      curve: Curves.elasticOut,
    );
    pinOpacity = _interval(
      SplashTimeline.pinStart,
      SplashTimeline.pinEnd,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );

    shieldScale = _interval(
      SplashTimeline.shieldStart,
      SplashTimeline.shieldEnd,
      curve: Curves.easeOutBack,
    );
    shieldOpacity = _interval(
      SplashTimeline.shieldStart,
      SplashTimeline.shieldEnd,
      curve: Curves.easeOut,
    );
    shieldGlow = _interval(
      SplashTimeline.shieldStart,
      SplashTimeline.shieldEnd,
      curve: Curves.easeOut,
    );

    logoOpacity = _interval(
      SplashTimeline.logoStart,
      SplashTimeline.logoEnd,
      curve: Curves.easeOut,
    );
    logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      _interval(
        SplashTimeline.logoStart,
        SplashTimeline.logoEnd,
        curve: Curves.easeOutCubic,
      ),
    );

    settle = _interval(
      SplashTimeline.settleStart,
      SplashTimeline.settleEnd,
      curve: Curves.easeInOut,
    );
  }

  final AnimationController _controller;

  late final Animation<double> backgroundGreen;
  late final Animation<double> cityOpacity;
  late final Animation<double> citySlide;
  late final Animation<double> hillsOpacity;
  late final Animation<double> roadProgress;
  late final Animation<double> truckProgress;
  late final Animation<double> pinProgress;
  late final Animation<double> pinOpacity;
  late final Animation<double> shieldScale;
  late final Animation<double> shieldOpacity;
  late final Animation<double> shieldGlow;
  late final Animation<double> logoOpacity;
  late final Animation<double> logoScale;
  late final Animation<double> settle;

  AnimationController get controller => _controller;

  bool get isComplete => _controller.status == AnimationStatus.completed;

  Animation<double> _interval(
    double start,
    double end, {
    Curve curve = Curves.linear,
  }) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: curve),
    );
  }

  /// Wheel rotation turns proportionally to truck travel along the road.
  double wheelRotationFor(double truckT) {
    return truckT * 12 * 3.141592653589793;
  }

  /// Small vertical suspension bounce while the truck moves.
  double truckSuspensionOffset(double truckT) {
    if (truckT <= 0) return 0;
    return (1 - (truckT * 18 % 1.0).abs()) * 3.5;
  }

  static AnimationController createController(TickerProvider vsync) {
    return AnimationController(
      vsync: vsync,
      duration: SplashConstants.duration,
    );
  }
}
