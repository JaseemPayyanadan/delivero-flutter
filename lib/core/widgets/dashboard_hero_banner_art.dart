import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const String kDashboardHeroBannerAsset = 'assets/images/hero-banner.png';

/// Vertical offset for the hero illustration block (increase to move down).
const double kDashboardHeroBannerTop = 170;
const double kDashboardHeroBannerHeight = 156;
const double kDashboardHeroBannerWidthFactor = 0.58;

/// Hero watermark opacity (0–1) — the illustration is tinted a deep purple and
/// used as a subtle tonal brand motif over the (lighter) lower gradient.
const double kDashboardHeroBannerOpacity = 0.20;

/// How far the white KPI card overlaps downward past the hero content.
const double kDashboardHeroKpiStripOffset = 56;

/// Bottom padding inside the hero so the KPI card is not clipped.
const double kDashboardHeroKpiStripBottomPadding = 76;

/// Top padding on the scroll content below the hero (clears KPI overlap).
const double kDashboardHeroKpiStripContentTopPadding = 64;

/// Purple vertical gradient for the dashboard hero (Fillo language).
const LinearGradient kDashboardHeroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    AppColors.dashboardHeroGradientStart,
    AppColors.dashboardHeroGradientMid,
    AppColors.dashboardHeroGradientEnd,
  ],
  stops: [0.0, 0.45, 1.0],
);

/// Purple vertical gradient for the dashboard hero (Fillo language).
class DashboardHeroBackground extends StatelessWidget {
  const DashboardHeroBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: kDashboardHeroGradient),
    );
  }
}

/// [hero-banner.png] tinted to a deep-purple tonal watermark for the hero.
///
/// The source art is green; tinting it deep purple with [BlendMode.srcIn] keeps
/// the silhouette but drops the clashing colour. It sits over the lighter lower
/// part of the gradient, so a darker tint reads as a quiet embossed brand motif
/// rather than a competing illustration.
class DashboardHeroBannerBlock extends StatelessWidget {
  const DashboardHeroBannerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kDashboardHeroBannerAsset,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      color: AppColors.primary900.withValues(
        alpha: kDashboardHeroBannerOpacity,
      ),
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}

/// Absolute hero illustration block — must be a direct child of the hero [Stack].
Positioned dashboardHeroBannerPositioned(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  return Positioned(
    right: 0,
    top: kDashboardHeroBannerTop,
    width: width * kDashboardHeroBannerWidthFactor,
    height: kDashboardHeroBannerHeight,
    child: const DashboardHeroBannerBlock(),
  );
}
