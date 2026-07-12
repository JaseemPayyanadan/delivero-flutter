import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Bold purple gradient header from the Fillo visual language.
///
/// Two overlap modes, both drawing the banner behind the status bar:
///
/// * **Avatar mode** (`avatar` + `belowAvatar`): a circular avatar straddles
///   the banner's bottom edge, left-aligned, with name/label content beneath
///   it on white. Used by the Profile screen.
/// * **Card mode** (`overlapChild`): a full-width child (e.g. a summary card)
///   rises up to straddle the banner's bottom edge — the mockup's
///   "card on a colored header" look. Used by Order details.
///
/// Designed to be the first item in a scroll view; it does not scroll or pin
/// on its own.
class DeliveroGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// Avatar mode: the straddling avatar and the content beneath it.
  final Widget? avatar;
  final Widget? belowAvatar;
  final double avatarSize;

  /// Card mode: a full-width child that overlaps the banner's bottom edge.
  final Widget? overlapChild;

  /// How far [overlapChild] rises into the banner.
  final double overlap;

  /// Height of the purple banner, excluding the status-bar inset.
  final double bannerHeight;

  /// Horizontal inset for the avatar / below content / overlap child.
  final double horizontalPadding;

  const DeliveroGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions,
    this.avatar,
    this.belowAvatar,
    this.overlapChild,
    this.avatarSize = 64,
    this.overlap = 40,
    this.bannerHeight = 92,
    this.horizontalPadding = 22,
  }) : assert(
         overlapChild != null || (avatar != null && belowAvatar != null),
         'Provide either overlapChild (card mode) or avatar + belowAvatar '
         '(avatar mode).',
       );

  Widget _banner(BuildContext context, double topInset, double height) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        height: topInset + height,
        padding: EdgeInsets.only(top: topInset, left: 4, right: 8),
        alignment: Alignment.topLeft,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryHeaderGradient,
        ),
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: subtitle == null
                    ? Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.appBarTitle.copyWith(
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.appBarTitle.copyWith(
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    // Card mode: banner with the overlap child straddling its bottom edge.
    if (overlapChild != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _banner(context, topInset, bannerHeight),
          Transform.translate(
            offset: Offset(0, -overlap),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                0,
              ),
              child: overlapChild,
            ),
          ),
        ],
      );
    }

    // Avatar mode.
    final bannerTotal = topInset + bannerHeight;
    const gapUnderAvatar = 12.0;
    final contentTopPadding = (avatarSize / 2) + gapUnderAvatar;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(context, topInset, bannerHeight),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                contentTopPadding,
                horizontalPadding,
                0,
              ),
              child: belowAvatar,
            ),
          ],
        ),
        Positioned(
          top: bannerTotal - (avatarSize / 2),
          left: horizontalPadding,
          child: SizedBox(width: avatarSize, height: avatarSize, child: avatar),
        ),
      ],
    );
  }
}
