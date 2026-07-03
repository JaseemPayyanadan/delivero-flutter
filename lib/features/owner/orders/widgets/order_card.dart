import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/orders/order_line_key.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../data/models/order.dart';

class OrderCard extends ConsumerWidget {
  final Order order;
  final List<Order> siblingOrders;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEnterSelectMode;

  const OrderCard({
    super.key,
    required this.order,
    this.siblingOrders = const [],
    this.isSelected = false,
    this.onToggleSelect,
    this.onEnterSelectMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTouched = ref.watch(lastTouchedOrderProvider);
    final shouldHighlight =
        lastTouched != null &&
        lastTouched.id == order.id &&
        DateTime.now().difference(lastTouched.at) <= const Duration(seconds: 8);
    final highlightColor = lastTouched?.wasCreated == true
        ? AppColors.success
        : AppColors.primary;

    final customerName = order.customerName.trim().isEmpty
        ? 'Unknown'
        : order.customerName.trim();
    final statusText = order.status.label;

    final displayId = _displayOrderId(order.id);

    final typeKind = switch (order.orderType) {
      OrderType.daily => 'Daily',
      OrderType.oneTime => 'One-time',
      OrderType.special => 'Special',
    };
    final typeLabel = '${order.deliveryRun.label} · $typeKind';

    final statusChipBg = switch (order.status) {
      OrderStatus.pending => AppColors.warning,
      _ => _getStatusColor(order.status),
    };
    final statusChipFg = _chipTextColor(statusChipBg);

    final dateLabel = DateFormat('EEE, d MMM').format(order.orderDate);
    final metaLine = '$displayId · $dateLabel';

    final payment = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(payment);
    final paymentChipFg = _chipTextColor(paymentColor);
    final paymentLabel = switch (payment) {
      PaymentStatus.paid => 'Paid',
      PaymentStatus.partial => 'Partial',
      PaymentStatus.unpaid => 'Unpaid',
    };

    const previewMax = 3;
    final previewItems = order.items.take(previewMax).toList();
    final moreLines = order.items.length - previewItems.length;
    const emptyLineItemsText = '—';
    final lineItemParts = previewItems.isEmpty
        ? const <String>[]
        : [
            ...previewItems.map(
              (i) =>
                  '${displayNameWithPackLabel(i.foodItemName, i.packLabel)} ${i.unit.compactAmount(i.quantity)}',
            ),
            if (moreLines > 0) '+$moreLines more',
          ];

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: shouldHighlight
                ? highlightColor.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: shouldHighlight
                  ? highlightColor.withValues(alpha: 0.75)
                  : AppColors.border.withValues(alpha: 0.7),
              width: shouldHighlight ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap:
                  onToggleSelect ??
                  () => context.push('/owner/orders/${order.id}'),
              onLongPress: onEnterSelectMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.successLighter,
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.success,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metaLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusChipBg.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusChipFg,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: AppColors.textLight,
                                    size: 20,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'details') {
                                      context.push('/owner/orders/${order.id}');
                                    } else if (value == 'select') {
                                      onEnterSelectMode?.call();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Text('View details'),
                                    ),
                                    if (onEnterSelectMode != null)
                                      const PopupMenuItem(
                                        value: 'select',
                                        child: Text('Select'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _deliveryRunIcon(order.deliveryRun),
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Payment',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: paymentColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: paymentColor.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          paymentLabel,
                                          style: TextStyle(
                                            color: paymentChipFg,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatRupee(order.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: AppColors.successDark,
                                        letterSpacing: -0.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.border.withValues(alpha: 0.65),
                              ),
                            ),
                            const Text(
                              'LINE ITEMS',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                color: AppColors.successDark,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                const textStyle = TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.1,
                                  height: 1.35,
                                );
                                final separatorStyle = textStyle.copyWith(
                                  color: AppColors.textLight,
                                );

                                if (lineItemParts.isEmpty) {
                                  return const Text(
                                    emptyLineItemsText,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle,
                                  );
                                }

                                final spans = <TextSpan>[];
                                for (int i = 0; i < lineItemParts.length; i++) {
                                  if (i > 0) {
                                    spans.add(
                                      TextSpan(
                                        text: ' | ',
                                        style: separatorStyle,
                                      ),
                                    );
                                  }
                                  spans.add(TextSpan(text: lineItemParts[i]));
                                }

                                return Text.rich(
                                  TextSpan(children: spans),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onToggleSelect != null)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textLight,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }
}

IconData _deliveryRunIcon(DeliveryRun run) {
  return switch (run) {
    DeliveryRun.morning => Icons.wb_sunny_outlined,
    DeliveryRun.afternoon => Icons.wb_twilight_rounded,
    DeliveryRun.evening => Icons.nights_stay_outlined,
    DeliveryRun.night => Icons.bedtime_outlined,
  };
}

String _displayOrderId(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty) return '#ORD-—';
  final upper = id.toUpperCase();
  if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
    return upper.startsWith('#') ? upper : '#$upper';
  }
  final short = upper.length > 4 ? upper.substring(0, 4) : upper;
  return '#ORD-$short';
}

Color _getPaymentColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid:
      return AppColors.success;
    case PaymentStatus.partial:
      return AppColors.warning;
    case PaymentStatus.unpaid:
      return AppColors.error;
  }
}

Color _getStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warning;
    case OrderStatus.delivered:
      return AppColors.success;
    case OrderStatus.cancelled:
      return AppColors.error;
    default:
      return AppColors.info;
  }
}

Color _chipTextColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  if (hsl.lightness > 0.6) {
    return hsl.withLightness(0.35).toColor();
  }
  return base;
}
