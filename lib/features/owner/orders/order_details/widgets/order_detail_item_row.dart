import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../../../../../data/models/product_unit.dart';

class OrderDetailItemRow extends StatelessWidget {
  final OrderItem item;

  const OrderDetailItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: Text(
              item.unit == ProductUnit.quantity
                  ? '${item.quantity}x'
                  : item.unit.formatAmount(item.quantity),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodItemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                if ((item.packLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.packLabel!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  item.unit == ProductUnit.quantity
                      ? '${money0.format(item.unitPrice)} × ${item.quantity}'
                      : '${money0.format(item.unitPrice)} × ${item.unit.formatAmount(item.quantity)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            money0.format(item.totalPrice),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
