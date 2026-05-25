import 'package:delivero/core/orders/business_day.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  group('businessDayKey', () {
    test('before 7 AM belongs to previous calendar day', () {
      expect(
        businessDayKey(DateTime(2025, 6, 21, 6), rolloverHour: 7),
        DateTime(2025, 6, 20),
      );
    });

    test('at and after 7 AM belongs to same calendar day', () {
      expect(
        businessDayKey(DateTime(2025, 6, 21, 7), rolloverHour: 7),
        DateTime(2025, 6, 21),
      );
      expect(
        businessDayKey(DateTime(2025, 6, 21, 18), rolloverHour: 7),
        DateTime(2025, 6, 21),
      );
    });
  });

  group('canModifyOrderItems', () {
    test('blocks editing pre-7 AM order after today\'s 7 AM', () {
      final order = productionTestOrder(
        orderDate: DateTime(2025, 6, 20, 6),
      );
      expect(
        canModifyOrderItems(
          order,
          referenceTime: DateTime(2025, 6, 20, 10),
          rolloverHour: 7,
        ),
        isFalse,
      );
    });

    test('allows editing order placed after 7 AM same day', () {
      final order = productionTestOrder(
        orderDate: DateTime(2025, 6, 20, 8),
      );
      expect(
        canModifyOrderItems(
          order,
          referenceTime: DateTime(2025, 6, 20, 10),
          rolloverHour: 7,
        ),
        isTrue,
      );
    });
  });
}
