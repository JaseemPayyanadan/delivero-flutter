import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../painter/road_painter.dart';
import '../splash_constants.dart';
import 'wheels.dart';

/// Delivery truck that follows the curved road with rotating wheels.
class SplashTruck extends StatelessWidget {
  const SplashTruck({
    super.key,
    required this.progress,
    required this.wheelRotation,
    required this.suspensionOffset,
    required this.roadCanvasSize,
  });

  /// 0 = off-screen left, 1 = end of road segment.
  final double progress;
  final double wheelRotation;
  final double suspensionOffset;
  final Size roadCanvasSize;

  static const _truckViewBoxWidth = 180.0;
  static const _truckViewBoxHeight = 100.0;
  static const _frontWheelCenter = Offset(35, 76);
  static const _rearWheelCenter = Offset(125, 76);

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final truckWidth = roadCanvasSize.width * 0.28;
    final truckHeight = truckWidth * (_truckViewBoxHeight / _truckViewBoxWidth);
    final wheelDiameter = truckWidth * (20 / _truckViewBoxWidth);

    final roadT = (progress * 0.86 + 0.02).clamp(0.0, 1.0);
    final sample = splashRoadSample(roadCanvasSize, roadT);
    final angle = sample.angle;

    final anchor = Offset(
      sample.position.dx,
      sample.position.dy + suspensionOffset,
    );

    Offset wheelLocal(Offset svgCenter) {
      return Offset(
        (svgCenter.dx / _truckViewBoxWidth) * truckWidth - truckWidth * 0.42,
        (svgCenter.dy / _truckViewBoxHeight) * truckHeight - truckHeight * 0.72,
      );
    }

    return RepaintBoundary(
      child: Transform.translate(
        offset: anchor,
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(-truckWidth * 0.42, -truckHeight * 0.72),
                child: SvgPicture.asset(
                  SplashConstants.truckAsset,
                  width: truckWidth,
                  height: truckHeight,
                  fit: BoxFit.contain,
                ),
              ),
              Transform.translate(
                offset:
                    wheelLocal(_frontWheelCenter) -
                    Offset(wheelDiameter / 2, wheelDiameter / 2),
                child: SplashWheel(
                  rotation: wheelRotation,
                  diameter: wheelDiameter,
                ),
              ),
              Transform.translate(
                offset:
                    wheelLocal(_rearWheelCenter) -
                    Offset(wheelDiameter / 2, wheelDiameter / 2),
                child: SplashWheel(
                  rotation: wheelRotation,
                  diameter: wheelDiameter,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
