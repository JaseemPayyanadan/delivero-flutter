import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Shows on-device notifications with sound. Used to alert the user when a
/// new order arrives or an existing order's status changes, regardless of
/// whether the change came from this device, another device, or the backend.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  static const String _orderChannelId = 'delivero_orders_high';
  static const String _orderChannelName = 'Order alerts';
  static const String _orderChannelDescription =
      'Alerts for new orders and order status changes';

  /// Fixed id for the daily kitchen-day reset notification.
  static const int orderDayResetNotificationId = 91001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timeZonesReady = false;
  int _notificationCounter = 1;
  void Function(String? payload)? _onNotificationTap;

  void setNotificationTapHandler(void Function(String? payload)? handler) {
    _onNotificationTap = handler;
  }

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTap?.call(response.payload);
      },
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _orderChannelId,
        _orderChannelName,
        description: _orderChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> _ensureTimeZones() async {
    if (_timeZonesReady || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notifications] Timezone fallback: $e');
      }
    }
    _timeZonesReady = true;
  }

  tz.TZDateTime _nextDailyRollover(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Daily reminder when a new order day starts (owner kitchen reset).
  Future<void> scheduleOrderDayReset({
    required int rolloverHour,
    required String timeLabel,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }
    await _ensureTimeZones();

    await _plugin.cancel(id: orderDayResetNotificationId);

    final clampedHour = rolloverHour.clamp(0, 23);
    final scheduled = _nextDailyRollover(clampedHour);

    await _plugin.zonedSchedule(
      id: orderDayResetNotificationId,
      title: 'New order day started',
      body:
          'Kitchen day reset at $timeLabel. Daily orders are recreated automatically.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _orderChannelId,
          _orderChannelName,
          channelDescription: _orderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'order_day_reset',
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'order_day_reset',
    );

    if (kDebugMode) {
      debugPrint(
        '[Notifications] Order day reset scheduled daily at $timeLabel ($scheduled)',
      );
    }
  }

  Future<void> cancelOrderDayReset() async {
    if (kIsWeb) return;
    if (!_initialized) return;
    await _plugin.cancel(id: orderDayResetNotificationId);
  }

  Future<void> showOrderAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }

    final id = _notificationCounter++ & 0x7fffffff;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _orderChannelId,
          _orderChannelName,
          channelDescription: _orderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'order',
          category: AndroidNotificationCategory.event,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      payload: payload,
    );
  }
}
