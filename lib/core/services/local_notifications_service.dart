import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _notificationCounter = 1;

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
