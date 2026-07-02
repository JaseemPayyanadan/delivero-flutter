import 'package:flutter/material.dart';

/// Shared timing, asset paths, and layout constants for the splash animation.
class SplashConstants {
  SplashConstants._();

  /// Reference launcher video duration (~5.04s).
  static const duration = Duration(milliseconds: 5042);

  static const launcherVideoAsset = 'assets/videos/delivero-launcher.mp4';

  static const skyBackground = Color(0xFFF5F5F5);

  static const logoAsset = 'assets/images/logo.svg';
  static const truckAsset = 'assets/images/truck.svg';
  static const cityAsset = 'assets/images/city.svg';
  static const hillsAsset = 'assets/images/hills.svg';
  static const roadAsset = 'assets/images/road.svg';
  static const pinAsset = 'assets/images/pin.svg';
  static const shieldAsset = 'assets/images/shield.svg';

  /// SVG viewBox for the curved road path (matches [road.svg]).
  static const roadViewBoxWidth = 600.0;
  static const roadViewBoxHeight = 180.0;

  /// Soft green tones used in the splash landscape.
  static const softGreenTop = 0xFFE8F5EE;
  static const softGreenBottom = 0xFFBEE5D1;
  static const pinOrange = 0xFFF7931E;
  static const shieldGreen = 0xFF0B7A4B;
}
