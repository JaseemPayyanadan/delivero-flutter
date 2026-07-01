import 'package:flutter/material.dart';

const double kOtpBgAspectRatio = 1054 / 1210;

double otpImageHeightFor(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final width =
      mediaQuery.size.width +
      mediaQuery.padding.left +
      mediaQuery.padding.right;
  return width / kOtpBgAspectRatio;
}

class OtpIllustration extends StatelessWidget {
  const OtpIllustration({super.key});

  static const _assetPath = 'assets/images/opt-screen-bg.jpg';

  static double heightForContext(BuildContext context) => otpImageHeightFor(context);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width =
        mediaQuery.size.width +
        mediaQuery.padding.left +
        mediaQuery.padding.right;

    return Transform.translate(
      offset: Offset(-mediaQuery.padding.left, 0),
      child: SizedBox(
        width: width,
        child: Image.asset(
          _assetPath,
          width: width,
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
