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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 18),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Text(
                'Delivery',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDelivered ? null : onMarkDelivered,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textLight,
                ),
                icon: Icon(
                  isDelivered
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  isDelivered ? 'Delivered' : 'Mark as Delivered',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (onOpenMaps != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenMaps,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLighter,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            if (onCancelOrder != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onCancelOrder,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel Order'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
