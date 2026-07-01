import 'package:flutter/material.dart';

const double kLoginBgAspectRatio = 1556 / 1674;

double loginImageHeightFor(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final width =
      mediaQuery.size.width +
      mediaQuery.padding.left +
      mediaQuery.padding.right;
  return width / kLoginBgAspectRatio;
}

class LoginIllustration extends StatelessWidget {
  const LoginIllustration({super.key});

  static const _assetPath = 'assets/images/login-bg.png';

  static double heightForContext(BuildContext context) =>
      loginImageHeightFor(context);

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
