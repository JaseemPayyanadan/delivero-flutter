import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user.dart';
import './firebase_service.dart';

class FactoryService {
  static final FirebaseFirestore _db = FirebaseService.firestore;

  /// Resolve factory ID from user context
  static Future<String> resolveFactoryId({
    String? providedFactoryId,
    User? user,
  }) async {
    // 1. Use provided factoryId if available
    if (providedFactoryId != null && providedFactoryId.isNotEmpty) {
      return providedFactoryId;
    }

    // 2. If no user context, cannot resolve
    if (user == null) {
      throw Exception(
        'Factory ID is required. Please provide factoryId or ensure user is logged in.',
      );
    }

    // 3. For owners, fetch from owner entity
    if (user.role == UserRole.owner) {
      if (user.linkedEntityId == null || user.linkedEntityId!.isEmpty) {
        throw Exception(
          'Owner user is missing linkedEntityId. Please contact support.',
        );
      }

      try {
        final doc = await _db
            .collection('owners')
            .doc(user.linkedEntityId)
            .get();

        if (!doc.exists) {
          throw Exception('Owner entity not found. Please contact support.');
        }

        final data = doc.data();
        final factoryId = data?['factoryId'] as String?;

        if (factoryId == null || factoryId.isEmpty) {
          throw Exception(
            'Owner entity is missing factoryId. Please contact support.',
          );
        }

        return factoryId;
      } catch (e) {
        throw Exception('Unable to determine factory: $e');
      }
    }

    // 4. For delivery drivers, fetch from driver entity
    if (user.role == UserRole.delivery) {
      if (user.linkedEntityId == null || user.linkedEntityId!.isEmpty) {
        throw Exception(
          'Delivery user is missing linkedEntityId. Please contact support.',
        );
      }

      try {
        final doc = await _db
            .collection('drivers')
            .doc(user.linkedEntityId)
            .get();

        if (!doc.exists) {
          throw Exception('Driver entity not found. Please contact support.');
        }

        final data = doc.data();
        final factoryId = data?['factoryId'] as String?;

        if (factoryId == null || factoryId.isEmpty) {
          throw Exception(
            'Driver entity is missing factoryId. Please contact support.',
          );
        }

        return factoryId;
      } catch (e) {
        throw Exception('Unable to determine factory: $e');
      }
    }

    // Fallback error
    throw Exception(
      'Factory ID is required. Unable to resolve from user context.',
    );
  }
}
