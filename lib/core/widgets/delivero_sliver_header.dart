import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

class DeliveroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;

  const DeliveroAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.centerTitle = false,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.backgroundPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: AppTheme.systemOverlayStyle,
      centerTitle: centerTitle,
      leading: leading,
      title: titleWidget ??
          Text(
            title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                context.appTextStyles.sectionHeader.copyWith(letterSpacing: 0.2),
          ),
      actions: actions,
    );
  }
}

class DeliveroSliverHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double expandedHeight;
  final bool pinned;
  final bool floating;
  final bool centerTitle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry titlePadding;
  final Color backgroundColor;
  final Gradient? backgroundGradient;

  const DeliveroSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.expandedHeight = 140,
    this.pinned = true,
    this.floating = false,
    this.centerTitle = false,
    this.actions,
    this.titlePadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
    this.backgroundColor = AppColors.backgroundPrimary,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    // Default [kToolbarHeight] (56) is too short for our two-line title + padding
    // in [FlexibleSpaceBar]; a taller collapsed bar avoids bottom overflow when pinned.
    const collapsedToolbarHeight = 80.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      toolbarHeight: collapsedToolbarHeight,
      floating: floating,
      pinned: pinned,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: AppTheme.systemOverlayStyle,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: titlePadding,
        centerTitle: centerTitle,
        background: backgroundGradient == null
            ? null
            : Container(
                decoration: BoxDecoration(gradient: backgroundGradient),
              ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.sliverTitle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.sliverSubtitle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
