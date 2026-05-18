import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/order.dart';

String orderDetailHumanize(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

String orderDetailDisplayId(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty) return '#ORD-—';
  final upper = id.toUpperCase();
  if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
    return upper.startsWith('#') ? upper : '#$upper';
  }
  final short = upper.length > 4 ? upper.substring(0, 4) : upper;
  return '#ORD-$short';
}

Color orderDetailStatusAccent(OrderStatus status) {
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

Color orderDetailStatusBg(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warningLighter.withValues(alpha: 0.72);
    case OrderStatus.delivered:
      return AppColors.backgroundTertiary.withValues(alpha: 0.64);
    case OrderStatus.cancelled:
      return AppColors.errorLighter.withValues(alpha: 0.68);
    default:
      return AppColors.infoLighter.withValues(alpha: 0.68);
  }
}

Color orderDetailStatusFg(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return AppColors.warning;
    case OrderStatus.delivered:
      return AppColors.textSecondary;
    case OrderStatus.cancelled:
      return AppColors.error;
    default:
      return AppColors.info;
  }
}

Color orderDetailPaymentColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid:
      return AppColors.success;
    case PaymentStatus.partial:
      return AppColors.warning;
    case PaymentStatus.unpaid:
      return AppColors.error;
  }
}
