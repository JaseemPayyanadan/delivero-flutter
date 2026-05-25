import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/orders/business_day.dart';
import '../../data/models/user.dart';
import 'local_notifications_service.dart';

/// Schedules a daily local notification when the kitchen order day resets.
class OrderDayResetNotificationService {
  OrderDayResetNotificationService._();

  static final OrderDayResetNotificationService instance =
      OrderDayResetNotificationService._();

  static String _notifyPrefsKey(String userId) => 'settings_${userId}_notify';

  Future<bool> _ownerNotificationsEnabled(String? userId) async {
    if (userId == null || userId.isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifyPrefsKey(userId)) ?? true;
  }

  /// Schedules or cancels the daily reset alert for the signed-in owner.
  Future<void> syncForOwner({
    required User? user,
    required int rolloverHour,
  }) async {
    if (kIsWeb) return;

    if (user == null || user.role != UserRole.owner) {
      await LocalNotificationsService.instance.cancelOrderDayReset();
      return;
    }

    final enabled = await _ownerNotificationsEnabled(user.id);
    if (!enabled) {
      await LocalNotificationsService.instance.cancelOrderDayReset();
      return;
    }

    await LocalNotificationsService.instance.scheduleOrderDayReset(
      rolloverHour: rolloverHour,
      timeLabel: formatOrderRolloverLabel(rolloverHour),
    );
  }
}
