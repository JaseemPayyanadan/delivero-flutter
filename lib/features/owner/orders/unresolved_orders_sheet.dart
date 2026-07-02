import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/orders/daily_order_recreation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

class UnresolvedOrdersSheet extends ConsumerWidget {
  /// IDs of the unresolved orders to track. The sheet watches live provider
  /// state so rows disappear as the owner resolves each one.
  final List<String> orderIds;

  /// Copy is configurable so the same sheet works both for the yesterday→today
  /// rollover and for the "resolve today before generating the next day" flow.
  final String title;
  final String subtitle;
  final String doneLabel;

  const UnresolvedOrdersSheet({
    super.key,
    required this.orderIds,
    this.title = 'Unresolved orders from yesterday',
    this.subtitle =
        "Review and update each order before today's orders are created.",
    this.doneLabel = "Done — create today's orders",
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOrders = ref.watch(ordersProvider);
    final unresolved = allOrders
        .where(
          (o) =>
              orderIds.contains(o.id) &&
              kUnresolvedOrderStatuses.contains(o.status),
        )
        .toList();

    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: unresolved.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'All resolved — tap Done to continue.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: unresolved.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _UnresolvedOrderRow(
                        order: unresolved[i],
                        money0: money0,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                child: Text(doneLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnresolvedOrderRow extends ConsumerWidget {
  final Order order;
  final NumberFormat money0;

  const _UnresolvedOrderRow({required this.order, required this.money0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemSummary = order.items.isEmpty
        ? '—'
        : order.items
                .take(2)
                .map((i) => '${i.foodItemName} ${i.unit.compactAmount(i.quantity)}')
                .join(', ') +
            (order.items.length > 2
                ? ' +${order.items.length - 2} more'
                : '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName.trim().isEmpty
                      ? 'Unknown'
                      : order.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                money0.format(order.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            itemSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    try {
                      HapticFeedback.lightImpact();
                    } catch (_) {}
                    ref.read(ordersProvider.notifier).updateOrder(
                          order.copyWith(
                            status: OrderStatus.cancelled,
                            updatedAt: DateTime.now(),
                          ),
                        );
                  },
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    try {
                      HapticFeedback.mediumImpact();
                    } catch (_) {}
                    final now = DateTime.now();
                    ref.read(ordersProvider.notifier).updateOrder(
                          order.copyWith(
                            status: OrderStatus.delivered,
                            deliveryTime: order.deliveryTime ?? now,
                            deliveryDate: order.deliveryDate ?? now,
                            updatedAt: now,
                          ),
                        );
                  },
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                  ),
                  label: const Text('Delivered'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
