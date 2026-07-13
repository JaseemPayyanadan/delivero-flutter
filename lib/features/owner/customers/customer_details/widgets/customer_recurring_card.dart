import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';
import '../../../../../data/models/customer.dart';
import '../../../../../data/models/product_unit.dart';

/// The customer's standing order: item rows plus frequency and per-delivery
/// estimate.
class CustomerRecurringCard extends StatelessWidget {
  final List<CustomerProduct> items;
  final Map<String, ProductUnit> unitById;
  final String scheduleLabel;
  final double? estimatedPerDelivery;

  const CustomerRecurringCard({
    super.key,
    required this.items,
    required this.unitById,
    required this.scheduleLabel,
    required this.estimatedPerDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailSectionHeader(
            title: 'Recurring order',
            trailing: items.isEmpty
                ? null
                : '${items.length} ${items.length == 1 ? 'item' : 'items'}',
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'No recurring items set yet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            for (final item in items.take(3)) ...[
              _ItemRow(
                name: item.name,
                quantity: item.quantity,
                unit: unitById[item.id] ?? ProductUnit.quantity,
              ),
              const SizedBox(height: 10),
            ],
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '+${items.length - 3} more items',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _MetaPair(
                    label: 'Frequency',
                    value: scheduleLabel == '—'
                        ? 'Weekly'
                        : 'Weekly ($scheduleLabel)',
                  ),
                ),
                Expanded(
                  child: _MetaPair(
                    label: 'Estimated total',
                    value: estimatedPerDelivery == null
                        ? '—'
                        : '₹${NumberFormat.compact().format(estimatedPerDelivery)} /deliv.',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String name;
  final int quantity;
  final ProductUnit unit;

  const _ItemRow({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_rounded,
            size: 18,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unit.compactAmount(quantity),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPair extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _MetaPair({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1.0,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
