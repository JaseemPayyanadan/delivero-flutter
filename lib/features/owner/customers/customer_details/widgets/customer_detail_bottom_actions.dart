import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Sticky bottom action bar: primary "New order" plus a "More" pill that opens
/// the secondary-actions sheet.
class CustomerDetailBottomBar extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onMore;

  const CustomerDetailBottomBar({
    super.key,
    required this.onNewOrder,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onNewOrder,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
            label: const Text('New order'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            // The app theme makes outlined buttons full-width, which would
            // resolve to a tight infinite width in this unflexed Row slot.
            minimumSize: const Size(0, 48),
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
