import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Elevated white card used as the section container on detail screens.
class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Title row that sits inset at the top of a [DetailCard].
class DetailSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  final IconData? icon;

  const DetailSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.trailingWidget,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: context.appTextStyles.sectionHeader.copyWith(
              fontSize: 15,
              letterSpacing: -0.35,
              height: 1.2,
            ),
          ),
        ),
        if (trailingWidget != null)
          trailingWidget!
        else if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.1,
            ),
          ),
      ],
    );
  }
}
