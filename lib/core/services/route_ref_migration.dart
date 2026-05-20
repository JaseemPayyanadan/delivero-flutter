import 'package:flutter/foundation.dart';

import '../../data/models/customer.dart';
import '../../data/models/delivery_route.dart';
import '../../data/models/order.dart';
import '../utils/route_refs.dart';
import 'firebase_service.dart';

/// One-time (per session) backfill: legacy route **names** → route **ids**.
abstract final class RouteRefMigration {
  RouteRefMigration._();

  static final Set<String> _syncedFactoryIds = {};
  static final Set<String> _inFlightFactoryIds = {};

  /// Planned Firestore update for a single customer or order document.
  @visibleForTesting
  static List<RouteRefMigrationTarget> planMigrationTargets({
    required List<DeliveryRoute> routes,
    required List<Customer> customers,
    required List<Order> orders,
  }) {
    final targets = <RouteRefMigrationTarget>[];

    for (final customer in customers) {
      final routeId = RouteRefs.routeIdForRef(customer.assignedRoute, routes);
      if (routeId == null) continue;
      final current = customer.assignedRoute?.trim();
      if (current == routeId) continue;
      targets.add(
        RouteRefMigrationTarget(
          collection: 'customers',
          id: customer.id,
          routeId: routeId,
        ),
      );
    }

    for (final order in orders) {
      final routeId = RouteRefs.routeIdForRef(order.assignedRoute, routes);
      if (routeId == null) continue;
      final current = order.assignedRoute?.trim();
      if (current == routeId) continue;
      targets.add(
        RouteRefMigrationTarget(
          collection: 'orders',
          id: order.id,
          routeId: routeId,
        ),
      );
    }

    return targets;
  }

  static bool needsSync({
    required List<DeliveryRoute> routes,
    required List<Customer> customers,
    required List<Order> orders,
  }) {
    if (routes.isEmpty) return false;
    for (final customer in customers) {
      if (RouteRefs.isLegacyOrUnknownRef(customer.assignedRoute, routes)) {
        return true;
      }
    }
    for (final order in orders) {
      if (RouteRefs.isLegacyOrUnknownRef(order.assignedRoute, routes)) {
        return true;
      }
    }
    return false;
  }

  /// Writes canonical route ids to Firestore when legacy name refs exist.
  static Future<void> syncIfNeeded({
    required String factoryId,
    required List<DeliveryRoute> routes,
    required List<Customer> customers,
    required List<Order> orders,
  }) async {
    if (routes.isEmpty) return;
    if (_syncedFactoryIds.contains(factoryId) ||
        _inFlightFactoryIds.contains(factoryId)) {
      return;
    }
    if (!needsSync(
      routes: routes,
      customers: customers,
      orders: orders,
    )) {
      _syncedFactoryIds.add(factoryId);
      return;
    }

    _inFlightFactoryIds.add(factoryId);
    try {
      final now = DateTime.now();
      final targets = planMigrationTargets(
        routes: routes,
        customers: customers,
        orders: orders,
      );

      if (targets.isEmpty) {
        _syncedFactoryIds.add(factoryId);
        return;
      }

      final writes =
          <({String collection, String id, Map<String, dynamic> data})>[];

      for (final target in targets) {
        if (target.collection == 'customers') {
          final customer = customers.firstWhere((c) => c.id == target.id);
          writes.add((
            collection: target.collection,
            id: target.id,
            data: Customer(
              id: customer.id,
              factoryId: customer.factoryId,
              name: customer.name,
              ownerName: customer.ownerName,
              email: customer.email,
              phone: customer.phone,
              address: customer.address,
              area: customer.area,
              isActive: customer.isActive,
              discountPercentage: customer.discountPercentage,
              assignedRoute: target.routeId,
              products: customer.products,
              createdAt: customer.createdAt,
              updatedAt: now,
            ).toJson(),
          ));
          continue;
        }

        final order = orders.firstWhere((o) => o.id == target.id);
        writes.add((
          collection: target.collection,
          id: target.id,
          data: order
              .copyWith(assignedRoute: target.routeId, updatedAt: now)
              .toJson(),
        ));
      }

      const chunkSize = 450;
      for (var i = 0; i < writes.length; i += chunkSize) {
        final batch = FirebaseService.firestore.batch();
        final chunk = writes.skip(i).take(chunkSize);
        for (final write in chunk) {
          batch.set(
            FirebaseService.firestore
                .collection(write.collection)
                .doc(write.id),
            write.data,
          );
        }
        await batch.commit();
      }

      debugPrint(
        '[RouteRefMigration] Normalized ${writes.length} route refs for $factoryId',
      );
      _syncedFactoryIds.add(factoryId);
    } catch (e, st) {
      debugPrint('[RouteRefMigration] Failed for $factoryId: $e\n$st');
    } finally {
      _inFlightFactoryIds.remove(factoryId);
    }
  }

  @visibleForTesting
  static void resetSessionState() {
    _syncedFactoryIds.clear();
    _inFlightFactoryIds.clear();
  }
}

@visibleForTesting
class RouteRefMigrationTarget {
  final String collection;
  final String id;
  final String routeId;

  const RouteRefMigrationTarget({
    required this.collection,
    required this.id,
    required this.routeId,
  });

  @override
  bool operator ==(Object other) {
    return other is RouteRefMigrationTarget &&
        other.collection == collection &&
        other.id == id &&
        other.routeId == routeId;
  }

  @override
  int get hashCode => Object.hash(collection, id, routeId);
}
