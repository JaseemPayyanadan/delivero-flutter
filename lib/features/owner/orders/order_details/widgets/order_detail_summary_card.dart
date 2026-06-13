import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../data/models/order.dart';
import 'order_detail_surfaces.dart';

class OrderDetailSummaryCard extends StatelessWidget {
  static const TextStyle _primaryDetailStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -0.35,
    height: 1.2,
  );

  final Order order;
  final String orderIdDisplay;
  final NumberFormat money0;
  final String routeLabel;
  final PaymentStatus paymentStatus;
  final Color paymentColor;
  final Color statusBg;
  final Color statusFg;
  final String statusLabel;
  final double balanceDue;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onViewCustomer;

  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    required this.orderIdDisplay,
    required this.money0,
    required this.routeLabel,
    required this.paymentStatus,
    required this.paymentColor,
    required this.statusBg,
    required this.statusFg,
    required this.statusLabel,
    required this.balanceDue,
    this.onPhoneTap,
    this.onViewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final name = order.customerName.trim();
    final route = routeLabel.trim();
    final phone = order.customerPhone.trim();
    final address = order.customerAddress.trim();
    final dateLine = DateFormat('EEEE, d MMM yyyy').format(order.orderDate);
    final orderTypeLabel = switch (order.orderType) {
      OrderType.daily => 'Daily',
      OrderType.oneTime => 'One-time',
      OrderType.special => 'Special',
    };
    final dueColor = paymentStatus == PaymentStatus.unpaid
        ? AppColors.error
        : AppColors.warning;
    final captionMuted = context.appTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
    );
    final showDue = paymentStatus != PaymentStatus.paid && balanceDue > 0.004;
    final hasCustomerInfo = name.isNotEmpty ||
        route.isNotEmpty ||
        phone.isNotEmpty ||
        address.isNotEmpty;
    final isDelivered = order.status == OrderStatus.delivered;

    return OrderDetailCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderDetailStatusPill(label: statusLabel, bg: statusBg, fg: statusFg),
          const SizedBox(height: 18),
          // Order ID + copy button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  orderIdDisplay,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.0,
                    height: 1.05,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: orderIdDisplay));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$orderIdDisplay copied'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$dateLine · $orderTypeLabel',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 22),
          Text('Order total', style: captionMuted.copyWith(letterSpacing: 0.35)),
          const SizedBox(height: 6),
          Text(
            money0.format(order.totalAmount),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -1.1,
              height: 1.05,
            ),
          ),
          if (showDue) ...[
            const SizedBox(height: 10),
            Text(
              paymentStatus == PaymentStatus.partial
                  ? '${money0.format(balanceDue)} balance due'
                  : '${money0.format(balanceDue)} due',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: dueColor,
                letterSpacing: -0.35,
              ),
            ),
          ],
          if (hasCustomerInfo) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            Text('Customer', style: captionMuted.copyWith(letterSpacing: 0.4)),
            const SizedBox(height: 10),
            if (name.isNotEmpty)
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _primaryDetailStyle,
              ),
            // Route — distinct style from name
            if (route.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    size: 14,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      route,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SummaryPhoneRow(phone: phone, onTap: onPhoneTap),
            ],
            // Delivery address
            if (address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // View customer link
            if (onViewCustomer != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onViewCustomer,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View customer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ],
          // Delivered timestamp
          if (isDelivered && order.deliveryTime != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivered · ${DateFormat('d MMM yyyy · HH:mm').format(order.deliveryTime!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
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

class _SummaryPhoneRow extends StatelessWidget {
  final String phone;
  final VoidCallback? onTap;

  const _SummaryPhoneRow({required this.phone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.phone_rounded,
            size: 16,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            phone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Semantics(
            button: true,
            label: 'Call $phone',
            child: row,
          ),
        ),
      ),
    );
  }
}
