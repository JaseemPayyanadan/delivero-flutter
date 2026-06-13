import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class OrderDetailBottomActions extends StatelessWidget {
  final bool isDelivered;
  final VoidCallback onMarkDelivered;
  final VoidCallback? onOpenMaps;
  final VoidCallback? onCancelOrder;

  const OrderDetailBottomActions({
    super.key,
    required this.isDelivered,
    required this.onMarkDelivered,
    this.onOpenMaps,
    this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Primary action — Deliver (always full width)
            SizedBox(
              width: double.infinity,
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
                label: Text(isDelivered ? 'Delivered' : 'Mark as delivered'),
              ),
            ),
            // Secondary action — Cancel (compact text button)
            if (onCancelOrder != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onCancelOrder,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Cancel order'),
              ),
            ],
            // Navigate — full width, secondary
            if (onOpenMaps != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenMaps,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLighter,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
