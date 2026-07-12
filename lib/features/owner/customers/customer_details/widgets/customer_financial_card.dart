import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Money-at-a-glance card: outstanding, lifetime value, order count, last order.
class CustomerFinancialCard extends StatelessWidget {
  final int totalOrders;
  final double lifetimeValue;
  final double outstanding;
  final DateTime? lastOrderDate;
  final NumberFormat money;

  const CustomerFinancialCard({
    super.key,
    required this.totalOrders,
    required this.lifetimeValue,
    required this.outstanding,
    required this.lastOrderDate,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = outstanding > 0.004;

    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DetailSectionHeader(title: 'Financial'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Outstanding',
                  value: money.format(outstanding),
                  valueColor: hasDue ? AppColors.error : AppColors.success,
                  emphasis: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  label: 'Lifetime value',
                  value: money.format(lifetimeValue),
                  valueColor: AppColors.primary,
                  emphasis: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Total orders',
                  value: '$totalOrders',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Tile(
                  label: 'Last order',
                  value: lastOrderDate == null
                      ? '—'
                      : DateFormat('d MMM yy').format(lastOrderDate!),
                  valueColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool emphasis;

  const _Tile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: emphasis ? 19 : 17,
                color: valueColor,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
