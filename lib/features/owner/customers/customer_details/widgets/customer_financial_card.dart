import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Money at a glance. Outstanding is the headline — it is the only number the
/// owner can act on — with lifetime value, order count and last order as a
/// supporting stat strip.
class CustomerFinancialCard extends StatelessWidget {
  final int totalOrders;
  final double lifetimeValue;
  final double outstanding;
  final DateTime? lastOrderDate;
  final NumberFormat money;

  /// Opens the "record a payment" flow. Null when nothing is owed.
  final VoidCallback? onCollect;

  const CustomerFinancialCard({
    super.key,
    required this.totalOrders,
    required this.lifetimeValue,
    required this.outstanding,
    required this.lastOrderDate,
    required this.money,
    this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = outstanding > 0.004;
    final accent = hasDue ? AppColors.error : AppColors.success;

    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DetailSectionHeader(title: 'Financial'),
          const SizedBox(height: 14),

          // Headline: what this customer still owes.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OUTSTANDING',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.0,
                          color: accent.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money.format(outstanding),
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            color: accent,
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDue ? 'Balance to collect' : 'All settled up',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (hasDue && onCollect != null)
                  FilledButton(
                    onPressed: onCollect,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 0,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('Collect'),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasDue
                          ? Icons.account_balance_wallet_rounded
                          : Icons.verified_rounded,
                      color: accent,
                      size: 21,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Supporting stats, separated by hairlines rather than boxes.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Lifetime',
                    value: money.format(lifetimeValue),
                    valueColor: AppColors.primary,
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(label: 'Orders', value: '$totalOrders'),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(
                    label: 'Last order',
                    value: lastOrderDate == null
                        ? '—'
                        : DateFormat('d MMM').format(lastOrderDate!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 9.5,
            letterSpacing: 0.9,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.divider,
    );
  }
}
