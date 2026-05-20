import 'package:collection/collection.dart';

import '../../../../core/utils/route_refs.dart';
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
    final route = RouteRefs.routeForRef(order.assignedRoute, routes);

    final derivedCustomerRoute =
        RouteRefs.routeIdForRef(
          customers
              .firstWhereOrNull((c) => c.id == order.customerId)
              ?.assignedRoute,
          routes,
        ) ??
        RouteRefs.routeIdForRef(
          customers
              .firstWhereOrNull(
                (c) => c.phone.trim() == order.customerPhone.trim(),
              )
              ?.assignedRoute,
          routes,
        ) ??
        RouteRefs.routeIdForRef(
          customers
              .firstWhereOrNull(
                (c) =>
                    c.name.trim().toLowerCase() ==
                    order.customerName.trim().toLowerCase(),
              )
              ?.assignedRoute,
          routes,
        );

    final effectiveRouteKey =
        RouteRefs.routeIdForRef(order.assignedRoute, routes) ??
        derivedCustomerRoute;
    final effectiveRoute = RouteRefs.routeForRef(effectiveRouteKey, routes);

    final summaryRouteLabel = RouteRefs.routeLabelForRef(
      effectiveRouteKey ?? order.assignedRoute,
      routes,
    );

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
