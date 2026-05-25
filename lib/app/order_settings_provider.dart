import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/orders/business_day.dart';
import '../core/services/order_day_reset_notification_service.dart';
import 'providers.dart';

/// Kitchen-day rollover hour (0–23) for the active factory.
final orderRolloverHourProvider =
    NotifierProvider<OrderRolloverHourNotifier, int>(
      OrderRolloverHourNotifier.new,
    );

class OrderRolloverHourNotifier extends Notifier<int> {
  String? _factoryId;

  @override
  int build() => kDefaultBusinessDayRolloverHour;

  static String prefsKey(String factoryId) =>
      'factory_${factoryId}_orderRolloverHour';

  Future<void> syncForFactory(String? factoryId) async {
    if (factoryId == null || factoryId.isEmpty) return;
    _factoryId = factoryId;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(prefsKey(factoryId));
    if (stored != null && stored >= 0 && stored <= 23) {
      state = stored;
    } else {
      state = kDefaultBusinessDayRolloverHour;
    }
    await _syncResetNotification();
  }

  Future<void> setRolloverHour(int hour) async {
    final factoryId = _factoryId ?? ref.read(authProvider).user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;
    final clamped = hour.clamp(0, 23);
    state = clamped;
    _factoryId = factoryId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey(factoryId), clamped);
    await _syncResetNotification();
  }

  Future<void> _syncResetNotification() async {
    await OrderDayResetNotificationService.instance.syncForOwner(
      user: ref.read(authProvider).user,
      rolloverHour: state,
    );
  }
}
