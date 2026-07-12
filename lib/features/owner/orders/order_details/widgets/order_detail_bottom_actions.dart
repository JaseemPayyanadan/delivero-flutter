import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Sticky bottom action bar: primary "Mark as Delivered" plus a "More" pill
/// that opens the secondary-actions sheet.
class OrderDetailBottomBar extends StatelessWidget {
  final bool isDelivered;
  final VoidCallback onMarkDelivered;
  final VoidCallback onMore;

  const OrderDetailBottomBar({
    super.key,
    required this.isDelivered,
    required this.onMarkDelivered,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isDelivered ? null : onMarkDelivered,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: AppColors.successLighter,
              disabledForegroundColor: AppColors.success,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            icon: Icon(
              isDelivered
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
            ),
            label: Text(isDelivered ? 'Delivered' : 'Mark as Delivered'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          label: const Text('More'),
        ),
      ],
    );
  }
}
