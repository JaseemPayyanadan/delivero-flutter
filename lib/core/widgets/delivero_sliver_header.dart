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
  final double leadingSlotWidth;
  final Color backgroundColor;

  const DeliveroAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.centerTitle = false,
    this.actions,
    this.leading,
    this.leadingSlotWidth = kToolbarHeight,
    this.backgroundColor = AppColors.backgroundPrimary,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final actionsCount = actions?.length ?? 0;
    final leftPad = leading == null ? 0.0 : leadingSlotWidth;
    // IconButtons are typically ~56 logical pixels wide.
    final rightPad = actionsCount <= 0 ? 0.0 : (actionsCount * 56.0);

    final Widget resolvedTitle =
        titleWidget ??
        Text(
          title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.appTextStyles.appBarTitle.copyWith(
            letterSpacing: -0.5,
          ),
        );

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: AppTheme.systemOverlayStyle,
      centerTitle: centerTitle,
      leading:
          leading ??
          (Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      title: centerTitle
          ? Padding(
              padding: EdgeInsets.only(left: leftPad, right: rightPad),
              child: Align(alignment: Alignment.center, child: resolvedTitle),
            )
          : resolvedTitle,
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
