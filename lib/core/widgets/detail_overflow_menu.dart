import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// One row in a [DetailOverflowMenu].
class DetailMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Destructive actions render in red and sit below a divider.
  final bool destructive;

  const DetailMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });
}

/// The three-dot menu used in the gradient header of detail screens. Sits in a
/// translucent circle so it reads against the gradient, and opens a rounded
/// card of icon + label rows with destructive actions set apart.
class DetailOverflowMenu extends StatelessWidget {
  final List<DetailMenuAction> actions;

  const DetailOverflowMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final normal = actions.where((a) => !a.destructive).toList();
    final destructive = actions.where((a) => a.destructive).toList();

    return PopupMenuButton<DetailMenuAction>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      padding: EdgeInsets.zero,
      icon: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      onSelected: (action) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        action.onSelected();
      },
      itemBuilder: (context) => [
        for (final action in normal)
          PopupMenuItem<DetailMenuAction>(
            value: action,
            height: 46,
            child: _MenuRow(action: action),
          ),
        if (normal.isNotEmpty && destructive.isNotEmpty)
          const PopupMenuDivider(height: 1),
        for (final action in destructive)
          PopupMenuItem<DetailMenuAction>(
            value: action,
            height: 46,
            child: _MenuRow(action: action),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final DetailMenuAction action;
  const _MenuRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? AppColors.error
        : AppColors.textPrimary;
    return Row(
      children: [
        Icon(
          action.icon,
          size: 18,
          color: action.destructive ? AppColors.error : AppColors.primary,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
