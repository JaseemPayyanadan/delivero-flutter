import 'package:collection/collection.dart';

import '../../../../data/models/customer.dart';
import '../../../../data/models/delivery_route.dart';
import '../../../../data/models/order.dart';

/// Precomputed route + payment figures for the order details screen.
class ResolvedOrderDetail {
  ResolvedOrderDetail({
    required this.route,
    required this.effectiveRoute,
    required this.summaryRouteLabel,
    required this.deliveryFee,
    required this.effectivePaid,
    required this.balanceDue,
    required this.paymentStatus,
  });

  final DeliveryRoute? route;
  final DeliveryRoute? effectiveRoute;
  final String summaryRouteLabel;
  final double deliveryFee;
  final double effectivePaid;
  final double balanceDue;
  final PaymentStatus paymentStatus;

  factory ResolvedOrderDetail.compute(
    Order order,
    List<DeliveryRoute> routes,
    List<Customer> customers,
  ) {
    final route = routes.firstWhereOrNull(
      (r) => r.id == order.assignedRoute || r.name == order.assignedRoute,
    );

    final derivedCustomerRoute =
        customers
            .firstWhereOrNull((c) => c.id == order.customerId)
            ?.assignedRoute
            ?.trim() ??
        customers
            .firstWhereOrNull(
              (c) => c.phone.trim() == order.customerPhone.trim(),
            )
            ?.assignedRoute
            ?.trim() ??
        customers
            .firstWhereOrNull(
              (c) =>
                  c.name.trim().toLowerCase() ==
                  order.customerName.trim().toLowerCase(),
            )
            ?.assignedRoute
            ?.trim();

    final effectiveRouteKey = (order.assignedRoute?.trim().isNotEmpty == true)
        ? order.assignedRoute!.trim()
        : derivedCustomerRoute;
    final effectiveRoute = effectiveRouteKey == null
        ? null
        : routes.firstWhereOrNull(
            (r) => r.id == effectiveRouteKey || r.name == effectiveRouteKey,
          );

    final summaryRouteLabel =
        (effectiveRoute ?? route)?.name ??
        (order.assignedRoute?.trim().isNotEmpty == true
            ? order.assignedRoute!.trim()
            : 'Unassigned');

    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;

    final deliveryFee =
        (order.totalAmount - order.subtotal + order.discountAmount).clamp(
      0.0,
      double.infinity,
    );

    final effectivePaid = switch (paymentStatus) {
      PaymentStatus.paid => order.totalAmount,
      PaymentStatus.unpaid => 0.0,
      PaymentStatus.partial => (order.amountPaid ?? 0.0).clamp(
        0.0,
        order.totalAmount,
      ),
    };
    final balanceDue = (order.totalAmount - effectivePaid).clamp(
      0.0,
      order.totalAmount,
    );

    return ResolvedOrderDetail(
      route: route,
      effectiveRoute: effectiveRoute,
      summaryRouteLabel: summaryRouteLabel,
      deliveryFee: deliveryFee,
      effectivePaid: effectivePaid,
      balanceDue: balanceDue,
      paymentStatus: paymentStatus,
    );
  }
}
