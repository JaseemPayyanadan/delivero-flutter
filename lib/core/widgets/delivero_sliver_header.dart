import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class DeliveroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;

  const DeliveroAppBar({
    super.key,
    required this.title,
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
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
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
  final List<Widget>? actions;
  final EdgeInsetsGeometry titlePadding;

  const DeliveroSliverHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.expandedHeight = 140,
    this.pinned = true,
    this.floating = false,
    this.actions,
    this.titlePadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: floating,
      pinned: pinned,
      backgroundColor: AppColors.backgroundPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: AppTheme.systemOverlayStyle,
      actions: actions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: titlePadding,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
